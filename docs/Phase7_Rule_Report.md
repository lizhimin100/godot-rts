# Phase 7 — MovementForce Rule System（规则系统）

## 概述

本阶段建立了 MovementForce 的规则系统。不改变任何游戏行为——只增加类型分类和规则入口。

---

## MovementSolver 职责监控

### MovementSolver 当前职责（Phase 7 末）

1. **读取 MovementIntent**：从单位获取由状态机写入的移动意图
2. **收集 Provider 建议力**：迭代 `_providers` 列表，调用每个 Provider 的 `calculate_force()`
3. **构建内联建议力**：路径力（策略方向）和分离力（避障推开）仍以内联形式构建
4. **委派 Pipeline 处理**：调用 `_force_pipeline.process(all_forces, delta, max_speed)` 进行过滤→修正→融合
5. **写入 velocity**：将 Pipeline 输出的 `FusionResult` 写入 `unit.velocity`（唯一写入点）
6. **到达检测**：通过策略的 `是否已到达()` 判断目标到达
7. **SLOT_LOCKED 锚点回归**：队形抵达后锚定与回归
8. **卡死检测与解卡**：速度低于阈值时的回退和放弃逻辑
9. **信号发射**：`移动完成`、`单位卡死` 信号通知外部系统

### 本阶段新增职责

- 无（纯数据扩展和规则入口，不影响 Solver 流程）

### 本阶段减少职责

- 无

### 职责趋势（Phase 3 → 7）

```
Phase 3: 收集 Provider 力 + 三力合成（内联权重常量）+ velocity 写入
Phase 4: 收集 Provider 力 + 内联力包装 + Fusion 委派 + velocity 写入
Phase 5: 收集 Provider 力 + 内联力包装 + Pipeline 委派 + velocity 写入
Phase 6: 队形力从 Solver 内联移至 FormationForceProvider
Phase 7: 纯规则元数据——Solver 无变化
```

**趋势**: Solver 职责持续减少（已消除融合规则、队形计算）。目标是让 Solver 只剩下"收集 → Pipeline → velocity"三行核心，其余全部外移到 Provider/Pipeline/Fusion。

---

## 核心原则

> MovementForce 不只是速度向量——它是**一种完整的移动影响**。

本阶段将 force_type 从「描述来源」升级为「描述角色」，使不同类型力可以在规则层区分处理，而不依赖模糊的 priority 数值。

## 修改文件

### `MovementForce.gd` — 扩展 ForceType 枚举

**旧枚举**（7 个值）：
```
PATH=0, FORMATION=1, SEPARATION=2, SLOT_ANCHOR=3,
STUCK_RECOVERY=4, FLOW_FIELD=5, CUSTOM=6
```

**新枚举**（12 个值）：
```
# 旧类型保留（向后兼容）
PATH=0, FORMATION=1, SEPARATION=2, SLOT_ANCHOR=3,
STUCK_RECOVERY=4, FLOW_FIELD=5, CUSTOM=6,

# 新规则分类
GOAL=7, AVOIDANCE=8, COLLISION=9, OVERRIDE=10, EXTERNAL=11
```

默认值从 `ForceType.PATH` 变更为 `ForceType.GOAL`。

### `MovementForceFusion.gd` — 规则入口

新增 `_apply_force_type_rules()` 方法：

```
solve() 流程中新增 Step 3: _apply_force_type_rules(groups, priorities)
  → 当前为 no-op（保持原有分组不变）
  → 可通过注释了解未来规则的实现模式
```

**约束**：
- 禁止在此方法内写 velocity
- 禁止在此方法内调用 `_blend_weighted`
- 只能操作 `groups` 字典和 `priorities` 数组

### Provider force_type 更新表

| Provider | 旧 force_type | 新 force_type | 说明 |
|---|---|---|---|
| FlowFieldForceProvider | `FLOW_FIELD` (5) | `GOAL` (7) | 目标导向力 |
| FormationForceProvider | `FORMATION` (1) | `FORMATION` (1) | 不变（两枚举均有） |
| 内联 Path 力 | `PATH` (0) | `GOAL` (7) | 目标导向力 |
| 内联 Separation 力 | `SEPARATION` (2) | `AVOIDANCE` (8) | 避让力 |

---

## 验证

| 检查项 | 结果 |
|---|---|
| `--check-only` 语法检查 | 0 errors |
| 运行时 SYSCHECK | `MovementSolver 共 2 个 Provider 已注册` |
| 无旧 `ForceType.FLOW_FIELD`/`SEPARATION` 残留 | ✔ |

## 验收标准检查

| 标准 | 状态 | 证据 |
|---|---|---|
| 所有已有 Provider 拥有 force_type | ✔ | FlowField→GOAL, Formation→FORMATION |
| Fusion 已有规则入口 | ✔ | `_apply_force_type_rules()` no-op 已就位 |
| 游戏行为保持一致 | ✔ | 规则入口为 no-op；类型变化不影响融合数学 |
| 输出完整规则文档 | ✔ | `docs/MovementForceRule.md` |
| MovementSolver 职责监控已建立 | ✔ | 本报告新增监控章节 |

---

**报告日期**: 2026-07-05  
**Phase 7 完**
