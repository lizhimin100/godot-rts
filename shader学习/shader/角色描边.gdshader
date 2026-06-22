shader_type canvas_item;

uniform float outline_with = 1.0 ; //描边宽度
uniform vec4 outline_color : source_color = vec4(0 , 0 , 0 , 1) ;//设置变量纯黑色不透明的轮廓颜色


void fragment(){
	vec2 uv = UV;

	vec2 uv_up = uv + vec2(0 , TEXTURE_PIXEL_SIZE.y) * outline_with ;
	vec2 uv_down = uv + vec2(0 , -TEXTURE_PIXEL_SIZE.y) * outline_with ;
	vec2 uv_left = uv + vec2(TEXTURE_PIXEL_SIZE.x , 0) * outline_with ;
	vec2 uv_right = uv + vec2(-TEXTURE_PIXEL_SIZE.x , 0) * outline_with ;

	vec4 color_up = texture(TEXTURE , uv_up) ;
	vec4 color_down = texture(TEXTURE , uv_down) ;
	vec4 color_left = texture(TEXTURE , uv_left) ;
	vec4 color_right = texture(TEXTURE , uv_right) ;
	vec4 outline = color_up + color_down + color_left + color_right ;
	outline.rgb = outline_color.rgb; //描边轮廓颜色
	outline.a = min(outline.a , 1);//限制透明度最大是1
	vec4 original_color = texture(TEXTURE , UV);  //原本立绘颜色
	COLOR = mix(outline , original_color , original_color.a); // 混合计算，四个采集图像和原本立绘叠加
	//原本的立绘透明度＝1，显示立绘，原本立绘无显示，透明度不为1，显示描边
}