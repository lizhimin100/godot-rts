extends RefCounted
## RPG Maker 风格四向奔跑：3×4 格、每格 48×48，整图 144×192。
## 切帧与动画命名与项目根目录 `rpgmaker.tscn` 一致（行序：下、左、右、上；帧序 0-1-2-1）。

const FRAME_W := 48
const FRAME_H := 48
const COLS := 3
const ROWS := 4

const _ANIMS := [
	{"name": "rundown", "row": 0, "speed": 5.0},
	{"name": "runleft", "row": 1, "speed": 5.0},
	{"name": "runright", "row": 2, "speed": 5.0},
	{"name": "runup", "row": 3, "speed": 5.0},
]


func build_sprite_frames(texture: Texture2D) -> SpriteFrames:
	if texture == null:
		return null
	var tw := texture.get_width()
	var th := texture.get_height()
	if tw != COLS * FRAME_W or th != ROWS * FRAME_H:
		return null
	var sf := SpriteFrames.new()
	var frame_cols := [0, 1, 2, 1]
	for anim in _ANIMS:
		var anim_name: String = anim.name
		var row: int = anim.row
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, true)
		sf.set_animation_speed(anim_name, float(anim.speed))
		for ci in frame_cols:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(ci * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
			sf.add_frame(anim_name, atlas, 1.0)
	return sf
