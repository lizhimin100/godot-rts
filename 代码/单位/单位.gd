@tool class_name Unit extends Area2D

signal quick_sell_pressed



@export var stats : AcUnitStats : set = set_stats

@onready var 皮肤: Sprite2D = $visuals/皮肤
@onready var 血条: ProgressBar = $血条
@onready var 蓝条: ProgressBar = $蓝条
@onready var 等级图标: TierIcon = $等级图标

@onready var 拖放组件: 拖放组件 = $拖放组件
@onready var 基于速度旋转组件: 角色旋转速度组件 = $基于速度旋转组件
@onready var 轮廓高亮组件: 轮廓高亮组件 = $轮廓高亮组件
@onready var 单位合成动画组件: UnitAnimations = $单位合成动画组件


var 是否悬停 := false

func set_stats(value : AcUnitStats) -> void:
	stats = value
	
	if value == null:
		return
	
	if not is_node_ready():
		await ready
	
	if not Engine.is_editor_hint():
		stats = value.duplicate()#复制状态副本，资源不共享
	
	皮肤.region_rect.position = Vector2(stats.皮肤坐标) * 营地场景.单元格 * 3
	等级图标.stats = stats

func _ready() -> void:
	if not Engine.is_editor_hint():
		拖放组件.开始拖动.connect(_on_drag_started)
		拖放组件.取消拖动.connect(_on_drag_canceled)
		#quick_sell_pressed.connect(func(): printt("出售单位"))

func _input(event: InputEvent) -> void:
	if not 是否悬停 :
		return
	if event.is_action_pressed("快速出售"):
		quick_sell_pressed.emit()


func reset_after_dragging(starting_position : Vector2) -> void:#重置位置
	基于速度旋转组件.enabled = false
	global_position = starting_position

func _on_drag_started() -> void:#开始拖动
	基于速度旋转组件.enabled = true


func _on_drag_canceled(starting_position : Vector2) -> void:#取消拖动
	reset_after_dragging(starting_position)



func _on_mouse_entered() -> void:
	if 拖放组件.是否拖动 :
		return
	是否悬停= true
	轮廓高亮组件.highlight()
	z_index = 99

func _on_mouse_exited() -> void:
	if 拖放组件.是否拖动 :
		return
	是否悬停= false
	轮廓高亮组件.clear_highlight()
	z_index = 0
