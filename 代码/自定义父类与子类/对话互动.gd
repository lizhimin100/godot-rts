class_name 对话互动
extends 互动

@export var 对话序列 : Array[String] = ["开场", "询问"]  # 按顺序配置对话线 # 导出对话内容
@onready var 策略相机: Camera2D = $"../../../../策略相机"

var 当前对话阶段 : int = 0  # 当前播放的对话阶段索引 

# Called when the node enters the scene tree for the first time.


func 对话交互逻辑(交互者: Node) -> void  :
	super.对话交互逻辑(交互者) #用super关键字先调用父类函数逻辑，再接上子类代码逻辑
	if 当前对话阶段 >= 对话序列.size(): #如果数组使用的索引大于等于（尤其是等于）数组大小时，代表数组已全部完成
		print("所有对话已完成")
		交互者.对话中 = false
		return
	#进行对话
	开始对话 = true
	print("当前阶段:", 当前对话阶段, "/", 对话序列.size())
	策略相机.聚焦对话位置(global_position)  #  传入NPC的位置，相机锁定
	Dialogic.start(对话序列[当前对话阶段])  #调用插件start方法
	print("对话实例类型: ", Dialogic.get_class()) # 检查对话实例是否有 timeline_ended 信号


func 对话阶段():
	当前对话阶段 += 1


func 角色移动 () :
	if 当前交互者:
		if 当前交互者.has_method("结束对话") :
			当前交互者.结束对话()
			print("成功调用 当前交互者.结束对话 方法")
		else:
			print("当前交互者 节点没有 结束对话 方法")
	else:
		print("当前交互者 为空，无法调用 结束对话 方法")


func _ready() -> void:
	if !策略相机:
		print("无法找到策略相机节点，请检查节点路径。")
	Dialogic.timeline_ended.connect(self.角色移动)  # ✅ 重复 角色回复移动关键行连接信号
	Dialogic.timeline_ended.connect(策略相机.重置相机)  # ✅ 重复 相机恢复关键行连接信号
	Dialogic.timeline_ended.connect(self.对话阶段)  # ✅ 重复 对话阶段和对话时间线关键行连接信号

func _process(_delta: float) -> void:
	if not 策略相机:
		策略相机 = get_node_or_null("../../../../场景/策略相机")
		if 策略相机:
			print("策略相机节点已加载。")
