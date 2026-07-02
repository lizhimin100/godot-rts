@tool
extends Node

# 说明：
# 1) 该脚本来自外部项目，仅做“预制商店参考”保留。
# 2) 原版依赖 InventoryManager/GameState/SaveGame/InventorySlot 等项目单例，
#    在通用插件工程中会触发 Parse Error。
# 3) 因此这里改成可编译占位脚本，确保插件导入任意项目时不会因它报错。

@export var reference_only := true
