shader_type canvas_item;

uniform float outline_with = 1.0 ; //描边宽度
uniform vec4 outline_color : source_color = vec4(0 , 0 , 0 , 1) ;//设置变量纯黑色不透明的轮廓颜色


void fragment(){
	vec2 uv = UV;

	vec2 uv_up = uv + vec2(0 , TEXTURE_PIXEL_SIZE.y) * outline_with ;
	vec2 uv_down = uv + vec2(0 , -TEXTURE_PIXEL_SIZE.y) * outline_with ;
	vec2 uv_left = uv + vec2(TEXTURE_PIXEL_SIZE.x , 0) * outline_with ;
	vec2 uv_right = uv + vec2(-TEXTURE_PIXEL_SIZE.x , 0) * outline_with ;

	// 采样前检查UV是否在[0,1]范围内（region_rect边界保护）
	// 防止越界采样到精灵图相邻行的像素导致"多行"显示问题
	float a_up = (uv_up.y <= 1.0 && uv_up.y >= 0.0) ? texture(TEXTURE , uv_up).a : 0.0;
	float a_down = (uv_down.y <= 1.0 && uv_down.y >= 0.0) ? texture(TEXTURE , uv_down).a : 0.0;
	float a_left = (uv_left.x <= 1.0 && uv_left.x >= 0.0) ? texture(TEXTURE , uv_left).a : 0.0;
	float a_right = (uv_right.x <= 1.0 && uv_right.x >= 0.0) ? texture(TEXTURE , uv_right).a : 0.0;

	float outline_alpha = a_up + a_down + a_left + a_right ;
	outline_alpha = min(outline_alpha , 1) ;

	vec4 original_color = texture(TEXTURE , UV);
	vec4 outline = vec4(outline_color.rgb, outline_alpha);

	COLOR = mix(outline , original_color , original_color.a);
}
