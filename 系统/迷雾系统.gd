extends Node

## 迷雾系统 — 阵营视野管理（分块更新）
##
## 视觉：
##   alpha=1.0 全黑（从未探索）
##   alpha=0.55 灰暗（已探索不在视野）
##   alpha=0.0 透明（当前可见）
##
## 规则：己方+友方提供视野，同阵营共享，敌人不提供视野
##
## ⚠ 分块架构：
##   - 1024×1024 网格 → 64×64 chunks (每块 16×16)
##   - 前后帧视野差异：离开视野的 chunk 标记为脏 + 探索值降级
##   - ❌ 不能有全屏 1000×1000 循环

signal 迷雾已更新

static var 实例: 迷雾系统 = null

var 视野来源表: Dictionary = {}

# ========== 网格参数 ==========
const 图宽: int = 2048
const 图高: int = 2048
const 网格宽: int = 1024
const 网格高: int = 1024
const 像元: float = float(图宽) / float(网格宽)  # 2.0
const 雾偏移: Vector2 = Vector2(524, 314)
const 视野格: int = int(150.0 / 像元)  # 约 75

# ========== 分块参数 ==========
const CHUNK_SIZE: int = 16
const CHUNK_COLS: int = 网格宽 / CHUNK_SIZE  # 64
const CHUNK_ROWS: int = 网格高 / CHUNK_SIZE  # 64

# ========== 渲染 ==========
var 渲染图: Image
var 渲染纹理: ImageTexture
var 迷雾精灵: Sprite2D = null

# ========== 已探索累积 ==========
var 探索图: Image  # R8 = 已探索程度 (0~255)

# ========== 帧控制 ==========
var _帧计数 := 0
var _已初始化 := false

# ========== 脏块队列 ==========
var _脏块: Array = []
var _脏块集: Dictionary = {}

# ========== 前后帧视野差异 ==========
## 上一帧的可见 chunk 集合（key = cxx + cyy * CHUNK_COLS）
var _上一帧视野块: Dictionary = {}

# 初始全展开标志
var _初始渲染完成: bool = false


func _enter_tree() -> void:
	实例 = self


func _exit_tree() -> void:
	if 实例 == self: 实例 = null


func _ready() -> void:
	渲染图 = Image.create_empty(网格宽, 网格高, false, Image.FORMAT_RGBA8)
	渲染图.fill(Color(0, 0, 0, 1))
	渲染纹理 = ImageTexture.create_from_image(渲染图)

	探索图 = Image.create_empty(网格宽, 网格高, false, Image.FORMAT_RGBA8)
	探索图.fill(Color.BLACK)


func _process(delta: float) -> void:
	if not _已初始化:
		_初始化精灵()
		return
	_帧计数 += 1
	if _帧计数 % 3 == 0:
		var 来源 = 收集视野来源()
		if not 来源.is_empty():
			更新迷雾(来源)


# ============================================================
# 视野来源
# ============================================================

func 注册视野来源(unit: Node2D) -> void:
	if not is_instance_valid(unit): return
	var t = _取阵营(unit)
	if not 视野来源表.has(t): 视野来源表[t] = []
	if unit not in 视野来源表[t]: 视野来源表[t].append(unit)


func 注销视野来源(unit: Node2D) -> void:
	if not is_instance_valid(unit): return
	var t = _取阵营(unit)
	if 视野来源表.has(t):
		视野来源表[t].erase(unit)
		if 视野来源表[t].is_empty(): 视野来源表.erase(t)


func 收集视野来源() -> Array:
	var 结果: Array = []
	for t in 视野来源表.keys():
		if t == 阵营管理器.阵营.敌人: continue
		for s in 视野来源表[t]:
			if is_instance_valid(s) and s not in 结果: 结果.append(s)
	return 结果


# ============================================================
# 可见性查询
# ============================================================

func 对阵营可见(世界坐标: Vector2, 阵营ID: int) -> bool:
	if 阵营ID == 阵营管理器.阵营.敌人: return false
	for s in 视野来源表.get(阵营ID, []):
		if is_instance_valid(s) and 世界坐标.distance_squared_to(s.global_position) <= 150 * 150:
			return true
	return false


func 单位对阵营可见(单位: Node2D, 阵营ID: int) -> bool:
	return is_instance_valid(单位) and 对阵营可见(单位.global_position, 阵营ID)


# ============================================================
# 核心更新（分块 + 前后帧差异）
# ============================================================

func 更新迷雾(来源列表: Array) -> void:
	if 来源列表.is_empty(): return

	# ---- 1. 计算当前视野块 ----
	var 当前视野块: Dictionary = {}
	for 单位 in 来源列表:
		if not is_instance_valid(单位): continue
		var c = _到网格(单位.global_position)
		_收集圆覆盖块(当前视野块, c.x, c.y, 视野格)

	# ---- 2. 前后帧差异：找"失去视野"的块 ----
	var 失去视野块: Array = []
	for key in _上一帧视野块:
		if not 当前视野块.has(key):
			失去视野块.append(key)

	# ---- 3. 已探索累积（画圆写入探索图，值=255） ----
	for 单位 in 来源列表:
		if not is_instance_valid(单位): continue
		var c = _到网格(单位.global_position)
		_叠加圆(探索图, c.x, c.y, 视野格, 255)

	# ---- 4. 失去视野块的探索值降级（255→128，表示"已探索但不可见"） ----
	for key in 失去视野块:
		var cxx = key % CHUNK_COLS
		var cyy = key / CHUNK_COLS
		_降级块探索值(cxx, cyy)

	# ---- 5. collect dirty chunks = current vision union lost vision ----
	_脏块.clear()
	_脏块集.clear()
	for key in 当前视野块:
		var _c = Vector2i(key % CHUNK_COLS, key / CHUNK_COLS)
		_脏块集[key] = true
		_脏块.append(_c)
	for key in 失去视野块:
		if not _脏块集.has(key):
			_脏块集[key] = true
			var _c = Vector2i(key % CHUNK_COLS, key / CHUNK_COLS)
			_脏块.append(_c)

	# ---- 6. 初始全展开（首次更新时添加所有已探索块） ----
	if not _初始渲染完成:
		_添加已探索块()
		_初始渲染完成 = true

	# ---- 7. 更新所有脏块 ----
	var 更新数 = _更新脏块()
	if 更新数 > 0:
		渲染纹理.update(渲染图)
		迷雾已更新.emit()

	# ---- 8. 保存当前帧视野 ----
	_上一帧视野块 = 当前视野块.duplicate()


# ============================================================
# 分块收集与差异处理
# ============================================================

func _收集圆覆盖块(out_dict: Dictionary, cx: int, cy: int, r: int) -> void:
	"""将圆覆盖的所有 chunk key 写入 out_dict"""
	var min_cx = max(0, (cx - r) / CHUNK_SIZE)
	var max_cx = min(CHUNK_COLS - 1, (cx + r) / CHUNK_SIZE)
	var min_cy = max(0, (cy - r) / CHUNK_SIZE)
	var max_cy = min(CHUNK_ROWS - 1, (cy + r) / CHUNK_SIZE)
	for cyy in range(min_cy, max_cy + 1):
		for cxx in range(min_cx, max_cx + 1):
			out_dict[cxx + cyy * CHUNK_COLS] = true


func _降级块探索值(cxx: int, cyy: int) -> void:
	"""将块内探索值从 255 降低到 192，表示"已探索但当前不可见"
	   这样渲染时显示为灰色（alpha=0.55）"""
	var ox = cxx * CHUNK_SIZE
	var oy = cyy * CHUNK_SIZE
	for y in range(CHUNK_SIZE):
		var gy = oy + y
		for x in range(CHUNK_SIZE):
			var gx = ox + x
			var cur = 探索图.get_pixel(gx, gy).r8
			if cur > 192:
				# 只有当前可见（值=255）的像素才降级为192
				# 旧探索值（<192）保持不变
				探索图.set_pixel(gx, gy, Color8(192, 0, 0, 255))


# ============================================================
# 脏块处理
# ============================================================

func _更新脏块() -> int:
	if _脏块.is_empty():
		return 0

	for coord in _脏块:
		_更新单个块(coord.x, coord.y)

	var count = _脏块.size()
	_脏块.clear()
	_脏块集.clear()
	return count


func _更新单个块(chunk_x: int, chunk_y: int) -> void:
	"""全量重绘一个 chunk（探索 + 可见）"""
	var ox = chunk_x * CHUNK_SIZE
	var oy = chunk_y * CHUNK_SIZE

	# 从探索图渲染基础颜色：灰暗或全黑
	for y in range(CHUNK_SIZE):
		var gy = oy + y
		for x in range(CHUNK_SIZE):
			var gx = ox + x
			if 探索图.get_pixel(gx, gy).r8 > 20:
				渲染图.set_pixel(gx, gy, Color(0, 0, 0, 0.55))
			else:
				渲染图.set_pixel(gx, gy, Color(0, 0, 0, 1))

	# 应用当前视野透明圆
	var 来源 = 收集视野来源()
	for 单位 in 来源:
		if not is_instance_valid(单位): continue
		var uc = _到网格(单位.global_position)
		if abs(uc.x - (ox + CHUNK_SIZE / 2)) > 视野格 + CHUNK_SIZE / 2:
			continue
		if abs(uc.y - (oy + CHUNK_SIZE / 2)) > 视野格 + CHUNK_SIZE / 2:
			continue
		_涂圆在块内(渲染图, ox, oy, uc.x, uc.y, 视野格)


func _添加已探索块() -> void:
	"""初始全展开：找出所有已探索块加入脏队列"""
	for cyy in range(CHUNK_ROWS):
		for cxx in range(CHUNK_COLS):
			var ox = cxx * CHUNK_SIZE
			var oy = cyy * CHUNK_SIZE
			var has_explored := false
			for y in range(CHUNK_SIZE):
				for x in range(CHUNK_SIZE):
					if 探索图.get_pixel(ox + x, oy + y).r8 > 20:
						has_explored = true
						break
				if has_explored: break
			if has_explored:
				var key = cxx + cyy * CHUNK_COLS
				if not _脏块集.has(key):
					_脏块集[key] = true
					_脏块.append(Vector2i(cxx, cyy))


# ============================================================
# 圆绘制（chunk 内）
# ============================================================

func _涂圆在块内(图: Image, ox: int, oy: int, cx: int, cy: int, r: int) -> void:
	var min_x = max(ox, cx - r)
	var max_x = min(ox + CHUNK_SIZE - 1, cx + r)
	var min_y = max(oy, cy - r)
	var max_y = min(oy + CHUNK_SIZE - 1, cy + r)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dx = x - cx
			var dy = y - cy
			if dx * dx + dy * dy <= r * r:
				图.set_pixel(x, y, Color(0, 0, 0, 0))


# ============================================================
# 内部
# ============================================================

func _到网格(世界坐标: Vector2) -> Vector2i:
	var v = 世界坐标 + Vector2(图宽, 图高) / 2 - 雾偏移
	return Vector2i(v / 像元)


func _叠加圆(图: Image, cx: int, cy: int, r: int, 灰度: int) -> void:
	"""在探索图上叠加圆（累积式，只增不减）"""
	for y in range(max(0, cy - r), min(网格高, cy + r + 1)):
		for x in range(max(0, cx - r), min(网格宽, cx + r + 1)):
			var dx = x - cx
			var dy = y - cy
			if dx * dx + dy * dy <= r * r:
				var 现 = 图.get_pixel(x, y).r8
				if 灰度 > 现: 图.set_pixel(x, y, Color8(灰度, 0, 0, 255))


func _取阵营(unit: Node2D) -> int:
	if unit.has_method("获取阵营"): return unit.获取阵营()
	return 0


func _初始化精灵() -> void:
	var tree = get_tree()
	if not tree or not tree.current_scene: return

	var existing = tree.root.find_child("迷雾覆盖层", true, false) as Sprite2D
	if existing:
		迷雾精灵 = existing
	else:
		迷雾精灵 = Sprite2D.new()
		迷雾精灵.name = "迷雾覆盖层"
		迷雾精灵.position = 雾偏移
		迷雾精灵.z_index = 100
		迷雾精灵.centered = true
		tree.current_scene.add_child(迷雾精灵)

	迷雾精灵.scale = Vector2(float(图宽) / float(网格宽), float(图高) / float(网格高))
	迷雾精灵.texture = 渲染纹理
	迷雾精灵.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_已初始化 = true

	var 来源 = 收集视野来源()
	if not 来源.is_empty(): 更新迷雾(来源)
