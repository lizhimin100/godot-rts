extends NavigationRegion2D
class_name 导航区域管理

## 导航区域管理器
## 从地面 TileMapLayer 生成 NavigationPolygon
## * 覆盖整个地面层的矩形区域
## * 建筑物/树木通过碰撞系统阻挡（路径上碰撞后由 move_and_slide + 避障处理）
## * NavigationAgent2D 获得有效的地图后可正确计算路径

static var 当前实例: 导航区域管理 = null

var _地面层: TileMapLayer


func _ready() -> void:
	当前实例 = self
	# 慢一帧查找，确保场景完全加载
	await get_tree().process_frame

	_地面层 = get_node_or_null("../地形/地面") as TileMapLayer
	if not _地面层:
		#print("导航区域管理：找不到地面层")  # DEBUG
		return

	_生成导航区域()
	#print("导航区域已生成")  # DEBUG


## 静态方法：全局触发导航更新
static func 更新导航() -> void:
	if 当前实例 and is_instance_valid(当前实例):
		当前实例.更新导航区域()

## 重新生成导航区域（建筑放置后调用）
func 更新导航区域() -> void:
	_生成导航区域()


func _生成导航区域() -> void:
	if not _地面层:
		return

	var 可用格子 := _地面层.get_used_cells()
	if 可用格子.is_empty():
		#print("地面层没有已使用的格子")  # DEBUG
		return

	# 计算所有格子的包围盒（包含整个地面）
	var 最小 := 可用格子[0]
	var 最大 := 可用格子[0]
	for 格 in 可用格子:
		最小 = Vector2i(min(最小.x, 格.x), min(最小.y, 格.y))
		最大 = Vector2i(max(最大.x, 格.x), max(最大.y, 格.y))

	# 扩大一圈让边界完整
	最小 -= Vector2i(1, 1)
	最大 += Vector2i(2, 2)

	var 单元格尺寸 := _地面层.tile_set.tile_size
	var 半格 := 单元格尺寸 / 2.0

	# 边界四个角（先转全局，再转为本节点的局部坐标）
	var 左上 = _地面层.to_global(_地面层.map_to_local(最小) - 半格)
	var 右上 = _地面层.to_global(_地面层.map_to_local(Vector2i(最大.x, 最小.y)) + Vector2(半格.x, -半格.y))
	var 右下 = _地面层.to_global(_地面层.map_to_local(最大) + 半格)
	var 左下 = _地面层.to_global(_地面层.map_to_local(Vector2i(最小.x, 最大.y)) + Vector2(-半格.x, 半格.y))
	左上 = to_local(左上)
	右上 = to_local(右上)
	右下 = to_local(右下)
	左下 = to_local(左下)

	# 构建一个大矩形 Polygon
	var 导航多边形 := NavigationPolygon.new()
	var 外轮廓 := PackedVector2Array([左上, 右上, 右下, 左下])
	导航多边形.add_outline(外轮廓)
	导航多边形.make_polygons_from_outlines()

	self.navigation_polygon = 导航多边形
	#print("导航区已更新：覆盖 ", 可用格子.size(), " 个格子")  # DEBUG
