class_name DamagePacket
extends RefCounted

## 伤害数据包 — 经过伤害管线的完整伤害信息
##
## 包含伤害值、伤害类型、攻击者、目标等
## 由 CombatComponent 创建，经过 DamageSystem → DamageResolver 管线

enum DamageType {
	PHYSICAL,  # 物理伤害 — 受护甲减免
	MAGIC,     # 魔法伤害 — 受护甲类型克制影响
	TRUE,      # 真实伤害 — 无视护甲与减免
}

enum ArmorType {
	UNARMORED,  # 无甲
	LIGHT,      # 轻甲
	MEDIUM,     # 中甲
	HEAVY,      # 重甲
}

var damage: float = 0.0
var damage_type: DamageType = DamageType.PHYSICAL
var attacker: Node2D = null
var target: Node2D = null
var position: Vector2 = Vector2.ZERO
