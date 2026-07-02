@tool
extends RefCounted

const AI_LIBRARY_BASE := "res://AI资源库"
## 默认扫描根（一图全动作）；须为字面量：const 内不能调用 path_join 等方法，否则脚本会编译失败并导致 RepoScript.new() 报错。
const NPC_ROOT_DEFAULT := "res://AI资源库/一图全动作"

func scan_npc_files(root: String = NPC_ROOT_DEFAULT) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(root):
		return result
	_scan_flat_character_folders(root, result)
	if result.is_empty():
		_scan_dir_recursive(root, result)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: Dictionary = a.get("data", {})
		var db: Dictionary = b.get("data", {})
		var ea: Dictionary = da.get("ext", {})
		var eb: Dictionary = db.get("ext", {})
		var pa := int(ea.get("librarySortPriority", 9999))
		var pb := int(eb.get("librarySortPriority", 9999))
		if pa != pb:
			return pa < pb
		return String(a.get("displayName", a.get("id", ""))) < String(b.get("displayName", b.get("id", "")))
	)
	return result


## 新目录约定：一图全动作/<角色文件夹>/npc.json（无 古风/任务类 等中间层）
func _scan_flat_character_folders(root: String, out_items: Array[Dictionary]) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var full := root.path_join(name)
		if not dir.current_is_dir():
			continue
		var json_path := ""
		for fname in ["npc.json", "NPC.json", "fx.json"]:
			var cand := full.path_join(fname)
			if FileAccess.file_exists(cand):
				json_path = cand
				break
		if json_path == "":
			continue
		var item := _build_item(json_path, false)
		if not item.is_empty():
			out_items.append(item)
	dir.list_dir_end()


func load_npc_json(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var text := FileAccess.get_file_as_string(file_path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func save_npc_json(file_path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t", false))
	return true


func validate_npc_data(data: Dictionary, expected_id: String = "", require_id_match_folder: bool = true, require_spritesheet: bool = true) -> PackedStringArray:
	var errors := PackedStringArray()
	var required_root: Array = ["schemaVersion", "meta", "assets", "gameplay", "ext"]
	if require_spritesheet:
		required_root.insert(3, "spritesheet")
	for key in required_root:
		if not data.has(key):
			errors.append("缺少根字段: %s" % key)

	if data.get("schemaVersion", -1) != 1:
		errors.append("schemaVersion 必须为 1")

	var meta: Dictionary = data.get("meta", {})
	var assets: Dictionary = data.get("assets", {})

	if require_id_match_folder and expected_id != "" and meta.get("id", "") != expected_id:
		errors.append("meta.id 与目录名不一致")

	if not meta.has("displayName"):
		errors.append("meta.displayName 缺失")
	if not meta.has("style"):
		errors.append("meta.style 缺失")
	if not meta.has("category"):
		errors.append("meta.category 缺失")
	if assets.get("spritePath", "") == "":
		errors.append("assets.spritePath 缺失")
	else:
		var sp := String(assets.get("spritePath", "")).strip_edges()
		if sp.begins_with("res://") and not ResourceLoader.exists(sp):
			errors.append("assets.spritePath 指向的文件不在项目中或尚未导入（请把贴图拷进项目并等 Godot 导入完成）：%s" % sp)

	var thumb := String(assets.get("thumbPath", "")).strip_edges()
	if thumb != "" and thumb.begins_with("res://") and not ResourceLoader.exists(thumb):
		errors.append("assets.thumbPath 指向的文件不在项目中或尚未导入：%s" % thumb)

	return errors


func _scan_dir_recursive(path: String, out_items: Array[Dictionary]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			_scan_dir_recursive(full, out_items)
		elif name == "npc.json" or name == "NPC.json" or name == "fx.json":
			# 与 _scan_flat_character_folders 一致：不要求文件夹名以 npc_ 开头，避免新手嵌套目录时扫不到
			var item := _build_item(full, false)
			if not item.is_empty():
				out_items.append(item)
	dir.list_dir_end()


func _build_item(json_path: String, require_npc_prefix_folder: bool = true) -> Dictionary:
	var folder_name := json_path.get_base_dir().get_file()
	if require_npc_prefix_folder and not folder_name.begins_with("npc_"):
		return {}

	var data := load_npc_json(json_path)
	if data.is_empty():
		return {}

	var meta: Dictionary = data.get("meta", {})
	var gameplay: Dictionary = data.get("gameplay", {})
	var style := String(meta.get("style", ""))
	var category := String(meta.get("category", ""))
	var role := String(gameplay.get("role", ""))
	var tags: PackedStringArray = PackedStringArray()
	var tv: Variant = meta.get("tags", [])
	if tv is Array:
		for x in tv as Array:
			tags.append(String(x))
	var id_match := require_npc_prefix_folder
	var norm_path := json_path.replace("\\", "/")
	var under_rpgmaker := norm_path.find("/RPGMAKER/") >= 0
	var errors := validate_npc_data(data, folder_name if id_match else "", id_match, not under_rpgmaker)

	return {
		"id": String(meta.get("id", folder_name)),
		"displayName": String(meta.get("displayName", folder_name)),
		"style": style,
		"category": category,
		"tags": tags,
		"role": role,
		"path": json_path,
		"data": data,
		"errors": errors
	}
