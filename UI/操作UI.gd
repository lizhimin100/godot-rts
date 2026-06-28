extends Control
class_name 操作UI

## 操作UI — RTS 选中单位命令面板
## 显示当前选中单位的可用操作按钮

# 全局引用（兼容脚本热更新场景）
static var _全局实例: 操作UI = null

var 当前选中单位 := []
var _当前选中建筑 := false
var _当前选中城堡 := false
var _当前建筑节点: Node = null

@onready var 操作面板: PanelContainer = $操作面板
@onready var 按钮行: HBoxContainer = $操作面板/按钮行
@onready var 停止按钮: Button = $操作面板/按钮行/停止
@onready var 驻守按钮: Button = $操作面板/按钮行/驻守
@onready var 巡逻按钮: Button = $操作面板/按钮行/巡逻
@onready var 攻击移动按钮: Button = $操作面板/按钮行/攻击移动
@onready var 训练行: HBoxContainer = $操作面板/训练行
@onready var 建筑名称标签 = $操作面板/建筑名称标签
@onready var 状态标签 = $操作面板/状态标签


func _enter_tree() -> void:
	_全局实例 = self
	add_to_group("操作UI")

func _exit_tree() -> void:
	if _全局实例 == self:
		_全局实例 = null

## 供外部获取实例（兼容热更新）
static func 获取实例() -> 操作UI:
	return _全局实例




func _ready() -> void:
	print("🖥️ 操作UI _ready() 节点就绪")
	操作面板.visible = false
	if 训练行:
		训练行.visible = false
		print("🖥️   训练行已隐藏")
	else:
		print("⚠️ 操作UI: 训练行节点未找到!")
	if 建筑名称标签:
		建筑名称标签.visible = false
	if 状态标签:
		状态标签.visible = false


func _on_unit_selected(unit: Node) -> void:
	_on_selection_changed([unit])


## 选中变更 — 接受选中单位数组（多选支持）
func _on_selection_changed(units: Array) -> void:
	if units.is_empty():
		_clear_selection()
		return

	当前选中单位 = units.duplicate()
	操作面板.visible = true
	_当前选中建筑 = false
	_当前选中城堡 = false
	_当前建筑节点 = null

	# 隐藏所有子面板
	按钮行.visible = false
	if 训练行:
		训练行.visible = false
	if 建筑名称标签:
		建筑名称标签.visible = false
	_隐藏状态标签()

	# 检测选中单位类型（以第一个为主）
	var unit = units[0]
	if not is_instance_valid(unit):
		return

	if unit.is_in_group("建筑"):
		_当前选中建筑 = true
		_当前建筑节点 = unit
		if unit is 城堡:
			_当前选中城堡 = true
	else:
		pass

	_更新按钮()


func _更新按钮() -> void:
	print("🖥️ _更新按钮: 城堡=%s 建筑=%s" % [_当前选中城堡, _当前选中建筑])
	# 城堡 → 显示训练行
	if _当前选中城堡:
		if 训练行:
			训练行.visible = true
			print("🖥️   显示训练行")
		_隐藏状态标签()
		return

	# 其他建筑 → 显示建筑名称
	if _当前选中建筑 and _当前建筑节点:
		_显示建筑信息(_当前建筑节点)
		return

	# 普通单位 → 显示命令按钮
	按钮行.visible = true
	print("🖥️   显示按钮行")


func _显示建筑信息(建筑: Node) -> void:
	if not 建筑名称标签:
		return
	var 名称 := ""
	var 描述 := ""
	if 建筑.has_method("获取建筑名称"):
		名称 = 建筑.获取建筑名称()
	elif "建筑名称" in 建筑:
		名称 = 建筑.建筑名称
	else:
		名称 = "建筑"

	if 建筑 is 房子:
		描述 = "提供人口上限"
	elif 建筑 is 防御塔:
		描述 = "自动攻击范围内敌人"
	else:
		描述 = ""

	建筑名称标签.text = 名称 if 描述.is_empty() else 名称 + " — " + 描述
	建筑名称标签.visible = true
	_隐藏状态标签()


var _状态标签计数 := 0

func _显示状态反馈(消息: String) -> void:
	if not 状态标签:
		return
	_状态标签计数 += 1
	var 当前计数 = _状态标签计数
	状态标签.text = 消息
	状态标签.visible = true
	await get_tree().create_timer(3.0).timeout
	# 只在没有新消息覆盖时才隐藏
	if is_instance_valid(状态标签) and _状态标签计数 == 当前计数:
		状态标签.visible = false


func _隐藏状态标签() -> void:
	if is_instance_valid(状态标签):
		状态标签.visible = false


func _clear_selection() -> void:
	当前选中单位 = []
	操作面板.visible = false
	_当前选中建筑 = false
	_当前选中城堡 = false
	_当前建筑节点 = null
	_隐藏状态标签()


func _发送命令到所有单位(方法名: String, 参数 = null) -> void:
	for unit in 当前选中单位:
		if is_instance_valid(unit) and unit.has_method(方法名):
			if 参数 != null:
				unit.call(方法名, 参数)
			else:
				unit.call(方法名)


func _on_取消选中_pressed() -> void:
	for unit in 当前选中单位:
		if is_instance_valid(unit):
			unit.选择状态 = false
	_clear_selection()


func _on_停止_pressed() -> void:
	_发送命令到所有单位("命令停止")


func _on_驻守_pressed() -> void:
	_发送命令到所有单位("命令驻守")


func _on_巡逻_pressed() -> void:
	var 最后位置 = _获取最后标记位置()
	if 最后位置 != Vector2.ZERO and 最后位置.distance_to(Vector2.ZERO) > 5:
		_发送命令到所有单位("命令巡逻", 最后位置)
	else:
		for unit in 当前选中单位:
			if is_instance_valid(unit) and unit.has_method("命令巡逻"):
				unit.命令巡逻(unit.global_position + Vector2(100, 0))


func _on_攻击移动_pressed() -> void:
	var rts = get_tree().get_first_node_in_group("rts")
	if not is_instance_valid(rts):
		for path in ["/root/平面/rts——node", "/root/世界岛场景/rts——node"]:
			rts = get_node_or_null(path)
			if is_instance_valid(rts):
				break
	if rts and rts.has_method("_amove模式中"):
		rts._amove模式中 = true
		print("A-move 模式已激活")


# ============================================================
# 城堡训练按钮
# ============================================================

func _on_训练剑士_pressed() -> void:
	print("🖱️ 训练剑士按钮被点击")
	_尝试训练单位("剑士")


func _on_训练弓箭手_pressed() -> void:
	print("🖱️ 训练弓箭手按钮被点击")
	_尝试训练单位("弓箭手")


func _on_训练农民_pressed() -> void:
	print("🖱️ 训练农民按钮被点击")
	_尝试训练单位("农民")


func _尝试训练单位(类型: String) -> void:
	print("🖥️ _尝试训练单位: %s" % 类型)
	if 当前选中单位.is_empty():
		_显示状态反馈("请先选中城堡")
		return

	var unit = 当前选中单位[0]
	if not is_instance_valid(unit):
		_显示状态反馈("选中单位已失效")
		return

	if unit.has_method("添加训练"):
		var 成功 = unit.添加训练(类型)
		if 成功:
			# 获取当前队列大小
			var 队列大小 = unit.获取队列大小() if unit.has_method("获取队列大小") else "?"
			_显示状态反馈("训练%s已加入队列 [%s/5]" % [类型, str(队列大小)])
		else:
			var 队列大小 = unit.获取队列大小() if unit.has_method("获取队列大小") else 5
			if 队列大小 >= 5:
				_显示状态反馈("训练队列已满（最大5）")
			else:
				_显示状态反馈("训练失败：资源不足")
	else:
		_显示状态反馈("该建筑无法训练" + 类型)


# ============================================================
# 辅助
# ============================================================

func _获取最后标记位置() -> Vector2:
	# 1. 组查找
	var rts = get_tree().get_first_node_in_group("rts")
	if is_instance_valid(rts) and rts.has_method("获取最后标记位置"):
		return rts.获取最后标记位置()
	# 2. 场景路径回退（兼容热更新）
	for path in ["/root/平面/rts——node", "/root/世界岛场景/rts——node"]:
		rts = get_node_or_null(path)
		if is_instance_valid(rts) and rts.has_method("获取最后标记位置"):
			return rts.获取最后标记位置()
	return Vector2.ZERO
