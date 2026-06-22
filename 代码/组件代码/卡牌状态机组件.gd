class_name CardStateMachine extends Node#卡牌状态机

@export var initial_state : CardState#初始状态

var current_state : CardState#存储当前状态
var states := {}#存储所有可用状态

func _init(card : CardUI) -> void:
	for child in get_children():#遍历状态机所有子节点
		if child is CardState:
			states[child.state] = child#键是其State,值是CardState
			child.transition_requested.connect(_on_transition_requested)
			child.card_ui = card
	
	if initial_state :
		initial_state.enter()
		current_state = initial_state

func on_input(event : InputEvent) -> void:
	if current_state:
		current_state.on_input(event)

func on_gui_input(event : InputEvent) -> void:
	if current_state:
		current_state.on_gui_input(event)

func on_mouse_entered() -> void:
	if current_state:
		current_state.on_mouse_entered()

func on_mouse_exited() -> void:
	if current_state:
		current_state.on_mouse_exited()

func _on_transition_requested(from: CardState , to: CardState.State) -> void:
	if from != current_state:
		return
	
	var new_state : CardState = states[to]#对应上from，都是CardState
	if not new_state:
		return
	if current_state:
		current_state.exit()
	
	new_state.enter()
	current_state = new_state
