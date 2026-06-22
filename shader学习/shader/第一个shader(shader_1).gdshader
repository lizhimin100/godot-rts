shader_type canvas_item;

//void vertex函数是顶点着色器，四个顶点，同时渲染
void vertex() {
	// Called for every vertex the material is visible on.
}

//void fragment 是片段着色器，在平面上表示像素，所有像素都会多线程的使用、调用该函数
void fragment() {
	COLOR =texture(TEXTURE , UV) ;
	//将图像纹理上的每一个像素颜色显示出来，获取图片所有颜色
	COLOR = COLOR * vec4(1.0 , 1.0 , 0.0 , 1.0) ; //能调整图片颜色
	//对应着 红色，绿色，蓝色，透明度
	//可以用（COLOR.d , COLOR.g ,COLOR.b ， COLOR.a）等方式，忽略通道，获取某一通道
	// Called for every pixel the material is visible on.
}


//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
