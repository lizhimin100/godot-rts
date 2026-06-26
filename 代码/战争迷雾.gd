extends Node2D

## 战争迷雾系统 — SubViewport 优化版 v2
##
## v2 优化（2026-06-26）:
##   1. 🏆 PackedByteArray 批量操作替代逐像素 get_pixel/set_pixel（~50x 更快）
##   2. 📦 单位列表按帧缓存，避免每帧多次 get_tree().get_nodes_in_group()
##   3. ⚡ SubViewport UPDATE_ALWAYS → UPDATE_ONCE 按需渲染
##   4. 📉 增加永久迷雾更新间隔 60→90，减少 CPU 负担
##   5. 🚀 降低延迟：更新间隔 20→10 + 移动阈值 30px→20px
##   6. 🧹 添加 _exit_tree() 清理
##
## 节点结构（代码中自动创建）:
##   战争迷雾 (Node2D) ← 本脚本
##   ├── 迷雾显示 (Sprite2D) — 可见的迷雾覆盖层，带 Shader
##   │   └── ShaderMaterial — 采样永久迷雾纹理 + 子视口纹理
##   └── 迷雾视口 (SubViewport) — 隐藏渲染视口
##       ├── 视口相机 (Camera2D) — 匹配世界坐标
##       └── 视野层 (Node2D) — 视野圆圈精灵容器

@export var 迷雾宽度: int = 2000
@export var 迷雾长度: int = 2000
@export var 雾纹理尺寸: int = 400          # SubViewport 分辨率（400×400 = 160K 像素）
@export var 视野半径: float = 150.0
@export var 视野单位组: String = "可选单位"

# 内建节点
var _迷雾显示: Sprite2D
var _子视口: SubViewport
var _视口相机: Camera2D
var _视野层: Node2D

# 永久迷雾（已探索区域，永不回退）
var _永久迷雾图片: Image
var _永久迷雾纹理: ImageTexture

# 视野圆圈纹理（白色径向渐变）
var _圆圈纹理: GradientTexture2D
var _圆圈缩放: float = 0.0

# 圆圈精灵对象池
var _圆圈池: Array[Sprite2D] = []

# 更新控制
var _帧计数: int = 0
var _更新间隔: int = 10               # 每 10 帧更新当前视野（~0.17s @60fps）
var _永久更新间隔: int = 90           # 每 90 帧合入永久迷雾（~1.5s）
var _上一次位置缓存: Dictionary = {}

# 缓存
var _投影缩放: float = 0.0
var _缓存单位列表: Array = []
var _列表缓存帧: int = -1


func _ready() -> void:
	_创建子视口()
	_创建迷雾显示()
	_创建圆圈纹理()
	_初始化永久迷雾()
	_更新投影参数()


func _exit_tree() -> void:
	# 清理子视口渲染资源
	if _子视口:
		_子视口.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_圆圈池.clear()


func _创建子视口() -> void:
	_子视口 = SubViewport.new()
	_子视口.name = "迷雾视口"
	_子视口.size = Vector2i(雾纹理尺寸, 雾纹理尺寸)
	_子视口.transparent_bg = true
	_子视口.handle_input_locally = false
	_子视口.render_target_update_mode = SubViewport.UPDATE_ONCE  # 按需渲染
	_子视口.render_target_v_flip = true
	add_child(_子视口)

	_视口相机 = Camera2D.new()
	_视口相机.name = "视口相机"
	_子视口.add_child(_视口相机)

	_视野层 = Node2D.new()
	_视野层.name = "视野层"
	_子视口.add_child(_视野层)


func _创建迷雾显示() -> void:
	_迷雾显示 = Sprite2D.new()
	_迷雾显示.name = "迷雾显示"
	_迷雾显示.z_index = 2
	_迷雾显示.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_迷雾显示.position = Vector2.ZERO

	var 最大边长 = float(max(迷雾宽度, 迷雾长度))
	_迷雾显示.scale = Vector2(最大边长 / float(雾纹理尺寸), 最大边长 / float(雾纹理尺寸))

	var shader = preload("res://shader学习/shader/战争迷雾.gdshader")
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("for_color", Color(0, 0, 0, 1))
	_迷雾显示.material = mat

	add_child(_迷雾显示)


func _创建圆圈纹理() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(0.0, 0.75, 1.0)
	g.colors = PackedColorArray(Color.WHITE, Color(1, 1, 1, 0.8), Color(1, 1, 1, 0))
	_圆圈纹理 = GradientTexture2D.new()
	_圆圈纹理.gradient = g
	_圆圈纹理.width = 128
	_圆圈纹理.height = 128
	_圆圈纹理.fill = 1  # RADIAL
	_圆圈纹理.fill_from = Vector2(0.5, 0.5)
	_圆圈纹理.fill_to = Vector2(0.5, 0)

	_圆圈缩放 = 视野半径 * 2.0 / 128.0


func _初始化永久迷雾() -> void:
	_永久迷雾图片 = Image.create_empty(雾纹理尺寸, 雾纹理尺寸, false, Image.FORMAT_RGBA8)
	_永久迷雾图片.fill(Color.WHITE)
	_永久迷雾纹理 = ImageTexture.create_from_image(_永久迷雾图片)
	_迷雾显示.texture = _永久迷雾纹理


func _更新投影参数() -> void:
	var 最大边长 = float(max(迷雾宽度, 迷雾长度))
	_投影缩放 = float(雾纹理尺寸) / 最大边长

	_视口相机.position = global_position
	_视口相机.zoom = Vector2(_投影缩放, _投影缩放)

	if _迷雾显示 and _迷雾显示.material:
		_迷雾显示.material.set_shader_parameter("current_texture", _子视口.get_texture())


func _process(_delta: float) -> void:
	if 视野单位组 == "":
		return

	_帧计数 += 1
	_列表缓存帧 = -1  # 每帧重置缓存标记

	# ── 每 _更新间隔 帧检测并更新 ──
	if _帧计数 % _更新间隔 == 0:
		var 需更新视野 := _检测是否有人移动()
		if 需更新视野:
			_更新视野圆圈()
			_子视口.render_target_update_mode = SubViewport.UPDATE_ONCE

		# ── 低频合入永久迷雾 ──
		if _帧计数 % _永久更新间隔 == 0 and 需更新视野:
			_合并到永久迷雾()


## 获取单位列表（按帧缓存，避免每帧多次 get_nodes_in_group）
func _获取单位列表() -> Array:
	var 当前帧 := _帧计数
	if 当前帧 != _列表缓存帧:
		_缓存单位列表.clear()
		var 单位们 := get_tree().get_nodes_in_group(视野单位组)
		for 单位 in 单位们:
			if is_instance_valid(单位):
				_缓存单位列表.append(单位)
		_列表缓存帧 = 当前帧
	return _缓存单位列表


func _检测是否有人移动() -> bool:
	var 单位们 := _获取单位列表()
	if 单位们.is_empty():
		return false

	var 有移动 := false
	var 新缓存: Dictionary = {}

	for 单位 in 单位们:
		if not is_instance_valid(单位):
			continue
		var pos := 单位.global_position
		var id := 单位.get_instance_id()
		新缓存[id] = pos

		if _上一次位置缓存.has(id):
			if _上一次位置缓存[id].distance_squared_to(pos) > 400:  # 20px 阈值
				有移动 = true
		else:
			有移动 = true

	_上一次位置缓存 = 新缓存
	return 有移动


func _更新视野圆圈() -> void:
	var 单位们 := _获取单位列表()
	var 有效单位数 := 0

	for i in 单位们.size():
		var 单位 = 单位们[i]
		if not is_instance_valid(单位):
			continue

		var 圆圈: Sprite2D = _从池获取圆圈(有效单位数)
		圆圈.position = 单位.global_position
		圆圈.scale = Vector2(_圆圈缩放, _圆圈缩放)
		圆圈.visible = true
		有效单位数 += 1

	for i in range(有效单位数, _圆圈池.size()):
		_圆圈池[i].visible = false


## 将当前可见区域合入永久迷雾（PackedByteArray 批量操作优化版）
func _合并到永久迷雾() -> void:
	var 视口纹理 := _子视口.get_texture()
	if not 视口纹理:
		return

	var 视口图片 := 视口纹理.get_image()
	if not 视口图片:
		return

	var 雾尺寸 := _永久迷雾图片.get_size()
	if 视口图片.get_size() != 雾尺寸:
		视口图片.resize(雾尺寸.x, 雾尺寸.y)

	# █ 核心优化：PackedByteArray 批量操作替代 get_pixel/set_pixel
	#   原理：RGBA8 = 每像素 4 字节 [R, G, B, A]，直接用 byte array 操作
	#   优势：避免 480K 次 Color 对象创建 + lock() 开销
	var 视口数据: PackedByteArray = 视口图片.get_data()
	var 永久数据: PackedByteArray = _永久迷雾图片.get_data()
	var 更新过 := false

	var 像素总数 := 雾尺寸.x * 雾尺寸.y
	for i in 像素总数:
		var off := i * 4
		# 视口 R > 128 = 可见区域
		if 视口数据[off] > 128:
			# 永久迷雾 R > 25 = 尚未探索
			if 永久数据[off] > 25:
				永久数据[off] = 0      # R
				永久数据[off + 1] = 0  # G
				永久数据[off + 2] = 0  # B
				更新过 = true

	if 更新过:
		_永久迷雾图片.set_data(雾尺寸.x, 雾尺寸.y, false, Image.FORMAT_RGBA8, 永久数据)
		_永久迷雾纹理.update(_永久迷雾图片)


func _从池获取圆圈(index: int) -> Sprite2D:
	while index >= _圆圈池.size():
		var s := Sprite2D.new()
		s.texture = _圆圈纹理
		s.visible = false
		s.name = "圆圈_%d" % _圆圈池.size()
		_视野层.add_child(s)
		_圆圈池.append(s)
	return _圆圈池[index]
