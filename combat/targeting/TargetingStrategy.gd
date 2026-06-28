class_name TargetingStrategy
extends RefCounted

## 目标选择策略基类
##
## 子类必须实现 find_target(owner, search_range) → Node2D
## 返回找到的目标，无目标时返回 null

func find_target(_owner: Node2D, _search_range: float) -> Node2D:
	return null
