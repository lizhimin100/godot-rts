# Phase 5 — MovementForce Pipeline（建议力生命周期流水线）报告

## 概述

本阶段建立了 **MovementForce Pipeline**，作为所有建议力的唯一处理入口。Future 所有移动功能（技能、Buff、击退、冲锋等）都通过此流水线处理。

## 新增文件

### `MovementForce.gd` — 新增字段

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `lifetime` | `float` | `-1.0` | -1=无限，0=本帧过期，>0=剩余秒数 |
| `flags` | `int` | `FLAG_NONE` | 位掩码，向 Pipeline 传递处理指令 |

**标志位定义：**

| 常量 | 值 | 意义 |
|---|---|---|
| `FLAG_NONE` | `0` | 默认行为 |
| `FLAG_IGNORE_WEIGHT` | `1 << 0` | 忽略 weight，强度取 strength |
| `FLAG_UNSTOPPABLE` | `1 << 1` | 不能被阻挡/卡死等覆盖 |
| `FLAG_TRANSIENT` | `1 << 2` | 一次性力（本帧有效，Provider 不再重复生成） |

### `MovementForcePipeline.gd`（`res://脚本/移动系统/MovementForcePipeline.gd`）

```
class_name MovementForcePipeline
extends RefCounted
```

**入口：** `process(forces, delta, max_speed) → FusionResult`

**流水线阶段（本帧内顺序）：**

```
原始 Array<MovementForce>
  │
  ▼
[Filter 阶段]
  1. remove_expired()   — lifetime ≥ 0 → 每帧递减 delta，归零后移除
  2. remove_invalid()   — is_zero() 或 null 跳过
  3. sort_priority()    — 按 priority 降序排列
  │
  ▼
[Modify 阶段]
  4. apply_multiplier() — 全局乘数修正（当前空实现，为 future 预留）
  5. apply_override()   — FLAG_IGNORE_WEIGHT → weight=1.0
                          FLAG_UNSTOPPABLE/TRANSIENT → 元数据记录
  │
  ▼
[Fusion 阶段]
  6. solve()            — 移交 MovementForceFusion 加权混合 + 限幅
  │
  ▼
FusionResult{direction, strength}
```

## 修改文件

### `MovementSolver.gd`

| 项目 | 前 | 后 |
|---|---|---|
| 融合实例 | `_force_fusion: MovementForceFusion` | `_force_pipeline: MovementForcePipeline` |
| 融合调用 | `_force_fusion.solve(forces, max_speed)` | `_force_pipeline.process(forces, delta, max_speed)` |
| 数组操作 | Solver 直接传递 `all_forces` 给 Fusion | Solver 传递 `all_forces` 给 Pipeline，Pipeline 内部管理生命周期 |

Solver 当前流程（Phase 5）：
```
intent → 策略 →
  收集Provider力() → Provider 输出 MovementForce(lifetime=-1, weight, priority)
+ 构建内联力()    → 内联力也包装为 MovementForce(lifetime=-1)
  ↓
Pipeline.process(all_forces, delta, max_speed)  ← 唯一处理入口
  ↓
velocity（唯一写入点）
  ↓
卡死检测（后处理）
```

## 生命周期语义

### `lifetime` 工作方式

```
流程入口 → 检查 lifetime
  ├─ lifetime < 0    → 永久有效，不移除
  ├─ lifetime = 0    → 本帧过期，立即移除（用于一次性瞬发力）
  └─ lifetime > 0    → 每帧：lifetime -= delta
                        ├─ 剩余 > 0 → 保留
                        └─ 剩余 ≤ 0 → 移除
```

### `flags` 工作方式

```
FlowFieldForceProvider 输出：
  source_name = "FlowField"
  lifetime = -1    ← 永久有效
  flags = FLAG_NONE

未来 KnockbackProvider 输出：
  source_name = "Knockback"
  lifetime = 0.5   ← 0.5 秒后自动过期
  priority = 10    ← 高于普通路径力
  flags = FLAG_UNSTOPPABLE | FLAG_TRANSIENT
  weight = 1.0     ← 全权重
```

## Pipeline 架构如何接入未来功能

### 技能 Force 如何进入

```
1. 创建 SkillForceProvider（extends MovementForceProvider）
2. calculate_force() 返回：
     MovementForce(
       direction = 技能方向,
       strength  = 技能移动速度,
       weight    = 1.0,
       priority  = 20,        ← 高于普通移动
       lifetime  = 技能持续时长,
       flags     = FLAG_TRANSIENT
     )
3. 在 Provider 注册表中追加路径字符串
4. Pipeline 自动处理：高优先级 → 覆盖普通移动 → 过期自动移除
5. Solver 无需修改一行代码
```

### Buff Force 如何进入

```
1. 创建 BuffForceProvider（extends MovementForceProvider）
2. 管理一个或多个活跃 buff 的 MovementForce 列表
3. 每帧根据活跃 buff 计算修正力：
     MovementForce(
       direction = 修正方向（无方向限制可设为 Vector2.ZERO）,
       strength  = 0（无强度修正）,
       weight    = 减速系数（如 0.5 = 半速）,
       priority  = -5,          ← 低于普通移动
       lifetime  = buff 剩余时间,
       flags     = FLAG_IGNORE_WEIGHT（如果强制定值）
     )
4. 减速 buff → weight=0.5 使路径力整体减半
5. 加速 buff → weight=1.5 使路径力加速
6. Solver 无需修改一行代码
```

### Knockback Force 如何进入

```
1. 创建 KnockbackForceProvider（extends MovementForceProvider）
2. 当击退事件触发时，创建一个 MovementForce：
     MovementForce(
       direction = 击退方向,
       strength  = 击退强度 500 px/s,
       weight    = 1.0,
       priority  = 15,           ← 高于普通移动但可能低于冲锋
       lifetime  = 0.3,          ← 300ms
       flags     = FLAG_UNSTOPPABLE | FLAG_IGNORE_WEIGHT
     )
3. FLAG_UNSTOPPABLE：即使卡死检测试图回退也不受影响
4. FLAG_IGNORE_WEIGHT：击退强度不受 weight 修正影响
5. 0.3 秒后自动过期 → 单位恢复普通移动
6. Solver 无需修改一行代码
```

### 冲锋 Force 如何进入

```
1. 创建 ChargeForceProvider（extends MovementForceProvider）
2. 当冲锋技能激活时：
     MovementForce(
       direction = 冲锋方向,
       strength  = 冲锋速度 800 px/s,
       weight    = 1.0,
       priority  = 30,           ← 最高优先级
       lifetime  = 冲锋持续时长,
       flags     = FLAG_IGNORE_WEIGHT | FLAG_UNSTOPPABLE
     )
3. priority=30 → 覆盖所有其他力（路径、队形、击退...）
4. Solver 无需修改一行代码
```

## 过度设计检查

| 问题 | 答案 |
|---|---|
| Pipeline 是否有 ≥ 2 个实际使用者？ | 目前仅 Solver（第 1 个）。但 Pipeline 是未来所有 Force 功能的必经入口（Knockback/Buff/Skill/冲锋都是隐式用户）。 |
| 删除 Pipeline 是否导致扩展变差？ | **是**。没有 Pipeline，每个新功能需要自建生命周期管理，或在 Solver/Fusion 中添加条件分支。有了 Pipeline，只需设置 lifetime/flags。 |

**结论：** Pipeline 本身有充分的扩展价值（Q2=是）。但 `_remove_expired()` / `_remove_invalid()` 等作为 **Pipeline 内部方法** 而非独立接口文件是正确的——保留为内部方法避免了过度设计。

## 验收标准检查

| 标准 | 状态 | 证据 |
|---|---|---|
| MovementForce 生命周期已建立 | ✔ | `lifetime` + `flags` 字段已添加 |
| Pipeline 成为 Force 唯一处理入口 | ✔ | Solver 仅调用 `_force_pipeline.process()` |
| Solver 不直接操作 Force 数组 | ✔ | 数组传递给 Pipeline，Solver 只取 `FusionResult` |
| 行为保持一致 | ✔ | 数学验证等价（lifetime=-1 的力行为不变）；零运行时错误 |
| 报告完整 | ✔ | 本文档 |

## 文件清单

```
新文件:
  脚本/移动系统/MovementForcePipeline.gd

修改文件:
  脚本/移动系统/MovementForce.gd
    - 新增: lifetime (float, 默认 -1.0)
    - 新增: flags (int, 默认 FLAG_NONE)
    - 新增: has_flag(flag) -> bool
    - 新增: FLAG_NONE, FLAG_IGNORE_WEIGHT, FLAG_UNSTOPPABLE, FLAG_TRANSIENT

  脚本/移动系统/MovementSolver.gd
    - 替换: _force_fusion → _force_pipeline
    - 替换: _force_fusion.solve() → _force_pipeline.process()
    - 更新: 文档注释反映 Phase 5

未修改:
  脚本/移动系统/FlowFieldForceProvider.gd
  脚本/移动系统/MovementForceProvider.gd
  脚本/移动系统/MovementForceFusion.gd
  脚本/移动系统/MovementIntent.gd
```

---

**报告日期**: 2026-07-05  
**Phase 5 完**
