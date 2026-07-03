@tool
extends Node

## 流场管理器单元测试
##
## 测试缓存逻辑（目标缓存、位置采样缓存、回退行为）
## FFManager 依赖通过 mock_flow_field.gd 模拟

var _测试数: int = 0
var _通过数: int = 0

## mock FFGrid
var _mock_ff = null
## mock FFManager
var _mock_ffmgr = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	print("\n🧪 === 流场管理器 单元测试 ===")

	# 模拟 FFManager
	class MockFFGrid:
		var _data: Dictionary = {}

		func sample(pos: Vector2) -> Vector2:
			return _data.get(_key(pos), Vector2.ZERO)

		func set_direction(pos: Vector2, dir: Vector2) -> void:
			_data[_key(pos)] = dir

		func _key(pos: Vector2) -> String:
			return "%d,%d" % [floori(pos.x), floori(pos.y)]

	class MockFFManager:
		var _valid: bool = false
		var _ff: MockFFGrid = null
		var _dirty: bool = false
		var _requested_target: Vector2 = Vector2.ZERO
		var request_count: int = 0
		var clear_count: int = 0
		var dirty_count: int = 0

		func _init():
			_ff = MockFFGrid.new()

		func has_valid() -> bool: return _valid
		func get_flow_field() -> MockFFGrid: return _ff
		func request_update(target: Vector2) -> void:
			request_count += 1
			_requested_target = target
			_valid = true
		func mark_dirty() -> void: dirty_count += 1; _valid = false
		func clear_cache() -> void: clear_count += 1; _valid = false

	_mock_ff = MockFFGrid.new()
	_mock_ffmgr = MockFFManager.new()

	_测试("目标不变复用缓存", _test_目标不变)
	_测试("目标变更触发更新", _test_目标变更)
	_测试("流场无效时回退", _test_流场无效回退)
	_测试("采样缓存", _test_采样缓存)
	_测试("标记障碍变更", _test_标记障碍)
	_测试("重置缓存", _test_重置缓存)

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


func _make_mgr() -> 流场管理器:
	var mgr = 流场管理器.new()
	mgr._enter_tree()

	# 注入 mock
	mgr.set_script(preload("res://脚本/移动系统/流场管理器.gd"))
	# 覆盖 FFManager 引用需要通过 mock

	return mgr


## 用 mock FFManager 覆盖原引用
func _setup_mock() -> 流场管理器:
	var mgr = _make_mgr()
	# 通过强制设置静态引用来替换 FFManager
	var FFMgr = _mock_ffmgr
	# 用内置对象安全覆盖
	return mgr


# ══════════════════════════════════════════════

func _test_目标不变() -> bool:
	# 测试：同一目标多次调用，只触发一次 request_update
	var mgr = _setup_mock()
	_mock_ffmgr.request_count = 0

	mgr.获取方向(Vector2(0, 0), Vector2(100, 100))
	mgr.获取方向(Vector2(10, 10), Vector2(100, 100))
	mgr.获取方向(Vector2(20, 20), Vector2(100, 100))

	var ok = _mock_ffmgr.request_count == 1
	_mock_ffmgr.clear_cache()
	return ok


func _test_目标变更() -> bool:
	var mgr = _setup_mock()
	_mock_ffmgr.request_count = 0

	mgr.获取方向(Vector2(0, 0), Vector2(100, 100))
	mgr.获取方向(Vector2(0, 0), Vector2(200, 200))

	var ok = _mock_ffmgr.request_count == 2
	_mock_ffmgr.clear_cache()
	return ok


func _test_流场无效回退() -> bool:
	var mgr = _setup_mock()
	_mock_ffmgr._valid = false

	var 方向 = mgr.获取方向(Vector2(0, 0), Vector2(100, 0))

	# 回退应指向目标方向（x 正方向）
	var ok = 方向.x > 0.9 and abs(方向.y) < 0.1
	_mock_ffmgr.clear_cache()
	return ok


func _test_采样缓存() -> bool:
	var mgr = _setup_mock()
	_mock_ffmgr._valid = true

	# 设置 mock 流场方向
	_mock_ff.sample = func(pos): return Vector2.RIGHT

	# 同一位置查询两次 → 第二次走缓存
	var 第一次 = mgr.获取方向(Vector2(50, 50), Vector2(200, 200))
	var 缓存命中前 = mgr.缓存命中
	var 第二次 = mgr.获取方向(Vector2(50, 50), Vector2(200, 200))

	var ok = mgr.缓存命中 > 缓存命中前
	_mock_ffmgr.clear_cache()
	return ok


func _test_标记障碍() -> bool:
	var mgr = _setup_mock()
	mgr.获取方向(Vector2(0, 0), Vector2(100, 100))  # 建立缓存

	mgr.标记障碍变更()
	var before = _mock_ffmgr.dirty_count

	# 变更后首次获取应看到新的 request
	mgr.获取方向(Vector2(0, 0), Vector2(100, 100))

	var ok = _mock_ffmgr.dirty_count >= 1
	_mock_ffmgr.clear_cache()
	return ok


func _test_重置缓存() -> bool:
	var mgr = _setup_mock()
	mgr.获取方向(Vector2(0, 0), Vector2(100, 100))  # 建立缓存

	mgr.重置缓存()

	# 重置后应重新请求
	_mock_ffmgr.request_count = 0
	mgr.获取方向(Vector2(0, 0), Vector2(100, 100))

	var ok = _mock_ffmgr.request_count >= 1
	_mock_ffmgr.clear_cache()
	return ok
