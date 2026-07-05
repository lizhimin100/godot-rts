# MovementForce 规则系统

## 概述

本文件定义 MovementForce 的规则系统——不同 force_type 如何协同。

规则由 `MovementForceFusion._apply_force_type_rules()` 执行。
当前为 no-op（Phase 7），保持原有行为不变。

---

## 目前已有 Force 类型

| 类型 | 枚举值 | 来源 | weight | priority | 融合方式 |
|---|---|---|---|---|---|
| **GOAL** | `ForceType.GOAL` | FlowFieldForceProvider（流场方向） | 1.0 | 0 | 加权混合 |
| **GOAL** | `ForceType.GOAL` | 内联路径力（策略方向） | 1.0 | 0 | 加权混合 |
| **FORMATION** | `ForceType.FORMATION` | FormationForceProvider（队形修正） | 0.6 | 0 | 加权混合 |
| **AVOIDANCE** | `ForceType.AVOIDANCE` | 内联分离力（避障推开） | 0.4 | 0 | 加权混合 |

**当前融合行为**：所有 force_type 按同一 `priority` 组混合。
同组（priority=0）内：

```
result = Σ(direction × strength × weight)
```

---

## Force 类型细分（按行为特征）

### GOAL（目标导向力）

单位移动的主要驱动力。

**特征**：
- 持续存在（lifetime = -1）
- 权重通常为 1.0（全效）
- 不应被 AVOIDANCE 等低权重力抵消

**来源**：流场方向（FlowFieldForceProvider）、策略路径（内联）

**建议规则**：即使 AVOIDANCE 总合成相反方向，GOAL 应确保单位仍向目标移动。

### FORMATION（队形修正力）

将单位拉向指定队形槽位的微调力。

**特征**：
- 仅 MOVING_TO_SLOT 状态时激活
- 权重 0.6（辅助修正，非主驱动）
- 距离目标越近，修正力越小

**来源**：FormationForceProvider

**建议规则**：GOAL 为主，FORMATION 为辅。当 GOAL 和 FORMATION 方向相反时，GOAL 不应被完全抵消。

### AVOIDANCE（避让力）

同阵营单位间的推开修正，防止重叠。

**特征**：
- 权重 0.4（弱推开）
- 只有靠近其他单位时才产生非零力

**来源**：内联分离力

**建议规则**：作为修正力不应干扰整体移动方向。当远离其他单位时应为零。

### COLLISION（碰撞响应）— 未使用

预留。未来用于被障碍物/单位碰撞时的物理响应。

### OVERRIDE（覆盖力）— 未使用

预留。未来用于：

- **击退（Knockback）**：priority=15, lifetime=0.3s, FLAG_UNSTOPPABLE
- **冲锋（Charge）**：priority=30, lifetime=冲锋时长
- **技能位移（Skill）**：priority=20, FLAG_TRANSIENT

**建议规则**：高 priority 覆盖低 priority（已由 Fusion 优先级规则支持）。
OVERRIDE 类型可考虑自动提升 priority + 1 以确保不被其他力干扰。

### EXTERNAL（外力）— 未使用

预留。未来用于：

- **减速 Buff**：weight=0.5，通过 Pipeline 全局 multiplier 或单独 Provider
- **加速 Buff**：weight=1.5
- **光环推力**：AuraForceProvider 持续输出轻力

**建议规则**：EXTERNAL 应放在 priority=-10 或更低，作为全局修正不干扰主移动方向。

---

## 未来规则建议

### 类型覆盖关系（纵向）

```
                    高 priority 完全覆盖低 priority
                              │
                     ┌────────┴────────┐
                     │                 │
                  OVERRIDE         其他类型
                  (无混合)         (按 priority 混合)
```

OVERRIDE 类力使用 `FLAG_IGNORE_WEIGHT` + 高 priority → 完全覆盖。
其他类型在同一 priority 内加权混合（当前行为）。

### 类型混合规则（横向，同 priority）

```
同 priority 组内：
  result = Σ(direction × strength × weight)
  
  当前所有 force_type 在 priority=0 时混合。
  权重差异已体现类型的相对重要性：
    GOAL(1.0) > FORMATION(0.6) > AVOIDANCE(0.4)
```

### 可考虑的扩展规则

| 规则 | 描述 | 可能影响 |
|---|---|---|
| GOAL 保底 | 即使 AVOIDANCE + FORMATION 反向，GOAL 方向分量不低于 50% | 单位在密集队形中仍能前进 |
| OVERRIDE 自动提权 | OVERRIDE 类型的 force 自动获得 `max(当前优先级 + 1, 10)` | 确保技能/击退不受普通移动干扰 |
| EXTERNAL 降权 | EXTERNAL 类型自动降至 priority=-10 | 确保外力不覆盖玩家操作 |
| 同类型叠加限制 | 同类型 force 超过 N 个时取 top-K 而非全部混合 | 防止大量单位产生爆炸式分离力 |

---

## 规则实现位置

所有规则集中在 `MovementForceFusion._apply_force_type_rules()`。

当前为 no-op（Phase 7）。

实现新规则的步骤：
1. 在 `_apply_force_type_rules()` 中读取 `groups` / `priorities`
2. 根据 `f.force_type` 修改分组或优先级
3. **不写 velocity**
4. **不调用 _blend_weighted**（那是下一步）
5. 回归测试：零语法错误 + 行为不变

---

**文档日期**: 2026-07-05  
**Phase 7 完**
