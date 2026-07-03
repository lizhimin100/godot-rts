extends Node

## 命令管理器 — 统一命令入口
## 方案B：外部管理队形偏移，CommandManager 全权负责
##
## ⚠ 队形偏移在命令时一次性计算完成（禁止每帧重新生成）
##
## ⭐ 新队形系统：
##   多单位移动时自动调用 队形系统.创建队形()
##   各单位的 slot 偏移锁定，不再每帧旋转
##   ⭐ slot_id = 有效单位索引（不是原始数组索引！）

func _diag() -> bool: return 调试配置.DEBUG_MOVE

static var 实例: 命令管理器 = null

enum 命令类型 {
	无, 移动, 攻击, 停止, 驻守, 巡逻, 移动攻击,
}

class 命令数据:
	var 类型: int
	var 目标位置: Vector2
	var 目标单位: Node2D

	func _init(type: int, pos: Vector2 = Vector2.ZERO, target: Node2D = null):
		类型 = type
		目标位置 = pos
		目标单位 = target


func _enter_tree() -> void:
	实例 = self


func _exit_tree() -> void:
	if 实例 == self:
		实例 = null


func 发出命令(units: Array, type: int, pos: Vector2 = Vector2.ZERO, target: Node2D = null) -> void:
	if units.is_empty():
		if _diag(): print("[CMD] 发出命令 type=", type, " 失败：单位列表为空")
		return

	if _diag(): print("[CMD] 发出命令 type=", type, " 单位数=", units.size(), " 有效=", units.filter(func(u): return is_instance_valid(u)).size(), " 位置=", pos)

	var cmd: 命令数据 = 命令数据.new(type, pos, target)

	# ⭐ 多单位队形移动：所有单位必须分配 slot_offset + slot_id + 加入队形系统
	if type == 命令类型.移动 and units.size() > 1:
		var 有效单位: Array[Node2D] = []
		for i in range(units.size()):
			var u = units[i]
			if is_instance_valid(u):
				有效单位.append(u)

		# ⭐ 集成新队形系统：为所有有效单位创建队形组
		if 队形系统.实例:
			# 先从旧队形中移除所有单位
			for u in 有效单位:
				队形系统.实例.移除单位(u)
			# 创建新队形组（槽位偏移创建即锁定）
			var 组ID = 队形系统.实例.创建队形(有效单位, pos, 队形系统.阵型类型.方阵, 48.0)
			if _diag():
				print("[CMD]  创建队形组 组ID=", 组ID, " 单位数=", 有效单位.size(), " 目标=", pos)

	# ⭐ 单单位移动：强制脱离旧队形，清空所有队形数据
	if type == 命令类型.移动 and units.size() == 1:
		var u = units[0]
		if is_instance_valid(u) and 队形系统.实例:
			if 队形系统.实例.是否在队形中(u):
				print("[FORM-LEAVE] unit=", u.name, " reason=single_command")
			队形系统.实例.移除单位(u)
			# 清空待处理的队形数据，防止新请求继承旧槽位
			if u.has_method("设队形"):
				u.设队形(Vector2.ZERO)
			if u.has_method("设队形槽位"):
				u.设队形槽位(-1)
			print("[CMD] single move target=(", pos.x, ",", pos.y, ")")

	# ⭐ 第二遍循环：设置 pending 数据 + 应用命令
	#   slot_id = 有效单位索引（匹配队形系统内部的槽位索引）
	var 有效索引: int = 0
	for i in range(units.size()):
		var unit = units[i]
		if not is_instance_valid(unit):
			if _diag(): print("[CMD]  跳过无效单位 index=", i)
			continue

		if _diag(): print("[CMD]  应用命令到: ", unit.name, " type=", type)

		# 多单位移动：在应用命令前先设置队形偏移
		if type == 命令类型.移动 and units.size() > 1:
			# ⭐ 从队形系统获取 slot_offset（与 _计算槽位偏移 一致）
			var slot_offset = _获取队形偏移(unit, 有效索引, units.size())
			if _diag(): print("[CMD]  设置队形: ", unit.name, " slot_id=", 有效索引, " offset=", slot_offset)
			if unit.has_method("设队形"):
				unit.设队形(slot_offset)
			if unit.has_method("设队形槽位"):
				# ⭐ 使用有效索引（不是原始数组索引 i）
				unit.设队形槽位(有效索引)
			有效索引 += 1

		_应用命令到单位(unit, cmd)

	# ⭐ 验收：多单位移动必须所有单位都有 slot_id
	if type == 命令类型.移动 and units.size() > 1 and 队形系统.实例:
		_输出队形分配(units)


func 命令移动(units: Array, pos: Vector2) -> void:
	发出命令(units, 命令类型.移动, pos)


func 命令攻击移动(units: Array, pos: Vector2) -> void:
	发出命令(units, 命令类型.移动攻击, pos)


func 命令攻击(units: Array, target: Node2D) -> void:
	发出命令(units, 命令类型.攻击, Vector2.ZERO, target)


func 命令停止(units: Array) -> void:
	发出命令(units, 命令类型.停止)


func 命令驻守(units: Array) -> void:
	发出命令(units, 命令类型.驻守)


func 命令巡逻(units: Array, pos: Vector2) -> void:
	发出命令(units, 命令类型.巡逻, pos)


func 处理右键点击(点击位置: Vector2, 点击目标: Node2D) -> void:
	var selected: Array = 选择管理器.获取选中()
	if selected.is_empty():
		return

	if 点击目标 and is_instance_valid(点击目标):
		var first = selected[0]
		if is_instance_valid(first) and first.has_method("是敌对"):
			if first.是敌对(点击目标):
				命令攻击(selected, 点击目标)
				return

	命令移动(selected, 点击位置)


func _应用命令到单位(unit, cmd: 命令数据) -> void:
	if not is_instance_valid(unit):
		if _diag(): print("[CMD]  ⚠ 单位无效")
		return

	if unit.has_method("设置命令"):
		if _diag(): print("[CMD]  调用 ", unit.name, ".设置命令(type=", cmd.类型, ")")
		unit.设置命令(cmd.类型, cmd.目标位置, cmd.目标单位)
		return

	if "当前命令" in unit:
		unit.当前命令 = cmd.类型
		if _diag(): print("[CMD]  直接设置 ", unit.name, ".当前命令 = ", cmd.类型)
	if "目标位置" in unit and cmd.目标位置 != Vector2.ZERO:
		unit.目标位置 = cmd.目标位置
	if "攻击目标" in unit and cmd.目标单位:
		unit.攻击目标 = cmd.目标单位

	if cmd.类型 == 命令类型.停止 and unit.has_method("命令停止"):
		unit.命令停止()
	if cmd.类型 != 命令类型.攻击 and unit.has_method("取消攻击"):
		unit.取消攻击()


## 从队形系统获取 slot_offset
## 匹配队形系统._计算槽位偏移的横排默认布局（与 创建队形 对齐）
func _获取队形偏移(unit: Node2D, slot_id: int, total: int) -> Vector2:
	if 队形系统.实例 and 队形系统.实例.是否在队形中(unit):
		var slot_target = 队形系统.实例.获取单位目标(unit)
		var group_target = 队形系统.实例.获取组目标(队形系统.实例.获取单位组ID(unit))
		return slot_target - group_target
	# fallback：使用与队形系统 _计算槽位偏移 方阵相同的公式
	return _计算方阵偏移(slot_id, total, 48.0)


## 计算方阵偏移（镜像队形系统._计算槽位偏移）
func _计算方阵偏移(索引: int, 总数: int, 间距: float) -> Vector2:
	var 列数 = ceili(sqrt(总数))
	const MAX_COLUMNS: int = 8
	列数 = mini(列数, MAX_COLUMNS)
	var 行数 = ceili(float(总数) / 列数)
	var 行 = 索引 / 列数
	var 列 = 索引 % 列数
	var 总宽 = (列数 - 1) * 间距
	var 总高 = (行数 - 1) * 间距
	return Vector2(-总宽 / 2.0 + 列 * 间距, -总高 / 2.0 + 行 * 间距)


## 验收：多单位移动后验证所有单位都有队形数据
func _输出队形分配(units: Array) -> void:
	if not 队形系统.实例:
		return
	var 有效计数: int = 0
	var 问题单位: Array[String] = []
	for unit in units:
		if not is_instance_valid(unit):
			continue
		有效计数 += 1
		if not 队形系统.实例.是否在队形中(unit):
			问题单位.append(unit.name + "(不在队形系统)")
		elif unit._pending_formation_slot < 0:
			问题单位.append(unit.name + "(slot_id=-1)")

	if 有效计数 <= 1:
		return

	if 问题单位.size() > 0:
		for msg in 问题单位:
			push_error("[FORM-ERROR] " + msg + " in group move")
	else:
		# 输出队形分配概况（从队形系统读取，不用 _pending_formation_slot）
		print("[FORM-ASSIGN] group count=", 有效计数)
		for unit in units:
			if not is_instance_valid(unit):
				continue
			if 队形系统.实例.是否在队形中(unit):
				var target = 队形系统.实例.获取单位目标(unit)
				var 组ID = 队形系统.实例.获取单位组ID(unit)
				print("[FORM-ASSIGN]  ", unit.name,
					  " target=(", int(target.x), ",", int(target.y), ")")
			else:
				print("[FORM-ASSIGN]  ", unit.name, " (不在队形系统 ❌)")
