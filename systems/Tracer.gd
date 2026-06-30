class_name Tracer
extends Node

## [MCP_TRACE] 事件链路追踪器
##
## 用法：Tracer.trace(module, event, details, cost_ms)
## 调用者负责计时，Tracer 只负责格式化输出
##
## 格式：
##   [MCP_TRACE] module | event | timestamp | cost_ms | side_effects
##
## 常量用作 side_effects 标志位，方便 grep

enum SideEffect {
	NONE            = 0,
	FF_UPDATE       = 1 << 0,  # FFManager.update_target
	SEPARATION      = 1 << 1,  # SeparationSystem.get_force
	PHYSICS_MOVE    = 1 << 2,  # move_and_slide
	SIGNAL_EMIT     = 1 << 3,  # any signal.emit
	STATE_CHANGE    = 1 << 4,  # state switching
	ANIMATION       = 1 << 5,  # animation.play
	UI_UPDATE       = 1 << 6,  # UI update
	FOG_UPDATE      = 1 << 7,  # fog of war update
	COMBAT_COOLDOWN = 1 << 8,  # cooldown timer
	DAMAGE_PACKET   = 1 << 9,  # DamagePacket creation
	INPUT_EVENT     = 1 << 10, # input event
	GROUP_QUERY     = 1 << 11, # get_nodes_in_group
	BFS             = 1 << 12, # BFS computation
}

const SIDE_NAME: Dictionary = {
	SideEffect.FF_UPDATE:       "ff_update",
	SideEffect.SEPARATION:      "separation",
	SideEffect.PHYSICS_MOVE:    "physics_move",
	SideEffect.SIGNAL_EMIT:     "signal_emit",
	SideEffect.STATE_CHANGE:    "state_change",
	SideEffect.ANIMATION:       "animation",
	SideEffect.UI_UPDATE:       "ui_update",
	SideEffect.FOG_UPDATE:      "fog_update",
	SideEffect.COMBAT_COOLDOWN: "cooldown",
	SideEffect.DAMAGE_PACKET:   "damage_packet",
	SideEffect.INPUT_EVENT:     "input_event",
	SideEffect.GROUP_QUERY:     "group_query",
	SideEffect.BFS:             "bfs",
}


static func trace(module: String, event: String, detail: String = "", cost_ms: float = -1.0, effects: int = 0) -> void:
	var timestamp: int = Time.get_ticks_msec()
	var cost_str: String = "%.4fms" % cost_ms if cost_ms >= 0 else "?"
	var effects_str: String = _effects_to_str(effects)
	# 使用 print 而非 push_notification，避免污染错误面板
	print("[MCP_TRACE] %s | %s | %d | %s | %s%s" % [
		module, event, timestamp, cost_str, detail, effects_str
	])


static func _effects_to_str(effects: int) -> String:
	if effects == 0:
		return ""
	var parts: PackedStringArray = []
	for bit in range(14):
		var flag: int = 1 << bit
		if effects & flag:
			if flag in SIDE_NAME:
				parts.append("+" + SIDE_NAME[flag])
	return "," + ",".join(parts)


## 快速计时器：返回一个用于计时的起始时间戳（ticks_msec）
static func start() -> int:
	return Time.get_ticks_usec()


## 结束计时：返回耗时 ms
static func stop(start_usec: int) -> float:
	return (Time.get_ticks_usec() - start_usec) / 1000.0


## 一次性追踪 + 耗时
static func trace_with_cost(module: String, event: String, detail: String = "", cost_ms: float = -1.0, effects: int = 0) -> void:
	trace(module, event, detail, cost_ms, effects)
