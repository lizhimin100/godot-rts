extends Node

## 命令管理器 — 统一命令入口
## 方案B：外部管理队形偏移，CommandManager 全权负责
##
## ⚠ 队形偏移在命令时一次性计算完成（禁止每帧重新生成）

const DIAG: bool = true

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
		if DIAG: print("[CMD] 发出命令 type=", type, " 失败：单位列表为空")
		return

	if DIAG: print("[CMD] 发出命令 type=", type, " 单位数=", units.size(), " 有效=", units.filter(func(u): return is_instance_valid(u)).size(), " 位置=", pos)

	var cmd: 命令数据 = 命令数据.new(type, pos, target)

	# 预先计算所有单位的队形偏移（一次性，禁止每帧重新生成）
	var offsets: Dictionary = {}
	if type == 命令类型.移动 and units.size() > 1:
		for i in range(units.size()):
			var u = units[i]
			if is_instance_valid(u):
				offsets[u] = UnitFormation.get_slot_offset(i, units.size())
			# ① 记录阵型日志
			UnitFormation.获取日志().记录阵型分配(pos, units, UnitFormation.DEFAULT_SPACING)

	for i in range(units.size()):
		var unit = units[i]
		if not is_instance_valid(unit):
			if DIAG: print("[CMD]  跳过无效单位 index=", i)
			continue

		if DIAG: print("[CMD]  应用命令到: ", unit.name, " type=", type)

		# 多单位移动：在应用命令前先设置队形偏移
		# ⭐ 必须在 _应用命令到单位 之前，否则信号回调会清除 当前移动请求
		if type == 命令类型.移动 and offsets.has(unit):
			if DIAG: print("[CMD]  设置队形偏移: ", unit.name, " offset=", offsets[unit])
			if unit.has_method("设队形"):
				unit.设队形(offsets[unit])
			if unit.has_method("设队形槽位"):
				unit.设队形槽位(i)

		_应用命令到单位(unit, cmd)


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
		if DIAG: print("[CMD]  ⚠ 单位无效")
		return

	if unit.has_method("设置命令"):
		if DIAG: print("[CMD]  调用 ", unit.name, ".设置命令(type=", cmd.类型, ")")
		unit.设置命令(cmd.类型, cmd.目标位置, cmd.目标单位)
		return

	if "当前命令" in unit:
		unit.当前命令 = cmd.类型
		if DIAG: print("[CMD]  直接设置 ", unit.name, ".当前命令 = ", cmd.类型)
	if "目标位置" in unit and cmd.目标位置 != Vector2.ZERO:
		unit.目标位置 = cmd.目标位置
	if "攻击目标" in unit and cmd.目标单位:
		unit.攻击目标 = cmd.目标单位

	if cmd.类型 == 命令类型.停止 and unit.has_method("命令停止"):
		unit.命令停止()
	if cmd.类型 != 命令类型.攻击 and unit.has_method("取消攻击"):
		unit.取消攻击()
