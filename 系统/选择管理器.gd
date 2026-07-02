extends Node

## 选择管理器 — 统一管理所有选中逻辑
##
## 职责：
##   1. 记录当前选中的单位列表
##   2. 记录鼠标悬停的单位
##   3. 只做3件事：记录引用、通知UI、不触发游戏逻辑
##   4. 选中敌人 ≠ 获得控制权
##   5. 选中不影响视野
##
## 使用方式（Autoload）：
##   选择管理器.选中单位([unit1, unit2])
##   选择管理器.获取选中() -> Array

signal 选中变化(units: Array)
signal 选中清空()
signal 悬停变化(unit)

static var 实例: 选择管理器 = null

# ========== 选中状态 ==========
var 选中单位列表: Array = []  # 当前选中的单位列表
var 悬停单位 = null           # 鼠标悬停的单位

# ========== 选中计数 ==========
var 选中数量: int:
	get: return 选中单位列表.size()


func _enter_tree() -> void:
	实例 = self


func _exit_tree() -> void:
	if 实例 == self:
		实例 = null
	选中单位列表.clear()
	悬停单位 = null


# ============================================================
# 选中操作
# ============================================================

## 设置选中的单位（替换当前选中）
func 选中单位(units: Array) -> void:
	if units.is_empty():
		取消选中()
		return

	# 过滤无效单位 + ⭐ 去重（防止框选时空间网格返回重复单位）
	var valid_units: Array = []
	var seen: Dictionary = {}
	for unit in units:
		if is_instance_valid(unit) and not seen.has(unit):
			seen[unit] = true
			valid_units.append(unit)

	if valid_units.is_empty():
		取消选中()
		return

	选中单位列表 = valid_units
	选中变化.emit(选中单位列表)


## 添加单位到选中（Shift加选）
func 添加选中(unit) -> void:
	if not is_instance_valid(unit):
		return
	if unit in 选中单位列表:
		return
	选中单位列表.append(unit)
	选中变化.emit(选中单位列表)


## 从选中中移除
func 移除选中(unit) -> void:
	if not is_instance_valid(unit):
		return
	选中单位列表.erase(unit)
	if 选中单位列表.is_empty():
		选中清空.emit()
	else:
		选中变化.emit(选中单位列表)


## 取消所有选中
func 取消选中() -> void:
	if 选中单位列表.is_empty():
		return
	选中单位列表.clear()
	选中清空.emit()


## 获取当前选中单位列表
func 获取选中() -> Array:
	return 选中单位列表.duplicate()


## 获取选中的第一个单位
func 获取第一个选中():
	if 选中单位列表.is_empty():
		return null
	return 选中单位列表[0]


## 选中是否包含特定单位
func 已选中(unit) -> bool:
	return unit in 选中单位列表


## 选中数量
func 获取数量() -> int:
	return 选中单位列表.size()


## 选中中是否有敌方单位（纯查询，不触发逻辑）
func 选中包含敌人() -> bool:
	for unit in 选中单位列表:
		if is_instance_valid(unit) and unit.has_method("_是敌人"):
			if unit._是敌人():
				return true
	return false


# ============================================================
# 悬停操作
# ============================================================

## 设置悬停单位
func 设置悬停(unit) -> void:
	if 悬停单位 == unit:
		return
	悬停单位 = unit
	悬停变化.emit(unit)


## 清除悬停
func 清除悬停() -> void:
	if 悬停单位 == null:
		return
	悬停单位 = null
	悬停变化.emit(null)
