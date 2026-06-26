extends 建筑基类
class_name 城堡

## 城堡 — 玩家主基地
## 可训练单位（剑士、弓箭手、农民）

signal 单位训练完成(单位类型: String, 位置: Vector2)

# 训练队列
var _训练队列: Array[Dictionary] = []
var _正在训练 := false
var _训练计时器: Timer

# 集结点
var 集结点: Vector2 = Vector2.ZERO
var _集结点标记 = null

# 可训练单位配置
const 可训练单位 := {
	"剑士": { "花费": { "金钱": 100, "木材": 0 }, "时间": 3.0 },
	"弓箭手": { "花费": { "金钱": 150, "木材": 50 }, "时间": 4.0 },
	"农民": { "花费": { "金钱": 50, "木材": 0 }, "时间": 2.0 },
}

const 单位图标 := {
	"剑士": "[S]",
	"弓箭手": "[A]",
	"农民": "[P]",
}

const 单位贴图 := {
	"剑士": preload("res://小剑资源/兵种/Knights/Troops/Warrior/Blue/Warrior_Blue.png"),
	"弓箭手": preload("res://小剑资源/兵种/Knights/Troops/Archer/Blue/Archer_Blue.png"),
	"农民": preload("res://小剑资源/兵种/Knights/Troops/Pawn/Blue/Pawn_Blue.png"),
}

const 单位图标帧尺寸 := {
	"剑士": Vector2i(192, 192),
	"弓箭手": Vector2i(256, 192),
	"农民": Vector2i(192, 192),
}


func _ready() -> void:
	super._ready()
	print("🏰 城堡 _ready()，阵营: %s，collision_layer: %d" % [阵营管理器.阵营.keys()[阵营], collision_layer])

	_训练计时器 = Timer.new()
	_训练计时器.name = "训练计时器"
	_训练计时器.one_shot = true
	_训练计时器.timeout.connect(_完成下一个训练)
	add_child(_训练计时器)

	# 集结点标记（使用小旗图标）
	_集结点标记 = preload("res://单位/建筑/集结点标记.gd").new()
	_集结点标记.name = "集结点标记"
	_集结点标记.visible = false
	_集结点标记.z_index = 50
	add_child(_集结点标记)
	print("🏰 城堡初始化完成，训练计时器已创建")


## 右键设置集结点（由 rts 系统在右击地面时调用）
func 命令移动(位置: Vector2) -> void:
	集结点 = 位置
	if _集结点标记:
		_集结点标记.global_position = 位置
		_集结点标记.visible = true


func 获取集结点() -> Vector2:
	return 集结点


## 添加单位到训练队列
func 添加训练(单位类型: String) -> bool:
	print("🏰 添加训练被调用: %s" % 单位类型)
	if not 可训练单位.has(单位类型):
		print("  ❌ 未知单位类型")
		return false
	if _训练队列.size() >= 5:
		print("  ❌ 队列已满")
		return false

	var 配置 = 可训练单位[单位类型]
	if 全局变量.金钱 < 配置["花费"]["金钱"] or 全局变量.木材 < 配置["花费"]["木材"]:
		print("资源不足！")
		return false

	# 扣除资源
	全局变量.金钱 -= 配置["花费"]["金钱"]
	全局变量.木材 -= 配置["花费"]["木材"]

	_训练队列.append({ "类型": 单位类型, "配置": 配置 })

	# 弹窗通知
	var 消耗文字 := ""
	if 配置["花费"]["木材"] > 0:
		消耗文字 = " (消耗 %d金+%d木)" % [配置["花费"]["金钱"], 配置["花费"]["木材"]]
	else:
		消耗文字 = " (消耗 %d金)" % [配置["花费"]["金钱"]]
	var 通知位置 = global_position + Vector2(0, -120)
	全局变量.显示通知("训练 " + 单位类型 + 消耗文字, 通知位置)

	if not _正在训练:
		_开始训练()

	return true


func _开始训练() -> void:
	if _训练队列.is_empty():
		_正在训练 = false
		return

	_正在训练 = true
	var 当前训练 = _训练队列[0]
	_训练计时器.wait_time = 当前训练["配置"]["时间"]
	_训练计时器.start()
	print("  ▶️ 开始训练: %s (%.1f秒)" % [当前训练["类型"], 当前训练["配置"]["时间"]])


func _完成下一个训练() -> void:
	if _训练队列.is_empty():
		_正在训练 = false
		return

	var 完成的 = _训练队列.pop_front()
	print("  ✅ 训练完成: %s，剩余队列: %d" % [完成的["类型"], _训练队列.size()])
	_生成单位(完成的["类型"])

	if not _训练队列.is_empty():
		_开始训练()
	else:
		_正在训练 = false


func _生成单位(类型: String) -> void:
	var 场景路径 := ""
	match 类型:
		"剑士": 场景路径 = "res://单位/剑士/剑士.tscn"
		"弓箭手": 场景路径 = "res://单位/弓箭手/弓箭手.tscn"
		"农民": 场景路径 = "res://单位/农民/农民.tscn"
		_:
			print("  ⚠️ 未知单位类型: %s" % 类型)
			return

	var 场景 = load(场景路径)
	if not 场景:
		print("  ⚠️ 无法加载场景: %s" % 场景路径)
		return

	var 实例 = 场景.instantiate()
	# 从城堡右下侧散开生成，不重叠不卡位
	var 偏移方向 := Vector2(80, 40)
	var 同类型计数 := 0
	for child in get_parent().get_children():
		if child.is_in_group("移动单位") and child.阵营 == 阵营:
			同类型计数 += 1
	实例.position = global_position + 偏移方向 + Vector2(同类型计数 % 5 * 25, int(同类型计数 / 5) * 25)
	if 阵营 == 阵营管理器.阵营.敌人:
		实例.collision_layer = 16
	实例.阵营 = 阵营
	get_parent().add_child(实例)

	# 集结点：训练出的单位自动前往
	if 集结点 != Vector2.ZERO and 实例.has_method("命令移动"):
		实例.命令移动(集结点)

	单位训练完成.emit(类型, 实例.position)


## 取消队列中最后一个训练
func 取消训练() -> bool:
	if _训练队列.is_empty():
		return false

	var 取消项 = _训练队列.pop_back()
	# 退还资源
	全局变量.金钱 += 取消项["配置"]["花费"]["金钱"]
	全局变量.木材 += 取消项["配置"]["花费"]["木材"]
	全局变量.显示通知("已取消训练 " + 取消项["类型"], global_position + Vector2(0, -120))
	return true


func 获取队列大小() -> int:
	return _训练队列.size()


func 获取队列信息() -> Array:
	return _训练队列.duplicate()


# =================== 队列显示 ===================

# 用于在城堡上方显示训练队列贴图
var _队列图标容器: Node2D = null
var _倒计时标签: Label = null
var _队列显示签名 := ""


func _enter_tree() -> void:
	_队列图标容器 = Node2D.new()
	_队列图标容器.name = "队列图标容器"
	_队列图标容器.z_index = 100
	_队列图标容器.position = Vector2(-56, -150)
	add_child(_队列图标容器)

	_倒计时标签 = Label.new()
	_倒计时标签.name = "倒计时标签"
	_倒计时标签.z_index = 100
	_倒计时标签.add_theme_font_size_override("font_size", 20)
	_倒计时标签.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_倒计时标签.add_theme_constant_override("outline_size", 6)
	_倒计时标签.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
	_倒计时标签.position = Vector2(-50, -130)
	add_child(_倒计时标签)


func _process(delta: float) -> void:
	_更新队列显示()


func _更新队列显示() -> void:
	if not is_instance_valid(_队列图标容器) or not is_instance_valid(_倒计时标签):
		return

	if _训练队列.is_empty() and not _正在训练:
		_队列图标容器.visible = false
		_倒计时标签.visible = false
		_重建队列图标("")
		return

	_队列图标容器.visible = true
	_倒计时标签.visible = true

	var 签名 := ""
	for i in range(_训练队列.size()):
		var 项 = _训练队列[i]
		签名 += str(项["类型"]) + "|"
	_重建队列图标(签名)

	# 倒计时
	if _正在训练 and _训练计时器:
		var 剩余时间 = _训练计时器.time_left
		if 剩余时间 > 0:
			var 当前类型 = _训练队列[0]["类型"] if _训练队列.size() > 0 else ""
			_倒计时标签.text = 单位图标.get(当前类型, "") + " %.1fs" % 剩余时间
		else:
			_倒计时标签.text = ""
	else:
		_倒计时标签.text = ""


func _重建队列图标(签名: String) -> void:
	if _队列显示签名 == 签名:
		return
	_队列显示签名 = 签名

	for child in _队列图标容器.get_children():
		child.queue_free()

	for i in range(_训练队列.size()):
		var 类型 := str(_训练队列[i]["类型"])
		var 帧尺寸: Vector2i = 单位图标帧尺寸.get(类型, Vector2i(192, 192))
		var 图标 := Sprite2D.new()
		图标.name = "队列图标_%s_%d" % [类型, i]
		图标.texture = 单位贴图.get(类型)
		图标.region_enabled = true
		图标.region_rect = Rect2(0, 0, 帧尺寸.x, 帧尺寸.y)
		图标.hframes = 6
		图标.frame = 0
		图标.centered = true
		图标.scale = Vector2(0.18, 0.18)
		图标.position = Vector2(i * 28, 0)
		_队列图标容器.add_child(图标)
