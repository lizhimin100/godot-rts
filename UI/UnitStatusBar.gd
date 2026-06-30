class_name UnitStatusBar
extends Node

## 单位/建筑头顶状态条管理
##
## 自动查找父节点已有的 血条/蓝条 ProgressBar，连接到 HealthComponent 信号驱动
## 如果 血条/蓝条 不存在（如建筑场景中没放置），则自动创建
##
## 显示规则：
##   - 不选中时不显示任何条
##   - 选中时显示 HP 条
##   - MP 条仅当 max_mp > 0 时才显示
##   - 初始隐藏，由父节点的 _on_selection_changed 控制显示

## 自动创建的进度条尺寸
const AUTO_BAR_WIDTH: float = 70.0
const HP_BAR_HEIGHT: float = 6.0
const MP_BAR_HEIGHT: float = 5.0
const BAR_OFFSET_Y: float = -55.0
const MP_BAR_GAP: float = 2.0

var _health: HealthComponent = null
var _hp_bar: ProgressBar = null
var _mp_bar: ProgressBar = null
var _selected: bool = false
var _bars_are_auto_created: bool = false
# hp_changed 去抖：同一帧多次受伤只刷新一次
var _hp_debounce_timer: float = 0.0
const HP_DEBOUNCE_TIME: float = 0.05


func _ready() -> void:
	_hp_bar = get_parent().get_node_or_null("血条") as ProgressBar
	_mp_bar = get_parent().get_node_or_null("蓝条") as ProgressBar

	# 如果场景中没有血条，自动创建
	if not _hp_bar:
		_hp_bar = _create_progress_bar("血条", Color(0, 0.73, 0.31), Vector2(AUTO_BAR_WIDTH, HP_BAR_HEIGHT), Vector2(0, BAR_OFFSET_Y))
		_bars_are_auto_created = true
	if not _mp_bar:
		_mp_bar = _create_progress_bar("蓝条", Color(0, 0.65, 0.94), Vector2(AUTO_BAR_WIDTH, MP_BAR_HEIGHT), Vector2(0, BAR_OFFSET_Y + HP_BAR_HEIGHT + MP_BAR_GAP))

	_health = _find_health()
	if _health:
		_health.hp_changed.connect(_on_hp_changed)
		_health.mp_changed.connect(_on_mp_changed)
		_health.died.connect(_on_died)

	# 初始隐藏
	if _hp_bar:
		_hp_bar.value = 100.0
		_hp_bar.visible = false
	if _mp_bar:
		_mp_bar.value = 100.0
		_mp_bar.visible = false

	# ⭐ 如果父节点已是选中状态（_ready 前已设置选择状态），立即同步
	var parent = get_parent()
	if parent and "选择状态" in parent and parent.选择状态:
		_selected = true
		_refresh()


## 设置选中状态（由 UnitBase/建筑基类 调用）
func set_selected(s: bool) -> void:
	_selected = s
	# ⭐ 不依赖 _health！选中直接控制 HP 条可见性
	if _hp_bar:
		_hp_bar.visible = s
		if s:
			_hp_bar.value = (_health.hp / max(_health.max_hp, 0.01)) * 100.0 if _health else 100.0
	if _mp_bar:
		var show_mp: bool = s and (_health and _health.max_mp > 0.0)
		_mp_bar.visible = show_mp
		if show_mp:
			_mp_bar.value = (_health.mp / max(_health.max_mp, 0.01)) * 100.0 if _health else 100.0
	# 重新确认 _health（应对脚本热重载导致引用丢失）
	if not _health:
		_health = _find_health()
		if _health:
			_health.hp_changed.connect(_on_hp_changed)
			_health.mp_changed.connect(_on_mp_changed)
			_health.died.connect(_on_died)


func _on_hp_changed(new_hp: float, max_hp: float, _delta: float) -> void:
	_hp_debounce_timer = HP_DEBOUNCE_TIME
	if _hp_bar:
		_hp_bar.value = (new_hp / max(max_hp, 0.01)) * 100.0
		# 受伤时才短暂显示（如果没选中）
		if not _selected and not _hp_bar.visible:
			_hp_bar.visible = true


func _on_mp_changed(new_mp: float, max_mp: float, _delta: float) -> void:
	if _mp_bar and _mp_bar.visible:
		_mp_bar.value = (new_mp / max(max_mp, 0.01)) * 100.0


func _on_died(_attacker) -> void:
	if _hp_bar:
		_hp_bar.visible = false
	if _mp_bar:
		_mp_bar.visible = false


func _refresh() -> void:
	if not _health:
		return

	var show: bool = _selected and not _health.is_dead()

	if _hp_bar:
		_hp_bar.visible = show
		if show:
			_hp_bar.value = (_health.hp / max(_health.max_hp, 0.01)) * 100.0

	if _mp_bar:
		var show_mp: bool = show and _health.max_mp > 0.0
		_mp_bar.visible = show_mp
		if show_mp:
			_mp_bar.value = (_health.mp / max(_health.max_mp, 0.01)) * 100.0


func _create_progress_bar(name: String, fill_color: Color, size: Vector2, pos: Vector2) -> ProgressBar:
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


func _process(delta: float) -> void:
	if _hp_debounce_timer > 0.0:
		_hp_debounce_timer -= delta
		if _hp_debounce_timer <= 0.0:
			_refresh()


func _find_health() -> HealthComponent:
	var parent: Node = get_parent()
	if not parent:
		return null
	for child in parent.get_children():
		if child is HealthComponent:
			return child
	return null
