class_name UnitStatusBar
extends Node

## 单位/建筑头顶状态条管理
##
## 显示规则：
##   - 不选中时不显示任何条
##   - 选中时显示 HP 条
##   - MP 条仅当 max_mp > 0 时才显示
##   - 通过 SelectionManager 信号驱动，不依赖父节点选择状态
##
## 数据来源：
##   - 生命值：父节点的 HealthComponent
##   - 选中状态：选择管理器

## 自动创建的进度条尺寸
const AUTO_BAR_WIDTH: float = 70.0
const HP_BAR_HEIGHT: float = 6.0
const MP_BAR_HEIGHT: float = 5.0
const BAR_OFFSET_Y: float = -55.0
const MP_BAR_GAP: float = 2.0

var _生命组件: HealthComponent = null
var _血条: ProgressBar = null
var _蓝条: ProgressBar = null
var _选中: bool = false
var _初始选中已处理: bool = false
# hp_changed 去抖
var _hp去抖计时: float = 0.0
const HP_DEBOUNCE_TIME: float = 0.05


func _ready() -> void:
	_血条 = get_parent().get_node_or_null("血条") as ProgressBar
	_蓝条 = get_parent().get_node_or_null("蓝条") as ProgressBar

	# 如果场景中没有血条，自动创建
	if not _血条:
		_血条 = _创建进度条("血条", Color(0, 0.73, 0.31), Vector2(AUTO_BAR_WIDTH, HP_BAR_HEIGHT), Vector2(0, BAR_OFFSET_Y))
	if not _蓝条:
		_蓝条 = _创建进度条("蓝条", Color(0, 0.65, 0.94), Vector2(AUTO_BAR_WIDTH, MP_BAR_HEIGHT), Vector2(0, BAR_OFFSET_Y + HP_BAR_HEIGHT + MP_BAR_GAP))

	_生命组件 = _查找生命组件()
	if _生命组件:
		_生命组件.hp_changed.connect(_on_hp变化)
		_生命组件.mp_changed.connect(_on_mp变化)
		_生命组件.died.connect(_on_死亡)

	# 初始隐藏
	if _血条:
		_血条.value = 100.0
		_血条.visible = false
	if _蓝条:
		_蓝条.value = 100.0
		_蓝条.visible = false

	# 连接到 SelectionManager 信号
	if 选择管理器.实例:
		if not 选择管理器.实例.选中变化.is_connected(_on_外部选中变化):
			选择管理器.实例.选中变化.connect(_on_外部选中变化)
		if not 选择管理器.实例.选中清空.is_connected(_on_外部取消选中):
			选择管理器.实例.选中清空.connect(_on_外部取消选中)

		# 延迟一帧检查初始选中状态
		call_deferred("_检查初始选中")


func _检查初始选中() -> void:
	"""检查父节点是否已在当前选中中"""
	if _初始选中已处理:
		return
	_初始选中已处理 = true
	if 选择管理器.实例:
		var parent = get_parent()
		if parent and 选择管理器.实例.已选中(parent):
			_set_selected(true)


# ============================================================
# 选中状态（来自 SelectionManager 信号）
# ============================================================

func _on_外部选中变化(units: Array) -> void:
	var parent = get_parent()
	_set_selected(parent in units)


func _on_外部取消选中() -> void:
	_set_selected(false)


## 旧接口 — 兼容直接调用
func set_selected(s: bool) -> void:
	_set_selected(s)


func _set_selected(s: bool) -> void:
	if _选中 == s:
		return
	_选中 = s

	if _血条:
		_血条.visible = s
		if s and _生命组件:
			_血条.value = (_生命组件.hp / max(_生命组件.max_hp, 0.01)) * 100.0

	if _蓝条:
		var show_mp: bool = s and (_生命组件 and _生命组件.max_mp > 0.0)
		_蓝条.visible = show_mp
		if show_mp:
			_蓝条.value = (_生命组件.mp / max(_生命组件.max_mp, 0.01)) * 100.0

	# 确认 _生命组件
	if not _生命组件:
		_生命组件 = _查找生命组件()
		if _生命组件:
			_生命组件.hp_changed.connect(_on_hp变化)
			_生命组件.mp_changed.connect(_on_mp变化)
			_生命组件.died.connect(_on_死亡)


# ============================================================
# HP/MP 变化响应
# ============================================================

func _on_hp变化(new_hp: float, max_hp: float, _delta: float) -> void:
	_hp去抖计时 = HP_DEBOUNCE_TIME
	if _血条:
		_血条.value = (new_hp / max(max_hp, 0.01)) * 100.0
		# 受伤时短暂显示（如果没选中）
		if not _选中 and not _血条.visible:
			_血条.visible = true


func _on_mp变化(new_mp: float, max_mp: float, _delta: float) -> void:
	if _蓝条 and _蓝条.visible:
		_蓝条.value = (new_mp / max(max_mp, 0.01)) * 100.0


func _on_死亡(_attacker) -> void:
	if _血条:
		_血条.visible = false
	if _蓝条:
		_蓝条.visible = false


func _process(delta: float) -> void:
	if _hp去抖计时 > 0.0:
		_hp去抖计时 -= delta
		if _hp去抖计时 <= 0.0:
			_刷新()


# ============================================================
# 内部
# ============================================================

func _创建进度条(name: String, fill_color: Color, size: Vector2, pos: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = name
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.size = size
	bar.position = pos
	bar.z_index = 100

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.24, 0.11, 0.10, 1.0)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.border_width_left = 1
	fill_style.border_width_top = 1
	fill_style.border_width_right = 1
	fill_style.border_width_bottom = 1
	fill_style.border_color = Color(0.24, 0.11, 0.10, 1.0)
	bar.add_theme_stylebox_override("fill", fill_style)

	get_parent().add_child(bar)
	return bar


func _查找生命组件() -> HealthComponent:
	var parent: Node = get_parent()
	if not parent:
		return null
	for child in parent.get_children():
		if child is HealthComponent:
			return child
	return null


func _刷新() -> void:
	if not _生命组件:
		return
	var show: bool = _选中 and not _生命组件.is_dead()

	if _血条:
		_血条.visible = show
		if show:
			_血条.value = (_生命组件.hp / max(_生命组件.max_hp, 0.01)) * 100.0

	if _蓝条:
		var show_mp: bool = show and _生命组件.max_mp > 0.0
		_蓝条.visible = show_mp
		if show_mp:
			_蓝条.value = (_生命组件.mp / max(_生命组件.max_mp, 0.01)) * 100.0
