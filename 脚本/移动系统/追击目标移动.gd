extends 移动策略
class_name 追击目标移动

## 追击目标策略 — 右键点击敌人时使用
##
## 流程：
##   1. 每帧获取目标实体的实时位置
##   2. 流场指向目标位置移动
##   3. 进入攻击范围后通知单位攻击（不再继续移动）
##   4. 目标死亡或超出追击上限时结束
##
## ⭐ 速度使用单位设定的 移动速度（非最大速度）

const DIAG: bool = false

func 计算速度(单位: Node2D, 请求: 移动请求) -> Vector2:
	if not is_instance_valid(请求.目标实体):
		return Vector2.ZERO

	var 目标位置 = 请求.目标实体.global_position
	var 方向 = 流场管理器.获取方向(单位.global_position, 目标位置)
	if 方向 == Vector2.ZERO:
		return Vector2.ZERO

	# ⭐ 使用移动速度（非最大速度），让单位按照自己设定的速度移动
	var 速度值 = 单位.移动速度 if "移动速度" in 单位 else 200.0
	if DIAG: print("[CHASE] ", 单位.name, " 追击速度=", 速度值)
	return 方向 * 速度值


func 是否已到达(单位: Node2D, 请求: 移动请求) -> bool:
	# 目标已死亡 → 结束
	if not is_instance_valid(请求.目标实体):
		return true
	if not _目标是否存活(请求.目标实体):
		return true

	# 超出追击上限 → 结束
	var 距离 = 单位.global_position.distance_to(请求.目标实体.global_position)
	if 距离 > 请求.追击上限:
		return true

	return false


## 检查目标实体是否还活着
func _目标是否存活(目标: Node2D) -> bool:
	if 目标.has_method("是否存活"):
		return 目标.是否存活()
	if 目标.has_method("获取当前生命值"):
		return 目标.获取当前生命值() > 0
	return true
