extends SubViewport

## RTS风格小地图 — 显示全图俯览，带视口指示器和点击移动

@export var 相机节点 : Node2D        # 小地图内部的 Camera2D，用于渲染全图
@export var 玩家节点 : Node2D:       # 主世界相机（用于计算视口范围），由外部设置
	set(val):
		玩家节点 = val
		if is_inside_tree() and not _已初始化:
			_初始化小地图相机()

@onready var 容器 := get_parent() as SubViewportContainer
@onready var 视口矩形 := $"../视口矩形" as ColorRect

var _已初始化 := false

func _ready() -> void:
	# 绑定容器点击事件
	容器.gui_input.connect(_on_容器点击)

	# 设置 SubViewport 渲染主世界的 2D 场景
	self.world_2d = get_tree().root.world_2d

	# 尝试自动查找主相机
	_尝试查找主相机()

	# 如果已经获取了主相机，初始化小地图相机
	if 玩家节点:
		_初始化小地图相机()


func _尝试查找主相机() -> void:
	if 玩家节点:
		return
	var root_vp := get_tree().root
	if root_vp and root_vp.get_camera_2d():
		玩家节点 = root_vp.get_camera_2d()


func _初始化小地图相机() -> void:
	if _已初始化 or not 相机节点 or not 玩家节点:
		return
	_已初始化 = true

	var 地图区域 := _计算地图边界()
	if 地图区域.size == Vector2.ZERO:
		return

	# 将小地图相机放在地图中心
	相机节点.position = 地图区域.get_center()

	# 计算缩放使整个地图适应小地图视口 (200×200)
	var 缩放x: float = size.x / 地图区域.size.x
	var 缩放y: float = size.y / 地图区域.size.y
	相机节点.zoom = Vector2(min(缩放x, 缩放y), min(缩放x, 缩放y))


func _计算地图边界() -> Rect2:
	var 世界 := get_tree().current_scene
	if not 世界:
		return Rect2(Vector2.ZERO, Vector2(2000, 2000))

	# 查找 TileMapLayer 来确定地图边界
	var tilemap = 世界.find_child("第一层地面图层", true, false)
	if tilemap and tilemap is TileMapLayer:
		var used: Rect2i = tilemap.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			var tile_size: Vector2i = tilemap.tile_set.tile_size
			var 起点v: Vector2i = used.position * tile_size
			var 大小v: Vector2i = used.size * tile_size
			var 起点f: Vector2 = Vector2(起点v)
			var 大小f: Vector2 = Vector2(大小v)
			return Rect2(起点f - Vector2(64, 64), 大小f + Vector2(128, 128))

	return Rect2(Vector2.ZERO, Vector2(2000, 2000))


func _process(_delta: float) -> void:
	if not 玩家节点 or not 视口矩形:
		return
	_更新视口矩形()


func _更新视口矩形() -> void:
	var 主相机 := 玩家节点 as Camera2D
	if not 主相机:
		return

	var 地图区域 := _计算地图边界()
	if 地图区域.size.x <= 0 or 地图区域.size.y <= 0:
		return

	# 主相机在世界空间中的视口范围
	var 窗口尺寸: Vector2 = get_tree().root.get_visible_rect().size
	var 缩放: float = 主相机.zoom.x
	var 视口宽: float = 窗口尺寸.x * 缩放
	var 视口高: float = 窗口尺寸.y * 缩放
	var 相机中心: Vector2 = 主相机.global_position
	var 视口左: float = 相机中心.x - 视口宽 / 2.0
	var 视口顶: float = 相机中心.y - 视口高 / 2.0

	# 映射到小地图坐标系 (200×200)
	var 地图起点: Vector2 = 地图区域.position
	var 地图大小: Vector2 = 地图区域.size

	var 比例左: float = (视口左 - 地图起点.x) / 地图大小.x
	var 比例顶: float = (视口顶 - 地图起点.y) / 地图大小.y
	var 比例宽: float = 视口宽 / 地图大小.x
	var 比例高: float = 视口高 / 地图大小.y

	# 更新视口矩形覆盖层
	视口矩形.position = Vector2(比例左 * size.x, 比例顶 * size.y)
	视口矩形.size = Vector2(比例宽 * size.x, 比例高 * size.y)


func _on_容器点击(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.is_pressed()):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	var 主相机 := 玩家节点 as Camera2D
	if not 主相机:
		return

	var 地图区域 := _计算地图边界()
	if 地图区域.size.x <= 0 or 地图区域.size.y <= 0:
		return

	# 鼠标位置 (相对于容器左上角)
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	var 点击位置: Vector2 = mouse_event.position

	# 映射到世界坐标
	var 比例x: float = 点击位置.x / size.x
	var 比例y: float = 点击位置.y / size.y
	比例x = clampf(比例x, 0.0, 1.0)
	比例y = clampf(比例y, 0.0, 1.0)

	var 世界x: float = 地图区域.position.x + 比例x * 地图区域.size.x
	var 世界y: float = 地图区域.position.y + 比例y * 地图区域.size.y

	# 移动主相机到目标位置
	主相机.global_position = Vector2(世界x, 世界y)
