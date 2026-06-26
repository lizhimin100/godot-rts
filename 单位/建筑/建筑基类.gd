class_name 建筑基类
extends StaticBody2D

## 建筑基类 — 所有 RTS 建筑的基类
## 不与 移动基类 共享继承（建筑不需要移动逻辑）
## 但实现相同的战斗接口（受伤、_是敌人、当前生命值）

signal 建筑被摧毁(建筑: 建筑基类)

# ========== 建筑属性 ==========
@export var 建筑名称: String = "建筑"
@export var 最大生命值: float = 500.0
@export var 阵营: 阵营管理器.阵营 = 阵营管理器.阵营.玩家

var 当前生命值: float = 500.0
var 已摧毁 := false
var 选择状态 := false  # 让 rts—node 可选/取消选中

# 节点
@onready var 建筑图像: Sprite2D = $建筑图像
@onready var 已摧毁图像: Sprite2D = $已摧毁图像
@onready var 碰撞: CollisionShape2D = $碰撞
@onready var 动画: AnimationPlayer = $动画


func _ready() -> void:
	当前生命值 = 最大生命值
	add_to_group("建筑")
	add_to_group("移动单位")  # 让胜负判定也能检测建筑

	if 已摧毁图像:
		已摧毁图像.visible = false

	# 从 collision_layer 推断阵营（兼容 tscn 直接设置 collision_layer）
	if collision_layer == 16:
		阵营 = 阵营管理器.阵营.敌人
	else:
		collision_layer = 4  # 改为建筑层（层3=建筑, bit值4）
		阵营 = 阵营管理器.阵营.玩家
	collision_mask = 0  # 建筑不需要主动碰撞别人

	# 玩家建筑可选
	if 阵营 == 阵营管理器.阵营.玩家:
		add_to_group("可选单位")


## 用阵营管理器判断阵营
func _是敌人() -> bool:
	return 阵营 == 阵营管理器.阵营.敌人

func _是玩家() -> bool:
	return 阵营 == 阵营管理器.阵营.玩家

## 获取阵营
func 获取阵营() -> int:
	return 阵营


## 受伤 — 被攻击时调用
func 受伤(伤害: float, 攻击来源 = null) -> void:
	if 已摧毁:
		return
	当前生命值 -= 伤害
	_播放受击效果()

	# 浮动伤害数字
	var 伤害数字 = _创建伤害数字(int(伤害))
	if 伤害数字:
		add_child(伤害数字)

	if 当前生命值 <= 0:
		死亡()


## 受击视觉反馈：闪红
func _播放受击效果() -> void:
	if not is_instance_valid(建筑图像):
		return
	if 动画 and 动画.has_animation("受击"):
		动画.play("受击")
	else:
		# 无动画时的降级：闪红
		var 原色调 = 建筑图像.modulate
		建筑图像.modulate = Color(2, 0.2, 0.2, 1)
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(建筑图像):
			建筑图像.modulate = 原色调


## 生成浮动伤害数字
func _创建伤害数字(伤害: int) -> Label:
	var label := Label.new()
	label.text = str(伤害)
	label.modulate = Color(1, 0.9, 0.1)
	label.position = Vector2(-15, -40)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)
	return label


## 死亡 — 切换摧毁精灵，淡出后删除
func 死亡() -> void:
	if 已摧毁:
		return
	已摧毁 = true

	# 切换为摧毁状态精灵
	if 建筑图像 and 已摧毁图像:
		建筑图像.visible = false
		已摧毁图像.visible = true

	# 禁用碰撞
	if 碰撞:
		碰撞.disabled = true

	建筑被摧毁.emit(self)

	# 淡出
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	queue_free()
