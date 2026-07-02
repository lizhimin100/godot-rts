extends Node

## 流场管理器 — 统一流场查询入口
##
## 职责：
##   1. 调用底层 FFManager 生成和查询流场
##   2. 流场不可用时回退到直接指向目标（全速）
##   3. 外部不应直接调用 FFManager

const DIAG: bool = true  # 诊断日志

static var 实例: 流场管理器 = null

var 流场缓存: Dictionary = {}
var 缓存命中: int = 0
var 缓存未命中: int = 0
var _已报告状态: bool = false

func _enter_tree() -> void:
	实例 = self

func _exit_tree() -> void:
	if 实例 == self: 实例 = null


## 获取从 位置 到 目标 的移动方向
## 流场可用 → 使用流场方向（绕障碍）
## 流场不可用 → 回退到直接指向目标（全速）
func 获取方向(位置: Vector2, 目标: Vector2) -> Vector2:
	if not is_instance_valid(FFManager.instance):
		if DIAG and not _已报告状态:
			print("[FF] ⚠ FFManager.instance 无效")
			_已报告状态 = true
		return _fallback(位置, 目标)

	if not FFManager.has_valid():
		if DIAG and not _已报告状态:
			print("[FF] ⚠ FFManager.has_valid()=false nav_world=", FFManager.instance.nav_world if FFManager.instance else "null")
			_已报告状态 = true
		# 请求更新（让流场在后台继续生成）
		FFManager.request_update(目标)
		return _fallback(位置, 目标)

	# 流场有效 → 采样
	if _已报告状态 == false:
		print("[FF] ✅ 流场有效，开始使用流场导航")
		_已报告状态 = true

	FFManager.request_update(目标)

	var ff: FFGrid = FFManager.get_flow_field()
	if not ff:
		return _fallback(位置, 目标)

	var dir: Vector2 = ff.sample(位置)
	if dir == Vector2.ZERO:
		# 当前位置在障碍上 → 回退到直接指向
		return _fallback(位置, 目标)

	return dir


## 回退：直接指向目标方向
func _fallback(从: Vector2, 到: Vector2) -> Vector2:
	var raw: Vector2 = 到 - 从
	if raw.length_squared() < 0.0001:
		return Vector2.ZERO
	return raw.normalized()


func 标记障碍变更() -> void:
	FFManager.mark_dirty()


func 重置缓存() -> void:
	流场缓存.clear()
	FFManager.clear_cache()
