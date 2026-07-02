class_name 单位基类
extends CharacterBody2D

## 单位基类 — RTS 单位根基类（服务化架构版）
##
## ⚠ 不再持有移动控制器，所有移动请求委托给 运动服务 全局单例
##    velocity 由 运动服务 在 _physics_process 中写入，
##    本类 _physics_process 只调用 move_and_slide()

const DIAG: bool = true

signal 避开友军
signal 移动开始              # 收到新的移动请求时
signal 移动结束(结果: 移动结果)  # 到达/卡死/目标丢失等

# ========== 阵营系统 ==========
var _阵营: int = 阵营管理器.阵营.玩家

@export var 阵营: int:
	get: return _阵营
	set(v):
		if _阵营 != v:
			_阵营 = v
			_更新阵营设置()

@export var 视野半径: float = 300.0

# ========== 移动参数 ==========
@export var 移动速度: float = 200.0
## 最大速度上限（用于技能加速/减速时限制上限，正常 = 移动速度）
@export var 最大速度: float = 350.0
@export var 停止阈值: float = 16.0
@export var move_priority: int = 0

# ========== 生命 ==========
@export var 最大生命值: float = 100.0

# ========== 战斗组件 ==========
var 生命组件: HealthComponent
var 战斗组件: CombatComponent
var 索敌组件: TargetingComponent
var 死亡处理器: DeathHandler
var _状态条: UnitStatusBar

# ========== 数据层 ==========
@export var stats: UnitStats = null

# ========== 当前移动请求（外部只读） ==========
## 由 运动服务 管理，单位仅用于读取状态
var 当前移动请求: 移动请求 = null

# ========== 命令状态（由 CommandManager 外部设置） ==========
var 当前命令: int = 命令管理器.命令类型.无
var 目标位置: Vector2 = Vector2.ZERO
var 攻击目标: Node2D = null

# ========== 视觉分离 ==========
var visual_offset: Vector2 = Vector2.ZERO
const VISUAL_RADIUS: float = 10.0
var _visual_sep_phase: int = 0
var _visual_sep_counter: int = 0
const VISUAL_SEP_INTERVAL: int = 10

# ========== 驻守图标 ==========
var _驻守图标: Node2D = null
const GARRISON_ICON = preload("res://combat/effects/garrison_icon.tscn")

# ========== 队形偏移预存（CommandManager 在请求创建前设置） ==========
var _pending_formation_offset: Vector2 = Vector2.ZERO
var _pending_formation_slot: int = -1


func _ready() -> void:
	# 阵营判定
	if collision_layer == 16:
		阵营 = 阵营管理器.阵营.敌人
	else:
		阵营 = 阵营管理器.阵营.玩家

	# 按脚底排序，上方单位被下方单位遮挡
	_设置碰撞()
	_visual_sep_phase = hash(get_instance_id()) % VISUAL_SEP_INTERVAL
	_visual_sep_counter = _visual_sep_phase
	_初始化战斗组件()
	_注册到管理器()

	add_to_group("移动单位")
	_add_to_selection_group()

	# 注册为视野来源
	if 迷雾系统.实例:
		迷雾系统.实例.注册视野来源(self)


func _enter_tree() -> void:
	# 每次进入场景树时连接运动服务信号（比 _ready 更可靠）
	if is_instance_valid(运动服务.实例):
			if not 运动服务.实例.移动完成.is_connected(_on_运动服务移动结束):
				运动服务.实例.移动完成.connect(_on_运动服务移动结束)


func _设置碰撞() -> void:
	"""根据阵营设置碰撞层和检测层
	   所有单位互撞 + 与建筑互撞"""
	if 阵营 == 阵营管理器.阵营.敌人:
		collision_layer = 16
		collision_mask = 32 + 8 + 4 + 16
	else:
		collision_layer = 8
		collision_mask = 32 + 16 + 8 + 4


func _exit_tree() -> void:
	if 单位管理器.实例: 单位管理器.实例.注销单位(self)
	if 迷雾系统.实例: 迷雾系统.实例.注销视野来源(self)
	if is_instance_valid(运动服务.实例):
		# 断开信号避免悬空引用
		if 运动服务.实例.移动完成.is_connected(_on_运动服务移动结束):
			运动服务.实例.移动完成.disconnect(_on_运动服务移动结束)


# ============================================================
# 注册
# ============================================================

func _注册到管理器() -> void:
	if 单位管理器.实例: 单位管理器.实例.注册单位(self)

func _add_to_selection_group() -> void:
	if 阵营 == 阵营管理器.阵营.玩家: add_to_group("可选单位")

func _更新阵营设置() -> void:
	_设置碰撞()
	if 阵营 == 阵营管理器.阵营.玩家:
		add_to_group("可选单位")
	else:
		remove_from_group("可选单位")


# ============================================================
# 战斗组件
# ============================================================

func _初始化战斗组件() -> void:
	if not stats:
		stats = UnitStats.new()
		stats.hp = 最大生命值

	生命组件 = HealthComponent.new()
	生命组件.name = "HealthComponent"
	生命组件.max_hp = 最大生命值
	add_child(生命组件)

	索敌组件 = TargetingComponent.new()
	索敌组件.name = "TargetingComponent"
	add_child(索敌组件)

	战斗组件 = CombatComponent.new()
	战斗组件.name = "CombatComponent"
	战斗组件.attack_range = 45.0
	战斗组件.attack_damage = 10.0
	战斗组件.attack_cooldown = 1.0
	战斗组件.attack_strike.connect(_on_默认打击)
	add_child(战斗组件)

	死亡处理器 = DeathHandler.new()
	死亡处理器.name = "DeathHandler"
	add_child(死亡处理器)

	var bar := UnitStatusBar.new()
	bar.name = "UnitStatusBar"
	_状态条 = bar
	add_child(bar)


func _on_默认打击(_target: Node2D, packet: DamagePacket) -> void:
	DamageSystem.apply_damage(packet)


# ============================================================
# 阵营关系
# ============================================================

func 获取阵营() -> int: return _阵营

func 获取关系(目标) -> int:
	if not 目标 or not is_instance_valid(目标): return 阵营管理器.关系.中立
	if 目标.has_method("获取阵营"): return 阵营管理器.获取关系(_阵营, 目标.获取阵营())
	if 目标 is 单位基类:
		if 目标.collision_layer == 16: return 阵营管理器.关系.敌对
		elif 目标.collision_layer == 8: return 阵营管理器.关系.友军
	return 阵营管理器.关系.中立

func 是敌对(目标) -> bool: return 获取关系(目标) == 阵营管理器.关系.敌对
func 是友军(目标) -> bool: return 获取关系(目标) == 阵营管理器.关系.友军
func _是敌人() -> bool: return _阵营 == 阵营管理器.阵营.敌人
func _是玩家() -> bool: return _阵营 == 阵营管理器.阵营.玩家


# ============================================================
# 移动入口（唯一对外接口）
# ============================================================

## 应用一个移动请求，委托给运动服务处理
func 应用移动请求(请求: 移动请求) -> void:
	if not is_instance_valid(运动服务.实例):
		return
	当前移动请求 = 请求
	运动服务.实例.请求移动(self, 请求)
	移动开始.emit()


## 设队形偏移 — CommandManager 在发出命令时调用（在请求创建前预存）
func 设队形(偏移: Vector2) -> void:
	_pending_formation_offset = 偏移


## 设队形槽位 — CommandManager 在发出命令时调用
func 设队形槽位(slot_id: int) -> void:
	_pending_formation_slot = slot_id


## 立即停止所有移动
func 立即停止() -> void:
	if is_instance_valid(运动服务.实例):
		运动服务.实例.强制停止(self, 移动结果.结果类型.被中断)
	当前移动请求 = null


## 响应运动服务的移动完成信号
func _on_运动服务移动结束(单位: Node2D, 结果: 移动结果) -> void:
	if 单位 != self:
		return
	当前移动请求 = null
	移动结束.emit(结果)


# ============================================================
# 命令接口（CommandManager 调用 + 子类可重写）
# ============================================================

func 设置命令(type: int, pos: Vector2 = Vector2.ZERO, target: Node2D = null) -> void:
	if DIAG: print("[CMD] 单位基类.设置命令: ", name, " type=", type, " pos=", pos, " target=", target.name if target else "null")
	当前命令 = type
	if pos != Vector2.ZERO: 目标位置 = pos
	if target: 攻击目标 = target

	match type:
		命令管理器.命令类型.移动: _执行移动命令()
		命令管理器.命令类型.攻击: _执行攻击命令()
		命令管理器.命令类型.移动攻击: _执行攻击移动命令()
		命令管理器.命令类型.停止: _执行停止命令()
		命令管理器.命令类型.驻守: _执行驻守命令()
		命令管理器.命令类型.巡逻: _执行巡逻命令()


func 取消攻击() -> void:
	if 战斗组件: 战斗组件.cancel_attack()
	if 索敌组件: 索敌组件.clear_target()


func _执行移动命令() -> void:
	取消攻击()
	var 请求 = 移动请求.前往位置(目标位置)
	请求.停止距离 = 停止阈值  # 使用单位自身的停止阈值
	if _pending_formation_offset != Vector2.ZERO:
		请求.队形偏移 = _pending_formation_offset
		请求.队形槽位 = _pending_formation_slot
		_pending_formation_offset = Vector2.ZERO
		_pending_formation_slot = -1
	应用移动请求(请求)
	_切换动画("移动")
	_隐藏驻守图标()


func _执行攻击命令() -> void:
	if not is_instance_valid(攻击目标) or not 是敌对(攻击目标): return
	if 索敌组件: 索敌组件.set_target(攻击目标)
	var 请求 = 移动请求.追击敌人(攻击目标)
	应用移动请求(请求)
	_切换动画("移动")
	_隐藏驻守图标()


func _执行攻击移动命令() -> void:
	取消攻击()
	var 请求 = 移动请求.移动攻击(目标位置)
	应用移动请求(请求)
	_切换动画("移动")
	_隐藏驻守图标()


func _执行停止命令() -> void:
	if DIAG: print("[CMD] ", name, " 执行停止命令")
	取消攻击()
	立即停止()
	_切换动画("待机")
	_隐藏驻守图标()


func _执行驻守命令() -> void:
	if DIAG: print("[CMD] ", name, " 执行驻守命令")
	取消攻击()
	立即停止()
	_切换动画("待机")
	_显示驻守图标()


func _执行巡逻命令() -> void:
	取消攻击()
	var 请求 = 移动请求.前往位置(目标位置)
	应用移动请求(请求)
	_切换动画("移动")
	_隐藏驻守图标()


# ============================================================
# 物理帧 — 唯一执行 move_and_slide()
# ============================================================

func _physics_process(delta: float) -> void:
	## 速度由 运动服务 写入，本帧只执行物理移动
	move_and_slide()


# ============================================================
# 子类接口
# ============================================================

func _切换动画(动画名: String) -> void: pass
func 获取当前生命值() -> float: return 生命组件.hp if 生命组件 else 最大生命值
func 获取最大生命值() -> float: return 生命组件.max_hp if 生命组件 else 最大生命值
func 是否存活() -> bool: return 生命组件 and not 生命组件.is_dead()
func 获取索敌组件() -> TargetingComponent: return 索敌组件


# ============================================================
# 视觉分离（仅影响 visual_offset，不碰 velocity）
# ============================================================

func _process(_delta: float) -> void:
	_update_visual_separation()
	if has_node("角色图像"):
		$角色图像.position = visual_offset

func _update_visual_separation() -> void:
	_visual_sep_counter += 1
	if _visual_sep_counter % VISUAL_SEP_INTERVAL != _visual_sep_phase: return
	var push: Vector2 = Vector2.ZERO
	var count: int = 0
	for other_node in 单位管理器.获取所有单位():
		var other: Node2D = other_node
		if other == self or not is_instance_valid(other): continue
		var offset: Vector2 = global_position - other.global_position
		var dist: float = offset.length()
		if dist < 1 or dist > 60: continue
		var strength: float = 1.0 - (dist / 60.0)
		push += offset.normalized() * strength
		count += 1
	if count > 0: push /= count
	visual_offset = visual_offset.lerp(push * VISUAL_RADIUS, 0.15)


# ============================================================
# 兼容旧接口（保留但标记为弃用）
# ============================================================

func _使用流场移动(delta: float) -> bool:
	"""兼容旧接口：返回是否已到达
	   新单位请用 应用移动请求() + 移动结束 信号"""
	if 当前移动请求 != null:
		return 运动服务.实例.是否在移动(self) == false
	return false


# ============================================================
# 驻守图标
# ============================================================

func _创建驻守图标() -> void:
	if _驻守图标 and is_instance_valid(_驻守图标): return
	_驻守图标 = GARRISON_ICON.instantiate()
	add_child(_驻守图标)

func _显示驻守图标() -> void:
	if not _驻守图标 or not is_instance_valid(_驻守图标): _创建驻守图标()
	if is_instance_valid(_驻守图标): _驻守图标.visible = true

func _隐藏驻守图标() -> void:
	if _驻守图标 and is_instance_valid(_驻守图标): _驻守图标.visible = false


## 逐圈搜索空位：20px→36px→52px→68px→84px，全占满才放弃
func _尝试队形散开() -> void:
	var 周围单位 = 单位管理器.获取所有单位() if is_instance_valid(单位管理器.实例) else []
	var 占据位置: Array = []
	for 其他 in 周围单位:
		if 其他 == self or not is_instance_valid(其他):
			continue
		if 其他.global_position.distance_squared_to(global_position) < 2500.0:
			占据位置.append(其他.global_position)
	if 占据位置.is_empty():
		return
	var 搜索圈半径 := [20, 36, 52, 68, 84]
	for 圈半径 in 搜索圈半径:
		var 候选位置列表: Array = [
			global_position + Vector2(圈半径, 0),
			global_position + Vector2(-圈半径, 0),
			global_position + Vector2(0, 圈半径),
			global_position + Vector2(0, -圈半径),
			global_position + Vector2(圈半径 * 0.7, 圈半径 * 0.7),
			global_position + Vector2(-圈半径 * 0.7, 圈半径 * 0.7),
			global_position + Vector2(圈半径 * 0.7, -圈半径 * 0.7),
			global_position + Vector2(-圈半径 * 0.7, -圈半径 * 0.7),
		]
		for 候选位置 in 候选位置列表:
			var 被占据 = false
			for 占用 in 占据位置:
				if 候选位置.distance_squared_to(占用) < 400.0:
					被占据 = true
					break
			if not 被占据:
				var 请求 = 移动请求.前往位置(候选位置)
				请求.停止距离 = 4.0
				应用移动请求(请求)
				return
	if _驻守图标 and is_instance_valid(_驻守图标): _驻守图标.visible = false
