extends Object
## 安全封装 InputMap：未配置的 action 不得调用 is_action_pressed，否则运行时会刷屏报错。


static func has_action(action: StringName) -> bool:
	if String(action).is_empty():
		return false
	return InputMap.has_action(action)


static func event_is_action_pressed_safe(event: InputEvent, action: StringName) -> bool:
	if event == null:
		return false
	if not has_action(action):
		return false
	return event.is_action_pressed(action)


## 任一 action 已定义且本帧按下则返回 true（常用于 interact + ui_accept 组合）。
static func event_any_action_pressed_safe(event: InputEvent, actions: Array) -> bool:
	if event == null:
		return false
	for a in actions:
		var an: StringName
		if a is StringName:
			an = a
		else:
			an = StringName(str(a))
		if has_action(an) and event.is_action_pressed(an):
			return true
	return false
