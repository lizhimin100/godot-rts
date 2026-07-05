extends Node

## 流场管理器 — 统一流场查询入口（Phase 7.4: 完全无状态版）
##
## ⭐ 职责：
##   1. 向 FFManager 查询流场方向
##   2. 流场不可用时回退到直接指向目标
##
## ⚠ Phase 7.4: 移除所有共享缓存。
##   _缓存目标 和 _采样缓存 导致跨单位目标污染：
##   当 unit A 和 unit B 有不同目标时，共享缓存会在两者之间
##   来回翻转，触发无效的流场重建和方向抖动。
##   所有缓存由底层 FFManager 管理（按目标位置独立缓存）。
##
##   每个 unit 的每帧方向查询完全独立计算。

static var 实例: 流场管理器 = null


func _enter_tree() -> void:
	实例 = self

func _exit_tree() -> void:
	if 实例 == self:
		实例 = null


## 获取从 位置 到 目标 的移动方向
##
## @param 位置  单位的世界坐标
## @param 目标  目标位置（由策略传入）
## @return      归一化方向向量（非零），回退时指向目标方向
func 获取方向(位置: Vector2, 目标: Vector2) -> Vector2:
	# 从 FFManager 获取流场方向（FFManager 按目标独立缓存）
	var dir: Vector2 = Vector2.ZERO
	if is_instance_valid(FFManager.instance) and FFManager.has_valid():
		dir = FFManager.get_direction(位置, 目标)

	# 流场不可用 → 直接指向目标
	if dir == Vector2.ZERO:
		var raw: Vector2 = 目标 - 位置
		if raw.length_squared() < 0.0001:
			return Vector2.ZERO
		dir = raw.normalized()

	return dir


## 检查流场是否已就绪
func 流场已就绪() -> bool:
	return is_instance_valid(FFManager.instance) and FFManager.has_valid()


## 直接清除采样缓存（现在为空操作，保留接口兼容）
func 清除采样缓存() -> void:
	pass


## 强制刷新流场（障碍变更后调用）
func 标记障碍变更() -> void:
	if is_instance_valid(FFManager.instance):
		FFManager.mark_dirty()


## 重置全部缓存（现在为空操作，保留接口兼容）
func 重置缓存() -> void:
	if is_instance_valid(FFManager.instance):
		FFManager.clear_cache()
