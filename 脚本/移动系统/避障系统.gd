extends Node

## 避障系统 — 纯分离力计算器
##
## ⚠ 核心原则：
##   avoidance_force 是速度微调 (px/s)，不是独立移动系统。
##   final 必须 <= unit.移动速度 * 0.35。
##   同组单位优先横向展开，不前后互推。
##   静止单位（SLOT_LOCKED）产生软绕行，不强推。
##
## ⚠ 调用约定：
##   运动服务在速度合成中使用 分离力权重(0.4)：
##     final = path + formation*0.6 + avoidance*0.4
##   本系统返回值单位 = px/s，不是位移不是冲量。

func _diag() -> bool: return 调试配置.DEBUG_AVOID

static var 实例: Node = null

## 避障半径 (px) — 约 spacing * 0.9
const 分离半径: float = 44.0

## raw → final 增益：累加方向长度 × 移动速度 × 此值
const 分离增益: float = 0.5

## 硬限幅比例：final ≤ 移动速度 × 此值
const 分离最大比例: float = 0.35

## 静止阈值：低于此速度视为 SLOT_LOCKED
const 静止速度阈值: float = 4.0

## 静止单位避障力折扣
const 静止折扣: float = 0.3


func _enter_tree() -> void:
	实例 = self

func _exit_tree() -> void:
	if 实例 == self:
		实例 = null


## ⭐ 计算避障力 (px/s)
## 返回值 = 速度修正向量，已限幅。
## cap = unit.移动速度 * 0.35
##
## @param 单位      当前移动单位（必须有 移动速度 或 最大速度 属性）
## @param 周围单位  九宫格邻居（来自 空间哈希网格）
## @param 期望方向  策略当前移动方向（归一化）
func 计算让路修正(单位: Node2D, 周围单位: Array, 期望方向: Vector2) -> Vector2:
	if not is_instance_valid(单位):
		return Vector2.ZERO

		# ⭐ Step 3: 使用实际移动速度(110)，不是最大速度硬上限(800)
		#    避障cap = 移动速度×0.35，不是 最大速度×0.35
	var move_speed: float = 单位.移动速度 if "移动速度" in 单位 else 单位.最大速度 if "最大速度" in 单位 else 200.0
	var max_avoid: float = move_speed * 分离最大比例  # ≈ 110*0.35=38.5

	var 累加方向 := Vector2.ZERO
	var 邻居数 := 0
	var 有同组移动邻居 := false

	# ⭐ Step 1+8: 遍历邻居，累加分离方向
	for 其他 in 周围单位:
		if 其他 == 单位 or not is_instance_valid(其他):
			continue

		# 只对同阵营产生避障
		if _是否为敌对(单位, 其他):
			continue

		var 偏移: Vector2 = 单位.global_position - 其他.global_position
		var 距离: float = 偏移.length()

		if 距离 > 分离半径 or 距离 < 1.0:
			continue

		邻居数 += 1
		var 强度 = 1.0 - 距离 / 分离半径

		# ⭐ Step 8: 静止单位 (SLOT_LOCKED) → 仅产生软绕行
		var is_stationary = "velocity" in 其他 and 其他.velocity.length_squared() < 静止速度阈值
		if is_stationary:
			强度 *= 静止折扣  # ×0.3

		# ⭐ Step 7: 标记同组非静止邻居 → 横向展开
		if not is_stationary and _在同一队形组(单位, 其他):
			有同组移动邻居 = true

		累加方向 += 偏移.normalized() * 强度

	# Phase 7.3: 邻居数归一化 e2�� reciprocity 稳定性修复
	# 当 C 被 N 个邻居同时推开时，原算法累积 N× 力
	# 导致：A 推 C 的力量 ×1，但 C 被 A+B+D 推的力 ×3 → 不对称
	# 修复：除以 sqrt(N)，使多邻居累积力≈ 单邻居力 × sqrt(N) 而不是 ×N
	if 邻居数 > 1:
		累加方向 /= maxf(1.0, sqrt(float(邻居数)))

	# --- 无邻居 → 返回零 ---
	if 累加方向.length_squared() < 0.0001:
		return Vector2.ZERO

	var 累加长 = 累加方向.length()
	var 归一方向 = 累加方向 / 累加长

	# --- raw force (before cap) ---
	#   formula: raw = direction * accumulation_length * move_speed * gain
	#   gain=0.5 → raw_mag = 累加长 * move_speed * 0.5
	var raw_mag = 累加长 * move_speed * 分离增益
	var raw_force = 归一方向 * raw_mag

	# --- Step 2: 硬限幅 ---
	var 修正 = raw_force
	if 修正.length_squared() > max_avoid * max_avoid:
		修正 = 修正.normalized() * max_avoid

	# --- Step 7: 同组横向展开（替换修正为横向分量） ---
	if 有同组移动邻居 and 期望方向.length_squared() > 0.001:
		var forward = 期望方向.normalized()
		var side = Vector2(-forward.y, forward.x)
		var side_amount = 修正.dot(side)  # 投影到侧向
		修正 = side * side_amount  # 只保留侧向分量

		# 重新限幅（投影可能超越原限幅）
		if 修正.length_squared() > max_avoid * max_avoid:
			修正 = 修正.normalized() * max_avoid

	# --- Step 6: 前向投影保护 ---
	#   防止 avoidance 长期把单位往目标反方向推
	if 期望方向.length_squared() > 0.001 and 修正.length_squared() > 1.0:
		var forward = 期望方向.normalized()
		var fwd_amount = 修正.dot(forward)

		# 如果反向分量超过 max_avoid * 0.5，移除整个反向分量
		if fwd_amount < -max_avoid * 0.5:
			修正 -= forward * fwd_amount  # 移除反向

			# 重新限幅
			if 修正.length_squared() > max_avoid * max_avoid:
				修正 = 修正.normalized() * max_avoid

	# --- Step 4: 日志（raw / cap / final） ---
	if _diag():
		var raw_len = raw_force.length()
		var final_len = 修正.length()
		if final_len > 1.0:
			print("[AVOID] unit=", 单位.name, " neighbors=", 邻居数,
				  " raw=", raw_len, " cap=", max_avoid,
				  " final=", final_len)
		elif 邻居数 > 3 and final_len < 0.5:
			print("[AVOID-IGNORE] unit=", 单位.name, " neighbors=", 邻居数,
				  " reason=final≈0 raw=", raw_len)

	return 修正


## 检查两单位是否在同一队形组（用于横向展开）
func _在同一队形组(a: Node2D, b: Node2D) -> bool:
	if not 队形系统.实例:
		return false
	var ga = 队形系统.实例.获取单位组ID(a)
	var gb = 队形系统.实例.获取单位组ID(b)
	return ga >= 0 and ga == gb


## 判断是否为敌对单位
func _是否为敌对(单位A: Node2D, 单位B: Node2D) -> bool:
	if 单位A.has_method("是敌对"):
		return 单位A.是敌对(单位B)
	return false
