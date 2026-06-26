extends Sprite2D
@export var 迷雾宽度 : int = 2000
@export var 迷雾长度 : int = 2000
var 图片 : Image
var 图片纹理 : ImageTexture

@export var 光源纹理 : Texture2D  #在迷雾里的笔刷
var 光源图片 : Image

var 再生迷雾图片 : Image
var 再生迷雾纹理 : ImageTexture

@export var 视野玩家 : CharacterBody2D
@export var 视野单位组 : String = ""

var _帧计数 := 0

func _ready() -> void:
	图片 = Image.create_empty(迷雾宽度 , 迷雾长度 , false , Image.FORMAT_RGBA8)
	图片.fill(Color.WHEAT)
	图片纹理 = ImageTexture.create_from_image(图片)
	texture = 图片纹理

	再生迷雾图片 = Image.create_empty(迷雾宽度 , 迷雾长度 , false , Image.FORMAT_RGBA8)
	再生迷雾图片.fill(Color.WHITE)
	再生迷雾纹理 = ImageTexture.create_from_image(再生迷雾图片)
	material.set_shader_parameter("current_texture" , 再生迷雾纹理)

	if 光源纹理:
		光源图片 = 光源纹理.get_image()

	# 延迟到场景完全就绪后再算第一次迷雾
	call_deferred("_第一次计算迷雾")

func _process(_delta: float) -> void:
	var 单位列表 = _取视野单位列表()
	if 单位列表.is_empty():
		return
	_帧计数 += 1
	# 每 3 帧更新一次
	if _帧计数 % 3 == 0:
		计算迷雾(单位列表)


func _取视野单位列表() -> Array:
	if 视野玩家:
		return [视野玩家]
	if 视野单位组 != "":
		var 组 = get_tree().get_nodes_in_group(视野单位组)
		var 结果: Array = []
		for 单位 in 组:
			if is_instance_valid(单位):
				结果.append(单位)
		return 结果
	return []


func 计算迷雾(单位列表: Array) -> void :
	if 单位列表.is_empty() or not 光源图片:
		return

	# 当前帧迷雾：从全白开始，逐个单位绘制视野
	再生迷雾图片.fill(Color.WHITE)

	for 单位 in 单位列表:
		if not is_instance_valid(单位):
			continue
		var 玩家位置 = 单位.global_position + Vector2(迷雾宽度 , 迷雾长度) / 2 - position
		玩家位置 -= Vector2(光源图片.get_size()) / 2

		# 永久迷雾：blend_rect 只会变暗不会变浅，所以直接画多个单位不会丢失已探索区域
		图片.blend_rect(光源图片 , Rect2i(Vector2.ZERO , 光源图片.get_size()) ,  玩家位置 )

		# 当前帧迷雾：画每个单位的视野
		再生迷雾图片.blend_rect(光源图片 , Rect2i(Vector2.ZERO , 光源图片.get_size()) ,  玩家位置 )

	图片纹理.update(图片)
	再生迷雾纹理.update(再生迷雾图片)

func _第一次计算迷雾() -> void:
	计算迷雾(_取视野单位列表())
