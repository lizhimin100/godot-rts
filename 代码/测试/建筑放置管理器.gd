extends Node2D

const BUILD_PREVIEW = preload("res://combat/effects/build_preview.tscn")

## 建筑放置管理器 — 处理建造UI按钮->选择位置->指派农民建造的完整流程
## 场景无关：自动在场景树中查找树/地砖/UI，不依赖硬编码路径

const 建筑贴图 := {
	全局变量.建筑类型.城堡: preload("res://小剑资源/兵种/Knights/Buildings/Castle/Castle_Blue.png"),
	全局变量.建筑类型.房子: preload("res://小剑资源/兵种/Knights/Buildings/House/House_Blue.png"),
	全局变量.建筑类型.防御塔: preload("res://小剑资源/兵种/Knights/Buildings/Tower/Tower_Blue.png"),
}

const 建筑碰撞尺寸 := {
	全局变量.建筑类型.城堡: Vector2(300, 240),
	全局变量.建筑类型.房子: Vector2(120, 180),
	全局变量.建筑类型.防御塔: Vector2(120, 240),
}

var 放置进行中 := false
var 当前建筑类型: int
var 预览精灵: Sprite2D
var 位置有效 := false

# 场景节点缓存（延迟查找，场景无关）
var 建筑父节点: Node = null
var 树图层: TileMapLayer = null
var 地面层: TileMapLayer = null


func _ready() -> void:
	# 延迟一帧查找场景节点（确保场景完全加载）
	call_deferred("_查找场景节点")


## 在场景树中自动查找需要的节点（不依赖硬编码路径）
func _查找场景节点() -> void:
	var 场景 = get_tree().current_scene
	if not 场景:
		return

	# 查找"单位"父节点（放置建筑的目标根）
	建筑父节点 = _查找节点递归(场景, "单位")
	if not 建筑父节点:
		建筑父节点 = 场景  # 回退到场景根

	# 查找 TileMapLayer：按名称模糊匹配
	for child in _递归子节点(场景):
		if child is TileMapLayer:
			if "树" in child.name or "树林" in child.name or "森林" in child.name:
				树图层 = child
			elif "地面" in child.name or "草地" in child.name or "地形" in child.name or "Ground" in child.name:
				地面层 = child

	# 初始化流场寻路
	if 地面层:
		FFManager.setup_nav(地面层, 树图层)
		FFManager.mark_dirty()
		#print("流场已初始化: 地面=%s 树=%s" % [地面层.name, str(树图层.name if 树图层 else "无")])  # DEBUG

	# 查找建造UI（通过组或名称）
	var 建造UI = get_tree().get_first_node_in_group("建造UI")
	if not 建造UI:
		for child in _递归子节点(场景):
			if "建造" in child.name and child.has_signal("建造1"):
				建造UI = child
				break
	if 建造UI:
		建造UI.建造1.connect(_on_建造城堡)
		建造UI.建造2.connect(_on_建造房子)
		建造UI.建造3.connect(_on_建造防御塔)
		#print("建筑放置管理器已连接建造UI: ", 建造UI.name)  # DEBUG
	else:
		pass  # 未找到建造UI节点


## 递归遍历节点的辅助函数
static func _递归子节点(根: Node) -> Array[Node]:
	var 结果: Array[Node] = []
	_递归收集(根, 结果)
	return 结果

static func _递归收集(节点: Node, 收集: Array[Node]) -> void:
	收集.append(节点)
	for child in 节点.get_children():
		_递归收集(child, 收集)


## 按名称递归查找节点
static func _查找节点递归(根: Node, 名称: String) -> Node:
	if 根.name == 名称:
		return 根
	for child in 根.get_children():
		var 结果 = _查找节点递归(child, 名称)
		if 结果:
			return 结果
	return null


func _on_建造城堡() -> void:
	开始放置(全局变量.建筑类型.城堡)


func _on_建造房子() -> void:
	开始放置(全局变量.建筑类型.房子)


func _on_建造防御塔() -> void:
	开始放置(全局变量.建筑类型.防御塔)


func 开始放置(类型: int) -> void:
	if 放置进行中:
		取消放置()

	当前建筑类型 = 类型
	放置进行中 = true
	位置有效 = false

	预览精灵 = BUILD_PREVIEW.instantiate()
	预览精灵.texture = 建筑贴图[类型]
	add_child(预览精灵)

	#print("开始放置: ", 全局变量.建筑类型.keys()[类型])  # DEBUG


func 取消放置() -> void:
	放置进行中 = false
	位置有效 = false
	if is_instance_valid(预览精灵):
		预览精灵.queue_free()
	预览精灵 = null


func _process(_delta: float) -> void:
	if not 放置进行中 or not is_instance_valid(预览精灵):
		return

	var 鼠标位置 = get_global_mouse_position()
	预览精灵.global_position = 鼠标位置

	# 碰撞检测：检查是否与已有建筑重叠（建筑层=4）
	var 空间 = get_world_2d().direct_space_state
	var 矩形 = RectangleShape2D.new()
	矩形.size = 建筑碰撞尺寸[当前建筑类型]

	var 形状 = PhysicsShapeQueryParameters2D.new()
	形状.set_shape(矩形)
	形状.transform = Transform2D(0, 鼠标位置)
	形状.collision_mask = 4  # 建筑层
	位置有效 = 空间.intersect_shape(形状).is_empty()

	# 单位检测：检查放置位置是否被单位占据（层8=操作单位, 层16=敌人单位）
	if 位置有效:
		形状.collision_mask = 8 + 16
		for 碰撞 in 空间.intersect_shape(形状):
			if 碰撞.collider is CharacterBody2D:
				位置有效 = false
				break

	# 树木检测
	if 位置有效 and _检测树木冲突(鼠标位置, 建筑碰撞尺寸[当前建筑类型]):
		位置有效 = false

	# 预览变色
	if 位置有效:
		预览精灵.modulate = Color(0.5, 1, 0.5, 0.5)
	else:
		预览精灵.modulate = Color(1, 0.3, 0.3, 0.5)


func _input(event: InputEvent) -> void:
	if not 放置进行中:
		return

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if 位置有效:
					放置建筑()
			MOUSE_BUTTON_RIGHT:
				取消放置()


## 查找距离建造位置最近的闲置农民
func _查找最近闲置农民(位置: Vector2) -> Node2D:
	var 最近距离 := INF
	var 最近农民: Node2D = null
	for 单位 in get_tree().get_nodes_in_group("移动单位"):
		if not is_instance_valid(单位):
			continue
		if 单位 is 农民 and 单位.当前状态 == 农民.State.IDLE and 单位.阵营 == 阵营管理器.阵营.玩家:
			var d = 单位.global_position.distance_to(位置)
			if d < 最近距离:
				最近距离 = d
				最近农民 = 单位
	return 最近农民


## 检测放置位置是否有树木冲突
func _检测树木冲突(位置: Vector2, 建筑尺寸: Vector2) -> bool:
	if not is_instance_valid(树图层):
		return false
	var 半尺寸 = 建筑尺寸 / 2
	var 建筑矩形 = Rect2(位置 - 半尺寸, 建筑尺寸)
	for tile_pos in 树图层.get_used_cells():
		var 树中心 = 树图层.map_to_local(tile_pos)
		var 树矩形 = Rect2(树中心 - Vector2(64, 96), Vector2(128, 192))
		if 建筑矩形.intersects(树矩形, false):
			return true
	return false


func 放置建筑() -> void:
	if not 放置进行中 or not 位置有效:
		return

	var 建造位置 = 预览精灵.global_position
	var 建筑类型 = 当前建筑类型

	var 最近农民 = _查找最近闲置农民(建造位置)
	if not 最近农民:
		#print("没有闲置农民可供建造！")  # DEBUG
		全局变量.显示通知("需要农民来建造！", 建造位置)
		取消放置()
		return

	if 最近农民.has_method("命令建造"):
		最近农民.命令建造(建筑类型, 建造位置)
		#print("已指派农民建造: ", 全局变量.建筑类型.keys()[建筑类型], " 位置: ", 建造位置)  # DEBUG
	else:
		#print("农民没有命令建造方法!")  # DEBUG
		取消放置()
		return

	取消放置()
