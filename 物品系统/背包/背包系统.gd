extends Resource   # 继承自 Resource 类，使该类成为可序列化的资源
class_name 背包父系统  # 定义类名为 "背包父系统"

@export var 存储物品列表 : Array [物品]  # 导出变量 "存储物品列表"，类型为 Array，用于存储背包中的物品
@export var 名字 : String  # 导出变量 "名字"，类型为 String，用于存储背包的名称

signal  物品发生变化 (indexes)  # 定义一个信号 "物品发生变化"，当背包中的物品发生变化时发出，传递变化的索引


# 函数：交换物品
# 参数：
# - index: 要交换的物品的索引
# - target_index: 目标索引，用于交换
func 交换物品 (index,target_index):
	var 物 = 存储物品列表 [index] # 获取要交换的物品
	var 交换物 = 存储物品列表 [target_index]  # 获取目标位置的物品
	if 物 is 物品 and 交换物 is 物品 and 物.物品名字 == 交换物.物品名字 : #判断物和交换物是否有数量，以及是否同名，是便叠加，否则执行下面交换
		交换物.数量 += 物.数量
		存储物品列表[index] = null
	else :
		存储物品列表 [target_index] = 物  # 将要交换的物品放到目标位置
		存储物品列表 [index] = 交换物 # 将目标位置的物品放到原位置
	emit_signal("物品发生变化",[index,target_index]) # 发出信号，通知物品发生变化，并传递变化的索引

	# 函数：删除物品
# 参数：
# - index: 要删除的物品的索引
func 删除物品 (index):
	if 存储物品列表[index] is 物品 :
		存储物品列表[index] = null  # 将指定索引的物品设置为 null，表示删除
		emit_signal("物品发生变化",[index]) # 发出信号，通知物品发生变化，并传递变化的索引

# 函数：设置物品数量
# 参数：
# - index: 物品的索引
# - ltem: 要设置的物品（注意拼写错误，应为 "item"）
# - number: 物品的数量
func 设置物品数量 (index,item,number):
	存储物品列表 [index] = item # 设置指定索引的物品
	if item != null :
		存储物品列表[index].number = number # 如果物品不为 null，设置其数量
	emit_signal("物品发生变化",[index]) # 发出信号，通知物品发生变化，并传递变化的索引
	
