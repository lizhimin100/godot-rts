@tool
extends Node2D
class_name 随机地图生成器场景

@export var 地图宽度: int = 80
@export var 地图高度: int = 50
@export var 随机种子: int = 0
@export_range(0.0, 1.0, 0.01) var 树木密度: float = 0.06
@export var 运行时自动生成: bool = true

@onready var 地面: TileMapLayer = $地形/地面
@onready var 树: TileMapLayer = $地形/树

const 草地候选 := [
	Vector2i(3, 3),
	Vector2i(4, 3),
	Vector2i(5, 3),
	Vector2i(6, 3),
	Vector2i(3, 4),
	Vector2i(4, 4),
	Vector2i(5, 4),
	Vector2i(6, 4),
	Vector2i(3, 5),
	Vector2i(4, 5),
	Vector2i(5, 5),
	Vector2i(6, 5),
]

const 树木候选 := [
	Vector2i(0, 0),
	Vector2i(3, 0),
	Vector2i(5, 0),
	Vector2i(0, 1),
	Vector2i(0, 2),
]


func _ready() -> void:
	if not Engine.is_editor_hint() and 运行时自动生成:
		生成地图()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			随机种子 = 0
			生成地图()


func 生成地图() -> void:
	if not is_instance_valid(地面) or not is_instance_valid(树):
		return

	var rng := RandomNumberGenerator.new()
	if 随机种子 == 0:
		rng.randomize()
	else:
		rng.seed = 随机种子

	地面.clear()
	树.clear()

	var 地面源 := _获取第一个图源(地面)
	var 树源 := _获取第一个图源(树)
	if 地面源 == -1:
		return

	var 起点 := Vector2i(-floori(地图宽度 * 0.5), -floori(地图高度 * 0.5))
	var 终点 := 起点 + Vector2i(地图宽度, 地图高度)

	for x in range(起点.x, 终点.x):
		for y in range(起点.y, 终点.y):
			var 坐标 := Vector2i(x, y)
			var 草地坐标: Vector2i = 草地候选[rng.randi_range(0, 草地候选.size() - 1)]
			地面.set_cell(坐标, 地面源, 草地坐标, 0)

			if 树源 != -1 and _可以生成树(坐标, rng):
				var 树坐标: Vector2i = 树木候选[rng.randi_range(0, 树木候选.size() - 1)]
				树.set_cell(坐标, 树源, 树坐标, 0)


func 清除地图() -> void:
	if is_instance_valid(地面):
		地面.clear()
	if is_instance_valid(树):
		树.clear()


func _获取第一个图源(图层: TileMapLayer) -> int:
	if not 图层.tile_set:
		return -1
	var 图源列表 := 图层.tile_set.get_source_list()
	if 图源列表.is_empty():
		return -1
	return 图源列表[0]


func _可以生成树(坐标: Vector2i, rng: RandomNumberGenerator) -> bool:
	if abs(坐标.x) < 5 and abs(坐标.y) < 4:
		return false
	if rng.randf() > 树木密度:
		return false

	var 相邻树数 := 0
	for x in range(坐标.x - 2, 坐标.x + 3):
		for y in range(坐标.y - 2, 坐标.y + 3):
			if 树.get_cell_source_id(Vector2i(x, y)) != -1:
				相邻树数 += 1
	return 相邻树数 < 3
