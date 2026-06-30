extends UnitBase
class_name 弓箭手

## 弓箭手 — RTS 可控制远程单位
##
## 3 状态状态机：IDLE / MOVE / ATTACK
## 战斗周期由 CombatComponent 管理
## 此脚本仅实现"打击时发射箭矢"和"攻击结束后去哪"

enum State {
	IDLE,
	MOVE,
	ATTACK
}

@export var 攻击力: float = 8.0
@export var 攻击范围: float = 150.0
@export var 攻击间隔: float = 0.8

const 玩家纹理: Texture2D = preload("res://小剑资源/兵种/Knights/Troops/Archer/Blue/Archer_Blue.png")
const 敌人纹理: Texture2D = preload("res://小剑资源/兵种/Knights/Troops/Archer/Red/Archer_Red.png")

var 当前状态: State = State.IDLE

const 箭矢场景: PackedScene = preload("res://单位/弓箭手/箭矢.tscn")

@onready var 角色图像: Sprite2D = $角色图像
@onready var 角色动画: AnimationPlayer = $角色动画
@onready var 选中标签: Label = $选中标签


func _ready() -> void:
	# 属性数据层
	stats = UnitStats.create_弓箭手_stats()
	stats.attack = 攻击力
	stats.attack_range = 攻击范围
	stats.attack_cooldown = 攻击间隔

	super._ready()

	# ---- 配置 CombatComponent ----
	combat_component.attack_damage = stats.attack
	combat_component.attack_range = stats.attack_range
	combat_component.attack_cooldown = stats.attack_cooldown
	combat_component.windup_time = 0.15   # ⭐ 前摇 0.15s（旧版行为）
	combat_component.recovery_time = 0.25 # ⭐ 后摇 0.25s（旧版行为）
	combat_component.cooldown_timing = CombatComponent.CooldownTiming.AT_STRIKE

	# ---- 连接战斗信号 ----
	if combat_component.attack_strike.is_connected(_on_default_attack_strike):
		combat_component.attack_strike.disconnect(_on_default_attack_strike)
	combat_component.attack_started.connect(_on_弓箭手_attack_started)
	combat_component.attack_strike.connect(_on_弓箭手_strike)
	combat_component.attack_finished.connect(_on_弓箭手_attack_finished)

	# ---- 纹理与材质 ----
	当前状态 = State.IDLE
	var 新材质 = 角色图像.material.duplicate()
	角色图像.material = 新材质

	if _是敌人():
		角色图像.texture = 敌人纹理
		角色图像.material.set_shader_parameter("outline_color", Color(0.9, 0.2, 0.2, 1))
		if is_instance_valid(选中标签):
			选中标签.visible = false
		collision_mask = 32 + 8 + 4
	else:
		角色图像.texture = 玩家纹理
		if is_instance_valid(选中标签):
			选中标签.visible = false
		collision_mask = 32 + 16 + 4

	角色动画.play("待机")
	角色动画.animation_finished.connect(_on_anim_finished)


func _physics_process(delta: float) -> void:
	if is_instance_valid(选中标签):
		选中标签.visible = 选择状态

	_同步命令状态()

	match 当前状态:
		State.IDLE:
			_处理待机状态(delta)
		State.MOVE:
			_处理移动状态(delta)
		State.ATTACK:
			velocity = velocity.move_toward(Vector2.ZERO, 移动速度 * 12.0 * delta)

	move_and_slide()

	if velocity.x != 0:
		角色图像.flip_h = velocity.x < 0


func 切换状态(to: State) -> void:
	if 当前状态 == to:
		return
	当前状态 = to
	match to:
		State.IDLE: _切换动画("待机")
		State.MOVE: _切换动画("移动")
		State.ATTACK: _切换动画("攻击")


func _切换动画(动画名: String) -> void:
	if 角色动画 and 角色动画.has_animation(动画名):
		角色动画.play(动画名)


func _on_anim_finished(anim_name: String) -> void:
	if anim_name == "攻击" and 当前状态 == State.ATTACK:
		角色动画.play("待机")
		角色动画.stop()


# ============================================================
# 命令同步
# ============================================================

func _同步命令状态() -> void:
	match 当前命令:
		命令类型.移动:
			if 当前状态 != State.MOVE:
				切换状态(State.MOVE)

		命令类型.攻击:
			var target = targeting_component.get_target() if targeting_component else null
			if target and is_instance_valid(target):
				if 当前状态 == State.IDLE:
					切换状态(State.MOVE)
				elif 当前状态 == State.ATTACK:
					if global_position.distance_to(target.global_position) > 攻击范围:
						切换状态(State.MOVE)
			else:
				命令停止()

		命令类型.无, 命令类型.驻守, _:
			if 当前状态 != State.IDLE:
				切换状态(State.IDLE)


# ============================================================
# 待机
# ============================================================

func _处理待机状态(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 移动速度 * 10.0 * delta)

	if 当前命令 in [命令类型.移动, 命令类型.攻击, 命令类型.巡逻]:
		if 目标位置 != Vector2.ZERO:
			切换状态(State.MOVE)
		return

	if 当前命令 == 命令类型.驻守:
		return

	if 当前命令 == 命令类型.无:
		var target = targeting_component.get_target() if targeting_component else null
		if target and is_instance_valid(target):
			目标位置 = target.global_position
			当前命令 = 命令类型.攻击
			_是自动索敌攻击 = true
			_追击起始位置 = global_position
			切换状态(State.MOVE)


# ============================================================
# 移动
# ============================================================

func _处理移动状态(delta: float) -> void:
	if _是自动索敌攻击 and _追击起始位置 != Vector2.ZERO:
		if global_position.distance_to(_追击起始位置) > 追击上限距离:
			targeting_component.clear_target()
			_是自动索敌攻击 = false
			_追击起始位置 = Vector2.ZERO
			if _原始目标位置 != Vector2.ZERO:
				目标位置 = _原始目标位置
				当前命令 = 命令类型.移动
				_是攻击移动 = true
				切换状态(State.MOVE)
			else:
				命令停止()

	var target = targeting_component.get_target() if targeting_component else null
	if target and is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= 攻击范围:
			切换状态(State.ATTACK)

	if target and is_instance_valid(target):
		目标位置 = target.global_position

	var 到达: bool = _使用流场移动(delta)
	if 到达:
		match 当前命令:
			命令类型.攻击:
				if not target or not is_instance_valid(target):
					if _原始目标位置 != Vector2.ZERO:
						目标位置 = _原始目标位置
						当前命令 = 命令类型.移动
						_是攻击移动 = true
						_是自动索敌攻击 = false
						切换状态(State.MOVE)

				target = targeting_component.get_target() if targeting_component else null
				if target:
					目标位置 = target.global_position

			命令类型.巡逻:
				_下一个巡逻点()
			_:
				命令停止()


# ============================================================
# CombatComponent 信号响应
# ============================================================

func _on_弓箭手_attack_started(_target: Node2D) -> void:
	_切换动画("攻击")


func _on_弓箭手_strike(target: Node2D, packet: DamagePacket) -> void:
	## ⭐ 发射箭矢（快照目标位置，不追踪 node）
	if target and is_instance_valid(target):
		var arrow = 箭矢场景.instantiate()
		arrow.target_position = target.global_position
		arrow.damage_packet = packet
		arrow.attacker = self
		get_parent().add_child(arrow)
		arrow.global_position = global_position + Vector2(20 if not 角色图像.flip_h else -20, -10)


func _on_弓箭手_attack_finished(_target: Node2D) -> void:
	var action = _default_attack_finished_decision()
	match action:
		"stay":
			pass
		"chase":
			切换状态(State.MOVE)
		"stop":
			命令停止()
