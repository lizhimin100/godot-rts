@tool
class_name 地图生成器 extends Node

## 地图生成器组件
## 挂在世界场景根节点下，用 set_cell() 自动生成地形

## 生成区域（瓦片坐标）
@export var 地图宽度: int = 35
@export var 地图高度: int = 25

## 生成偏移（从哪个瓦片坐标开始）
@export var 偏移X: int = -10
@export var 偏移Y: int = -10

## 是否在 _ready() 时自动生成
@export var 自动生成: bool = false

var _已生成 := false

## 各 TileMapLayer 及其默认瓦片坐标配置
## [节点路径, 默认瓦片坐标x, 默认瓦片坐标y]
var _图层配置 := [
	["场景/第一层地面图层", 0, 0],
	["场景/第二层地面图层", 8, 0],
	["场景/草地", 0, 4],
	["场景/阴影", 5, 5],
	["场景/桥梁", 0, 9],
]


func _ready() -> void:
	if 自动生成 and not _已生成:
		生成地图()


func 生成地图() -> void:
	var 世界 := get_tree().current_scene
	if not 世界:
		# EditorInterface 模式
		if Engine.is_editor_hint():
			_编辑器生成()
		return

	_已生成 = true
	var 总计数 := 0

	for 配置 in _图层配置:
		var 路径 := 配置[0] as String
		var 默认x := 配置[1] as int
		var 默认y := 配置[2] as int

		var tilemap := _查找TileMapLayer(世界, 路径)
		if not tilemap:
			continue

		var 计数 := _填充图层(tilemap, Vector2i(默认x, 默认y))
		总计数 += 计数
		#print("地图生成: ", tilemap.name, " +", 计数, " 格")  # DEBUG

	# 更新寻路网格
	var 草地 := _查找TileMapLayer(世界, "场景/草地")
	if 草地 and 草地.has_method("_ready"):
		# 触发寻路脚本重新计算
		if 草地.get("astar"):
			草地.astar.region = 草地.get_used_rect()
			草地.astar.update()

	_已生成 = true
	#print("地图生成完成！共 ", 总计数, " 格")  # DEBUG


func _编辑器生成() -> void:
	var es := EditorInterface.get_edited_scene_root()
	if not es:
		return
	var 总计数 := 0
	for 配置 in _图层配置:
		var 路径 := 配置[0] as String
		var tilemap := es.get_node(路径) as TileMapLayer
		if not tilemap:
			continue
		var 计数 := _填充图层(tilemap, Vector2i(配置[1], 配置[2]))
		总计数 += 计数
	#print("编辑器地图生成完成！共 ", 总计数, " 格")  # DEBUG


func _查找TileMapLayer(根: Node, 路径: String) -> TileMapLayer:
	return 根.get_node(路径) as TileMapLayer


func _填充图层(tilemap: TileMapLayer, 默认坐标: Vector2i) -> int:
	var ts := tilemap.tile_set
	if not ts:
		return 0

	var source_ids: Array[int] = ts.get_source_list()
	if source_ids.is_empty():
		return 0
	var sid: int = source_ids[0]

	var 计数 := 0
	var 区域 := Rect2i(偏移X, 偏移Y, 地图宽度, 地图高度)

	for x in range(区域.position.x, 区域.end.x):
		for y in range(区域.position.y, 区域.end.y):
			var pos := Vector2i(x, y)
			if tilemap.get_cell_source_id(pos) == -1:
				tilemap.set_cell(pos, sid, 默认坐标, 0)
				计数 += 1

	return 计数


func 清除地图() -> void:
	var 世界 := get_tree().current_scene
	if Engine.is_editor_hint():
		世界 = EditorInterface.get_edited_scene_root()
	if not 世界:
		return

	var 区域 := Rect2i(偏移X, 偏移Y, 地图宽度, 地图高度)
	var 总计数 := 0

	for 配置 in _图层配置:
		var 路径 := 配置[0] as String
		var tilemap := _查找TileMapLayer(世界, 路径)
		if not tilemap:
			continue

		var 计数 := 0
		for x in range(区域.position.x, 区域.end.x):
			for y in range(区域.position.y, 区域.end.y):
				var pos := Vector2i(x, y)
				if tilemap.get_cell_source_id(pos) != -1:
					tilemap.set_cell(pos, -1, Vector2i(0, 0), 0)
					计数 += 1

		#print("清除: ", tilemap.name, " -", 计数)  # DEBUG
		总计数 += 计数

	#print("地图清除完成！共移除 ", 总计数, " 格")  # DEBUG
