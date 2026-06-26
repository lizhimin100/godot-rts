extends CanvasLayer

## 胜负判定系统
## 场景需要有一个 Label 子节点（显示胜负文字）

@export var 胜利文字: String = "🏆 胜利！"
@export var 失败文字: String = "💀 失败..."
@export var 检测间隔: float = 1.0  # 每1秒检测一次

var _已结束 := false
var _已开战 := false  # 是否有过单位存在（区分"未开战"和"全灭"）
var _计时 := 0.0

@onready var 胜负标签: Label = $胜负标签


func _ready() -> void:
	process_mode = PROCESS_MODE_WHEN_PAUSED
	if 胜负标签:
		胜负标签.visible = false


func _input(event: InputEvent) -> void:
	if not _已结束:
		return
	if event.is_action_pressed("ui_accept"):  # 空格/回车
		get_tree().paused = false
		get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if _已结束:
		return

	_计时 += delta
	if _计时 < 检测间隔:
		return
	_计时 = 0.0

	_检测胜负()


func _检测胜负() -> void:
	var 玩家存活 := 0
	var 敌人存活 := 0

	for 单位 in get_tree().get_nodes_in_group("移动单位"):
		if not is_instance_valid(单位):
			continue
		if 单位.当前生命值 <= 0:
			continue
		# 碰撞层8=玩家单位, 4=玩家建筑, 16=敌人(单位和建筑)
		if 单位.collision_layer == 8 or 单位.collision_layer == 4:
			玩家存活 += 1
		elif 单位.collision_layer == 16:
			敌人存活 += 1

	# 检测是否有单位存在（标记开战）
	if 玩家存活 + 敌人存活 > 0:
		_已开战 = true

	if 玩家存活 == 0 and 敌人存活 == 0:
		if _已开战:
			# 双方同归于尽 → 平局
			_显示结果("⚖️ 平局！", Color(0.8, 0.8, 0.3))
		return  # 还没开战，忽略

	if 敌人存活 == 0 and 玩家存活 > 0:
		_显示结果(胜利文字, Color(0.3, 1, 0.3))
	elif 玩家存活 == 0 and 敌人存活 > 0:
		_显示结果(失败文字, Color(1, 0.3, 0.3))


func _显示结果(文字: String, 颜色: Color) -> void:
	if _已结束:
		return
	_已结束 = true

	if not 胜负标签:
		return

	胜负标签.text = 文字
	胜负标签.modulate = 颜色
	胜负标签.visible = true

	# 缩放动画
	var tween := create_tween()
	tween.tween_property(胜负标签, "scale", Vector2(1.3, 1.3), 0.4).from(Vector2(0.3, 0.3))
	tween.parallel().tween_property(胜负标签, "modulate:a", 1.0, 0.4)

	# 暂停游戏
	await get_tree().create_timer(1.0).timeout
	get_tree().paused = true
	# 显示提示
	胜负标签.text += "\n\n按 空格 重新开始"
