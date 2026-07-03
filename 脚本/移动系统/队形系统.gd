extends Node
## 队形系统 — 管理单位组的阵型槽位与偏移
##
## ⭐ 核心理念：
##   槽位偏移在创建时锁定，永不旋转变化。
##   slot_target = group_target + fixed_slot_offset   （路径规划 + 队形力）
##   队形力使用固定 slot_target，不用质心（防 centroid shift 与 path 打架）
##
##   三种力的 RTS 原则：
##     path force + formation force x 0.6 + separation force x 0.4
##
## ⚠ 关键约束：
##   - slot_offset 只分配一次，绝不每帧变化
##   - 不旋转偏移（rotated 产生 jitter）
##   - 到达单位不参与队形力（由运动服务管理）
##   - 队形力只能温柔修正，不能主导移动

func _diag() -> bool: return 调试配置.DEBUG_FORMATION

static var 实例: Node = null

## debug 节流（每 0.5 秒输出一次槽位概况）
var _debug_timer: float = 0.0
const DEBUG_INTERVAL: float = 0.5


## 阵型枚举
enum 阵型类型 {
	横排,     # 一字排开
	方阵,     # 矩形方阵（自动计算行列，列数上限 MAX_COLUMNS）
	楔形,     # V 字箭头
	纵队,     # 一列纵队
}

## 方阵最大列数：超过此值则自动加行，防队形过宽
const MAX_COLUMNS: int = 8


## 单个槽位（偏移创建即锁定，永不变化）
class 槽位:
	var 单位: Node2D
	var 槽位ID: int
	## ⭐ 固定偏移：相对于组目标的偏移量，创建后绝不变化
	var 偏移: Vector2
	var 阵型: int

	func _init(u: Node2D, id: int, off: Vector2, ft: int):
		单位 = u; 槽位ID = id; 偏移 = off; 阵型 = ft


## 队形组
class 队形组:
	var 组ID: int
	var 槽位列表: Array[槽位] = []
	## 组的目标位置（玩家点击点，各单位的最终目标 = 此点 + 槽位偏移）
	var 目标中心: Vector2
	## 行列数（debug）
	var 列数: int = 0
	var 行数: int = 0

	func _init(id: int):
		组ID = id


## 组 ID 自增
var _下一个组ID: int = 0
## 组字典: group_id -> 队形组
var _组字典: Dictionary = {}
## 单位 -> 组 映射
var _单位所属组: Dictionary = {}


func _enter_tree() -> void:
	实例 = self

func _exit_tree() -> void:
	if 实例 == self:
		实例 = null


# ============================================================
# 公开 API
# ============================================================

## 创建队形组
## @param 单位列表  参与队形的所有单位
## @param 目标中心  队伍的目标移动点
## @param 阵型      阵型类型
## @param 间距      单位间间距（px）
## @return          组ID
func 创建队形(单位列表: Array[Node2D], 目标中心: Vector2,
			 阵型: int = 阵型类型.横排, 间距: float = 24.0) -> int:
	var 组 = 队形组.new(_下一个组ID)
	_下一个组ID += 1
	组.目标中心 = 目标中心

	# 过滤无效单位
	var 有效: Array[Node2D] = []
	for u in 单位列表:
		if is_instance_valid(u):
			有效.append(u)

	var 总数 = 有效.size()

	# 计算行列数（如果方阵）
	if 阵型 == 阵型类型.方阵:
		组.列数 = ceili(sqrt(总数))
		组.行数 = ceili(float(总数) / 组.列数)

	for i in 总数:
		# ⭐ 槽位偏移创建即锁定，永不旋转
		var 偏移 = _计算槽位偏移(i, 总数, 阵型, 间距)
		组.槽位列表.append(槽位.new(有效[i], i, 偏移, 阵型))
		_单位所属组[有效[i]] = 组

	_组字典[组.组ID] = 组

	if _diag():
		var colrow = ""
		if 组.列数 > 0:
			colrow = " columns=%d rows=%d" % [组.列数, 组.行数]
		print("[FORM-SLOTS] group=", 组.组ID, " count=", 总数, colrow, " spacing=", 间距, " type=", 阵型)
		for 槽 in 组.槽位列表:
			var 理想 = 目标中心 + 槽.偏移
			print("[FORM-IDEAL] unit=", 槽.单位.name, " slot=", 槽.槽位ID, " ideal=(", 理想.x, ",", 理想.y, ")")

	return 组.组ID


## 更新组的目标位置
func 更新组目标(组ID: int, 新目标: Vector2) -> void:
	var 组 = _组字典.get(组ID)
	if not 组:
		return
	组.目标中心 = 新目标


## 获取单位所属组 ID（-1 表示无队形）
func 获取单位组ID(单位: Node2D) -> int:
	var 组 = _单位所属组.get(单位)
	return 组.组ID if 组 else -1


## 获取组的原始目标中心（不含槽位偏移，流场导航用）
## 所有单位共享同一组目标 -> 流场只需生成一次
func 获取组目标(组ID: int) -> Vector2:
	var 组 = _组字典.get(组ID)
	return 组.目标中心 if 组 else Vector2.ZERO


## ⭐ 获取单位的最终目标位置（路径规划 + 队形力用）
##   返回 = 组目标 + 固定槽位偏移（不旋转，不变化）
##   对应 RTS 原则：slot binding（结构）
func 获取单位目标(单位: Node2D) -> Vector2:
	var 组 = _单位所属组.get(单位)
	if not 组:
		return Vector2.ZERO

	var 槽 = _查找槽位(组, 单位)
	if not 槽:
		return 组.目标中心

	# ⭐ 固定偏移，绝不旋转
	return 组.目标中心 + 槽.偏移


## ⭐ 获取单位的实时队形位置（旧版，保留兼容）
##   返回 = 组当前质心 + 固定槽位偏移
##   ⚠ 不应用于队形力计算（会与 path_velocity 打架）
func 获取单位实时目标(单位: Node2D) -> Vector2:
	var 组 = _单位所属组.get(单位)
	if not 组:
		return Vector2.ZERO

	var 槽 = _查找槽位(组, 单位)
	if not 槽:
		return 单位.global_position

	var 组中心 = _计算组中心(组)
	return 组中心 + 槽.偏移


## ⭐ 计算队形力 — 将单位温柔拉向固定 slot_target
## 这是三种力之一，权重要求 x0.6
##
## 队形力只应是温柔修正（最大 max_speed * 0.45），不能主导移动。
## 死区内 force=0，防与 path_velocity 打架。
##
## @return  队形修正向量（已限幅，单位 px/s）
func 计算队形力(单位: Node2D) -> Vector2:
	var 组 = _单位所属组.get(单位)
	if not 组:
		return Vector2.ZERO

	var 槽 = _查找槽位(组, 单位)
	if not 槽:
		return Vector2.ZERO

	# ⭐ 使用固定 slot_target（group_target + offset），不用质心
	#   避免 centroid shift 导致的力与 path velocity 打架
	var 理想位置 = 获取单位目标(单位)
	var 偏移向量 = 理想位置 - 单位.global_position
	var 距离 = 偏移向量.length()

	# 死区：足够接近时 force=0，防震荡
	const 死区: float = 8.0
	if 距离 < 死区:
		return Vector2.ZERO

	# 温柔修正力，最大 max_speed * 0.45
	var 移动速度: float = 单位.移动速度 if "移动速度" in 单位 else 单位.最大速度 if "最大速度" in 单位 else 200.0
	const 增益: float = 0.6
	var 最大力: float = 移动速度 * 0.45
	var 强度 = minf(距离 * 增益, 最大力)
	var 力 = 偏移向量.normalized() * 强度

	if _diag() and 力.length() > 1.0:
		print("[FORM-FORCE] <", 单位.name, "> dist=", 距离, " force=", 力.length(), " ideal=", 理想位置)

	return 力


## 移除单位（死亡/离队时调用）
func 移除单位(单位: Node2D) -> void:
	var 组 = _单位所属组.get(单位)
	if not 组:
		return

	组.槽位列表 = 组.槽位列表.filter(func(s): return s.单位 != 单位)
	_单位所属组.erase(单位)

	# 组空 -> 自动销毁
	if 组.槽位列表.is_empty():
		_组字典.erase(组.组ID)
		if _diag():
			print("[FORM] 组ID=", 组.组ID, " 空，自动销毁")


## 销毁整个队形组
func 销毁组(组ID: int) -> void:
	var 组 = _组字典.get(组ID)
	if not 组:
		return

	for 槽 in 组.槽位列表:
		_单位所属组.erase(槽.单位)
	_组字典.erase(组ID)

	if _diag():
		print("[FORM] 销毁组 组ID=", 组ID)


## 获取当前活跃的队形组数量
func 获取活跃组数() -> int:
	return _组字典.size()

## 检查单位是否在队形中
func 是否在队形中(单位: Node2D) -> bool:
	return 单位 in _单位所属组

## 获取组行列数（debug）
func 获取组行列(组ID: int) -> Dictionary:
	var 组 = _组字典.get(组ID)
	if not 组:
		return {}
	return {"columns": 组.列数, "rows": 组.行数}


# ============================================================
# 调试（每 0.5 秒输出槽位概况打印）
# ============================================================

func _physics_process(delta: float) -> void:
	_debug_timer += delta
	if _debug_timer < DEBUG_INTERVAL:
		return
	_debug_timer = 0.0

	if not _diag():
		return

	# 低频输出所有活跃组的理想位置分布
	for 组ID in _组字典:
		var 组 = _组字典[组ID] as 队形组
		if not 组:
			continue

		var col_info = ""
		if 组.列数 > 0:
			col_info = " columns=%d rows=%d" % [组.列数, 组.行数]

		print("[FORM-SLOTS] group=", 组ID, " count=", 组.槽位列表.size(), col_info)

		for 槽 in 组.槽位列表:
			if not is_instance_valid(槽.单位):
				continue
			var 理想 = 获取单位目标(槽.单位)
			print("[FORM-IDEAL] unit=", 槽.单位.name, " slot=", 槽.槽位ID, " ideal=(", 理想.x, ",", 理想.y, ")")


# ============================================================
# 内部
# ============================================================

## 计算槽位偏移（静态方法，创建时调一次）
## @param 索引  槽位序号（0-index）
## @param 总数  总单位数
## @param 阵型  阵型类型
## @param 间距  单位间距
static func _计算槽位偏移(索引: int, 总数: int, 阵型: int, 间距: float) -> Vector2:
	match 阵型:
		阵型类型.横排:
			# 一字横排，居中
			var 总宽 = (总数 - 1) * 间距
			return Vector2(-总宽 / 2.0 + 索引 * 间距, 0.0)

		阵型类型.方阵:
			# 自动计算行列，尽量接近正方形
			# ⭐ Y 居中对齐，非仅向下延伸
			var 列数 = ceili(sqrt(总数))
			列数 = mini(列数, MAX_COLUMNS)
			var 行数 = ceili(float(总数) / 列数)
			var 行 = 索引 / 列数
			var 列 = 索引 % 列数
			var 总宽 = (列数 - 1) * 间距
			var 总高 = (行数 - 1) * 间距
			return Vector2(-总宽 / 2.0 + 列 * 间距, -总高 / 2.0 + 行 * 间距)

		阵型类型.楔形:
			# V 字
			var 行 = 索引 / 3
			var 列 = 索引 % 3
			var 半宽 = (行 + 1) * 间距 * 0.5
			match 列:
				0: return Vector2(-半宽, 行 * 间距)
				1: return Vector2(半宽, 行 * 间距)
				2: return Vector2(0.0, 行 * 间距)
			return Vector2.ZERO

		阵型类型.纵队:
			return Vector2(0.0, 索引 * 间距)

		_:
			return Vector2.ZERO


## 查找单位在组中的槽位
func _查找槽位(组: 队形组, 单位: Node2D) -> 槽位:
	for 槽 in 组.槽位列表:
		if 槽.单位 == 单位:
			return 槽
	return null


## 计算组当前质心
func _计算组中心(组: 队形组) -> Vector2:
	var 和 = Vector2.ZERO
	var 计数 = 0

	for 槽 in 组.槽位列表:
		if is_instance_valid(槽.单位):
			和 += 槽.单位.global_position
			计数 += 1

	if 计数 == 0:
		return 组.目标中心

	return 和 / 计数


## 获取组所有理想位置（调试用）
func 获取所有理想位置(组ID: int) -> Array[Vector2]:
	var 组 = _组字典.get(组ID)
	if not 组:
		return []

	var 结果: Array[Vector2] = []
	for 槽 in 组.槽位列表:
		if is_instance_valid(槽.单位):
			结果.append(获取单位目标(槽.单位))
	return 结果
