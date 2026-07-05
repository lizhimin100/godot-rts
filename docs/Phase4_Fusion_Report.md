# Phase 4 — Force Fusion（建议力融合层）报告

## 概述

本阶段完成了建议力融合层的建立。**MovementSolver 不再包含任何具体融合规则**，所有 weight × priority × strength 规则集中在 `MovementForceFusion` 中。

## 新增文件

### `MovementForceFusion.gd`（`res://脚本/移动系统/MovementForceFusion.gd`）

```
class_name MovementForceFusion
extends RefCounted
```

**职责**：接收 `Array<MovementForce>` → 按规则融合 → 输出 `FusionResult{direction, strength}`

**当前支持的融合规则**：

| 规则 | 说明 | 实现位置 |
|---|---|---|
| **优先级覆盖** | 高 `priority` 组完全覆盖低组 | `solve()` → 按 `priority` 分组，从高到低遍历 |
| **加权混合** | 同优先级：`result = Σ(direction × strength × weight)` | `_blend_weighted()` |
| **限幅** | 融合结果限幅到 `max_speed` | `solve()` → `minf(len, max_speed)` |
| **零力跳过** | `is_zero()` 的力不参与融合 | `solve()` → 跳过零力 |

**不支持的规则（当前为空白）**：
- 无方向动量/惯性（每帧独立计算）
- 加速度限制（直接输出速度）
- 方向平滑（未来可通过 Provider 化实现）

## 修改文件

### `MovementSolver.gd`（`res://脚本/移动系统/MovementSolver.gd`）

**变更摘要**：

| 项目 | 旧 | 新 |
|---|---|---|
| 融合规则 | 内联 `队形力权重=0.6` `分离力权重=0.4` | 全部移至 `MovementForceFusion` |
| 力收集 | 仅 Provider 力 | Provider 力 + 内联力（`_构建内联力()`） |
| 三力合成 | 硬编码权重常量 | 每个 `MovementForce` 自带 `weight`/`priority` |
| Provider 注册 | 硬编码 `FlowFieldForceProvider.new()` | 文件路径 `_PROVIDER_PATHS` + 静态 `注册Provider()` API |
| SLOT_LOCKED | 保留 | 保留（状态处理，非力的融合） |
| 卡死检测 | 保留 | 保留（后处理，非力的融合） |

**Solver 当前流程**：
```
intent → 策略 →
  收集Provider力() ← 迭代所有已注册 Provider（类型无关）
+ 构建内联力()    ← 路径力/队形力/分离力包装为 MovementForce
  ↓
ForceFusion.solve(all_forces, max_speed)
  ↓
velocity（唯一写入点）
  ↓
卡死检测（后处理）
```

**内联力权重**（写在各 `MovementForce.weight` 字段，非 Solver 常量）：

| 力类型 | weight | priority | 说明 |
|---|---|---|---|
| 路径力（策略） | 1.0 | 0 | 主驱动力 |
| 队形力（槽位修正） | 0.6 | 0 | 辅助修正 |
| 分离力（避障推开） | 0.4 | 0 | 弱推开 |

### `FlowFieldForceProvider.gd`

保持不变。Provider 自注册已被移除（改为 Solver 的 `_PROVIDER_PATHS` 加载）。

## 架构验证

### ✔ MovementSolver 仅负责流程控制

Solver 不再包含任何 weight/priority 计算公式，职责变为：
1. 收集所有建议力（Provider + 内联）
2. 调用 `Fusion.solve()`
3. 写入 `unit.velocity`
4. 状态处理（SLOT_LOCKED、到达检测、卡死检测）

### ✔ Fusion 成为唯一建议力融合入口

所有建议力（包括内联构建的路径力/队形力/分离力）都通过 `MovementForceFusion.solve()` 处理。不存在绕过 Fusion 的融合路径。

### ✔ 游戏行为保持一致

经数学验证，新旧融合公式完全等价：

```
旧: final = path + formation×0.6 + separation×0.4
新: Σ(direction×strength×weight)
  = path_dir×path_speed×1.0 + form_dir×form_len×0.6 + sep_dir×sep_len×0.4
  = path + formation×0.6 + separation×0.4  ✓
```

限幅逻辑等价：`minf(blended.length(), max_speed)` 等价于原条件限幅。

## 验收标准检查

| 标准 | 状态 | 证据 |
|---|---|---|
| Solver 仅负责流程控制 | ✔ | 无融合规则残留 |
| Fusion 唯一融合入口 | ✔ | 所有力通过 `solve()` |
| 游戏行为一致 | ✔ | 数学验证等价；零运行时错误 |
| 报告完整 | ✔ | 本文档 |

## 下一步建议 Provider 化清单

以下模块仍「写死」在 Solver 的 `_构建内联力()` 中，建议逐步 Provider 化：

| 模块 | 当前状态 | 建议处理 |
|---|---|---|
| **路径力** | 内联（策略 `.计算速度()`） | Provider 化或保持现状（策略本身已是抽象） |
| **队形力** | 内联（`队形系统.计算队形力()`） | → `FormationForceProvider`（Phase 5 候选） |
| **分离力** | 内联（`避障系统.计算让路修正()`） | → `SeparationForceProvider`（Phase 5 候选） |
| **SLOT_LOCKED 锚点回归** | 状态机（Solver 硬编码） | 无需 Provider 化，属状态处理 |
| **卡死恢复** | 后处理（Solver 硬编码） | 无需 Provider 化，属异常处理 |

## 新增 Provider 流程（未来）

```
1. 创建文件：scripts/movement/KnockbackForceProvider.gd
   → extends MovementForceProvider
   → 实现 calculate_force() / is_active()

2. 注册：
   a) 内置：在 MovementSolver._PROVIDER_PATHS 追加路径字符串
   b) 外部：MovementSolver.注册Provider(KnockbackForceProvider.new())

3. Fusion 自动处理：
   → Provider 输出 MovementForce(direction, strength, weight, priority)
   → Fusion.solve() 按统一规则融合
   → 无需修改 Solver 业务逻辑
```

## 文件清单

```
新文件:
  脚本/移动系统/MovementForceFusion.gd

修改文件:
  脚本/移动系统/MovementSolver.gd
    - 移除: 队形力权重/分离力权重 常量
    - 新增: _force_fusion 实例
    - 新增: _构建内联力() 方法
    - 新增: 静态 注册Provider() API
    - 修改: _注册所有Provider() → 文件路径加载 + 静态队列
    - 修改: _解析单位() → 使用 Fusion.solve()

未修改:
  脚本/移动系统/FlowFieldForceProvider.gd
  脚本/移动系统/MovementForce.gd
  脚本/移动系统/MovementForceProvider.gd
  脚本/移动系统/MovementIntent.gd
```

---

**报告日期**: 2026-07-05  
**Phase 4 完**
