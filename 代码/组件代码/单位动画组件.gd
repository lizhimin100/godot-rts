class_name UnitAnimations extends Node#单位合成的动画组件

const COMBINE_ANIM_LENGTH := 0.6 #长度
const COMBINE_ANIM_SCALE := Vector2(0.7 , 0.7)#缩放比例
const COMBINE_ANIM_ALPHA := 0.5 #透明度

@export var unit : Unit

func play_combine_animation(target_position : Vector2) -> void:#动画结束抵达的位置
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	unit.血条.hide()
	unit.蓝条.hide()
	unit.等级图标.hide()
	tween.tween_property(unit , "global_position" , target_position , COMBINE_ANIM_LENGTH)
	tween.parallel().tween_property(unit , "scale" , COMBINE_ANIM_SCALE , COMBINE_ANIM_LENGTH)
	tween.parallel().tween_property(unit , "modulate:a" , COMBINE_ANIM_ALPHA , COMBINE_ANIM_LENGTH)
	tween.tween_callback(unit.queue_free)
