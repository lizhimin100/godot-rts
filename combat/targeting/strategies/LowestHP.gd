class_name LowestHPStrategy
extends TargetingStrategy

## 最低血量策略 — 在搜索范围内寻找血量百分比最低的敌对目标

func find_target(owner: Node2D, search_range: float) -> Node2D:
	if not owner or not is_instance_valid(owner):
		return null

	var best: Node2D = null
	var lowest_ratio: float = 1.1  # > 1.0 确保第一个目标一定选中
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

		var ratio: float = _get_hp_ratio(node)
		if ratio < lowest_ratio:
			lowest_ratio = ratio
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

		var ratio: float = _get_hp_ratio(node)
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			best = node

	return best


static func _get_hp_ratio(node: Node) -> float:
	var hc: HealthComponent = node.get_node_or_null("HealthComponent") as HealthComponent
	if hc:
		return hc.hp / max(hc.max_hp, 1.0)
	if "当前生命值" in node and "最大生命值" in node:
		return float(node.当前生命值) / max(float(node.最大生命值), 1.0)
	if "max_hp" in node:
		var max_val = node.get("max_hp")
		var cur_val = node.get("hp")
		if typeof(max_val) == TYPE_FLOAT:
			return cur_val / max(max_val, 1.0)
	return 0.0


static func _is_enemy(owner: Node2D, target: Node) -> bool:
	return NearestStrategy._is_enemy(owner, target)


static func _is_dead(node: Node) -> bool:
	return NearestStrategy._is_dead(node)
