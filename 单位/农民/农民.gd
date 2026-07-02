extends 单位基类
class_name 农民

## 农民 — RTS 基础生产单位
##
## 3 状态状态机：IDLE / MOVE / BUILD
## 速度由 运动服务 统一管理
## 建造移动使用 技能驱动移动 策略

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

var _建造类型: int = -1
var _建造位置: Vector2 = Vector2.ZERO
var _建造计时器: Timer
var _施工场地: Node2D = null
var _施工场地碰撞体: StaticBody2D = null
var _建造进度UI: Node2D = null
const 建造时间表: Dictionary = {
	全局变量.建筑类型.城堡: 48.0,
	全局变量.建筑类型.房子: 8.0,
	全局变量.建筑类型.防御塔: 18.0,
}
var _建造总时间: float = 8.0

var _建造闪烁计时: float = 0.0
var _建造闪烁间隔: float = 2.0
## 建造接近方向（瞬移前记录，用于瞬移后朝向）
var _建造接近方向: float = 1.0
const 建造站立偏移: float = 30.0
var _原始z_index: int = 0

const 建造接近阈值: float = 80.0

@onready var 选中标签: Label = $选中标签
@onready var 角色图像: Sprite2D = $角色图像
@onready var 角色动画: AnimationPlayer = $角色动画


func _ready() -> void:
	stats = UnitStats.create_农民_stats()
	# 移动速度由场景值决定，stats 不覆盖

	super._ready()
	当前状态 = State.IDLE

	var 新材质 = 角色图像.material.duplicate()
	角色图像.material = 新材质

	if _是敌人():
		角色图像.texture = 敌人纹理
		角色图像.material.set_shader_parameter("outline_color", Color(0.9, 0.2, 0.2, 1))
	else:
		角色图像.texture = 玩家纹理

	选中标签.visible = false
	角色动画.play("待机")

	_建造计时器 = Timer.new()
	_建造计时器.name = "建造计时器"
	_建造计时器.one_shot = true
	_建造计时器.timeout.connect(_建造完成)
	add_child(_建造计时器)

	角色动画.animation_finished.connect(_动画结束重播)

	# 监听移动结束
	移动结束.connect(_on_农民移动结束)


func _physics_process(delta: float) -> void:
	if is_instance_valid(选中标签):
		选中标签.visible = false

	if 当前状态 == State.BUILD:
		_处理建造振荡(delta)

	_同步命令状态()

	match 当前状态:
		State.IDLE:
			_处理待机状态(delta)
		State.MOVE:
			_处理移动状态(delta)

	super._physics_process(delta)

	# ⭐ 移动中速度归零时的动画 fallback
	if 当前状态 == State.MOVE and velocity.length_squared() < 4.0:
		if 当前状态 == State.BUILD:
			pass
		elif 角色动画.current_animation == "移动":
			角色动画.play("待机")

	# 动画
	if 当前状态 == State.MOVE:
		if velocity.length_squared() < 4.0:
			if 角色动画.current_animation == "移动":
				角色动画.play("待机")
		else:
			if 角色动画.current_animation != "移动":
				角色动画.play("移动")

	if velocity.x != 0:
		角色图像.flip_h = velocity.x < 0

	if 当前状态 == State.MOVE and _建造类型 >= 0 and _检测施工场地接触():
		_开始建造()


func _on_农民移动结束(结果: 移动结果) -> void:
	match 结果.结果:
		移动结果.结果类型.已到达:
			if _建造类型 >= 0:
				_开始建造()
			else:
				当前命令 = 命令管理器.命令类型.无
				切换状态(State.IDLE)
		_:
			pass


func 命令移动(位置: Vector2, 攻击移动: bool = false) -> void:
	if _建造类型 >= 0:
		_取消建造()
	设置命令(命令管理器.命令类型.移动, 位置)


func 命令停止() -> void:
	if _建造类型 >= 0:
		_取消建造()
	设置命令(命令管理器.命令类型.停止)


func 命令攻击(目标: Node2D) -> void:
	if _建造类型 >= 0:
		_取消建造()
	设置命令(命令管理器.命令类型.攻击, Vector2.ZERO, 目标)


func 设置命令(type: int, pos: Vector2 = Vector2.ZERO, target: Node2D = null) -> void:
	if _建造类型 >= 0:
		_取消建造()
	super.设置命令(type, pos, target)


func _同步命令状态() -> void:
	if 当前状态 == State.BUILD:
		return
	match 当前命令:
		命令管理器.命令类型.移动:
			if 当前状态 != State.MOVE:
				切换状态(State.MOVE)
		命令管理器.命令类型.无, 命令管理器.命令类型.驻守, _:
			if 当前状态 != State.IDLE:
				切换状态(State.IDLE)


func 切换状态(to: State) -> void:
	if 当前状态 == to: return
	当前状态 = to
	_建造闪烁计时 = 0.0
	_建造闪烁间隔 = randf_range(1.0, 3.0)
	match to:
		State.IDLE:
			_切换动画("待机")
			# ⚠ 不调用强制停止（运动服务的到达锁定已负责 velocity 归零）
		State.MOVE:
			_切换动画("移动")
		State.BUILD:
			if 角色动画.has_animation("攻击"):
				角色动画.play("攻击")
			else:
				角色动画.play("待机")


func _切换动画(动画名: String) -> void:
	if 角色动画 and 角色动画.has_animation(动画名):
		角色动画.play(动画名)


func _动画结束重播(动画名: String) -> void:
	if 当前状态 == State.BUILD and 动画名 == "攻击" and 角色动画.has_animation("攻击"):
		角色动画.play("攻击")


func _处理待机状态(delta: float) -> void:
	if 当前命令 in [命令管理器.命令类型.移动, 命令管理器.命令类型.攻击, 命令管理器.命令类型.巡逻]:
		if 目标位置 != Vector2.ZERO:
			切换状态(State.MOVE)
		return


func _处理移动状态(delta: float) -> void:
	if _建造类型 >= 0:
		if not is_instance_valid(_施工场地):
			_创建施工场地()
		if not is_instance_valid(运动服务.实例) or not 运动服务.实例.是否在移动(self):
			var 请求 = 移动请求.技能驱动(_建造位置, self, {"建筑类型": _建造类型})
			请求.停止距离 = 建造接近阈值
			应用移动请求(请求)
		return


const CONSTRUCTION_SITE = preload("res://combat/effects/construction_site.tscn")
const AFTERIMAGE = preload("res://combat/effects/afterimage.tscn")
const BUILD_COUNTDOWN_UI = preload("res://combat/effects/build_countdown_ui.tscn")


func _创建施工场地() -> void:
	if not 施工纹理.has(_建造类型):
		return
	_施工场地 = CONSTRUCTION_SITE.instantiate()
	_施工场地.global_position = _建造位置
	_施工场地.add_to_group("施工场地")
	get_parent().add_child(_施工场地)
	_施工场地.set_building_texture(施工纹理[_建造类型])
	_施工场地.set_blocker_size(全局变量.建筑碰撞尺寸.get(_建造类型, Vector2(80, 80)))
	_施工场地.set_builder(self, 阵营, _建造类型)
	var 建筑HP = 全局变量.建筑最大生命值.get(_建造类型, 200.0)
	_施工场地.set_building_hp(建筑HP)
	_施工场地碰撞体 = _施工场地.get_node("Blocker") as StaticBody2D


func _开始建造() -> void:
	if 当前状态 == State.BUILD:
		return
	if not is_instance_valid(_施工场地):
		_创建施工场地()
	切换状态(State.BUILD)
	_建造总时间 = 建造时间表.get(_建造类型, 8.0)
	_建造计时器.start(_建造总时间)
	_原始z_index = z_index
	# 记录接近方向
	if is_instance_valid(_施工场地):
		_建造接近方向 = _施工场地.global_position.x - global_position.x
	_瞬移到建筑边缘(true)
	if is_instance_valid(_施工场地):
		var sprite2d = _施工场地.get_node("Sprite") as Sprite2D
		if sprite2d:
			sprite2d.modulate = Color(1, 1, 1, 1)
		if not is_instance_valid(_建造进度UI):
			_建造进度UI = BUILD_COUNTDOWN_UI.instantiate()
			_施工场地.add_child(_建造进度UI)
			var ui_bar := _建造进度UI.get_node("建造倒计时") as ProgressBar
			if ui_bar:
				ui_bar.value = 0.0
	全局变量.显示通知("建造中...", _建造位置)


func _瞬移到建筑边缘(立即: bool = false) -> void:
	if _建造类型 < 0 or not is_instance_valid(_施工场地):
		return
	var 建筑中心 = _施工场地.global_position
	var 水平范围: float = 30.0
	var site_sprite: Sprite2D = _施工场地.get_node("Sprite") as Sprite2D
	if site_sprite and site_sprite.texture:
		水平范围 = site_sprite.texture.get_size().x * 0.35
	else:
		水平范围 = 全局变量.建筑碰撞尺寸.get(_建造类型, Vector2(80, 80)).x * 0.35
	var _瞬移位置: Vector2 = 建筑中心 + Vector2(randf_range(-水平范围, 水平范围), 30.0)
	z_index = 60
	if 立即:
		global_position = _瞬移位置
		# 面向建筑中心
		if has_node("角色图像"):
			$角色图像.flip_h = global_position.x < 建筑中心.x
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
				global_position = _瞬移位置
		)
		tween.tween_property(self, "scale", 原缩放, 0.1)


func _处理建造振荡(delta: float) -> void:
	if _建造类型 < 0 or not is_instance_valid(_施工场地) or _建造位置 == Vector2.ZERO:
		_取消建造()
		return
	_建造闪烁计时 += delta
	if _建造闪烁计时 < _建造闪烁间隔:
		return
	_建造闪烁计时 = 0.0
	_建造闪烁间隔 = randf_range(1.0, 3.0)
	_瞬移到建筑边缘(false)
	if is_instance_valid(_施工场地) and _建造计时器.time_left > 0 and _建造总时间 > 0:
		var 进度: float = (1.0 - _建造计时器.time_left / _建造总时间) * 100.0
		if is_instance_valid(_建造进度UI):
			var ui_bar: ProgressBar = _建造进度UI.get_node("建造倒计时") as ProgressBar
			if ui_bar:
				ui_bar.value = 进度


func _生成瞬移残影(旧位置: Vector2, 新位置: Vector2) -> void:
	const 残影数量: int = 5
	for i in 残影数量:
		var 进度 = float(i) / float(残影数量 - 1)
		var 中间位置 = 旧位置.lerp(新位置, 进度)
		中间位置 += Vector2(randf_range(-8, 8), randf_range(-8, 8))
		var 残影: Sprite2D = AFTERIMAGE.instantiate()
		残影.texture = 角色图像.texture
		残影.region_enabled = 角色图像.region_enabled
		残影.region_rect = 角色图像.region_rect
		残影.hframes = 角色图像.hframes
		残影.frame = 角色图像.frame
		残影.centered = 角色图像.centered
		残影.scale = scale * 0.6
		残影.global_position = 中间位置
		残影.modulate = Color(0, 0, 0, 0.5)
		残影.z_index = z_index - 1
		get_parent().add_child(残影)
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
	if is_instance_valid(_建造进度UI):
		_建造进度UI.queue_free()
		_建造进度UI = null
	if is_instance_valid(_施工场地):
		_施工场地.queue_free()
		_施工场地 = null
	_施工场地碰撞体 = null
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
	当前命令 = 命令管理器.命令类型.移动
	切换状态(State.MOVE)
	var 请求 = 移动请求.技能驱动(_建造位置, self, {"建筑类型": _建造类型})
	请求.停止距离 = 建造接近阈值
	应用移动请求(请求)


func _建造完成() -> void:
	if _建造类型 < 0:
		return
	if is_instance_valid(_建造进度UI):
		_建造进度UI.queue_free()
		_建造进度UI = null
	if is_instance_valid(_施工场地):
		_施工场地.queue_free()
		_施工场地 = null
	_施工场地碰撞体 = null
	var 场景 = 全局变量.建筑场景.get(_建造类型)
	if 场景:
		var 建筑 = 场景.instantiate()
		建筑.global_position = _建造位置
		get_parent().add_child(建筑)
		FFManager.mark_dirty()
		全局变量.显示通知("建造完成！", _建造位置 + Vector2(0, -40))
	_建造类型 = -1
	_建造位置 = Vector2.ZERO
	当前命令 = 命令管理器.命令类型.无
	z_index = _原始z_index
	切换状态(State.IDLE)


func 执行攻击() -> void:
	pass
