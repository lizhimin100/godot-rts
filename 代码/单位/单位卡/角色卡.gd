class_name UnitCard extends Button
signal unit_bought(unit : AcUnitStats)

const HOVER_BORDER_COLOR := Color("fafa82")

@export var player_stats : PlayerStats 
@export var unit_stats : AcUnitStats :set = _set_unit_stats

@onready var 特性: Label = %特性
@onready var 底部: Panel = %底部
@onready var 单位名称: Label = %单位名称
@onready var 金币消耗: Label = %金币消耗
@onready var 边框: Panel = %边框
@onready var 单位图标: TextureRect = %单位图标
@onready var 空占位符: Panel = %空占位符
@onready var border_sb :StyleBoxFlat = 边框.get_theme_stylebox("panel")
@onready var bottom_sb :StyleBoxFlat = 底部.get_theme_stylebox("panel")

var bought := false
var border_color :Color

func _ready() -> void:
	player_stats.changed.connect(_on_player_stats_changed)
	_on_player_stats_changed()
	unit_bought.connect(
		func(unit : AcUnitStats):
			printt("购买单位：" , unit)
			printt("剩余金币：" , player_stats.金钱)
	)


func _set_unit_stats(value : AcUnitStats) -> void:
	unit_stats = value
	if not is_node_ready():
		await  ready
	if not unit_stats:
		空占位符.show()
		disabled = true
		bought = true
		return
	border_color = AcUnitStats.稀有度颜色[unit_stats.稀有度]
	border_sb.border_color = border_color
	bottom_sb.bg_color = border_color
	单位名称.text = unit_stats.单位名称
	金币消耗.text =str(unit_stats.金币费用)
	单位图标.texture.region.position = Vector2(unit_stats.皮肤坐标) *  营地场景.单元格 * 3
	
	
	
	
func _on_player_stats_changed() -> void:
	if not unit_stats:
		return
	var has_enough_gold := player_stats.金钱 >= unit_stats.金币费用#是否有足够的钱
	disabled = not has_enough_gold#有足够就不禁用，没有就禁用
	
	if has_enough_gold or bought :
		modulate = Color(Color.WHITE , 1.0)
	else :modulate = Color(Color.WHITE , 0.5)

func _on_pressed() -> void:
	if bought :
		return
	bought = true
	空占位符.show()
	player_stats.金钱 -= unit_stats.金币费用
	unit_bought.emit(unit_stats)

func _on_mouse_entered() -> void:
	if not disabled:
		border_sb.border_color = HOVER_BORDER_COLOR

func _on_mouse_exited() -> void:
	border_sb.border_color = border_color#恢复原始的边框颜色
