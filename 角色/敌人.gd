extends CharacterBody2D # 继承自 CharacterBody2D 节点，适用于2D物理运动
class_name 自动追击敌人


# ███ 配置参数 ███
@export var 移动速度 = 200
@export var 玩家节点 : CharacterBody2D 
@onready var 导航 = $"导航/自动寻路组件"

func _physics_process(delta: float) -> void:
	var 移动方向 = to_local(导航.get_next_path_position()) . normalized() #将方向归一化，变成值为1的方向向量
	velocity = 移动方向 * 移动速度 #设置敌人的速度
	move_and_slide()

func _on_timer_timeout() -> void:
	导航.target_position = 玩家节点.position #每隔0.1秒将玩家节点位置更新给导航
