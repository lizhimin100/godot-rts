class_name UnitBase
extends CharacterBody2D

## 单位基类 — RTS 单位根基类
##
## 继承自 CharacterBody2D，提供：
##   - 阵营系统 + 关系判断
##   - 命令系统（移动/攻击/驻守/巡逻/停止）
##   - 移动控制器（UnitController: 流场 + 分离转向 + 停止检测 + 卡死解卡）
##   - 战斗系统（受伤/死亡/伤害数字）
##   - 索敌系统（寻找最近敌对目标）
##   - 驻守图标
##   - 导航代理（保留，仅追敌使用）

signal 避开友军

# ========== 阵营系统 ==========
@export var 阵营: 阵营管理器.阵营 = 阵营管理器.阵营.玩家

# ========== 移动参数 ==========
@export var 移动速度: float = 200.0
@export var 最大速度: float = 350.0
@export var 加速度: float = 800.0
@export var 停止阈值: float = 16.0
@export var 选择状态: bool = false
## 让路优先级（越大越优先）
@export var move_priority: int = 0

# ========== 战斗属性 ==========
@export var 最大生命值: float = 100.0
var 当前生命值: float = 100.0
var _已死亡: bool = false

# ========== 排斥力参数（旧接口保留） ==========
@export var 排斥距离: float = 32.0
@export var 排斥强度: float = 150.0

# ========== 移动控制器（核心） ==========
var unit_controller: UnitController

# ========== 导航代理（保留，仅子类追敌使用） ==========
var 导航代理: NavigationAgent2D

# ========== 命令状态 ==========
var 目标位置: Vector2 = Vector2.ZERO
var 点击位置: Vector2 = Vector2.ZERO
var 移动方向: Vector2 = Vector2.ZERO
var 攻击目标: Node2D = null
var 巡逻路径: Array[Vector2] = []
var 当前巡逻索引: int = 0

enum 命令类型 { 无, 移动, 攻击, 驻守, 巡逻 }
var 当前命令: 命令类型 = 命令类型.无
var _是攻击移动: bool = false

# ========== 索敌与追击系统 ==========
@export var 索敌范围: float = 250.0
@export var 追击上限距离: float = 400.0
var _原始目标位置: Vector2 = Vector2.ZERO
var _追击起始位置: Vector2 = Vector2.ZERO
var _是自动索敌攻击: bool = false

# ========== 驻守图标 ==========
var _驻守图标: Sprite2D = null

# ========== 流场缓存（旧接口） ==========
var _流场上次目标: Vector2 = Vector2.ZERO

# ========== 视觉分离系统 ==========
## 视觉偏移向量 — 用于 Sprite2D 轻微错开，不参与物理碰撞
var visual_offset: Vector2 = Vector2.ZERO
## 视觉分离半径（像素），越大错开越明显
const VISUAL_RADIUS: float = 10.0


func _ready() -> void:
	当前生命值 = 最大生命值

	# 阵营判定（兼容旧碰撞层规则）
	if collision_layer == 16:
		阵营 = 阵营管理器.阵营.敌人
	else:
		阵营 = 阵营管理器.阵营.玩家

	# 初始化移动控制器（作为子节点）
	_初始化移动控制器()

	# 初始化导航代理（仅追敌用）
	_初始化导航()

	# 分组注册
	add_to_group("移动单位")
	if 阵营 == 阵营管理器.阵营.玩家:
		add_to_group("可选单位")

	# 碰撞掩码：确保包含建筑层（层4）
	if not (collision_mask & 4):
		collision_mask += 4


## 初始化移动控制器
func _初始化移动控制器() -> void:
	unit_controller = UnitController.new()
	unit_controller.name = "UnitController"
	unit_controller.max_speed = 移动速度
	unit_controller.stop_radius = 停止阈值
	unit_controller.separation_radius = 24.0
	unit_controller.separation_strength = 4.0
	add_child(unit_controller)


## 初始化导航代理（子类追敌使用）
func _初始化导航() -> void:
	if 导航代理:
		return
	导航代理 = NavigationAgent2D.new()
	导航代理.name = "导航代理"
	add_child(导航代理)


# ============================================================
# 阵营关系判断
# ============================================================

func 获取阵营() -> int:
	return 阵营


func 判断关系(目标) -> int:
	if not 目标 or not is_instance_valid(目标):
		return 阵营管理器.关系.中立
	if 目标.has_method("获取阵营"):
		return 阵营管理器.获取关系(阵营, 目标.获取阵营())
	if 目标 is UnitBase:
		if 目标.collision_layer == 16:
			return 阵营管理器.关系.敌对
		elif 目标.collision_layer == 8:
			return 阵营管理器.关系.友军
	return 阵营管理器.关系.中立


func 是敌对(目标) -> bool:
	return 判断关系(目标) == 阵营管理器.关系.敌对


func 是友军(目标) -> bool:
	return 判断关系(目标) == 阵营管理器.关系.友军


func _是敌人() -> bool:
	return 阵营 == 阵营管理器.阵营.敌人


func _是玩家() -> bool:
	return 阵营 == 阵营管理器.阵营.玩家


# ============================================================
# 通用命令接口
# ============================================================

func 命令移动(位置: Vector2, 攻击移动: bool = false) -> void:
	攻击目标 = null
	目标位置 = 位置
	当前命令 = 命令类型.移动
	_是攻击移动 = 攻击移动
	_是自动索敌攻击 = false
	_追击起始位置 = Vector2.ZERO
	if 攻击移动:
		_原始目标位置 = 位置
	else:
		_原始目标位置 = Vector2.ZERO
	_触发流场计算()
	_通知移动控制器()
	_切换动画("移动")
	_隐藏驻守图标()


func 命令停止() -> void:
	攻击目标 = null
	当前命令 = 命令类型.无
	_是攻击移动 = false
	_是自动索敌攻击 = false
	_追击起始位置 = Vector2.ZERO
	_原始目标位置 = Vector2.ZERO
	目标位置 = global_position
	if unit_controller:
		unit_controller.stop()
	if 导航代理:
		导航代理.target_position = global_position
	velocity = Vector2.ZERO
	visual_offset = Vector2.ZERO
	_切换动画("待机")
	_隐藏驻守图标()


func 命令驻守() -> void:
	攻击目标 = null
	当前命令 = 命令类型.驻守
	_是自动索敌攻击 = false
	_追击起始位置 = Vector2.ZERO
	_原始目标位置 = Vector2.ZERO
	目标位置 = global_position
	velocity = Vector2.ZERO
	if unit_controller:
		unit_controller.stop()
	_切换动画("待机")
	_显示驻守图标()


func 命令攻击(目标: Node2D) -> void:
	if not is_instance_valid(目标):
		return
	if not 是敌对(目标):
		return
	攻击目标 = 目标
	目标位置 = 目标.global_position
	当前命令 = 命令类型.攻击
	_是自动索敌攻击 = false
	_追击起始位置 = Vector2.ZERO
	_原始目标位置 = Vector2.ZERO
	_触发流场计算()
	_通知移动控制器()
	_切换动画("移动")
	_隐藏驻守图标()


func 命令巡逻(位置: Vector2) -> void:
	攻击目标 = null
	巡逻路径 = [global_position, 位置]
	当前巡逻索引 = 1
	目标位置 = 位置
	当前命令 = 命令类型.巡逻
	_触发流场计算()
	_通知移动控制器()
	_切换动画("移动")


func _下一个巡逻点() -> void:
	当前巡逻索引 = (当前巡逻索引 + 1) % 巡逻路径.size()
	目标位置 = 巡逻路径[当前巡逻索引]
	当前命令 = 命令类型.移动
	_触发流场计算()
	_通知移动控制器()


## 通知移动控制器更换目标
func _通知移动控制器() -> void:
	if unit_controller and unit_controller.is_inside_tree():
		unit_controller.set_target(目标位置)


## 更新视觉分离偏移量
## 每帧计算与周围单位的距离，推挤 Sprite2D 微幅错开
func _update_visual_separation() -> void:
	var push: Vector2 = Vector2.ZERO
	var count: int = 0
	var tree: SceneTree = get_tree()
	if not tree:
		return


	for other_node in tree.get_nodes_in_group("移动单位"):
		var other: Node2D = other_node
		if other == self or not is_instance_valid(other):
			continue

		var offset: Vector2 = global_position - other.global_position
		var dist: float = offset.length()

		# 完全重叠或超出 60px → 跳过
		if dist < 1 or dist > 60:
			continue

		var strength: float = 1.0 - (dist / 60.0)
		push += offset.normalized() * strength
		count += 1

	if count > 0:
		push /= count

	visual_offset = visual_offset.lerp(push * VISUAL_RADIUS, 0.15)


func _process(_delta: float) -> void:
	_update_visual_separation()
	if has_node("角色图像"):
		$角色图像.position = visual_offset


# ============================================================
# 旧接口：_导航移动到（子类兼容，不调 move_and_slide）
# ============================================================

## 旧式导航移动 — 使用流场方向但不调 move_and_slide
## 返回 true 表示已到达
func _导航移动到(目标位置: Vector2, delta: float) -> bool:
	var 剩余距离: float = global_position.distance_to(目标位置)
	if 剩余距离 <= 停止阈值:
		velocity = velocity.move_toward(Vector2.ZERO, 加速度 * delta)
		if velocity.length() < 5.0:
			velocity = Vector2.ZERO
		return true

	# 获取方向（流场 → 回退指向目标）
	var 移动方向: Vector2 = 流场寻路.获取方向(global_position, 目标位置)
	var 目标速度: Vector2 = 移动方向 * 移动速度

	# 旧式排斥力（子类兼容）
	var 排斥力: Vector2 = _计算排斥力()
	if 排斥力 != Vector2.ZERO:
		目标速度 += 排斥力

	# 速度平滑
	velocity = velocity.move_toward(目标速度.limit_length(最大速度), 加速度 * delta)
	return false


# ============================================================
# 流场触发（旧接口）
# ============================================================

func _触发流场计算() -> void:
	if 目标位置.distance_to(_流场上次目标) > 1.0:
		流场寻路.计算流场(目标位置)
		_流场上次目标 = 目标位置


# ============================================================
# 索敌
# ============================================================

func _寻找最近的敌对目标(搜索范围: float) -> Node2D:
	var 最近: Node2D = null
	var 最近距离: float = 搜索范围

	for 单位 in get_tree().get_nodes_in_group("移动单位"):
		if 单位 == self or not is_instance_valid(单位):
			continue
		if not 是敌对(单位):
			continue
		if 单位.当前生命值 <= 0:
			continue
		var d = global_position.distance_squared_to(单位.global_position)
		var 范围平方 = 搜索范围 * 搜索范围
		if d <= 范围平方:
			if d < 最近距离 * 最近距离:
				最近距离 = sqrt(d)
				最近 = 单位

	for 建筑 in get_tree().get_nodes_in_group("建筑"):
		if not is_instance_valid(建筑):
			continue
		if not 是敌对(建筑):
			continue
		if 建筑.当前生命值 <= 0:
			continue
		var d = global_position.distance_squared_to(建筑.global_position)
		var 范围平方 = 搜索范围 * 搜索范围
		if d <= 范围平方:
			if d < 最近距离 * 最近距离:
				最近距离 = sqrt(d)
				最近 = 建筑

	return 最近


# ============================================================
# 子类需要重写的方法
# ============================================================

func 执行攻击() -> void:
	pass


func _切换动画(动画名: String) -> void:
	pass


# ============================================================
# 驻守图标
# ============================================================

func _创建驻守图标() -> void:
	_驻守图标 = Sprite2D.new()
	_驻守图标.name = "驻守图标"
	_驻守图标.position = Vector2(0, -38)
	_驻守图标.z_index = 100
	_驻守图标.centered = true
	var img: Image = Image.create(14, 14, false, Image.FORMAT_RGBA8)
	for x in range(14):
		for y in range(14):
			var cx = x - 6.5
			var cy = y - 6.5
			var dist = sqrt(cx * cx + cy * cy)
			if dist <= 5.0:
				img.set_pixel(x, y, Color(0.2, 0.5, 1.0, 0.9))
			elif dist <= 6.5:
				img.set_pixel(x, y, Color(1, 1, 1, 0.9))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_驻守图标.texture = tex
	_驻守图标.visible = false
	add_child(_驻守图标)


func _显示驻守图标() -> void:
	if not _驻守图标 or not is_instance_valid(_驻守图标):
		_创建驻守图标()
	if is_instance_valid(_驻守图标):
		_驻守图标.visible = true


func _隐藏驻守图标() -> void:
	if _驻守图标 and is_instance_valid(_驻守图标):
		_驻守图标.visible = false


# ============================================================
# 旧接口：排斥力（子类兼容，委托给 UnitSteering）
# ============================================================

func _计算总避障力(目标方向: Vector2) -> Vector2:
	return _计算排斥力()


func _计算排斥力() -> Vector2:
	# 委托给新的 Steering 系统（使用旧参数保持兼容）
	var steer: Vector2 = UnitSteering.get_steering(self,
			排斥距离, 排斥强度 / 100.0)
	return steer


# ============================================================
# 战斗系统
# ============================================================

func 受伤(伤害: float, 攻击来源 = null) -> void:
	当前生命值 -= 伤害
	_播放受击效果(攻击来源)
	var 伤害数字 = _创建伤害数字(int(伤害))
	if 伤害数字:
		add_child(伤害数字)
	if 当前生命值 <= 0:
		死亡()


func _播放受击效果(攻击来源 = null) -> void:
	_触发屏幕震动()

	var 原色调 = modulate
	var 原缩放 = scale
	modulate = Color(2, 0.2, 0.2, 1)
	scale = 原缩放 * 1.15
	position += Vector2(randf_range(-5, 5), randf_range(-5, 5))
	await get_tree().create_timer(0.06).timeout
	if is_instance_valid(self):
		modulate = Color(1.5, 0.4, 0.4, 1)
		scale = 原缩放 * 1.08
		await get_tree().create_timer(0.06).timeout
		if is_instance_valid(self):
			modulate = 原色调
			scale = 原缩放


func _触发屏幕震动() -> void:
	var 相机 = get_viewport().get_camera_2d()
	if 相机 and 相机.has_method("震屏"):
		var 震级: float = 6.0 if (_是敌人() or 阵营 == 阵营管理器.阵营.敌人) else 4.0
		相机.震屏(震级, 0.2)


func _创建伤害数字(伤害: int) -> Label:
	var label: Label = Label.new()
	label.text = str(伤害)
	label.modulate = Color(1, 0.95, 0.3)
	label.position = Vector2(-20, -55)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 0.8)
	tween.tween_property(label, "position:x", label.position.x + randf_range(-10, 10), 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)
	return label


func 死亡() -> void:
	if _已死亡:
		return
	_已死亡 = true
	set_process(false)
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	var 原缩放 = scale
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.08)
	tween.tween_property(self, "scale", 原缩放 * 1.3, 0.1)
	await tween.finished

	if not is_instance_valid(self):
		return

	var tween2: Tween = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(self, "modulate:a", 0.0, 0.35)
	tween2.tween_property(self, "scale", 原缩放 * 0.3, 0.35)
	tween2.tween_property(self, "rotation", randf_range(-0.3, 0.3), 0.35)
	await tween2.finished
	queue_free()
