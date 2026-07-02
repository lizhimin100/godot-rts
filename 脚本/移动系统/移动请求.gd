class_name 移动请求 extends Resource
## 描述一次移动的完整意图
## 由调用方（命令系统/技能系统/玩家输入）构建后发给运动服务

enum 移动类型 {
	前往位置,    # 右键地面 → 走到该坐标停
	追击敌人,    # 右键敌人  → 追着打直到目标死亡或超出追击距离
	移动攻击,    # A 键 + 右键 → 沿途遇敌自动攻击，清完后继续走
	技能驱动,    # 建造/嘲讽/冲锋等技能触发的位移
}

@export var 类型: 移动类型

## 核心目标（通常为目标位置，追击敌人时为目标单位的当前位置）
@export var 目标位置: Vector2
## 追击目标时使用（目标可能移动，每帧由策略重新采样）
var 目标实体: Node2D

## 技能系统使用——谁触发的这次移动
var 技能来源: Node2D

## 队形偏移：由命令系统在发出命令时一次性分配
@export var 队形偏移: Vector2
## 队形槽位 ID：用于队形展开时锁定偏移，避免每帧重算
@export var 队形槽位: int = -1

## 到达停止距离（px）：进入此范围内视为到达
@export var 停止距离: float = 4.0

## 追击最大距离（仅追击类型使用）
@export var 追击上限: float = 400.0

## 额外数据（灵活扩展，如建造的建筑类型等）
@export var 额外数据: Dictionary = {}

## 构造快捷函数（方便调用方一行创建）
static func 前往位置(位置: Vector2) -> 移动请求:
	var r = 移动请求.new()
	r.类型 = 移动类型.前往位置
	r.目标位置 = 位置
	return r

static func 追击敌人(目标: Node2D, 上限: float = 400.0) -> 移动请求:
	var r = 移动请求.new()
	r.类型 = 移动类型.追击敌人
	r.目标实体 = 目标
	r.追击上限 = 上限
	return r

static func 移动攻击(位置: Vector2) -> 移动请求:
	var r = 移动请求.new()
	r.类型 = 移动类型.移动攻击
	r.目标位置 = 位置
	return r

static func 技能驱动(位置: Vector2, 来源: Node2D, 数据: Dictionary = {}) -> 移动请求:
	var r = 移动请求.new()
	r.类型 = 移动类型.技能驱动
	r.目标位置 = 位置
	r.技能来源 = 来源
	r.额外数据 = 数据
	return r
