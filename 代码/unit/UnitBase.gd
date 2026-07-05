class_name 单位基类
extends CharacterBody2D

## 单位基类 — RTS 单位根基类（状态机整合版）
##
## ⚠ velocity 由 运动服务 在 _physics_process 中写入，
##    本类 _physics_process 只调用 move_and_slide()
##    状态决策由 单元状态机 子节点统一处理

const DIAG: bool = true

signal 避开友军
signal 移动开始              # 收到新的移动请求时

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
@export var 停止阈值: float = 4.0
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

# ========== 命令状态（由 CommandManager + 状态机共同管理） ==========
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

# ========== MovementSolver（新移动系统） ==========
## 当前移动意图（由状态机写入，MovementSolver 读取）
var 移动意图: MovementIntent = MovementIntent.new()
## 是否已迁移到 MovementSolver（Phase 1: false，所有单位走旧路径）
var _using_movement_solver: bool = false

# ========== 状态机引用 ==========
var _状态机: 单元状态机 = null


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

	# 创建状态机子节点
	_状态机 = 单元状态机.附加到(self)


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
	# 状态机的 _exit_tree 会自动断开运动服务信号


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
##
## ⚠ Phase 7.4: 禁止 clear() 就地修改 intent。
##   clear() 修改同一个 RefCounted 对象，导致 MovementSolver
##   在该间隙读到无效 intent → 抽搐。
##   必须原子性替换为新 intent。
func 立即停止() -> void:
	if _using_movement_solver:
		# ★ 原子替换：创建新 NONE 类型 intent，不清除旧对象
		移动意图 = MovementIntent.new()
		if is_instance_valid(MovementSolver.实例):
			MovementSolver.实例.强制停止(self, 移动结果.结果类型.被中断)
		当前移动请求 = null
		return

	if is_instance_valid(运动服务.实例):
		运动服务.实例.强制停止(self, 移动结果.结果类型.被中断)
	当前移动请求 = null


# ============================================================
# 命令接口（CommandManager 调用 → 状态机响应）
# ============================================================

func 设置命令(type: int, pos: Vector2 = Vector2.ZERO, target: Node2D = null) -> void:
	if DIAG: print("[CMD] 单位基类.设置命令: ", name, " type=", type, " pos=", pos, " target=", target.name if target else "null")

	# 非攻击命令取消正在进行的攻击
	if type != 命令管理器.命令类型.攻击:
		取消攻击()

	# 设置命令参数
	当前命令 = type
	if pos != Vector2.ZERO: 目标位置 = pos
	if target:
		攻击目标 = target
		# 同步给索敌组件（状态机需要它判断距离）
		if 索敌组件 and type == 命令管理器.命令类型.攻击:
			索敌组件.set_target(target)

	# 通知状态机立即响应（不必等下一帧 physics）
	if _状态机:
		_状态机.立即响应()


func 取消攻击() -> void:
	if 战斗组件: 战斗组件.cancel_attack()
	if 索敌组件: 索敌组件.clear_target()


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
	# 驻守图标跟随当前命令状态
	_更新驻守图标()

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

func _更新驻守图标() -> void:
	if 当前命令 == 命令管理器.命令类型.驻守:
		_显示驻守图标()
	else:
		_隐藏驻守图标()


# ============================================================
# 兼容旧接口（保留但标记为弃用）
# ============================================================

func _使用流场移动(delta: float) -> bool:
	"""兼容旧接口：返回是否已到达
	   新单位请用 应用移动请求() + 状态机信号"""
	if 当前移动请求 != null:
		return 运动服务.实例.是否在移动(self) == false
	return false
