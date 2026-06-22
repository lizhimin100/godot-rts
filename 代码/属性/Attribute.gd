class_name Attribute extends Resource  #属性

signal attribute_changed(attribute : Attribute)

@export var attribute_name : String
#属性的原始值（保持不变）
@export var base_value : = 0.0 :set = setter_base_value
#执行计算公式后数值
var current_value := 0.0 : set = setter_current_value

#存储运算操作对象数组（类型是AttributeModifier）
var modifiers :Array[AttributeModifier] = []
var attribute_set :
	get():
		return attribute_set.get_ref()

#region set的setter函数
func setter_base_value(v):
	base_value = v
	current_value = v
func setter_current_value(v):
	current_value = v
	attribute_changed.emit(self)
#endregion
# 添加修改器
func get_base_value() ->float:
	return base_value

func get_value() -> float:
	return current_value

func apply_modifier(mod : AttributeModifier):
	modifiers.append(mod)# 添加修改器
	current_value = _compute_value()# 重新计算当前值
# 移除修改器
func remove_modifier(mod : AttributeModifier):
	modifiers.erase(mod)
	current_value = _compute_value()

#数值计算 ,计算最终值
func _compute_value() -> float:
	var compuet_result = 0.0
	#计算公式运算的结果
	# 获取依赖属性
	var dervied_attribute : Array[Attribute] = []#获取计算属性的数组
	var dervied_attribute_names = derived_from()# 获取依赖类属性名列表
	# 通过属性集获取依赖属性实例
	for _name in dervied_attribute_names : #依次从属性集中获取属性对象
		var _attribute = attribute_set.find_attribute(_name)#赋值给属性数组
		dervied_attribute.append(_attribute)#将依赖属性的数组作为参数传入属性计算公式
	 # 调用自定义计算函数
	compuet_result = custom_compute(dervied_attribute)
	#修改器运算结果
	for mod in modifiers:
		compuet_result = mod.operate(compuet_result)
	
	return compuet_result 
# 自定义计算函数（子类可重写）,属性自定义计算公式，子类继承可重写该函数
func custom_compute(_compute_params : Array[Attribute]) -> float:
	return base_value
# 返回依赖属性列表（子类可重写）
func derived_from() -> Array[String]:#属性依赖列表
	return []# 默认没有依赖属性
