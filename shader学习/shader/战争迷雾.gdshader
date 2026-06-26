shader_type canvas_item;

uniform vec4 for_color : source_color ;
uniform sampler2D current_texture ;

void fragment() {
	COLOR.rgb = for_color.rgb;
	// TEXTURE = 永久迷雾: r=1(未探索), r=0(已探索)
	// current_texture = 子视口(当前视野): r=1(可见), r=0(不可见)
	// 公式: α = 未探索 + (1 - 当前可见) * 0.5
	//   未探索且不可见 → α=1.0 (全黑)
	//   已探索但当前不可见 → α=0.5 (半透明白色，迷雾回退)
	//   当前可见 → α=0.0 (全透明)
	COLOR.a = texture(TEXTURE, UV).r + (1.0 - texture(current_texture, UV).r) * 0.5;
}
