extends UnitBase
class_name 剑士

## 剑士 — RTS 可控制近战单位
##
## 3 状态状态机：IDLE / MOVE / ATTACK
## 战斗逻辑委托给组件系统：
##   targeting_component → 目标选择（直接引用，无需 find_child）
##   combat_component   → 攻击冷却 + 触发
##   DamageSystem       → 伤害结算
##   health_component   → HP/死亡

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
	super._ready()

	# 配置战斗组件（父类已创建好，直接通过引用设置）
	combat_component.attack_damage = 攻击力
	combat_component.attack_range = 攻击范围
	combat_component.attack_cooldown = 攻击间隔

	# 断开默认直伤连接，改用剑士自定义攻击流程
	if combat_component.attack_initiated.is_connected(_on_default_attack):
		combat_component.attack_initiated.disconnect(_on_default_attack)
	combat_component.attack_initiated.connect(_on_剑士_attack)

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
			# 攻击时保持静止（CombatComponent 触发攻击）
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
				if 当前状态 != State.ATTACK and 当前状态 != State.MOVE:
					切换状态(State.MOVE)
				if 当前状态 == State.ATTACK:
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
	var 排斥力: Vector2 = _计算排斥力()
	if 排斥力.length_squared() > 0.01:
		velocity = velocity.move_toward(排斥力, 移动速度 * 10.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 移动速度 * 10.0 * delta)

	if 当前命令 in [命令类型.移动, 命令类型.攻击, 命令类型.巡逻]:
		if 目标位置 != Vector2.ZERO:
			切换状态(State.MOVE)
		return

	if 当前命令 == 命令类型.驻守:
		return

	# TargetingComponent 自动索敌 → 追击
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
	# 追击限距检测
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

	# 进入攻击范围 → 切换 ATTACK（CombatComponent 的 _process 会触发攻击）
	var target = targeting_component.get_target() if targeting_component else null
	if target and is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= 攻击范围:
			切换状态(State.ATTACK)
			return

	# 追击中更新目标
	if target and is_instance_valid(target):
		目标位置 = target.global_position

	# ⭐ 使用 _使用流场移动（减少 FFManager 每帧调用）
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
# 攻击响应 — 由 CombatComponent.attack_initiated 触发
# ============================================================

func _on_剑士_attack(target: Node2D, packet: DamagePacket) -> void:
	if 当前状态 != State.ATTACK:
		return

	# 攻击动画延迟
	await get_tree().create_timer(0.2).timeout
	if not is_instance_valid(self) or 当前状态 != State.ATTACK:
		return

	# 通过 DamageSystem 造成伤害
	if target and is_instance_valid(target):
		DamageSystem.apply_damage(packet)

	# 攻击后判定
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self):
		return

	var current_target = targeting_component.get_target() if targeting_component else null
	if current_target and is_instance_valid(current_target):
		if global_position.distance_to(current_target.global_position) <= 攻击范围:
			切换状态(State.ATTACK)  # 继续攻击
		else:
			targeting_component.set_target(current_target)
			目标位置 = current_target.global_position
			当前命令 = 命令类型.攻击
			切换状态(State.MOVE)  # 追击
	else:
		# 目标死亡 → 回到原始位置或待机
		if _原始目标位置 != Vector2.ZERO:
			目标位置 = _原始目标位置
			当前命令 = 命令类型.移动
			_是攻击移动 = true
			切换状态(State.MOVE)
		else:
			命令停止()
