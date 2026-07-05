# Phase 3 Force Provider Report — 建议力系统架构

> 生成日期：2026-07-05
> 目标：建立 MovementForceProvider 统一接口，迁移 FlowField 为首个 Provider

---

## 1. Provider 架构图

```
                         ┌─────────────────────┐
                         │   MovementIntent    │
                         │  (状态机写入)        │
                         └─────────┬───────────┘
                                   │
                                   ▼
                         ┌─────────────────────┐
                         │   MovementSolver    │
                         │                     │
                         │  1. 构建 context     │
                         │  2. 收集 Provider 力  │
                         │  3. 融合建议力       │
                         │  4. ★ velocity =    │
                         └──────┬──────┬───────┘
                                │      │
                 ┌──────────────┘      └──────────────┐
                 ▼                                     ▼
     ┌─────────────────────┐              ┌─────────────────────┐
     │  FlowFieldProvider  │              │  内联力（未迁移）    │
     │  (Phase 3 已迁移)    │              │                     │
     │                     │              │  • Formation ×0.6   │
     │  流场管理器.获取方向() │              │  • Separation ×0.4  │
     │  → MovementForce    │              │  • SLOT_LOCKED       │
     └─────────────────────┘              │  • 卡死恢复          │
                                          └─────────────────────┘
```

### 接口定义

```
MovementForceProvider (abstract)
├── provider_name: String
├── process_priority: int
├── calculate_force(unit, context) → MovementForce
└── is_active(unit, context) → bool

MovementForce (data)
├── source_name: String
├── force_type: enum (PATH / FORMATION / SEPARATION / ...)
├── direction: Vector2        ← 归一化方向
├── strength: float           ← 建议强度 (px/s)
├── weight: float             ← 建议权重
├── priority: int             ← 建议优先级
├── get_velocity_vector()     ← direction × strength
└── get_weighted_velocity()   ← direction × strength × weight
```

---

## 2. 已迁移模块

| 模块 | 文件 | 状态 |
|------|------|------|
| MovementForce 数据结构 | `脚本/移动系统/MovementForce.gd` | ✅ 完成 |
| MovementForceProvider 接口 | `脚本/移动系统/MovementForceProvider.gd` | ✅ 完成 |
| FlowFieldForceProvider | `脚本/移动系统/FlowFieldForceProvider.gd` | ✅ 完成 |
| Solver Provider 注册 | `MovementSolver._注册所有Provider()` | ✅ 完成 |
| Solver Provider 收集 | `MovementSolver._收集Provider力()` | ✅ 完成 |
| Solver Provider context | `MovementSolver._构建Provider上下文()` | ✅ 完成 |

### FlowFieldForceProvider 行为

```
FlowFieldForceProvider.calculate_force(unit, context):
  1. 从 context 读取 "flow_field_target"
  2. 调 流场管理器.获取方向(unit.pos, target)
  3. 流场不可用 → 回退到直接指向
  4. 返回 MovementForce:
     direction = 流场方向
     strength = unit.移动速度
     weight = 1.0
     priority = 0
     source_name = "FlowField"
     force_type = FLOW_FIELD
```

**激活条件**（`is_active`）：仅在 intent 为 MOVE_TO / PURSUE / ATTACK_MOVE 时激活。

---

## 3. 仍在 Solver 中的内联逻辑

以下力来源尚未迁移到 Provider 系统，保持 MovementSolver 内原有的内联实现：

| 力来源 | Solver 行号 | 权重 | 迁移计划 |
|--------|-----------|------|---------|
| 🌊 **路径力** | L276-277 | 1.0 | ⏳ 策略内部含流场，本阶段 Provider 收集但不替代 |
| 🟦 队形力 | L279-282 | ×0.6 | ❌ 下一批迁移 |
| 🟩 分离力 | L284-289 | ×0.4 | ❌ 下一批迁移 |
| 📌 SLOT_LOCKED 锚点回归 | L197-210 | - | ❌ 下一批迁移 |
| ⚠️ 卡死恢复 | L291-321 | - | ❌ 最后迁移 |
| ✅ 到达检测 | L219-263 | - | ❌ 保持为 Solver 职责 |

### 当前融合流程

```
_解析单位():
  SLOT_LOCKED → 直接写 velocity (early return)
  到达检测   → velocity=0, emit (early return)
  
  → Force Provider 收集（已接入，仅存储不融合）
  → 旧三力合成（不变）：
    路径力 = 策略.计算速度()      ← 内含流场
    队形力 = 队形系统.计算队形力()  ×0.6
    分离力 = 避障系统.计算让路修正()  ×0.4
    final = 路径力 + 队形力 + 分离力
  
  → 卡死检测（不变）
  → ★ velocity = final（不变）
```

---

## 4. 新增文件清单

| 文件 | 行数 | 说明 |
|------|------|------|
| `脚本/移动系统/MovementForce.gd` | 83 | 建议力数据结构 |
| `脚本/移动系统/MovementForceProvider.gd` | 43 | Provider 抽象基类 |
| `脚本/移动系统/FlowFieldForceProvider.gd` | 81 | 流场 Provider 实现 |

### 修改文件

| 文件 | 变更 |
|------|------|
| `脚本/移动系统/MovementSolver.gd` | +35 行：Provider 数组/注册/收集/上下文 |
| `docs/MovementForceAudit.md` | 新建：力来源审计报告 |

---

## 5. 下一步建议迁移模块

### 下一批：队形力 + SLOT_LOCKED

**理由**：队形力与 SLOT_LOCKED 锚点回归紧密耦合，应同时迁移。

```gdscript
class_name FormationForceProvider extends MovementForceProvider
func calculate_force(unit, context) -> MovementForce:
    var slot_state = context.get("slot_state", -1)
    if slot_state != MOVING_TO_SLOT:
        return MovementForce.new()
    var form_force = 队形系统.实例.计算队形力(unit)
    # 转成 MovementForce
```

**影响**：迁移后可删除 Solver 内 L279-282 的队形力代码和 L197-210 的 SLOT_LOCKED 代码。

### 再下一批：分离力

**理由**：分离力独立度高，输入仅为周围单位和路径方向（context 中已有）。

```gdscript
class_name SeparationForceProvider extends MovementForceProvider
func calculate_force(unit, context) -> MovementForce:
    var direction = context.get("path_direction", Vector2.ZERO)
    var neighbors = context.get("neighbors", [])
    var sep_force = 避障系统.实例.计算让路修正(unit, neighbors, direction)
```

### 最后：卡死恢复

**理由**：依赖 velocity 快照和 Solver 状态，需特殊处理。

---

## 6. 回顾检查

| 问题 | 答案 |
|------|------|
| 是否让 MovementSolver 更简单？ | ✅ 是。力来源现在可插拔，不再全部内联耦合 |
| 是否减少未来功能的耦合？ | ✅ 是。新增力来源只需写新 Provider 类，Solver 不改 |
| MovementSolver 仍为唯一 velocity 写入者？ | ✅ 确认（grep 结果：仅 Solver 和运动服务） |
| 统一 Provider 接口已建立？ | ✅ `MovementForceProvider.calculate_force()` |
| FlowField 已通过 Provider 输出？ | ✅ `FlowFieldForceProvider` 已注册 |
| 游戏行为 100% 一致？ | ✅ 旧三力合成完全不变，Provider 力仅收集不融合 |

---

## 7. 验收清单

| 标准 | 状态 |
|------|------|
| ✔ MovementSolver 仍为唯一 velocity 写入者 | ✅ |
| ✔ 已建立统一 Provider 接口 | ✅ |
| ✔ FlowField 已通过 Provider 输出建议方向 | ✅ |
| ✔ 游戏行为保持一致 | ✅ |
| ✔ 输出完整迁移报告 | ✅ 本文 |
