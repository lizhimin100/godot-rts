class_name MovementIntent
extends RefCounted

## MovementIntent — 单位移动意图数据载体
##
## 由 单元状态机 写入，由 MovementSolver 读取。
## 是状态机（决策层）与 MovementSolver（执行层）之间的唯一接口。
##
## 职责边界：
##   状态机：决定"去哪儿、干什么"→ 写入 MovementIntent
##   Solver：决定"怎么去" → 读取 MovementIntent + 计算速度

enum IntentType {
	NONE,          # 无移动意图
	MOVE_TO,       # 移动到指定位置（右键地面）
	PURSUE,        # 追击敌人（右键敌人）
	ATTACK_MOVE,   # A-move：沿途遇敌自动攻击
	SKILL_DRIVEN,  # 技能驱动位移（建造/冲锋/击退）
}

## 意图类型
var type: int = IntentType.NONE

## 目标位置（MOVE_TO/ATTACK_MOVE/SKILL_DRIVEN 使用）
var target_position: Vector2 = Vector2.ZERO

## 追击目标实体（PURSUE 使用）
var target_unit: Node2D = null

## 优先级（预留，将来用于多意图仲裁）
var priority: int = 0

## 到达停止距离（进入此范围视为到达）
var stop_distance: float = 4.0

## 追击上限距离（仅 PURSUE 使用）
var pursue_max_range: float = 400.0

## 队形偏移（由 CommandManager 分配，创建即锁定）
var formation_offset: Vector2 = Vector2.ZERO

## 队形槽位 ID（-1 = 无队形）
var formation_slot: int = -1

## 额外数据（SKILL_DRIVEN 使用）
var extra_data: Dictionary = {}


# ============================================================
# 静态构造器
# ============================================================

## 移动前往位置
static func move_to(pos: Vector2) -> MovementIntent:
	var intent = MovementIntent.new()
	intent.type = IntentType.MOVE_TO
	intent.target_position = pos
	return intent


## 追击敌人
static func pursue(target: Node2D, max_range: float = 400.0) -> MovementIntent:
	var intent = MovementIntent.new()
	intent.type = IntentType.PURSUE
	intent.target_unit = target
	intent.pursue_max_range = max_range
	return intent


## 移动攻击（A-move）
static func attack_move(pos: Vector2) -> MovementIntent:
	var intent = MovementIntent.new()
	intent.type = IntentType.ATTACK_MOVE
	intent.target_position = pos
	return intent


## 技能驱动位移
static func skill_driven(pos: Vector2, data: Dictionary = {}) -> MovementIntent:
	var intent = MovementIntent.new()
	intent.type = IntentType.SKILL_DRIVEN
	intent.target_position = pos
	intent.extra_data = data
	return intent


# ============================================================
# 工具方法
# ============================================================

## 重置为无意图
func clear() -> void:
	type = IntentType.NONE
	target_position = Vector2.ZERO
	target_unit = null
	priority = 0
	stop_distance = 4.0
	pursue_max_range = 400.0
	formation_offset = Vector2.ZERO
	formation_slot = -1
	extra_data = {}


## 检查是否有效意图
func is_valid() -> bool:
	return type != IntentType.NONE
