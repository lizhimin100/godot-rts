class_name 属性组件 extends Node

@export var 属性集 : AttributeSet

#region 外部函数
func 获取属性数组(attribute_name : String) -> float:
	var attribute = 属性集.find_attribute(attribute_name)
	return attribute.get_value()
	

func 获取属性对象 (attribute_name : String) -> Attribute:
	return 属性集.find_attribute(attribute_name)


#endregion
