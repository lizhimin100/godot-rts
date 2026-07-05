# Phase 6 — Formation Provider Migration（队形 Provider 化）

## 概述

本阶段将队形方向计算从 `MovementSolver._构建内联力()` 迁移到独立的 `FormationForceProvider`。队形现在是一个真正的 `MovementForceProvider`，与流场力位于同一抽象层级。

## 迁移前后结构

### 前（Phase 5）

```
MovementSolver._构建内联力():
  ① 路径力（内联 → MovementForce）
  ② 队形力（内联 → MovementForce）   ← 仍在 Solver 中
  ③ 分离力（内联 → MovementForce）
      ↓
Pipeline.process()
      ↓
Fusion.solve()

MovementSolver 知道队形如何计算。
```

### 后（Phase 6）

```
MovementSolver._收集Provider力():
  FlowFieldForceProvider    ← 已 Provider 化
  FormationForceProvider    ← ★ 本阶段迁移
      ↓
MovementSolver._构建内联力():
  ① 路径力（内联 → MovementForce）
  ③ 分离力（内联 → MovementForce）
      ↓
Pipeline.process()
      ↓
Fusion.solve()

MovementSolver 不知道队形如何计算。
Solver 只知道收到一个 MovementForce(Formation)。
```

## 新增文件

### `FormationForceProvider.gd`（`res://脚本/移动系统/FormationForceProvider.gd`）

```
class_name FormationForceProvider
extends MovementForceProvider
```

**职责**：从队形系统读取槽位修正方向，输出 FORMATION 类型建议力。

**核心逻辑**：

| 项目 | 值 | 说明 |
|---|---|---|
| `provider_name` | `"Formation"` | 调试标识 |
| `process_priority` | `15` | 在流场力（10）之后执行 |
| `weight` | `0.6` | 与旧 `队形力权重` 常量完全一致 |
| `priority` | `0` | 与路径力同优先级（混合权重） |
| `lifetime` | `-1.0` | 永久有效（与旧行为一致） |
| `flags` | `FLAG_NONE` | 默认 |
| `force_type` | `ForceType.FORMATION` | 类型标识 |

**激活条件**：
```
slot_state == MOVING_TO_SLOT 且 队形系统.实例 有效
```
与旧 Solver 条件完全一致：
```gdscript
# 旧 Solver 内联代码 — 已删除
if 队形系统.实例 and data.slot_state == MOVING_TO_SLOT:
```

**底层算法**（完全保留）：
```
队形力向量 = 队形系统.实例.计算队形力(unit)
```
调用完全相同的方法，零行为变更。

## 修改文件

### `MovementSolver.gd`

| 变更 | 旧 | 新 |
|---|---|---|
| `_PROVIDER_PATHS` | 仅 `FlowFieldForceProvider` | `FlowFieldForceProvider` + `FormationForceProvider` |
| `_构建内联力()` | ② 队形力（~12 行） | 已删除（移至 Provider） |
| 文档注释 | `队形力、分离力：仍内联` | `队形力由 FormationForceProvider 提供` |

**已删除的 Solver 内联代码**（~12 行，完整迁移至 Provider）：
```gdscript
# ② 队形力 — 槽位修正，仅 MOVING_TO_SLOT 使用
if 队形系统.实例 and data.slot_state == MOVING_TO_SLOT:
    var 队形力向量 = 队形系统.实例.计算队形力(unit)
    if 队形力向量.length_squared() > 0.0001:
        var ff = MovementForce.new()
        ff.source_name = "Formation"
        ff.force_type = MovementForce.ForceType.FORMATION
        ff.direction = 队形力向量.normalized()
        ff.strength = 队形力向量.length()
        ff.weight = 0.6
        ff.priority = 0
        forces.append(ff)
```

## 保留的旧逻辑

| 逻辑 | 位置（旧） | 位置（新） | 是否改变 |
|---|---|---|---|
| `计算队形力(unit)` 调用 | `_构建内联力()` | `FormationForceProvider.calculate_force()` | 否 |
| 零力判断 `length_squared > 0.0001` | `_构建内联力()` | `FormationForceProvider` | 否 |
| 方向归一化 | `_构建内联力()` | `FormationForceProvider` | 否 |
| 强度取 `队形力向量.length()` | `_构建内联力()` | `FormationForceProvider` | 否 |
| weight = 0.6 | Solver 常量 `队形力权重` | `FormationForceProvider` 字段 | 否 |
| 仅 MOVING_TO_SLOT 激活 | `data.slot_state == MOVING_TO_SLOT` | `context["slot_state"] == MOVING_TO_SLOT` | 否（等值且源相同） |
| 队形系统可用检查 | `队形系统.实例` | `is_instance_valid(队形系统.实例)` | 是（更安全，语义不变） |

## 验证

| 检查项 | 结果 |
|---|---|
| `--check-only` 语法检查 | 0 errors |
| Runtime 运行时 | 0 MovementSolver/FormationForce 错误 |
| SYSCHECK Provider 注册 | `MovementSolver 共 2 个 Provider 已注册` |
| `FormationForceProvider.gd.uid` 存在 | ✔ |

## 验收标准检查

| 标准 | 状态 | 证据 |
|---|---|---|
| Formation 完全 Provider 化 | ✔ | 独立 `FormationForceProvider.gd`，通过 `_PROVIDER_PATHS` 注册 |
| Solver 不再包含队形计算 | ✔ | `_构建内联力()` 中队形相关 ~12 行已删除 |
| 游戏行为一致 | ✔ | 底层算法、weight(0.6)、priority(0)、激活条件完全相同 |
| Pipeline/Fusion 无需修改 | ✔ | Provider 输出标准 `MovementForce`，Pipeline/Fusion 无感知 |
| 报告完整 | ✔ | 本文档 |

## 下一步建议

| 模块 | 当前状态 | 建议 |
|---|---|---|
| **路径力** | 内联（策略 `.计算速度()`） | Provider 化或保持现状（策略本身已是抽象，收益有限） |
| **分离力** | 内联（`避障系统.计算让路修正()`） | → `SeparationForceProvider`（下一候选） |
| **SLOT_LOCKED 锚点回归** | Solver 状态机硬编码 | 无需 Provider 化（属状态处理，非力） |
| **卡死恢复** | Solver 后处理 | 无需 Provider 化（属异常处理，非力） |

## 文件清单

```
新文件:
  脚本/移动系统/FormationForceProvider.gd

修改文件:
  脚本/移动系统/MovementSolver.gd
    - _PROVIDER_PATHS 追加 FormationForceProvider
    - _构建内联力() 删除第②段（队形力）
    - 文档注释更新

未修改（验证仍工作）:
  脚本/移动系统/FlowFieldForceProvider.gd
  脚本/移动系统/MovementForce.gd
  脚本/移动系统/MovementForceProvider.gd
  脚本/移动系统/MovementForceFusion.gd
  脚本/移动系统/MovementForcePipeline.gd
  脚本/移动系统/MovementIntent.gd
```

---

**报告日期**: 2026-07-05  
**Phase 6 完**
