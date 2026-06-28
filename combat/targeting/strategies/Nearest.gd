class_name NearestStrategy
extends TargetingStrategy

## 最近目标策略 — 搜索半径内最近的敌对目标

func find_target(owner: Node2D, search_range: float) -> Node2D:
	if not owner or not is_instance_valid(owner):
		return null

	var nearest: Node2D = null
	var nearest_dist_sq: float = search_range * search_range
	var owner_pos: Vector2 = owner.global_position
	var tree: SceneTree = owner.get_tree()
	if not tree:
		return null

	# 同时搜索单位组和建筑组
	for node in tree.get_nodes_in_group("移动单位"):
		if node == owner or not is_instance_valid(node):
			continue
		if not _is_enemy(owner, node):
			continue
		if _is_dead(node):
			continue

		var dist_sq: float = owner_pos.distance_squared_to(node.global_position)
		if dist_sq <= nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = node

	# 额外搜索建筑组（可能不在移动单位组中）
	for node in tree.get_nodes_in_group("建筑"):
		if node == owner or not is_instance_valid(node):
			continue
		if nearest and nearest == node:
			continue  # 已在上面找到
		if not _is_enemy(owner, node):
			continue
		if _is_dead(node):
			continue

		var dist_sq: float = owner_pos.distance_squared_to(node.global_position)
		if dist_sq <= nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = node

	return nearest


static func _is_enemy(owner: Node2D, target: Node) -> bool:
	if target.has_method("是敌对"):
		return target.是敌对(owner)
	if target.has_method("判断关系"):
		return target.判断关系(target) == 阵营管理器.关系.敌对
	# 通过阵营管理器判断
	if target.has_method("获取阵营"):
		return 阵营管理器.是敌对(owner.获取阵营(), target.获取阵营())
	return false


static func _is_dead(node: Node) -> bool:
	var hc: HealthComponent = node.get_node_or_null("HealthComponent") as HealthComponent
	if hc:
		return hc.is_dead()
	if "当前生命值" in node:
		return node.当前生命值 <= 0
	if "hp" in node:
		var hp_val = node.get("hp")
		return hp_val <= 0 if typeof(hp_val) == TYPE_FLOAT else false
	return false
