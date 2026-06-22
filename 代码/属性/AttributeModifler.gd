class_name AttributeModifier extends Resource  #修改器

enum OperationType {
	ADD,# 加法
	SUB,# 减法
	MULT,# 乘法
	DIVIDE,# 除法
	SET,# 直接设置
}

var type : OperationType # 操作类型
var value : float # 操作值
# 构造函数
func _init(_type : OperationType = OperationType.ADD , _value : float = 0.0 ) -> void:
	type = _type
	value = _value
# 静态方法：创建加减乘除等修改器
static  func add (_value : float) -> AttributeModifier:#加法公式
	return AttributeModifier.new(OperationType.ADD , _value)

static  func subtract (_value : float) -> AttributeModifier:#减法公式
	return AttributeModifier.new(OperationType.SUB , _value)

static  func multiply (_value : float) -> AttributeModifier:#乘法公式
	return AttributeModifier.new(OperationType.MULT , _value)

static  func divide (_value : float) -> AttributeModifier:#除法公式
	return AttributeModifier.new(OperationType.DIVIDE , _value)

static  func forcefully_set_value (_value : float) -> AttributeModifier:#除法公式
	return AttributeModifier.new(OperationType.SET , _value)
# 执行操作
func operate (_base_value : float):
	match type :
		OperationType.ADD :return _base_value + value
		OperationType.SUB :return _base_value - value
		OperationType.MULT :return _base_value * value
		# 避免除零错误
		OperationType.DIVIDE :return 0.0 if is_zero_approx(value) else _base_value / value
		OperationType.SET :return value 
	return 0.0
