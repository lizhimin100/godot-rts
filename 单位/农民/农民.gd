extends UnitBase
class_name 农民

## 农民 — RTS 基础生产单位
## 可建造建筑、采集资源
## BUILD 状态特殊：不调用 move_and_slide（避免被施工场地碰撞体推走）

enum State {
	IDLE,
	MOVE,
	BUILD
}

@export var 攻击力: float = 5.0
@export var 攻击范围: float = 25.0

const 玩家纹理: Texture2D = preload("res://小剑资源/兵种/Knights/Troops/Pawn/Blue/Pawn_Blue.png")
const 敌人纹理: Texture2D = preload("res://小剑资源/兵种/Knights/Troops/Pawn/Red/Pawn_Red.png")

const 施工纹理: Dictionary = {
	全局变量.建筑类型.城堡: preload("res://小剑资源/兵种/Knights/Buildings/Castle/Castle_Construction.png"),
	全局变量.建筑类型.房子: preload("res://小剑资源/兵种/Knights/Buildings/House/House_Construction.png"),
	全局变量.建筑类型.防御塔: preload("res://小剑资源/兵种/Knights/Buildings/Tower/Tower_Construction.png"),
}

var 当前状态: State = State.IDLE
var _建造目标: Node2D = null

# 建造系统
var _建造类型: int = -1
var _建造位置: Vector2 = Vector2.ZERO
var _建造计时器: Timer
var _施工场地: Node2D = null
var _施工场地碰撞体: StaticBody2D = null
const 建造时间表: Dictionary = {
	全局变量.建筑类型.城堡: 48.0,
	全局变量.建筑类型.房子: 8.0,
	全局变量.建筑类型.防御塔: 18.0,
}
var _建造总时间: float = 8.0

# 建造闪烁瞬移参数
var _建造闪烁计时: float = 0.0
var _建造闪烁间隔: float = 2.0
const 建造站立偏移: float = 30.0
var _原始z_index: int = 0

const 建造接近阈值: float = 60.0

@onready var 选中标签: Label = $选中标签
@onready var 角色图像: Sprite2D = $角色图像
@onready var 角色动画: AnimationPlayer = $角色动画


func _ready() -> void:
	super._ready()
	当前状态 = State.IDLE

	var 新材质 = 角色图像.material.duplicate()
	角色图像.material = 新材质

	if _是敌人():
		角色图像.texture = 敌人纹理
		角色图像.material.set_shader_parameter("outline_color", Color(0.9, 0.2, 0.2, 1))
		collision_mask = 32 + 8 + 4
	else:
		角色图像.texture = 玩家纹理
		collision_mask = 32 + 16 + 4

	选中标签.visible = false
	角色动画.play("待机")

	# 建造计时器
	_建造计时器 = Timer.new()
	_建造计时器.name = "建造计时器"
	_建造计时器.one_shot = true
	_建造计时器.timeout.connect(_建造完成)
	add_child(_建造计时器)

	# 攻击动画结束自动重播（建造时持续敲击）
	角色动画.animation_finished.connect(_动画结束重播)


func _physics_process(delta: float) -> void:
	if is_instance_valid(选中标签):
		选中标签.visible = 选择状态

	# ⭐ BUILD 状态：不调用 move_and_slide
	if 当前状态 == State.BUILD:
		_处理建造振荡(delta)
		return

	_同步命令状态()

	match 当前状态:
		State.IDLE:
			_处理待机状态(delta)
		State.MOVE:
			_处理移动状态(delta)

	# ⭐ 统一 move_and_slide（控制器只设 velocity）
	move_and_slide()
	if velocity.x != 0:
		角色图像.flip_h = velocity.x < 0

	# 移动中碰到施工场地碰撞体 -> 开始建造
	if 当前状态 == State.MOVE and _建造类型 >= 0 and _检测施工场地接触():
		_开始建造()


func 命令移动(位置: Vector2, 攻击移动: bool = false) -> void:
	# 只要有建造任务，取消建造
	if _建造类型 >= 0:
		_取消建造()
	super.命令移动(位置, 攻击移动)


func 命令停止() -> void:
	if _建造类型 >= 0:
		_取消建造()
	super.命令停止()


func 命令攻击(目标: Node2D) -> void:
	if _建造类型 >= 0:
		_取消建造()
	super.命令攻击(目标)


func _同步命令状态() -> void:
	if 当前状态 == State.BUILD:
		return
	match 当前命令:
		命令类型.移动:
			if 当前状态 != State.MOVE:
				切换状态(State.MOVE)
		命令类型.无, 命令类型.驻守, _:
			if 当前状态 != State.IDLE:
				切换状态(State.IDLE)


func _通知命令变更() -> void:
	_同步命令状态()


func 切换状态(to: State) -> void:
	if 当前状态 == to: return
	当前状态 = to
	_建造闪烁计时 = 0.0
	_建造闪烁间隔 = randf_range(1.0, 3.0)
	match to:
		State.IDLE: _切换动画("待机")
		State.MOVE: _切换动画("移动")
		State.BUILD:
			if 角色动画.has_animation("攻击"):
				角色动画.play("攻击")
			else:
				角色动画.play("待机")


func _切换动画(动画名: String) -> void:
	if 角色动画 and 角色动画.has_animation(动画名):
		角色动画.play(动画名)


# ============================================================
# 待机
# ============================================================

func _动画结束重播(动画名: String) -> void:
	if 当前状态 == State.BUILD and 动画名 == "攻击" and 角色动画.has_animation("攻击"):
		角色动画.play("攻击")


func _处理待机状态(delta: float) -> void:
	if 当前命令 in [命令类型.移动, 命令类型.攻击, 命令类型.巡逻]:
		if 目标位置 != Vector2.ZERO:
			切换状态(State.MOVE)
		return
	var 排斥力: Vector2 = _计算排斥力()
	if 排斥力.length_squared() > 0.01:
		velocity = velocity.move_toward(排斥力, 移动速度 * 10.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 移动速度 * 10.0 * delta)


# ============================================================
# 移动（包含前往建造 + 正常流场移动）
# ============================================================

func _处理移动状态(delta: float) -> void:
	# ⭐ 前往建造：直线走向建筑中心，不走流场导航
	if _建造类型 >= 0:
		if not is_instance_valid(_施工场地):
			_创建施工场地()
		# 接近检测
		if global_position.distance_to(_建造位置) <= 建造接近阈值:
			_开始建造()
			return
		# 直接向建筑中心移动，让 move_and_slide 处理碰撞
		var 到建筑 = _建造位置 - global_position
		velocity = 到建筑.normalized() * 移动速度 * 0.6
		return

	# ⭐ 正常移动：使用流场控制器（流场+避障+卡死检测）
	var 所有单位: Array = get_tree().get_nodes_in_group("移动单位")
	FFManager.update_target(目标位置, 所有单位)
	if unit_controller.move_toward(目标位置, delta, FFManager.get_flow_field(), 所有单位):
		当前命令 = 命令类型.无
		切换状态(State.IDLE)
		return


## 创建施工场地（含碰撞体，阻挡单位穿过）
func _创建施工场地() -> void:
	if not 施工纹理.has(_建造类型):
		return
	_施工场地 = Node2D.new()
	_施工场地.name = "施工场地"
	_施工场地.z_index = 50
	_施工场地.global_position = _建造位置

	var 精灵: Sprite2D = Sprite2D.new()
	精灵.texture = 施工纹理[_建造类型]
	精灵.modulate = Color(1, 1, 1, 0.3)
	_施工场地.add_child(精灵)

	# 进度条
	var 进度条: ProgressBar = ProgressBar.new()
	进度条.name = "建造进度条"
	进度条.min_value = 0.0
	进度条.max_value = 100.0
	进度条.value = 0.0
	进度条.size = Vector2(60, 10)
	进度条.position = Vector2(-30, -60)
	进度条.modulate = Color(1, 1, 1, 0.85)
	进度条.show_percentage = false
	_施工场地.add_child(进度条)

	# 碰撞体——建筑占用体积
	_施工场地碰撞体 = StaticBody2D.new()
	_施工场地碰撞体.collision_layer = 4  # 建筑层
	var 碰撞形状: CollisionShape2D = CollisionShape2D.new()
	var 矩形: RectangleShape2D = RectangleShape2D.new()
	矩形.size = 全局变量.建筑碰撞尺寸.get(_建造类型, Vector2(80, 80))
	碰撞形状.shape = 矩形
	_施工场地碰撞体.add_child(碰撞形状)
	_施工场地.add_child(_施工场地碰撞体)

	_施工场地.add_to_group("施工场地")
	get_parent().add_child(_施工场地)


## 开始建造
func _开始建造() -> void:
	if not is_instance_valid(_施工场地):
		_创建施工场地()

	切换状态(State.BUILD)
	_建造总时间 = 建造时间表.get(_建造类型, 8.0)
	_建造计时器.start(_建造总时间)

	_原始z_index = z_index
	_瞬移到建筑边缘(true)

	if is_instance_valid(_施工场地):
		var 精灵: Node = _施工场地.get_child(0) if _施工场地.get_child_count() > 0 else null
		if 精灵 and 精灵 is Sprite2D:
			精灵.modulate = Color(1, 1, 1, 1)

	全局变量.显示通知("建造中...", _建造位置)


## 瞬移到建筑边缘
func _瞬移到建筑边缘(立即: bool = false) -> void:
	if _建造类型 < 0 or not is_instance_valid(_施工场地):
		return

	var 建筑中心 = _施工场地.global_position

	var 水平范围: float = 30.0
	var 精灵: Sprite2D = null
	if _施工场地.get_child_count() > 0:
		精灵 = _施工场地.get_child(0) as Sprite2D
	if 精灵 and 精灵.texture:
		水平范围 = 精灵.texture.get_size().x * 0.35
	else:
		水平范围 = 全局变量.建筑碰撞尺寸.get(_建造类型, Vector2(80, 80)).x * 0.35
	var 目标位置: Vector2 = 建筑中心 + Vector2(randf_range(-水平范围, 水平范围), 30.0)


	z_index = 60

	if 立即:
		global_position = 目标位置
		_建造闪烁计时 = 0.0
		_建造闪烁间隔 = randf_range(1.0, 3.0)
	else:
		var 旧位置 = global_position
		var 原缩放 = scale
		_生成瞬移残影(旧位置, 目标位置)
		var tween: Tween = create_tween().set_parallel(false)
		tween.tween_property(self, "scale", Vector2.ZERO, 0.08)
		tween.tween_callback(func():
			if is_instance_valid(self):
				global_position = 目标位置
		)
		tween.tween_property(self, "scale", 原缩放, 0.1)


func _处理建造振荡(delta: float) -> void:
	velocity = Vector2.ZERO  # 建造时不动

	if _建造类型 < 0 or not is_instance_valid(_施工场地) or _建造位置 == Vector2.ZERO:
		_取消建造()
		return

	var 建筑中心 = _施工场地.global_position if is_instance_valid(_施工场地) else _建造位置

	_建造闪烁计时 += delta
	if _建造闪烁计时 < _建造闪烁间隔:
		return

	_建造闪烁计时 = 0.0
	_建造闪烁间隔 = randf_range(1.0, 3.0)

	_瞬移到建筑边缘(false)

	if is_instance_valid(_施工场地) and _建造计时器.time_left > 0 and _建造总时间 > 0:
		var 进度条 = _施工场地.get_node_or_null("建造进度条")
		if 进度条:
			进度条.value = (1.0 - _建造计时器.time_left / _建造总时间) * 100.0


func _生成瞬移残影(旧位置: Vector2, 新位置: Vector2) -> void:
	const 残影数量: int = 5
	const 残影存在时间: float = 0.3
	const 残影尺寸缩放: float = 0.6

	for i in 残影数量:
		var 进度 = float(i) / float(残影数量 - 1)
		var 中间位置 = 旧位置.lerp(新位置, 进度)
		中间位置 += Vector2(randf_range(-8, 8), randf_range(-8, 8))

		var 残影: Sprite2D = Sprite2D.new()
		残影.texture = 角色图像.texture
		残影.region_enabled = 角色图像.region_enabled
		残影.region_rect = 角色图像.region_rect
		残影.hframes = 角色图像.hframes
		残影.frame = 角色图像.frame
		残影.centered = 角色图像.centered
		残影.scale = scale * 残影尺寸缩放
		残影.global_position = 中间位置
		残影.modulate = Color(0, 0, 0, 0.5)
		残影.z_index = z_index - 1

		get_parent().add_child(残影)

		var 残影tween: Tween = create_tween()
		残影tween.tween_property(残影, "modulate:a", 0.0, 残影存在时间)
		残影tween.parallel().tween_property(残影, "scale", scale * 残影尺寸缩放 * 1.5, 残影存在时间)
		残影tween.tween_callback(残影.queue_free)

	var 拖尾: Line2D = Line2D.new()
	拖尾.points = PackedVector2Array([旧位置, 新位置])
	拖尾.width = 12.0
	拖尾.default_color = Color(0, 0, 0, 0.3)
	拖尾.gradient = Gradient.new()
	拖尾.gradient.set_color(0, Color(0, 0, 0, 0.5))
	拖尾.gradient.set_color(1, Color(0, 0, 0, 0.0))
	拖尾.z_index = z_index - 1
	get_parent().add_child(拖尾)

	var 拖尾tween: Tween = create_tween()
	拖尾tween.tween_property(拖尾, "width", 0.0, 0.2)
	拖尾tween.parallel().tween_property(拖尾, "default_color:a", 0.0, 0.2)
	拖尾tween.tween_callback(拖尾.queue_free)


func _检测施工场地接触() -> bool:
	if not is_instance_valid(_施工场地碰撞体):
		return false
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		if col and col.get_collider() == _施工场地碰撞体:
			return true
	return false


func _取消建造() -> void:
	if _建造类型 < 0:
		return
	if _建造计时器 and _建造计时器.time_left > 0:
		_建造计时器.stop()
	if is_instance_valid(_施工场地):
		_施工场地.queue_free()
		_施工场地 = null
	_施工场地碰撞体 = null
	var 类型名 = "未知"
	if _建造类型 >= 0 and _建造类型 < 全局变量.建筑类型.size():
		类型名 = 全局变量.建筑类型.keys()[_建造类型]
	print("建造已取消: ", 类型名)
	_建造类型 = -1
	_建造位置 = Vector2.ZERO
	z_index = _原始z_index
	切换状态(State.IDLE)


func 命令建造(建筑类型: int, 建筑位置: Vector2) -> void:
	if 当前状态 == State.BUILD:
		return
	_建造类型 = 建筑类型
	_建造位置 = 建筑位置
	_建造目标 = null

	目标位置 = 建筑位置
	当前命令 = 命令类型.移动
	if 导航代理:
		导航代理.target_position = 目标位置
	切换状态(State.MOVE)
	print("农民前往建造: ", 全局变量.建筑类型.keys()[建筑类型], " 位置: ", 建筑位置)


func _建造完成() -> void:
	if _建造类型 < 0:
		return

	if is_instance_valid(_施工场地):
		_施工场地.queue_free()
		_施工场地 = null
	_施工场地碰撞体 = null

	var 场景 = 全局变量.建筑场景.get(_建造类型)
	if 场景:
		var 建筑 = 场景.instantiate()
		建筑.global_position = _建造位置
		get_parent().add_child(建筑)
		# ⭐ 通知流场管理器障碍变化
		FlowFieldManager.mark_dirty()
		print("农民建造完成: ", 全局变量.建筑类型.keys()[_建造类型])
		全局变量.显示通知("建造完成！", _建造位置 + Vector2(0, -40))
	else:
		print("未知建筑类型: ", _建造类型)

	_建造类型 = -1
	_建造位置 = Vector2.ZERO
	当前命令 = 命令类型.无
	z_index = _原始z_index
	切换状态(State.IDLE)


func 执行攻击() -> void:
	pass
