extends UnitBase
class_name 剑士

## 剑士 — RTS 可控制近战单位
##
## 3 状态状态机：IDLE / MOVE / ATTACK
## 战斗周期由 CombatComponent 管理（windup→strike→recovery→cooldown）
## 此脚本仅实现"打击时做什么"和"攻击结束后去哪"

enum State {
	IDLE,
	MOVE,
	ATTACK
}

@export var 攻击力: float = 12.0
@export var 攻击范围: float = 45.0
@export var 攻击间隔: float = 1.0

const 玩家纹理: Texture2D = preload("res://小剑资源/兵种/Knights/Troops/Warrior/Blue/Warrior_Blue.png")
const 敌人纹理: Texture2D = preload("res://小剑资源/兵种/Knights/Troops/Warrior/Red/Warrior_Red.png")

var 当前状态: State = State.IDLE

@onready var 角色图像: Sprite2D = $角色图像
@onready var 角色动画: AnimationPlayer = $角色动画
@onready var 选中标签: Label = $选中标签


func _ready() -> void:
	# 属性数据层（在 super._ready 之前）
	stats = UnitStats.create_剑士_stats()
	stats.attack = 攻击力
	stats.attack_range = 攻击范围
	stats.attack_cooldown = 攻击间隔

	super._ready()

	# ---- 配置 CombatComponent ----
	combat_component.attack_damage = stats.attack
	combat_component.attack_range = stats.attack_range
	combat_component.attack_cooldown = stats.attack_cooldown
	combat_component.windup_time = 0.2    # ⭐ 前摇 0.2s（旧版行为）
	combat_component.recovery_time = 0.2  # ⭐ 后摇 0.2s（旧版行为）
	combat_component.cooldown_timing = CombatComponent.CooldownTiming.AT_STRIKE

	# ---- 连接战斗信号 ----
	if combat_component.attack_strike.is_connected(_on_default_attack_strike):
		combat_component.attack_strike.disconnect(_on_default_attack_strike)
	combat_component.attack_started.connect(_on_剑士_attack_started)
	combat_component.attack_strike.connect(_on_剑士_strike)
	combat_component.attack_finished.connect(_on_剑士_attack_finished)

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
			# ⭐ 安全检测：目标离开攻击范围时立即切回移动，不等攻击周期结束
			#    也避免 _同步命令状态 在边缘情况未能及时触发切换
			var atk_target := targeting_component.get_target() if targeting_component else null
			if atk_target and is_instance_valid(atk_target):
				if global_position.distance_to(atk_target.global_position) > 攻击范围:
					切换状态(State.MOVE)
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
		# 攻击动画播完 → 播放待机等待下次攻击
		# ⚠ 不要 .stop()：play() 后立即 stop() 会导致待机帧不生效，
		#   角色会卡在攻击动画的最后一帧（举剑帧）
		角色动画.play("待机")


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
			return

	var target = targeting_component.get_target() if targeting_component else null
	if target and is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= 攻击范围:
			切换状态(State.ATTACK)
			return

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
						return
				target = targeting_component.get_target() if targeting_component else null
				if target:
					目标位置 = target.global_position
				return
			命令类型.巡逻:
				_下一个巡逻点()
			_:
				命令停止()
		return


# ============================================================
# CombatComponent 信号响应
# ============================================================

func _on_剑士_attack_started(_target: Node2D) -> void:
	## ⭐ 每次攻击切换动画（不论是否已在 ATTACK）
	_切换动画("攻击")


func _on_剑士_strike(target: Node2D, packet: DamagePacket) -> void:
	## ⭐ CombatComponent 已在打击时检查距离，这里只需造成伤害
	if target and is_instance_valid(target):
		DamageSystem.apply_damage(packet)


func _on_剑士_attack_finished(_target: Node2D) -> void:
	## ⭐ 攻击结束后的状态决策：继续攻击 / 追击 / 停止
	var action = _default_attack_finished_decision()
	match action:
		"stay":
			pass  # 继续 ATTACK，下一个周期自动开始
		"chase":
			切换状态(State.MOVE)
		"stop":
			命令停止()
