shader_type canvas_item;
varying vec2 center_uv;

uniform float scale_factor = 2.0 ;
uniform sampler2D screen_tex : hint_screen_texture , filter_nearest; //将屏幕渲染画风赋值给该变量
void vertex() {
	center_uv = (SCREEN_MATRIX * CANVAS_MATRIX * MODEL_MATRIX * vec4(0.5 , 0.5 , 0 , 1 )).xy ;//将局部坐标转换为齐次坐标,再用model转换为世界坐标
//计算出像素坐标在屏幕上的坐标
	center_uv = (center_uv + 1.0) / 2.0 ;
}

void fragment() {
	vec2 uv_difference = SCREEN_UV - center_uv ;
	vec2 modified_uv = uv_difference / scale_factor + center_uv ;

	vec4 sampled_color = texture(screen_tex , modified_uv) ;
	COLOR.rgb = sampled_color.rgb ;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
