extends RefCounted
## 程序生成椭圆形半透明脚底阴影贴图（与 AI像素商K 工程内 shadow_texture.gd 逻辑一致）。

const SHADOW_W := 20
const SHADOW_H := 8

func build_texture() -> ImageTexture:
	var img := Image.create(SHADOW_W, SHADOW_H, false, Image.FORMAT_RGBA8)
	var cx := SHADOW_W / 2.0
	var cy := SHADOW_H / 2.0
	var rx := maxf(cx - 0.5, 0.1)
	var ry := maxf(cy - 0.5, 0.1)
	for y in SHADOW_H:
		for x in SHADOW_W:
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			var d := dx * dx + dy * dy
			var a := 0.0
			if d <= 1.0:
				a = 0.78 * (1.0 - d * 0.35)
			img.set_pixel(x, y, Color(0, 0, 0, a))
	return ImageTexture.create_from_image(img)
