class_name GlodDisplay extends MarginContainer
@export var player_stats : PlayerStats

@onready var 金钱数: Label = $"背景/内边距/整体竖排版/1横排版/金钱数"



func _ready() -> void:
	player_stats.changed.connect(_on_player_stats_changed)
	_on_player_stats_changed()

func _on_player_stats_changed() -> void:
	金钱数.text = str(player_stats.金钱)
