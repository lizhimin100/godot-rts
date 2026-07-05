extends Node
## ⚠ DEPRECATED: Movement 2.0 migration in progress.
##    新单位使用 MovementSolver。此系统保留给遗留单位使用。
##    当所有单位迁移完成后移除。
signal 移动完成(单位: Node2D, 结果: 移动结果)
signal 单位卡死(单位: Node2D)
static var 实例: Node = null


## ⭐ Slot 锁定状态
enum MoveSlotState {
	MOVING_TO_SLOT,
	SLOT_LOCKED,
}


# ============================================================
# 内部数据结构
# ============================================================

class 移动数据:
	var 请求: 移动请求
	var 策略: 移动策略
	var 上次位置: Vector2

	# ⭐ 到达标记：true 表示已发出完成信号，等待下一帧从 _移动中单位 移除
	var 已到达: bool = false

	# ⭐ Slot 状态（-1=无队形，0=MOVING_TO_SLOT，1=SLOT_LOCKED）
	var slot_state: int = -1
	var anchor_position: Vector2 = Vector2.ZERO

	# 卡死检测（内联）
	var 卡死计时: float = 0.0
	var 卡死计数: int = 0
	var 回退计时: float = 0.0
	var 回退中: bool = false

# ============================================================
# 状态
# ============================================================

var _移动中单位: Dictionary = {}

# 卡死参数
const 最大卡死放弃: int = 3
const 卡死速度阈值: float = 2.0    # px/s
const 卡死超时: float = 0.5        # 秒

# 三力权重（RTS 原则：三种力合成最终速度）
const 队形力权重: float = 0.6
const 分离力权重: float = 0.4

## 调试开关：统一由 调试配置 管理
##   DEBUG_MOVE      → 运动服务、路径日志、方向日志、卡死恢复
##   DEBUG_FORMATION → 队形系统
##   DEBUG_AVOID     → 避障系统
## 正常运行全部 false，仅输出错误


func _enter_tree() -> void:
	实例 = self
	process_priority = -100

func _exit_tree() -> void:
	if 实例 == self:
		实例 = null

func _ready() -> void:
	set_physics_process(true)
	# ⭐ 启动自检：打印所有移动系统 singleton 实例状态
	print("[SYSCHECK] === 移动系统自检 ===")
	print("[SYSCHECK] 运动服务.实例 = ", self, " ", is_instance_valid(实例))
	print("[SYSCHECK] 空间哈希网格.实例 = ", 空间哈希网格.实例 if 空间哈希网格.实例 else "NULL ❌")
	print("[SYSCHECK] 队形系统.实例 = ", 队形系统.实例 if 队形系统.实例 else "NULL ❌")
	print("[SYSCHECK] 流场管理器.实例 = ", 流场管理器.实例 if 流场管理器.实例 else "NULL ❌")
	print("[SYSCHECK] 避障系统.实例 = ", 避障系统.实例 if 避障系统.实例 else "NULL ❌")
	print("[SYSCHECK] 单位管理器.实例 = ", 单位管理器.实例 if 单位管理器.实例 else "NULL ❌")
	print("[SYSCHECK] FFManager.instance = ", FFManager.instance if is_instance_valid(FFManager.instance) else "NULL ❌")
	print("[SYSCHECK] ====================")


func _physics_process(delta: float) -> void:
	# 1. 重建空间哈希网格（所有单位，包括静止的）
	_重建空间哈希()

	# 2. 更新所有移动单位
	_更新所有移动单位(delta)


# ============================================================
# 公开接口（3 个核心方法）
# ============================================================

## 发起移动请求
## 单位已有移动 → 自动发送"被中断"结果
func 请求移动(单位: Node2D, 请求: 移动请求) -> void:
	if not is_instance_valid(单位):
		return

	# ⭐ Movement 2.0：已迁移单位由 MovementSolver 处理
	if "移动意图" in 单位 and 单位._using_movement_solver:
		return

	if 单位 in _移动中单位:
		_发送结果(单位, 移动结果.结果类型.被中断)

	var 策略 := _构建策略(请求)
	if 策略 == null:
		return

	var 数据 := 移动数据.new()
	数据.请求 = 请求
	数据.策略 = 策略
	数据.上次位置 = 单位.global_position
	_移动中单位[单位] = 数据

	# ⭐ 初始化 slot 状态（防御：即使 slot_id 丢失也强制启用队形模式）
	if 队形系统.实例 and 队形系统.实例.是否在队形中(单位):
		if 请求.队形槽位 < 0:
			push_error("[FORM-ERROR] <" + 单位.name + "> 队形中但请求缺少 slot_id")
		数据.slot_state = MoveSlotState.MOVING_TO_SLOT
	elif 请求.队形槽位 >= 0:
		数据.slot_state = MoveSlotState.MOVING_TO_SLOT

	# 同步队形系统目标（传入组目标，无需方向——队形偏移已锁定）
	if 队形系统.实例 and 请求.队形槽位 >= 0:
		var 组ID = 队形系统.实例.获取单位组ID(单位)
		if 组ID >= 0:
			队形系统.实例.更新组目标(组ID, 请求.目标位置)


## 强制停止单位的移动
func 强制停止(单位: Node2D, 原因: int = 移动结果.结果类型.被中断) -> void:
	if not is_instance_valid(单位):
		_移动中单位.erase(单位)
		return

	# ⭐ Movement 2.0：已迁移单位由 MovementSolver 处理
	if "移动意图" in 单位 and 单位._using_movement_solver:
		if is_instance_valid(MovementSolver.实例):
			MovementSolver.实例.强制停止(单位, 原因)
		return

	var 数据 = _移动中单位.get(单位)
	# ⭐ SLOT_LOCKED：保留在 _移动中单位，仅停止速度
	#   新命令会通过 请求移动 覆盖数据
	if 数据 and 数据.slot_state == MoveSlotState.SLOT_LOCKED:
		单位.velocity = Vector2.ZERO
		_发送结果(单位, 原因)
		return

	_移动中单位.erase(单位)
	单位.velocity = Vector2.ZERO
	_发送结果(单位, 原因)


## 获取单位当前的移动请求（外部读取用）
func 获取当前请求(单位: Node2D) -> 移动请求:
	var 数据 = _移动中单位.get(单位)
	return 数据.请求 if 数据 else null


## 检查单位是否正在移动
func 是否在移动(单位: Node2D) -> bool:
	return 单位 in _移动中单位

## 检查单位是否处于 SLOT_LOCKED 状态（队形已到达，仅做锚点回归）
func 是否是槽锁定(单位: Node2D) -> bool:
	var 数据 = _移动中单位.get(单位)
	return 数据 != null and 数据.slot_state == MoveSlotState.SLOT_LOCKED


# ============================================================
# 核心更新循环
# ============================================================

func _更新所有移动单位(delta: float) -> void:
	var 待移除: Array[Node2D] = []

	for 单位 in _移动中单位.keys():
		if not is_instance_valid(单位):
			待移除.append(单位)
			continue

		# ⭐ Movement 2.0：跳过已迁移单位
		if "移动意图" in 单位 and 单位.移动意图 != null and 单位._using_movement_solver:
			待移除.append(单位)
			continue

		var 数据 = _移动中单位[单位]
		var 请求 = 数据.请求
		var 策略 = 数据.策略

		# ============================================================
		# ⭐ SLOT_LOCKED：仅 anchor return + 强制 idle 动画
		# ============================================================
		if 数据.slot_state == MoveSlotState.SLOT_LOCKED:
			var dist_to_anchor = 单位.global_position.distance_to(数据.anchor_position)
			if dist_to_anchor > 2.0:
				var return_dir = (数据.anchor_position - 单位.global_position).normalized()
				var 最大速度: float = 单位.最大速度 if "最大速度" in 单位 else 350.0
				var return_speed = minf(dist_to_anchor * 0.5, 最大速度 * 0.25)
				单位.velocity = return_dir * return_speed
			else:
				单位.velocity = Vector2.ZERO

			# ⭐ SLOT_LOCKED 每帧强制 idle 动画
			#   即使 anchor return 产生小速度，也不允许外部动画系统切回移动动画
			if 单位.has_method("_切换动画"):
				单位._切换动画("待机")
			continue

		# ── 已到达 → 保持静止，从运动系统完全退出 ──
		if 数据.已到达:
			单位.velocity = Vector2.ZERO
			待移除.append(单位)
			continue

		# ── 到达检测 ──
		if 策略.是否已到达(单位, 请求):
			if 数据.slot_state == MoveSlotState.MOVING_TO_SLOT:
				# ⭐ 队形单位到达 → SLOT_LOCKED（不移除，继续跟踪）
				数据.slot_state = MoveSlotState.SLOT_LOCKED
				# ⭐ anchor = slot_target（不是当前位置！）
				#   确保锚点回归总是拉回正确的槽位目标
				var slot_target = 请求.目标位置 + 请求.队形偏移
				if 队形系统.实例 and 队形系统.实例.是否在队形中(单位):
					slot_target = 队形系统.实例.获取单位目标(单位)
				数据.anchor_position = slot_target
				单位.velocity = Vector2.ZERO
				_发送结果(单位, 移动结果.结果类型.已到达)
				if 单位.has_method("_切换动画"):
					单位._切换动画("待机")
				if 调试配置.DEBUG_MOVE:
					print("[SLOT-LOCKED] <", 单位.name, "> anchor=(", int(slot_target.x), ",", int(slot_target.y), ") slot_id=", 请求.队形槽位)
				continue
			else:
				# 非队形单位到达 → 正常移除
				if 调试配置.DEBUG_MOVE:
					print("[ARRIVE] <", 单位.name, "> 到达，从运动系统移除")
				数据.已到达 = true
				单位.velocity = Vector2.ZERO
				_发送结果(单位, 移动结果.结果类型.已到达)
				if 单位.has_method("_切换动画"):
					单位._切换动画("待机")
				continue

		# ============================================================
		# ⭐ 三力合成：path force + formation force + separation force
		#    仅 MOVING_TO_SLOT / 无队形 单位执行
		# ============================================================

		# ① 路径力 — 策略计算的速度（方向 x 移动速度）
		var 路径速度 = 策略.计算速度(单位, 请求)

		# ② 队形力 — 仅 MOVING_TO_SLOT 单位使用（x0.6）
		var 队形力 = Vector2.ZERO
		if 队形系统.实例 and 数据.slot_state == MoveSlotState.MOVING_TO_SLOT:
			队形力 = 队形系统.实例.计算队形力(单位)
			if 调试配置.DEBUG_MOVE and 队形力.length() < 0.1 and 路径速度.length() > 10.0:
				print("[DIAG] <", 单位.name, "> 队形中但队形力≈0 slot_id=", 请求.队形槽位)

		# ③ 分离力 — 同阵营单位推开（x0.4）
		var 路径方向 = 路径速度.normalized() if 路径速度.length_squared() > 0.01 else Vector2.ZERO
		var 分离力 = Vector2.ZERO
		if 避障系统.实例:
			var 周围单位 = _获取周围单位(单位)
			分离力 = 避障系统.实例.计算让路修正(单位, 周围单位, 路径方向)

		# ⭐ 合成：final = path + formation x 0.6 + separation x 0.4
		var 最终速度 = 路径速度 + 队形力 * 队形力权重 + 分离力 * 分离力权重

		# 限幅到最大速度
		var 最大速度: float = 单位.最大速度 if "最大速度" in 单位 else 350.0
		if 最终速度.length_squared() > 最大速度 * 最大速度:
			最终速度 = 最终速度.normalized() * 最大速度

		if 调试配置.DEBUG_MOVE and 最终速度.length_squared() > 4.0:
			print("[SPEED] <", 单位.name, "> final=", 最终速度.length(),
				  " path=", 路径速度.length(), " form=", 队形力.length(),
				  " sep=", 分离力.length())

		# ⭐ 方向日志：打印 PATH、FORMATION、FINAL 三方向（仅队形单位）
		if 调试配置.DEBUG_MOVE and 请求.队形槽位 >= 0 and 数据.slot_state == MoveSlotState.MOVING_TO_SLOT:
			var p_dir = 路径速度.normalized() if 路径速度.length_squared() > 0.01 else Vector2.ZERO
			var f_dir = 队形力.normalized() if 队形力.length_squared() > 0.01 else Vector2.ZERO
			var v_dir = 最终速度.normalized() if 最终速度.length_squared() > 0.01 else Vector2.ZERO
			if 最终速度.length_squared() > 4.0:
				print("[FORCE-DIR] <", 单位.name, "> slot_id=", 请求.队形槽位,
					  " PATH=(", p_dir.x, ",", p_dir.y, ")",
					  " FORM=(", f_dir.x, ",", f_dir.y, ")",
					  " FINAL=(", v_dir.x, ",", v_dir.y, ")")

		# ============================================================
		# 卡死检测（内联）
		# ============================================================

		if _检测卡死(单位, 数据, 最终速度, delta):
			# 回退阶段：反向移动 0.3 秒
			if not 数据.回退中:
				数据.回退计时 = 0.0
			数据.回退计时 += delta
			数据.回退中 = true

			if 数据.回退计时 < 0.3:
				# 朝向反方向缓慢后退
				var 后退方向 = (数据.上次位置 - 单位.global_position).normalized()
				if 后退方向 == Vector2.ZERO:
					后退方向 = Vector2(0, 1)
				最终速度 = 后退方向 * (最大速度 * 0.5)
			else:
				# 回退结束 → 增加卡死计数
				数据.回退中 = false
				数据.卡死计数 += 1

				if 数据.卡死计数 >= 最大卡死放弃:
					# 卡死超限 → 放弃移动
					待移除.append(单位)
					单位.velocity = Vector2.ZERO
					_发送结果(单位, 移动结果.结果类型.卡死)
					if 单位.has_method("_切换动画"):
						单位._切换动画("待机")
					continue

				# 重置流场，尝试新路径
				if is_instance_valid(流场管理器.实例):
					流场管理器.实例.标记障碍变更()
		else:
			# ⭐ 不卡死了 → 完全恢复（不是缓慢衰减）
			if 数据.回退中:
				数据.回退中 = false
				if 调试配置.DEBUG_MOVE:
					print("[DIAG] <", 单位.name, "> 卡死恢复 卡死计数=", 数据.卡死计数)
			数据.卡死计数 = 0
			数据.卡死计时 = 0.0

		# 写入 velocity
		单位.velocity = 最终速度
		数据.上次位置 = 单位.global_position

	# 清理
	for 单位 in 待移除:
		_移动中单位.erase(单位)

	# 每帧诊断摘要（每 60 帧输出一次）
	if 调试配置.DEBUG_MOVE and Engine.get_physics_frames() % 60 == 0:
		var 队形数 = 0
		if 队形系统.实例:
			队形数 = 队形系统.实例.获取活跃组数()
		var 哈希插入 = 空间哈希网格.实例.获取插入总数() if 空间哈希网格.实例 else 0
		print("[DIAG] 移动中=", _移动中单位.size(), " 哈希插入=", 哈希插入,
			  " 队形组=", 队形数)


# ============================================================
# 内部方法
# ============================================================

## 重建空间哈希网格（每帧开始时调用）
func _重建空间哈希() -> void:
	if not 空间哈希网格.实例:
		return

	空间哈希网格.实例.清空()

	# 加入所有移动中的单位
	for 单位 in _移动中单位.keys():
		if is_instance_valid(单位):
			空间哈希网格.实例.插入单位(单位)

	# ⭐ 加入所有单位（包括已到达的静止单位 → 它们是障碍物）
	if is_instance_valid(单位管理器.实例):
		var 全部单位 = 单位管理器.获取所有单位()
		for 单位 in 全部单位:
			if is_instance_valid(单位):
				空间哈希网格.实例.插入单位(单位)


## 获取单位周围的单位（通过空间哈希九宫格）
func _获取周围单位(单位: Node2D) -> Array[Node2D]:
	if 空间哈希网格.实例:
		return 空间哈希网格.实例.查询9宫格(单位.global_position)
	return []


## 构建移动策略
func _构建策略(请求: 移动请求) -> 移动策略:
	match 请求.类型:
		移动请求.移动类型.前往位置:
			return 前往位置移动.new()
		移动请求.移动类型.追击敌人:
			return 追击目标移动.new()
		移动请求.移动类型.移动攻击:
			return 移动攻击移动.new()
		移动请求.移动类型.技能驱动:
			return 技能驱动移动.new()
		_:
			return 前往位置移动.new()


## 发送移动完成结果
func _发送结果(单位: Node2D, 原因: int) -> void:
	if not is_instance_valid(单位):
		return

	# 追击目标丢失 → 用目标丢失类型
	var 最终原因 = 原因
	if 原因 == 移动结果.结果类型.被中断:
		var 请求 = 获取当前请求(单位)
		if 请求 and 请求.类型 == 移动请求.移动类型.追击敌人:
			if not is_instance_valid(请求.目标实体):
				最终原因 = 移动结果.结果类型.目标丢失

	var 结果 = 移动结果.new()
	结果.结果 = 最终原因
	移动完成.emit(单位, 结果)


## 内联卡死检测
## @return  true=卡死（期望移动但实际不动）
func _检测卡死(单位: Node2D, 数据: 移动数据, 期望速度: Vector2, delta: float) -> bool:
	var 期望 = 期望速度.length()
	var 实际 = 单位.velocity.length()

	# 期望本身很小 → 不检测
	if 期望 < 卡死速度阈值:
		数据.卡死计时 = 0.0
		return false

	# 实际远低于期望 → 可能卡住
	if 实际 < 卡死速度阈值:
		数据.卡死计时 += delta
		if 数据.卡死计时 >= 卡死超时:
			数据.卡死计时 = 0.0
			return true
	else:
		数据.卡死计时 = 0.0

	return false
