@tool
extends Node

## 队形系统单元测试

var _测试数: int = 0
var _通过数: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	print("\n🧪 === 队形系统 单元测试 ===")

	_测试("创建横排队形", _test_创建横排)
	_测试("计算队形力", _test_队形力)
	_测试("移除单位", _test_移除单位)
	_测试("查询组 ID", _test_组ID)
	_测试("销毁组", _test_销毁组)
	_测试("方阵偏移", _test_方阵偏移)
	_测试("楔形偏移", _test_楔形偏移)
	_测试("纵队偏移", _test_纵队偏移)

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


func _make_system():
	var s = 队形系统.new()
	s._enter_tree()
	return s


func _cleanup(s) -> void:
	s._exit_tree()
	s.queue_free()


func _make_unit(name_tag: String = "") -> Node2D:
	var u = Node2D.new()
	u.name = name_tag
	return u


# ══════════════════════════════════════════════

func _test_创建横排() -> bool:
	var s = _make_system()
	var u1 = _make_unit("a")
	var u2 = _make_unit("b")
	var u3 = _make_unit("c")

	var 组ID = s.创建队形([u1, u2, u3], Vector2(500, 300), 队形系统.阵型类型.横排, 24.0)

	# 组ID >= 0
	var ok = 组ID >= 0

	# 3个单位都在队形中
	ok = ok and s.是否在队形中(u1)
	ok = ok and s.是否在队形中(u2)
	ok = ok and s.是否在队形中(u3)

	# 组ID一致
	ok = ok and s.获取单位组ID(u1) == 组ID
	ok = ok and s.获取单位组ID(u2) == 组ID
	ok = ok and s.获取单位组ID(u3) == 组ID

	# 横排：中间(索引1)偏移应为 (0,0)，两边对称
	var 目标1 = s.获取单位目标(u1)
	var 目标2 = s.获取单位目标(u2)
	var 目标3 = s.获取单位目标(u3)

	# 移动方向默认 RIGHT，所以 offset 不旋转
	# offset: u1=-24,0  u2=0,0  u3=24,0
	# 目标 = 500,300 + offset
	ok = ok and 目标1.x < 目标2.x and 目标2.x < 目标3.x

	u1.free(); u2.free(); u3.free()
	_cleanup(s)
	return ok


func _test_队形力() -> bool:
	var s = _make_system()
	var u = _make_unit("unit")

	# 单单位横排 → 偏移 (0,0)
	s.创建队形([u], Vector2(200, 200), 队形系统.阵型类型.横排, 24.0)

	# 单位在 (100, 100)，组目标在 (200, 200)，移动方向 RIGHT
	# 实时目标 = 组质心(100,100) + (0,0) = (100,100)
	# 单位在 (100,100) → 距离 = 0 → 队形力 = (0,0)
	u.global_position = Vector2(100, 100)
	var 力 = s.计算队形力(u)
	var ok1 = 力.length() < 1.0

	# 单位在 (50, 100)，距离理想位置(100,100) 50px
	u.global_position = Vector2(50, 100)
	力 = s.计算队形力(u)
	# 强度 = min(50 * 8 * 0.1, 60) = min(40, 60) = 40
	# 方向 = (100-50, 100-100) = (50, 0).normalized() = (1, 0)
	# 力 = (1, 0) * 40 = (40, 0)
	var ok2 = 力.x > 35 and 力.x < 45 and abs(力.y) < 5

	u.free()
	_cleanup(s)
	return ok1 and ok2


func _test_移除单位() -> bool:
	var s = _make_system()
	var u1 = _make_unit("a")
	var u2 = _make_unit("b")

	var 组ID = s.创建队形([u1, u2], Vector2(100, 100), 队形系统.阵型类型.横排)
	s.移除单位(u1)

	var ok1 = not s.是否在队形中(u1)  # u1 已移除
	var ok2 = s.是否在队形中(u2)      # u2 仍在
	var ok3 = s.获取单位组ID(u2) == 组ID  # 组还在

	u1.free(); u2.free()
	_cleanup(s)
	return ok1 and ok2 and ok3


func _test_组ID() -> bool:
	var s = _make_system()
	var u = _make_unit()

	var id1 = s.创建队形([u], Vector2(100, 100))
	var id2 = s.创建队形([_make_unit()], Vector2(200, 200))

	# 两次创建应得不同 ID
	var ok = id2 > id1

	s.销毁组(id2)
	s.移除单位(u)
	_cleanup(s)
	return ok


func _test_销毁组() -> bool:
	var s = _make_system()
	var u = _make_unit()

	var 组ID = s.创建队形([u], Vector2(100, 100))
	s.销毁组(组ID)

	var ok1 = not s.是否在队形中(u)
	var ok2 = s.获取单位组ID(u) == -1

	u.free()
	_cleanup(s)
	return ok1 and ok2


func _test_方阵偏移() -> bool:
	var s = _make_system()
	var units: Array[Node2D] = []
	for i in range(4):
		units.append(_make_unit("sq_%d" % i))

	s.创建队形(units, Vector2(0, 0), 队形系统.阵型类型.方阵, 24.0)

	# 4人方阵：2×2
	# 索引0: 列0 行0 → (-12, 0)
	# 索引1: 列1 行0 → (12, 0)
	# 索引2: 列0 行1 → (-12, 24)
	# 索引3: 列1 行1 → (12, 24)
	var 目标0 = s.获取单位目标(units[0])
	var 目标1 = s.获取单位目标(units[1])
	var 目标2 = s.获取单位目标(units[2])
	var 目标3 = s.获取单位目标(units[3])

	# u0 在左列，u2 在左列 → x 相同
	var ok = abs(目标0.x - 目标2.x) < 1.0

	# u1 在右列，u3 在右列 → x 相同
	ok = ok and abs(目标1.x - 目标3.x) < 1.0

	# u0 在 u2 上方 → y 更小
	ok = ok and 目标0.y < 目标2.y

	for u in units: u.free()
	_cleanup(s)
	return ok


func _test_楔形偏移() -> bool:
	var s = _make_system()
	var units: Array[Node2D] = []
	for i in range(3):
		units.append(_make_unit("w_%d" % i))

	s.创建队形(units, Vector2(0, 0), 队形系统.阵型类型.楔形, 24.0)

	# 楔形3人：行0 → V 字
	# u0: (-12, 0), u1: (12, 0), u2: (0, 0)
	# u0 和 u1 x 对称
	var 目标0 = s.获取单位目标(units[0])
	var 目标1 = s.获取单位目标(units[1])
	var 目标2 = s.获取单位目标(units[2])

	var ok = abs(目标0.x + 目标1.x) < 1.0  # 左右对称
	ok = ok and 目标0.y == 目标1.y           # 同一行
	ok = ok and 目标2.x == 0.0               # 中间在中心

	for u in units: u.free()
	_cleanup(s)
	return ok


func _test_纵队偏移() -> bool:
	var s = _make_system()
	var units: Array[Node2D] = []
	for i in range(3):
		units.append(_make_unit("col_%d" % i))

	s.创建队形(units, Vector2(0, 0), 队形系统.阵型类型.纵队, 24.0)

	# 纵队3人：索引 0→(0,0), 1→(0,24), 2→(0,48)
	var 目标0 = s.获取单位目标(units[0])
	var 目标1 = s.获取单位目标(units[1])
	var 目标2 = s.获取单位目标(units[2])

	var ok = abs(目标0.x) < 1.0 and abs(目标1.x) < 1.0 and abs(目标2.x) < 1.0
	ok = ok and 目标0.y < 目标1.y and 目标1.y < 目标2.y
	ok = ok and abs(目标0.y - 0.0) < 1.0
	ok = ok and abs(目标1.y - 24.0) < 1.0
	ok = ok and abs(目标2.y - 48.0) < 1.0

	for u in units: u.free()
	_cleanup(s)
	return ok
