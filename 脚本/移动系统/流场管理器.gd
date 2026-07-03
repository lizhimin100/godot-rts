extends Node

## 流场管理器 — 统一流场查询入口（共享缓存版）
##
## ⭐ 流场共享缓存机制：
##   当多个单位向同一目标移动时，流场只计算一次，所有单位共享。
##   目标变更时才触发 FFManager.request_update()。
##
## ⚠ 目标输入：
##   流场接收的是每个单位的 slot_target（组目标 + 槽位偏移），
##   由各策略通过 获取最终目标(请求, 单位) 传入。
##   不是在运动服务层面重新组装的 group_target。
##
## 职责：
##   1. 缓存流场目标：目标不变 → 复用缓存，不触发更新
##   2. 采样缓存：同一位置的方向最多每帧计算一次
##   3. 调用底层 FFManager 生成和查询流场
##   4. 流场不可用时回退到直接指向目标（全速）

func _diag() -> bool: return 调试配置.DEBUG_MOVE

static var 实例: 流场管理器 = null


## 当前缓存的流场目标
var _缓存目标: Vector2 = Vector2.ZERO
## 缓存是否有效
var _缓存有效: bool = false
## 缓存的流场是否已就绪（FFManager.has_valid）
var _流场就绪: bool = false

## 位置 → 方向 采样缓存（按 8px 网格离散化）
## key = "%d,%d", value = Vector2
var _采样缓存: Dictionary = {}
## 采样缓存网格精度（越小越精确但越耗内存）
const 采样网格精度: float = 8.0

var 缓存命中: int = 0
var 缓存未命中: int = 0
var _已报告状态: bool = false


func _enter_tree() -> void:
	实例 = self

func _exit_tree() -> void:
	if 实例 == self:
		实例 = null


## 获取从 位置 到 目标 的移动方向
##
## ⭐ 目标 = slot_target（由策略传入的最终目标，含槽位偏移）
##   流场共享缓存基于 slot_target 做 key，只在该目标变化时重建。
##
## @return  归一化方向向量（非零），回退时指向目标方向
func 获取方向(位置: Vector2, 目标: Vector2) -> Vector2:
	# ── 目标变更 → 重置缓存 ──
	if not _缓存有效 or _缓存目标.distance_squared_to(目标) > 4.0:
		_缓存目标 = 目标
		_缓存有效 = true
		_流场就绪 = false
		_采样缓存.clear()

		if _diag():
			print("[FF] 🎯 流场目标=", 目标, " (变更后)")

		# 请求生成流场（只在新目标时触发）
		if is_instance_valid(FFManager.instance):
			FFManager.request_update(目标)
		else:
			if _diag() and not _已报告状态:
				print("[FF] ⚠ FFManager.instance 无效")
			return _fallback(位置, 目标)

	# ── 采样缓存命中 → 直接返回 ──
	var 采样键 = _采样键(位置)
	if _采样缓存.has(采样键):
		缓存命中 += 1
		return _采样缓存[采样键]

	缓存未命中 += 1

	# ── 检查流场是否已就绪 ──
	if not _流场就绪:
		if is_instance_valid(FFManager.instance) and FFManager.has_valid():
			_流场就绪 = true
			if _diag():
				print("[FF] ✅ 流场就绪，目标=", 目标, " 开始采样")
		else:
			# 流场还在生成中 → 回退
			var 回退方向 = _fallback(位置, 目标)
			_采样缓存[采样键] = 回退方向
			return 回退方向

	# ── 流场就绪 → 采样 ──
	var ff: FFGrid = FFManager.get_flow_field()
	if not ff:
		_流场就绪 = false
		var 回退方向 = _fallback(位置, 目标)
		_采样缓存[采样键] = 回退方向
		return 回退方向

	var dir: Vector2 = ff.sample(位置)

	# 当前位置在障碍上 → 回退
	if dir == Vector2.ZERO:
		var 回退方向 = _fallback(位置, 目标)
		_采样缓存[采样键] = 回退方向
		return 回退方向

	# 缓存并返回
	_采样缓存[采样键] = dir.normalized()
	return _采样缓存[采样键]


## 清除位置采样缓存（目标不变时，清理过期的位置缓存）
func 清除采样缓存() -> void:
	_采样缓存.clear()


## 强制刷新流场（障碍变更后调用）
func 标记障碍变更() -> void:
	_缓存有效 = false
	_流场就绪 = false
	_采样缓存.clear()

	if is_instance_valid(FFManager.instance):
		FFManager.mark_dirty()


## 重置全部缓存
func 重置缓存() -> void:
	_缓存有效 = false
	_流场就绪 = false
	_采样缓存.clear()
	缓存命中 = 0
	缓存未命中 = 0

	if is_instance_valid(FFManager.instance):
		FFManager.clear_cache()


## 检查流场是否已就绪
func 流场已就绪() -> bool:
	return _流场就绪


## 获取当前缓存目标
func 获取缓存目标() -> Vector2:
	return _缓存目标 if _缓存有效 else Vector2.ZERO


# ============================================================
# 内部
# ============================================================

## 生成采样缓存键（按网格离散化）
func _采样键(位置: Vector2) -> String:
	var gx = floori(位置.x / 采样网格精度)
	var gy = floori(位置.y / 采样网格精度)
	return "%d,%d" % [gx, gy]


## 回退：直接指向目标方向（全速）
func _fallback(从: Vector2, 到: Vector2) -> Vector2:
	var raw: Vector2 = 到 - 从
	if raw.length_squared() < 0.0001:
		return Vector2.ZERO
	return raw.normalized()
