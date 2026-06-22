shader_type canvas_item;

uniform vec4 for_color : source_color ;
uniform sampler2D current_texture ;

void fragment() {
	COLOR.rgb = for_color.rgb ;
	COLOR.a = texture(TEXTURE , UV).r + texture(current_texture , UV).r / 2.0  ; //调整rgb值时，不能动r的值，不然迷雾透明度有问题
	//获取第一个和第二个采样结果的值除以2，作为迷雾透明度
}
