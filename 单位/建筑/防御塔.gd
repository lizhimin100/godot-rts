class_name 防御塔
extends 建筑基类

## 防御塔 — 自动攻击范围内敌人
##
## 复用完整战斗组件栈：
##   CombatComponent     → 攻击冷却 + 触发
##   TargetingComponent  → 自动索敌（最近目标策略）
##   HealthComponent     → HP 管理
##   DamageSystem        → 伤害管线

# 攻击属性
const 攻击力: float = 15.0
const 攻击范围: float = 250.0
const 攻击间隔: float = 1.5


func _ready() -> void:
	super._ready()
	建筑名称 = "防御塔"
	最大生命值 = 800.0

	# 配置战斗组件
	var combat: CombatComponent = _get_combat()
	if combat:
		combat.attack_damage = 攻击力
		combat.attack_range = 攻击范围
		combat.attack_cooldown = 攻击间隔
		combat.process_mode = PROCESS_MODE_INHERIT  # 激活
		combat.attack_strike.connect(_on_塔_attack)

	# 配置目标选择
	var targeting: TargetingComponent = _get_targeting()
	if targeting:
		targeting.search_range = 攻击范围 + 50.0  # 略大于攻击范围，提前锁定
		targeting.chase_range = 攻击范围 * 1.5
		targeting.process_mode = PROCESS_MODE_INHERIT  # 激活

	# 塔不需要 HUD 的 MP 条
	var hc: HealthComponent = _get_health()
	if hc:
		hc.max_hp = 最大生命值
		hc.set_hp(最大生命值)


## 攻击响应 — 防御塔直接造成伤害（无弹道）
func _on_塔_attack(_target: Node2D, packet: DamagePacket) -> void:
	# 播放攻击动画
	if 动画 and 动画.has_animation("攻击"):
		动画.play("攻击")

	# 直接通过 DamageSystem 造成伤害
	DamageSystem.apply_damage(packet)
