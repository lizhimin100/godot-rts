extends Node

## 伤害系统 — 全局伤害管线（注册为 Autoload）
##
## 职责：
##   1. 接收 DamagePacket
##   2. 查找目标 HealthComponent
##   3. 调用 DamageResolver 解析伤害
##   4. 应用伤害到 HealthComponent
##
## 使用方式（注册为 Autoload 后）：
##   DamageSystem.apply_damage(packet)

static var instance: DamageSystem = null


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


## 应用完整伤害包（含护甲计算）
static func apply_damage(
	packet: DamagePacket,
	target_armor_type: int = DamagePacket.ArmorType.UNARMORED,
	target_armor_value: float = 0.0
) -> float:
	if not _validate(packet):
		return 0.0

	return instance._apply(packet, target_armor_type, target_armor_value)


## 简化版 — 直接应用伤害值，不经过护甲计算（用于箭矢等已预计算的场景）
static func apply_raw_damage(packet: DamagePacket) -> float:
	if not _validate(packet):
		return 0.0

	var hc: HealthComponent = _find_health_component(packet.target)
	if not hc:
		return 0.0

	hc.take_damage(packet.damage, packet.attacker)
	return packet.damage


func _apply(packet: DamagePacket, target_armor_type: int, target_armor_value: float) -> float:
	var hc: HealthComponent = _find_health_component(packet.target)
	if not hc:
		return 0.0

	# 通过 DamageResolver 计算最终伤害
	var final_damage: float = DamageResolver.resolve(packet, target_armor_type, target_armor_value)
	if final_damage <= 0.0:
		return 0.0

	hc.take_damage(final_damage, packet.attacker)
	return final_damage


static func _validate(packet: DamagePacket) -> bool:
	if not instance:
		push_error("DamageSystem: 未初始化！请注册为 Autoload 或在场景中创建 DamageSystem 节点。")
		return false
	if not packet or not is_instance_valid(packet.target):
		return false
	var hc: HealthComponent = _find_health_component(packet.target)
	if not hc:
		return false
	return true


static func _find_health_component(node: Node) -> HealthComponent:
	# 查找名为 HealthComponent 的子节点
	var hc: HealthComponent = node.get_node_or_null("HealthComponent") as HealthComponent
	if hc:
		return hc
	# 遍历所有子节点查找
	for child in node.get_children():
		if child is HealthComponent:
			return child
	return null
