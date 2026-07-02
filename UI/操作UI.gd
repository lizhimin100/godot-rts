extends Control
class_name 操作UI

## 操作UI — RTS 选中单位命令面板
##
## 数据来源：
##   - 选中单位：选择管理器
##   - 命令发送：命令管理器
##   不直接访问 unit 属性

const DIAG: bool = true  # 诊断日志

# 全局引用
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

	# 监听选择管理器的选中变化
	if 选择管理器.实例:
		if DIAG: print("[UI] 连接选择管理器信号: 选中变化 + 选中清空")
		选择管理器.实例.选中变化.connect(_on_选中变化)
		选择管理器.实例.选中清空.connect(_on_选中清空)
	else:
		if DIAG: print("[UI] ⚠ 选择管理器.实例 为 null！信号未连接")
		# 延迟重试
		await get_tree().process_frame
		if 选择管理器.实例:
			if DIAG: print("[UI] 延迟连接成功")
			选择管理器.实例.选中变化.connect(_on_选中变化)
			选择管理器.实例.选中清空.connect(_on_选中清空)
		else:
			if DIAG: print("[UI] ⚠ 延迟后仍然无法连接选择管理器")


func _exit_tree() -> void:
	if _全局实例 == self:
		_全局实例 = null


static func 获取实例() -> 操作UI:
	return _全局实例


func _ready() -> void:
	操作面板.visible = false
	if 训练行:
		训练行.visible = false
	if 建筑名称标签:
		建筑名称标签.visible = false
	if 状态标签:
		状态标签.visible = false


# ============================================================
# 选中变化响应（来自 SelectionManager）
# ============================================================

func _on_选中变化(units: Array) -> void:
	if DIAG: print("[UI] 选中变化: ", units.size(), " 个单位")
	if units.is_empty():
		_清除选中()
		return

	当前选中单位 = units.duplicate()
	if DIAG: print("[UI] 当前选中: ", 当前选中单位.size(), " 个单位, 第一个=", 当前选中单位[0].name if 当前选中单位 else "无")
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
		if DIAG: print("[UI] ⚠ 选中单位无效")
		return

	if unit.is_in_group("建筑"):
		_当前选中建筑 = true
		_当前建筑节点 = unit
		if unit is 城堡:
			_当前选中城堡 = true

	_更新按钮()


func _on_选中清空() -> void:
	if DIAG: print("[UI] 选中清空")
	_清除选中()


# ============================================================
# 按钮更新
# ============================================================

func _更新按钮() -> void:
	# 城堡 → 显示训练行
	if _当前选中城堡:
		if 训练行:
			训练行.visible = true
		_隐藏状态标签()
		return

	# 其他建筑 → 显示建筑名称
	if _当前选中建筑 and _当前建筑节点:
		_显示建筑信息(_当前建筑节点)
		return

	# 普通单位 → 显示命令按钮
	按钮行.visible = true
	if DIAG: print("[UI] 显示按钮行")


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
	if is_instance_valid(状态标签) and _状态标签计数 == 当前计数:
		状态标签.visible = false


func _隐藏状态标签() -> void:
	if is_instance_valid(状态标签):
		状态标签.visible = false


func _清除选中() -> void:
	当前选中单位 = []
	操作面板.visible = false
	_当前选中建筑 = false
	_当前选中城堡 = false
	_当前建筑节点 = null
	_隐藏状态标签()


# ============================================================
# 按钮事件 — 通过命令管理器发送
# ============================================================

func _on_取消选中_pressed() -> void:
	if DIAG: print("[UI] 取消选中 按钮按下")
	选择管理器.取消选中()


func _on_停止_pressed() -> void:
	if DIAG: print("[UI] 停止按钮按下, 当前选中单位=", 当前选中单位.size(), " 有效=", 当前选中单位.filter(func(u): return is_instance_valid(u)).size())
	if not 当前选中单位.is_empty():
		命令管理器.命令停止(当前选中单位)


func _on_驻守_pressed() -> void:
	if DIAG: print("[UI] 驻守按钮按下, 当前选中单位=", 当前选中单位.size())
	if not 当前选中单位.is_empty():
		命令管理器.命令驻守(当前选中单位)


func _on_巡逻_pressed() -> void:
	if 当前选中单位.is_empty():
		return
	var 最后位置 = _获取最后标记位置()
	if 最后位置 != Vector2.ZERO and 最后位置.distance_to(Vector2.ZERO) > 5:
		命令管理器.命令巡逻(当前选中单位, 最后位置)
	else:
		for unit in 当前选中单位:
			if is_instance_valid(unit):
				命令管理器.命令巡逻([unit], unit.global_position + Vector2(100, 0))


func _on_攻击移动_pressed() -> void:
	## A-move 模式：左键点击时发送攻击移动命令
	## 在当前选中单位的位置发送移动命令
	if not 当前选中单位.is_empty():
		var input_handler = get_tree().get_first_node_in_group("输入处理器")
		if input_handler and input_handler.has_method("_获取最后右键位置"):
			var pos = input_handler._获取最后右键位置()
			if pos != Vector2.ZERO:
				命令管理器.命令移动(当前选中单位, pos)
			else:
				命令管理器.命令移动(当前选中单位, Vector2(100, 0))
		else:
			命令管理器.命令移动(当前选中单位, Vector2(100, 0))


# ============================================================
# 城堡训练按钮
# ============================================================

func _on_训练剑士_pressed() -> void:
	_尝试训练单位("剑士")

func _on_训练弓箭手_pressed() -> void:
	_尝试训练单位("弓箭手")

func _on_训练农民_pressed() -> void:
	_尝试训练单位("农民")


func _尝试训练单位(类型: String) -> void:
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
	var input_handler = get_tree().get_first_node_in_group("输入处理器")
	if input_handler and input_handler.has_method("_获取最后右键位置"):
		return input_handler._获取最后右键位置()
	return Vector2.ZERO
