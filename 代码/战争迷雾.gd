extends Sprite2D
@export var 迷雾宽度 : int
@export var 迷雾长度 : int
var 图片 : Image 
var 图片纹理 : ImageTexture

@export var 光源纹理 : Texture2D  #在迷雾里的笔刷
var 光源图片 : Image

var 再生迷雾图片 : Image
var 再生迷雾纹理 : ImageTexture


@export var 视野玩家 : CharacterBody2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	图片 = Image.create_empty(迷雾宽度 , 迷雾长度 , false , Image.FORMAT_RGBA8)
	图片.fill(Color.WHEAT)
	图片纹理 = ImageTexture.create_from_image(图片)
	texture = 图片纹理
	
	再生迷雾图片 = 图片.duplicate()
	再生迷雾纹理 = 图片纹理.duplicate()
	material.set_shader_parameter("current_texture" , 再生迷雾纹理) #设置着色器中current_texture的纹理是什么
	
	光源图片 = 光源纹理.get_image()
	
	计算迷雾()

func _process(_delta: float) -> void:
	if 视野玩家.velocity != Vector2.ZERO :
		计算迷雾()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func 计算迷雾() -> void :
	var 玩家位置 = 视野玩家.global_position + Vector2(迷雾宽度 , 迷雾长度) / 2- position #矫正笔刷点亮迷雾为玩家位置
	玩家位置 -= Vector2(光源图片.get_size()) / 2
	图片.blend_rect(光源图片 , Rect2i(Vector2.ZERO , 光源图片.get_size()) ,  玩家位置 )#实现笔刷涂抹
#更新迷雾纹理
	图片纹理.update(图片)
	
	再生迷雾图片.fill(Color.WHITE)#让战争迷雾能再生
	再生迷雾图片.blend_rect(光源图片 , Rect2i(Vector2.ZERO , 光源图片.get_size()) ,  玩家位置 )
	再生迷雾纹理.update(再生迷雾图片)
