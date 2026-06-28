class_name HighestThreatStrategy
extends TargetingStrategy

## 高威胁目标策略 — 优先攻击高威胁目标
##
## 威胁评估：
##   - 攻击力高的单位（通过 CombatComponent.attack_damage 评估）
##   - 建筑（防御塔/城堡）具有基础威胁加成
##
## 注意：当前为简化版威胁评估，未来可扩展为更复杂的仇恨系统

# 建筑基础威胁加成
const BUILDING_THREAT_BONUS: Dictionary = {
	"防御塔": 50.0,
	"城堡": 30.0,
}

func find_target(owner: Node2D, search_range: float) -> Node2D:
	if not owner or not is_instance_valid(owner):
		return null

	var best: Node2D = null
	var highest_threat: float = -1.0
	var owner_pos: Vector2 = owner.global_position
	var tree: SceneTree = owner.get_tree()
	if not tree:
		return null

	for node in tree.get_nodes_in_group("移动单位"):
		if node == owner or not is_instance_valid(node):
			continue
		if not _is_enemy(owner, node):
			continue
		if _is_dead(node):
			continue
		if owner_pos.distance_to(node.global_position) > search_range:
			continue

		var threat: float = _evaluate_threat(node)
		if threat > highest_threat:
			highest_threat = threat
			best = node

	for node in tree.get_nodes_in_group("建筑"):
		if node == owner or not is_instance_valid(node):
			continue
		if not _is_enemy(owner, node):
			continue
		if _is_dead(node):
			continue
		if owner_pos.distance_to(node.global_position) > search_range:
			continue

		var threat: float = _evaluate_threat(node)
		if threat > highest_threat:
			highest_threat = threat
			best = node

	return best


static func _evaluate_threat(node: Node) -> float:
	var threat: float = 10.0  # 基础威胁值

	# 从 CombatComponent 获取攻击力
	var combat: CombatComponent = node.get_node_or_null("CombatComponent") as CombatComponent
	if combat:
		threat += combat.attack_damage * 2.0

	# 建筑额外威胁
	var class_name_str: String = node.get("class_name") if "class_name" in node else ""
	if class_name_str in BUILDING_THREAT_BONUS:
		threat += BUILDING_THREAT_BONUS[class_name_str]

	# 检查当前生命值（受伤越重威胁越低？或越高？这里用越低→越优先）
	var ratio: float = _get_hp_ratio(node)
	threat *= (0.5 + ratio * 0.5)  # HP 满时 1x，HP 低时 0.5x

	return threat


static func _get_hp_ratio(node: Node) -> float:
	return LowestHPStrategy._get_hp_ratio(node)


static func _is_enemy(owner: Node2D, target: Node) -> bool:
	return NearestStrategy._is_enemy(owner, target)


static func _is_dead(node: Node) -> bool:
	return NearestStrategy._is_dead(node)
