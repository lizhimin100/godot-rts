class_name HealthComponent
extends Node

## 生命值组件 — 管理 HP/MP 与受伤/死亡信号
## 供 UnitBase / 建筑基类 组合使用
##
## 信号:
##   hp_changed(new_hp, max_hp, delta) — HP 变化时触发
##   mp_changed(new_mp, max_mp, delta) — MP 变化时触发
##   died(attacker) — 生命值归零时触发

signal hp_changed(new_hp: float, max_hp: float, delta: float)
signal mp_changed(new_mp: float, max_mp: float, delta: float)
signal died(attacker)

@export var max_hp: float = 100.0
## 最大魔力值设为 0 表示该单位没有魔力条
@export var max_mp: float = 0.0

var hp: float:
	get:
		return _hp

var mp: float:
	get:
		return _mp

var _hp: float
var _mp: float
var _dead: bool = false


func _ready() -> void:
	_hp = max_hp
	_mp = max_mp


## 受到伤害 — 由 DamageSystem 调用，不直接调用此方法
func take_damage(amount: float, attacker = null) -> void:
	if _dead or amount <= 0.0:
		return

	var old_hp = _hp
	_hp = max(0.0, _hp - amount)
	hp_changed.emit(_hp, max_hp, _hp - old_hp)

	if _hp <= 0.0 and not _dead:
		_dead = true
		died.emit(attacker)


## 治疗 — 恢复 HP
func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return

	var old_hp = _hp
	_hp = min(max_hp, _hp + amount)
	hp_changed.emit(_hp, max_hp, _hp - old_hp)


## 强制设置 HP（用于初始化或外部修改）
func set_hp(value: float) -> void:
	_hp = clamp(value, 0.0, max_hp)
	hp_changed.emit(_hp, max_hp, 0.0)


## 消耗魔力，成功返回 true
func use_mp(amount: float) -> bool:
	if _mp < amount:
		return false

	var old_mp = _mp
	_mp -= amount
	mp_changed.emit(_mp, max_mp, _mp - old_mp)
	return true


## 恢复魔力
func add_mp(amount: float) -> void:
	if amount <= 0:
		return
	var old_mp = _mp
	_mp = min(max_mp, _mp + amount)
	mp_changed.emit(_mp, max_mp, _mp - old_mp)


func is_dead() -> bool:
	return _dead


## 重置到满状态（用于对象池复用）
func reset() -> void:
	_hp = max_hp
	_mp = max_mp
	_dead = false
