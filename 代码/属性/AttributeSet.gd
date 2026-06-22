class_name AttributeSet extends Resource #属性集
#导出的编辑器可编辑的属性数组
@export var attributes : Array[Attribute] = [] : set = setter_arrtibutes


#运行的数据，缓存字典（属性名->属性实例）
var attributes_runtime_dict : Dictionary[String , Attribute] = {}
# attributes的setter函数
func setter_arrtibutes(v):
	attributes = v# 设置属性数组
	
	attributes_runtime_dict.clear()# 清空缓存字典
	
	# 遍历所有属性
	for attr in attributes:
		if attributes_runtime_dict.has(attr.attribute_name):# 检查重复属性名
			push_warning("Attributeset,属性集有重复的属性名称%s" % attr.attribute_name )
			continue
			
		#构建属性集的缓存， 复制属性（避免引用问题）
		var duplicated_attribute = attr.duplicate(true) as Attribute
		duplicated_attribute.attribute_set = weakref(self)# 设置属性集的引用
		# 添加到缓存字典
		attributes_runtime_dict[attr.attribute_name] = duplicated_attribute
		# 连接属性变化信号
		duplicated_attribute.attribute_changed.connect(_on_attribute_changed)
# 按名称查找属性
func find_attribute(attribute_name : String) -> Attribute:
	if attributes_runtime_dict.has(attribute_name):
		return attributes_runtime_dict[attribute_name]
	push_error("AttributeSet,属性集未能找到指定的属性对象")
	return null



#region 信号通知
func _on_attribute_changed(attribute : Attribute):
	pass# 默认不做处理，但可以在这里添加全局响应逻辑
#endregion
