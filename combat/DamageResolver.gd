class_name DamageResolver
extends RefCounted

## 伤害解析器 — 根据伤害类型与护甲类型计算最终伤害
##
## 克制关系：
##   物理 → 中甲 0.85、重甲 0.70
##   魔法 → 轻甲 0.90、重甲 1.10
##   真实 → 无视所有减免

# 伤害类型 × 护甲类型 → 倍率表
const DAMAGE_MULTIPLIER: Dictionary = {
	DamagePacket.DamageType.PHYSICAL: {
		DamagePacket.ArmorType.UNARMORED: 1.0,
		DamagePacket.ArmorType.LIGHT: 1.0,
		DamagePacket.ArmorType.MEDIUM: 0.85,
		DamagePacket.ArmorType.HEAVY: 0.70,
	},
	DamagePacket.DamageType.MAGIC: {
		DamagePacket.ArmorType.UNARMORED: 1.0,
		DamagePacket.ArmorType.LIGHT: 0.90,
		DamagePacket.ArmorType.MEDIUM: 1.0,
		DamagePacket.ArmorType.HEAVY: 1.10,
	},
	DamagePacket.DamageType.TRUE: {
		DamagePacket.ArmorType.UNARMORED: 1.0,
		DamagePacket.ArmorType.LIGHT: 1.0,
		DamagePacket.ArmorType.MEDIUM: 1.0,
		DamagePacket.ArmorType.HEAVY: 1.0,
	},
}

## 护甲减伤公式常数: 减伤率 = 护甲值 / (护甲值 + 常数)
const ARMOR_CONSTANT: float = 50.0


## 计算最终伤害
static func resolve(packet: DamagePacket, target_armor_type: int, target_armor_value: float) -> float:
	if packet.damage <= 0.0:
		return 0.0

	# 真实伤害无视护甲
	if packet.damage_type == DamagePacket.DamageType.TRUE:
		return packet.damage

	# 类型克制倍率
	var type_table: Dictionary = DAMAGE_MULTIPLIER.get(packet.damage_type, {})
	var multiplier: float = type_table.get(target_armor_type, 1.0)

	# 护甲减伤
	var reduction: float = target_armor_value / (target_armor_value + ARMOR_CONSTANT)

	return packet.damage * multiplier * (1.0 - reduction)
