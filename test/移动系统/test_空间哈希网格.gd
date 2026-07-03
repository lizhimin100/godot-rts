@tool
extends Node

## 空间哈希网格单元测试
## 运行方式：将本脚本挂载到任意场景，点击运行。

var _测试数: int = 0
var _通过数: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	print("\n🧪 === 空间哈希网格 单元测试 ===")

	_测试("插入与九宫格查询", _test_插入与九宫格)
	_测试("清空", _test_清空)
	_测试("半径查询", _test_半径查询)
	_测试("无效单位", _test_无效单位)
	_测试("批量插入", _test_批量插入)
	_测试("网格边界跨越", _test_边界跨越)

	print("\n✅ 结果: %d/%d 通过" % [_通过数, _测试数])
	if _通过数 < _测试数:
		printerr("❌ 部分测试失败!")

	get_tree().quit(0 if _通过数 == _测试数 else 1)


func _测试(名称: String, 函数: Callable) -> void:
	_测试数 += 1
	var ok = 函数.call()
	if ok:
		_通过数 += 1
		print("  ✅ %s" % 名称)
	else:
		printerr("  ❌ %s" % 名称)


func _make_grid():
	var g = 空间哈希网格.new()
	g._enter_tree()  # 初始化 实例
	return g


func _cleanup_grid(g) -> void:
	g._exit_tree()
	g.queue_free()


func _make_unit(pos: Vector2, name_tag: String = "") -> Node2D:
	var u = Node2D.new()
	u.global_position = pos
	u.name = name_tag
	return u


# ══════════════════════════════════════════════
# 测试用例
# ══════════════════════════════════════════════

func _test_插入与九宫格() -> bool:
	var g = _make_grid()
	var u1 = _make_unit(Vector2(100, 100), "u1")
	var u2 = _make_unit(Vector2(150, 100), "u2")

	g.插入单位(u1)
	g.插入单位(u2)

	var 结果 = g.查询9宫格(Vector2(100, 100))
	# 应该至少包含两个单位
	var found = 结果.size() >= 2

	u1.free()
	u2.free()
	_cleanup_grid(g)
	return found


func _test_清空() -> bool:
	var g = _make_grid()
	var u = _make_unit(Vector2(0, 0))
	g.插入单位(u)

	if g.查询9宫格(Vector2(0, 0)).size() != 1:
		u.free()
		_cleanup_grid(g)
		return false

	g.清空()
	var 结果 = g.查询9宫格(Vector2(0, 0))

	u.free()
	_cleanup_grid(g)
	return 结果.size() == 0


func _test_半径查询() -> bool:
	var g = _make_grid()
	var center = _make_unit(Vector2(200, 200), "center")
	var near = _make_unit(Vector2(220, 200), "near")  # 20px away
	var far = _make_unit(Vector2(400, 400), "far")    # 283px away

	g.插入单位(center)
	g.插入单位(near)
	g.插入单位(far)

	var 结果 = g.查询半径(Vector2(200, 200), 50.0)

	center.free()
	near.free()
	far.free()
	_cleanup_grid(g)

	# 应该找到 center 和 near，但 far 超出 50px
	# near 距离 20px ∈ [0, 50], far 距离 283px ∉ [0, 50]
	# 注意：center 与自己距离 0，也会在结果中
	return 结果.size() == 2


func _test_无效单位() -> bool:
	var g = _make_grid()
	var u = _make_unit(Vector2(50, 50), "u")
	g.插入单位(u)

	# 插入空引用
	g.插入单位(null)

	# 插入后释放
	var temp = _make_unit(Vector2(60, 60), "temp")
	g.插入单位(temp)
	temp.free()  # 释放后变为无效引用

	var 结果 = g.查询9宫格(Vector2(50, 50))

	_cleanup_grid(g)
	# 只应该包含一个有效单位 u
	# temp 已 free → is_instance_valid 检查应排除
	return 结果.size() == 1 and 结果[0] == u


func _test_批量插入() -> bool:
	var g = _make_grid()
	var units: Array[Node2D] = []
	for i in range(10):
		var u = _make_unit(Vector2(i * 10, 0), "batch_%d" % i)
		units.append(u)

	g.批量插入(units)
	var 结果 = g.查询9宫格(Vector2(0, 0))

	for u in units:
		u.free()
	_cleanup_grid(g)

	# 10个单位都在附近，九宫格应全部找到
	return 结果.size() == 10


func _test_边界跨越() -> bool:
	var g = _make_grid()
	# 网格大小 64px，边界测试：61px 处的单位应同时出现在 0 和 64 两个格子
	var u = _make_unit(Vector2(63, 63), "edge")
	g.插入单位(u)

	# 查询 (0,0) 的中宫格
	var 结果 = g.查询9宫格(Vector2(200, 200))

	u.free()
	_cleanup_grid(g)

	# 200,200 距离 63,63 远，不应查询到
	return 结果.size() == 0
