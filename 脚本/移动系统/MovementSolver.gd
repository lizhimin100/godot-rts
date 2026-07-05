extends Node

## MovementSolver — 唯一 velocity 写入者（Movement 2.0）
##
## 职责：
##   1. 读取已迁移单位的 MovementIntent
##   2. 通过 MovementForceProvider 收集建议力
##   3. 通过 MovementForcePipeline 过滤→修正→融合建议力 ★
##   4. 写入 unit.velocity（★ 唯一写入点）
##   5. 到达检测 + 信号发射
##   6. SLOT_LOCKED 锚点回归
##   7. 卡死检测与解卡
##
## ★ Phase 5 变更：
##   Pipeline 成为 Force 的唯一处理入口。
##   Solver 不直接操作 MovementForce 数组。
##   生命周期（过期/无效/标志）由 Pipeline 统一管理。
##
## Provider 架构（Phase 3+）：
##   路径力由 FlowFieldForceProvider 提供（已 Provider 化）
##   队形力由 FormationForceProvider 提供（Phase 6 已迁移）
##   分离力由 SeparationForceProvider 提供（Phase 7 已迁移）
##   当前唯一剩余内联力：路径力（策略方向 × 速度，待评估是否需 Provider 化）
##
## 与旧系统关系：
##   - 仅处理 _using_movement_solver == true 的单位
##   - 运动服务 的 gate 会跳过这些单位
##   - 空间哈希复用 运动服务 已重建的数据
##
## 处理顺序（本帧内）：
##   priority -100: 运动服务（跳过已迁移单位）
##   priority  -1: 单元状态机（写入 MovementIntent）
##   priority   0: MovementSolver（读取意图 → 写 velocity）【本系统】
##   priority   0: UnitBase（scene node, 在 autoload 之后 → move_and_slide()）

signal 移动完成(单位: Node2D, 结果: 移动结果)
signal 单位卡死(单位: Node2D)

static var 实例: Node = null


# ============================================================
# SLOT_LOCKED 状态（与 运动服务.MoveSlotState 保持一致）
# ============================================================

const SLOT_NONE: int = -1
const MOVING_TO_SLOT: int = 0
const SLOT_LOCKED: int = 1


# ============================================================
# Provider 脚本路径注册表
# ============================================================
# 内置 Provider 路径列表。Solver 在 _ready() 时按路径加载。
# 新增内置 Provider → 在数组中追加一行路径字符串。
# 外部 Provider 可通过 MovementSolver.注册Provider() 静态 API 注册，
# 无需修改本文件。
# ============================================================
const _PROVIDER_PATHS: Array[String] = [
	"res://脚本/移动系统/FlowFieldForceProvider.gd",
	"res://脚本/移动系统/FormationForceProvider.gd",
	"res://脚本/移动系统/SeparationForceProvider.gd",
]


# ============================================================
# 卡死参数（与 运动服务 一致）
# ============================================================

const 最大卡死放弃: int = 3
const 卡死速度阈值: float = 2.0
const 卡死超时: float = 0.5


# ============================================================
# 每个单位的状态数据
# ============================================================

class SolverUnitData:
	# 策略
	var 策略: 移动策略 = null
	var 上次意图类型: int = MovementIntent.IntentType.NONE

	# 位置追踪
	var 上次位置: Vector2 = Vector2.ZERO

	# ⭐ Slot 状态
	var slot_state: int = SLOT_NONE
	var anchor_position: Vector2 = Vector2.ZERO

	# ⭐ 到达标记
	var 已到达: bool = false

	# 卡死检测
	var 卡死计时: float = 0.0
	var 卡死计数: int = 0
	var 回退计时: float = 0.0
	var 回退中: bool = false

	# Phase 7.4: Direction continuity smoothing
	# Stores previous frame direction to prevent frame-to-frame flip
	var last_dir: Vector2 = Vector2.ZERO


# ============================================================
# 运行时状态
# ============================================================

var _单位数据: Dictionary = {}  # Unit → SolverUnitData

# ============================================================
# Force Provider 系统（Phase 3）
# ============================================================

## 注册的 Force Provider 列表
var _providers: Array[MovementForceProvider] = []

## 待注册的 Provider 静态队列（外部通过 注册Provider() 添加）
static var _待注册Provider: Array[MovementForceProvider] = []

## ⭐ Force Pipeline 实例（Phase 5 — 建议力生命周期流水线）
var _force_pipeline: MovementForcePipeline = null

## 当前帧收集的所有建议力（仅调试用）
var _当前帧力: Array[MovementForce] = []


# ============================================================
# 生命周期
# ============================================================

func _enter_tree() -> void:
	实例 = self
	process_priority = 0

func _exit_tree() -> void:
	if 实例 == self:
		实例 = null


func _ready() -> void:
	set_physics_process(true)
	print("[SYSCHECK] MovementSolver.实例 = ", self, " ", is_instance_valid(实例))

	# ⭐ 初始化 Force Pipeline（Phase 5 — 建议力生命周期流水线）
	_force_pipeline = MovementForcePipeline.new()

	# ⭐ 注册 Force Provider（从静态待注册队列迁移）
	_注册所有Provider()


func _注册所有Provider() -> void:
	# ① 按路径加载内置 Provider
	for path in _PROVIDER_PATHS:
		var script = load(path)
		if script == null or not script.can_instantiate():
			push_error("[SYSCHECK] MovementSolver 无法加载 Provider 脚本: ", path)
			continue
		var instance = script.new()
		if instance is MovementForceProvider:
			_providers.append(instance)
			print("[SYSCHECK] MovementSolver 已加载 Provider: ", path.get_file())
		else:
			push_error("[SYSCHECK] MovementSolver 脚本不是 MovementForceProvider: ", path)

	# ② 静态注册队列（外部通过 注册Provider() 添加）
	for p in _待注册Provider:
		if p != null:
			_providers.append(p)
			print("[SYSCHECK] MovementSolver 已注册外部 Provider: ", p.provider_name)
	_待注册Provider.clear()

	print("[SYSCHECK] MovementSolver 共 ", _providers.size(), " 个 Provider 已注册")


## 静态注册 Provider（外部调用，无需修改本文件）
## @param provider 已实例化的 MovementForceProvider 实例
static func 注册Provider(provider: MovementForceProvider) -> void:
	_待注册Provider.append(provider)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(单位管理器.实例):
		return

	for unit in 单位管理器.获取所有单位():
		if not is_instance_valid(unit):
			continue
		# ⭐ 只处理已迁移单位
		if not ("_using_movement_solver" in unit) or not unit._using_movement_solver:
			continue
		if not ("移动意图" in unit) or unit.移动意图 == null or not unit.移动意图.is_valid():
			# 意图为空 → 已迁移单位不应在此状态，但安全处理
			continue

		_解析单位(unit, delta)

	# 清理无效单位
	_清理死单位()


# ============================================================
# 外部接口
# ============================================================

## 强制停止单位移动（供 UnitBase.立即停止 调用）
func 强制停止(单位: Node2D, 原因: int = 移动结果.结果类型.被中断) -> void:
	if not is_instance_valid(单位):
		_单位数据.erase(单位)
		return

	var data = _单位数据.get(单位)
	# SLOT_LOCKED：保留在追踪中，仅停止速度
	if data and data.slot_state == SLOT_LOCKED:
		单位.velocity = Vector2.ZERO
		_发送结果(单位, 原因)
		return

	_单位数据.erase(单位)
	单位.velocity = Vector2.ZERO
	_发送结果(单位, 原因)


## 检查单位是否在移动中
func 是否在移动(单位: Node2D) -> bool:
	return 单位 in _单位数据


## 检查单位是否处于 SLOT_LOCKED 状态
func 是否是槽锁定(单位: Node2D) -> bool:
	var data = _单位数据.get(单位)
	return data != null and data.slot_state == SLOT_LOCKED


# ============================================================
# 核心：解析单个单位的 MovementIntent
# ============================================================

func _解析单位(unit: Node2D, delta: float) -> void:
	var intent: MovementIntent = unit.移动意图
	if not intent or not intent.is_valid():
		return

	# --- 获取/创建单位状态数据 ---
	var data = _单位数据.get(unit)
	if not data:
		data = SolverUnitData.new()
		_单位数据[unit] = data
		data.上次意图类型 = intent.type
		data.策略 = _构建策略(intent)
		data.上次位置 = unit.global_position

	# --- 意图类型变更 → 重建策略 ---
	if intent.type != data.上次意图类型:
		data.策略 = _构建策略(intent)
		data.上次意图类型 = intent.type
		data.已到达 = false
		data.slot_state = SLOT_NONE
		data.卡死计时 = 0.0
		data.卡死计数 = 0
		data.回退中 = false
		data.已到达 = false

	# 转换为移动请求（供策略 API 使用）
	var 请求: 移动请求 = _意图转请求(unit, intent)
	if not 请求:
		return

	# ============================================================
	# ⭐ SLOT_LOCKED：仅 anchor return + 强制 idle 动画
	# ============================================================
	if data.slot_state == SLOT_LOCKED:
		var dist_to_anchor = unit.global_position.distance_to(data.anchor_position)
		if dist_to_anchor > 2.0:
			var return_dir = (data.anchor_position - unit.global_position).normalized()
			var 最大速度: float = unit.最大速度 if "最大速度" in unit else 350.0
			var return_speed = minf(dist_to_anchor * 0.5, 最大速度 * 0.25)
			unit.velocity = return_dir * return_speed
		else:
			unit.velocity = Vector2.ZERO

		# 强制 idle 动画
		if unit.has_method("_切换动画"):
			unit._切换动画("待机")
		return

	# ── 已到达 → 保持静止，从系统退出 ──
	if data.已到达:
		unit.velocity = Vector2.ZERO
		_单位数据.erase(unit)
		return

	# ── 到达检测 ──
	if data.策略.是否已到达(unit, 请求):
		if data.slot_state == MOVING_TO_SLOT:
			# 队形单位到达 → SLOT_LOCKED（不移除，继续跟踪）
			data.slot_state = SLOT_LOCKED
			var slot_target = 请求.目标位置 + 请求.队形偏移
			if 队形系统.实例 and 队形系统.实例.是否在队形中(unit):
				slot_target = 队形系统.实例.获取单位目标(unit)
			data.anchor_position = slot_target
			unit.velocity = Vector2.ZERO
			_发送结果(unit, 移动结果.结果类型.已到达)
			if unit.has_method("_切换动画"):
				unit._切换动画("待机")
			return
		else:
			# 非队形单位到达 → 正常移除
			data.已到达 = true
			unit.velocity = Vector2.ZERO
			_发送结果(unit, 移动结果.结果类型.已到达)
			if unit.has_method("_切换动画"):
				unit._切换动画("待机")
			return

	# ============================================================
	# ⭐ 收集所有建议力（Provider + 内联）
	# ============================================================

	var provider_forces = _收集Provider力(unit, data, intent, 请求)
	var inline_forces = _构建内联力(unit, data, intent, 请求)
	var all_forces = provider_forces + inline_forces
	_当前帧力 = all_forces

	# ============================================================
	# ⭐ 融合 — MovementForceFusion（Phase 4）
	# ============================================================
	# Solver 不再包含具体融合规则。
	# 所有 weight × priority × strength 规则集中在 Fusion 层。
	# 此处只做：收集 → 融合 → velocity（唯一写入点）
	# ============================================================

	var 最大速度: float = unit.最大速度 if "最大速度" in unit else 350.0
	var fusion_result = _force_pipeline.process(all_forces, delta, 最大速度)
	var 最终速度 = fusion_result.direction * fusion_result.strength

	# ============================================================
	# 卡死检测（与 运动服务._检测卡死 一致）
	# ============================================================

	if _检测卡死(unit, data, 最终速度, delta):
		# 回退阶段：反向移动 0.3 秒
		if not data.回退中:
			data.回退计时 = 0.0
		data.回退计时 += delta
		data.回退中 = true

		if data.回退计时 < 0.3:
			var 后退方向 = (data.上次位置 - unit.global_position).normalized()
			if 后退方向 == Vector2.ZERO:
				后退方向 = Vector2(0, 1)
			最终速度 = 后退方向 * (最大速度 * 0.5)
		else:
			data.回退中 = false
			data.卡死计数 += 1

			if data.卡死计数 >= 最大卡死放弃:
				_单位数据.erase(unit)
				unit.velocity = Vector2.ZERO
				_发送结果(unit, 移动结果.结果类型.卡死)
				if unit.has_method("_切换动画"):
					unit._切换动画("待机")
				return

			if is_instance_valid(流场管理器.实例):
				流场管理器.实例.标记障碍变更()
	else:
		if data.回退中:
			data.回退中 = false
		data.卡死计数 = 0
		data.卡死计时 = 0.0

	# ★ 写入 velocity（唯一写入点）
	unit.velocity = 最终速度
	data.上次位置 = unit.global_position


# ============================================================
# 工具方法
# ============================================================

## 意图 → 移动请求 转换（复用现有策略 API）
func _意图转请求(unit: Node2D, intent: MovementIntent) -> 移动请求:
	var 请求 = 移动请求.new()

	match intent.type:
		MovementIntent.IntentType.MOVE_TO:
			请求.类型 = 移动请求.移动类型.前往位置
			请求.目标位置 = intent.target_position

		MovementIntent.IntentType.PURSUE:
			请求.类型 = 移动请求.移动类型.追击敌人
			请求.目标实体 = intent.target_unit
			请求.追击上限 = intent.pursue_max_range

		MovementIntent.IntentType.ATTACK_MOVE:
			请求.类型 = 移动请求.移动类型.移动攻击
			请求.目标位置 = intent.target_position

		MovementIntent.IntentType.SKILL_DRIVEN:
			请求.类型 = 移动请求.移动类型.技能驱动
			请求.目标位置 = intent.target_position
			请求.额外数据 = intent.extra_data

		_:
			return null

	请求.停止距离 = intent.stop_distance
	请求.队形偏移 = intent.formation_offset
	请求.队形槽位 = intent.formation_slot

	return 请求


## 构建移动策略（与 运动服务._构建策略 一致）
func _构建策略(intent: MovementIntent) -> 移动策略:
	match intent.type:
		MovementIntent.IntentType.MOVE_TO:
			return 前往位置移动.new()
		MovementIntent.IntentType.PURSUE:
			return 追击目标移动.new()
		MovementIntent.IntentType.ATTACK_MOVE:
			return 移动攻击移动.new()
		MovementIntent.IntentType.SKILL_DRIVEN:
			return 技能驱动移动.new()
		_:
			return 前往位置移动.new()




# ============================================================
# 内联建议力构建（Phase 7 — 分离力已迁移至 SeparationForceProvider）
# ============================================================
#
# 当前仍以内联形式计算的力：
#   ① 路径力（策略方向 × 速度）
#
# 已 Provider 化：
#   ② 队形力 → FormationForceProvider
#   ③ 分离力 → SeparationForceProvider
#
# 每个力被包装为 MovementForce，通过 Fusion.solve() 统一融合。
#
# ============================================================

## 构建内联建议力（尚未 Provider 化的力）
## @param unit    目标单位
## @param data    单位状态数据
## @param intent  当前 MovementIntent
## @param 请求    转换后的移动请求
## @return        建议力数组
func _构建内联力(unit: Node2D, data: SolverUnitData, intent: MovementIntent,
				 请求: 移动请求) -> Array[MovementForce]:
	var forces: Array[MovementForce] = []

	# ① 路径力 — 策略计算的速度（主驱动力）
	var 路径速度 = data.策略.计算速度(unit, 请求)
	var 路径方向 = 路径速度.normalized() if 路径速度.length_squared() > 0.01 else Vector2.ZERO

	if 路径方向 != Vector2.ZERO:
		var pf = MovementForce.new()
		pf.source_name = "Path"
		pf.force_type = MovementForce.ForceType.GOAL
		# Phase 7.4: Direction continuity smoothing
		# Blend with last frame direction to prevent frame-to-frame flip
		if data.last_dir != Vector2.ZERO and 路径方向 != Vector2.ZERO:
			路径方向 = 路径方向.lerp(data.last_dir, 0.3).normalized()
		data.last_dir = 路径方向

		pf.direction = 路径方向
		pf.strength = 路径速度.length()
		pf.weight = 1.0
		pf.priority = 0
		forces.append(pf)

	# ③ 分离力 — 已迁移至 SeparationForceProvider（2026-07-05）
	#     旧内联代码（代替代保持参考，已删除）：
	#       if 避障系统.实例:
	#           var 周围单位 = _获取周围单位(unit)
	#           var 分离力向量 = 避障系统.实例.计算让路修正(unit, 周围单位, 路径方向)
	#           if 分离力向量.length_squared() > 0.0001:
	#               → MovementForce(AVOIDANCE, weight=0.4)

	return forces


# ============================================================
# Force Provider 接口（Phase 3）
# ============================================================

## 收集所有 Provider 的建议力
## @param unit    目标单位
## @param data    单位状态数据
## @param intent  当前 MovementIntent
## @param 请求    转换后的移动请求
## @return        建议力数组（空表示无 Provider 激活）
func _收集Provider力(unit: Node2D, data: SolverUnitData, intent: MovementIntent,
					请求: 移动请求) -> Array[MovementForce]:
	var forces: Array[MovementForce] = []

	# 构建 Provider context
	var context: Dictionary = _构建Provider上下文(unit, data, intent, 请求)

	for provider in _providers:
		if not provider.is_active(unit, context):
			continue
		var force = provider.calculate_force(unit, context)
		if force and not force.is_zero():
			forces.append(force)

	return forces


## 构建 Provider 上下文字典
## 传入所有 Provider 可能需要的环境信息
func _构建Provider上下文(unit: Node2D, data: SolverUnitData,
						intent: MovementIntent, 请求: 移动请求) -> Dictionary:
	var ctx: Dictionary = {}
	ctx["unit"] = unit
	ctx["intent"] = intent
	ctx["request"] = 请求
	ctx["strategy"] = data.策略

	# 流场目标（供 FlowFieldForceProvider 使用）
	if data.策略:
		ctx["flow_field_target"] = data.策略.获取流场目标(请求, unit)

	# Slot 状态
	ctx["slot_state"] = data.slot_state
	ctx["anchor_position"] = data.anchor_position

	return ctx


## 发送移动完成结果（与 运动服务._发送结果 一致）
func _发送结果(单位: Node2D, 原因: int) -> void:
	if not is_instance_valid(单位):
		return

	var 最终原因 = 原因
	if 原因 == 移动结果.结果类型.被中断:
		# 追击目标丢失 → 用目标丢失类型
		var data = _单位数据.get(单位)
		if data and data.上次意图类型 == MovementIntent.IntentType.PURSUE:
			if not is_instance_valid(单位.攻击目标 if "攻击目标" in 单位 else null):
				最终原因 = 移动结果.结果类型.目标丢失

	var 结果 = 移动结果.new()
	结果.结果 = 最终原因
	移动完成.emit(单位, 结果)


## 卡死检测（与 运动服务._检测卡死 一致）
func _检测卡死(unit: Node2D, data: SolverUnitData, 期望速度: Vector2, delta: float) -> bool:
	var 期望 = 期望速度.length()
	var 实际 = unit.velocity.length()

	if 期望 < 卡死速度阈值:
		data.卡死计时 = 0.0
		return false

	if 实际 < 卡死速度阈值:
		data.卡死计时 += delta
		if data.卡死计时 >= 卡死超时:
			data.卡死计时 = 0.0
			return true
	else:
		data.卡死计时 = 0.0

	return false


## 清理无效/已释放的单位
func _清理死单位() -> void:
	var 待移除: Array = []
	for unit in _单位数据.keys():
		if not is_instance_valid(unit):
			待移除.append(unit)
	for unit in 待移除:
		_单位数据.erase(unit)
