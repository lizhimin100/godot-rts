class_name  XPTracker extends VBoxContainer

@export var player_stats : PlayerStats

@onready var 进度条: ProgressBar = %进度条
@onready var 经验标签: Label = %经验标签
@onready var 等级标签: Label = %等级标签


func _ready() -> void:
	player_stats.changed.connect(_on_player_stats_changed)
	_on_player_stats_changed()

func _on_player_stats_changed() -> void:
	if player_stats.等级 < 10:_set_xp_bar_value()
	else:_set_max_level_value()
	
	等级标签.text = "lvl : %s" % player_stats.等级

#func _input(event: InputEvent) -> void:
	#if event.is_action_pressed("UI确认"):
		#player_stats.经验 += 5

func _set_max_level_value() -> void:
	经验标签.text = "MAX"
	进度条.value = 100

func _set_xp_bar_value() -> void:
	var xp_requirement : float = player_stats.get_current_xp_requirement()#转换成浮点数
	经验标签.text = "%s/%s" % [player_stats.经验 , player_stats.get_current_xp_requirement()]
	进度条.value = (player_stats.经验 / xp_requirement) * 100 #两个整数要整除后再乘以100
