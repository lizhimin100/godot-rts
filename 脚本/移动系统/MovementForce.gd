class_name MovementForce
extends RefCounted

## MovementForce — 建议力数据单元
##
## 由 MovementForceProvider 输出，由 MovementSolver 收集融合。
## 纯数据载体，不包含 velocity 或任何物理操作。

## 力类型枚举
##
## Phase 7 新增规则分类：
##   GOAL      — 目标导向力（流场、路径 → 主驱动力）
##   AVOIDANCE — 避让力（分离、碰撞回避）
##   COLLISION — 碰撞响应力（被推开等）
##   OVERRIDE  — 覆盖力（冲锋、技能、击退 — 高优先）
##   EXTERNAL  — 外力（Buff、光环、环境）
##
## 旧类型名保留为别名，保持不变（可按需切换至新分类）。
enum ForceType {
	# === 旧具体类型（保留向后兼容） ===
	PATH,           # 路径力（流场推动）
	FORMATION,      # 队形力（槽位修正）
	SEPARATION,     # 分离力（避障推开）
	SLOT_ANCHOR,    # 槽位锚点回归
	STUCK_RECOVERY, # 卡死恢复
	FLOW_FIELD,     # 流场方向（Provider 化后）
	CUSTOM,         # 预留自定义扩展（可映射到任意新类型）

	# === 新规则类型（Phase 7） ===
	GOAL,           # 目标导向力 — 流场、路径等主移动方向
	AVOIDANCE,      # 避让力 — 分离、障碍回避
	COLLISION,      # 碰撞响应 — 被其他实体推开
	OVERRIDE,       # 覆盖力 — 冲锋、击退、技能驱动
	EXTERNAL,       # 外力 — Buff、光环、环境风向
}

## 力的来源名称（用于调试/日志）
var source_name: String = ""

## 力类型
var force_type: int = ForceType.GOAL

## 建议方向（归一化向量，非速度量）
var direction: Vector2 = Vector2.ZERO

## 建议强度（px/s，不含权重）
var strength: float = 0.0

## 权重（Provider 设定建议值，Solver 最终决定）
var weight: float = 1.0

## 优先级（越大越优先，紧急处理用）
var priority: int = 0

## 生命周期（Phase 5）
##   -1 = 无限（默认，当前行为）
##    0 = 本帧过期（一次性力）
##   >0 = 剩余持续时间（秒）
var lifetime: float = -1.0

## 标志位（Phase 5 — 位掩码）
## 用于向 Pipeline 传递额外处理指令，无需新增接口。
## 当前定义：
##   FLAG_NONE          = 0        （默认）
##   FLAG_IGNORE_WEIGHT = 1 << 0   （忽略 weight，强度取 strength）
##   FLAG_UNSTOPPABLE   = 1 << 1   （不能被阻挡/卡死覆盖）
##   FLAG_TRANSIENT     = 1 << 2   （一次性力，融合后自动丢弃）
const FLAG_NONE: int = 0
const FLAG_IGNORE_WEIGHT: int = 1 << 0
const FLAG_UNSTOPPABLE: int = 1 << 1
const FLAG_TRANSIENT: int = 1 << 2

## 标志值
var flags: int = FLAG_NONE

## 便捷检查标志位
func has_flag(flag: int) -> bool:
	return (flags & flag) != 0


## 获取速度向量（方向 × 强度）
func get_velocity_vector() -> Vector2:
	return direction * strength


## 获取权重修正后的速度向量（方向 × 强度 × 权重）
func get_weighted_velocity() -> Vector2:
	return direction * strength * weight


## 空力判断
func is_zero() -> bool:
	return direction.length_squared() < 0.0001 or strength < 0.01


func _to_string() -> String:
	return "MovementForce(%s dir=(%.2f,%.2f) str=%.1f w=%.1f pri=%d)" % [
		source_name, direction.x, direction.y, strength, weight, priority
	]
