@tool
extends Node

## 避障系统单元测试

var _测试数: int = 0
var _通过数: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	print("\n🧪 === 避障系统 单元测试 ===")

	_测试("同阵营分离力", _test_同阵营分离)
	_测试("敌对单位无分离", _test_敌对无分离)
	_测试("距离外无分离", _test_距离外无分离)
	_测试("自身无分离", _test_自身无分离)
	_测试("分离力限幅", _test_分离力限幅)
	_测试("无单位返回零", _test_空列表)

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


## 创建一个可测试的单位
class TestUnit extends Node2D:
	var 最大速度: float = 350.0
	var 阵营: int = 1

	func 是敌对(other) -> bool:
		if other.has_method("获取阵营"):
			return 获取阵营() != other.获取阵营()
		return false

	func 获取阵营() -> int:
		return 阵营


func _make_unit(team: int = 1, pos: Vector2 = Vector2.ZERO) -> TestUnit:
	var u = TestUnit.new()
	u.阵营 = team
	u.global_position = pos
	return u


# ══════════════════════════════════════════════

func _test_同阵营分离() -> bool:
	var sys = 避障系统.new()
	var 自身 = _make_unit(1, Vector2(0, 0))
	var 队友 = _make_unit(1, Vector2(20, 0))  # 20px away

	# 修正应在 -X 方向（推离队友）
	var 结果 = sys.计算让路修正(自身, [自身, 队友], Vector2.RIGHT)

	var ok = 结果.x < 0  # 应向 X 负方向推离

	自身.free(); 队友.free()
	return ok


func _test_敌对无分离() -> bool:
	var sys = 避障系统.new()
	var 自身 = _make_unit(1, Vector2(0, 0))
	var 敌人 = _make_unit(2, Vector2(20, 0))  # 敌对阵营

	var 结果 = sys.计算让路修正(自身, [自身, 敌人], Vector2.RIGHT)

	var ok = 结果.length() < 1.0  # 不应该有修正

	自身.free(); 敌人.free()
	return ok


func _test_距离外无分离() -> bool:
	var sys = 避障系统.new()
	var 自身 = _make_unit(1, Vector2(0, 0))
	var 远处 = _make_unit(1, Vector2(200, 0))  # 200px away > 32px radius

	var 结果 = sys.计算让路修正(自身, [自身, 远处], Vector2.RIGHT)

	var ok = 结果.length() < 1.0

	自身.free(); 远处.free()
	return ok


func _test_自身无分离() -> bool:
	var sys = 避障系统.new()
	var 自身 = _make_unit(1, Vector2(0, 0))

	var 结果 = sys.计算让路修正(自身, [自身], Vector2.RIGHT)

	var ok = 结果.length() < 1.0

	自身.free()
	return ok


func _test_分离力限幅() -> bool:
	var sys = 避障系统.new()
	var 自身 = _make_unit(1, Vector2(0, 0))
	var 很近 = _make_unit(1, Vector2(2, 0))  # 极度接近

	var 结果 = sys.计算让路修正(自身, [自身, 很近], Vector2.RIGHT)

	# 限幅 ≤ 最大速度 * 分离最大比例(0.4)
	var 上限 = 350.0 * 0.4
	var ok = 结果.length() <= 上限 + 1.0

	自身.free(); 很近.free()
	return ok


func _test_空列表() -> bool:
	var sys = 避障系统.new()
	var 自身 = _make_unit(1, Vector2(0, 0))

	var 结果 = sys.计算让路修正(自身, [], Vector2.RIGHT)

	var ok = 结果.length() < 1.0

	自身.free()
	return ok
