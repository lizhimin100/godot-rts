extends 移动基类
class_name 人族步兵

enum State {
	IDLE,   # 待机状态
	CHASE,  # 追敌状态
	MOVE,    # 移动状态
	ATTACK   # 攻击状态
}

@export_group("战斗属性")
@export var 警戒范围: float = 300.0
@export var 攻击范围: float = 10.0


# 状态变量
var 当前状态: State = State.IDLE
var 索敌: bool = false
var 当前敌人: Node2D = null
#节点引用
@onready var 选中标签: Label = $选中标签
@onready var 索敌区域: Area2D = $索敌区域
@onready var 角色图像: Sprite2D = $角色图像
@onready var 角色动画: AnimationPlayer = $角色动画
@onready var 导航代理: NavigationAgent2D = $导航代理




func _ready() -> void:
	super._ready()
	当前状态 = State.IDLE
	选中标签.visible = false#初始化选中标签
# 配置索敌区域
	var 碰撞形状 = CircleShape2D.new()
	碰撞形状.radius = 警戒范围
	索敌区域.get_node("CollisionShape2D").shape = 碰撞形状
	索敌区域.body_entered.connect(_on_索敌区域_进入)
	索敌区域.body_exited.connect(_on_索敌区域_离开)

func _input(event) -> void:
	if not 选择状态: return
	if event.is_action_pressed("移动"):
		var 鼠标位置 = get_global_mouse_position()
		var 点击目标 = _获取点击目标(鼠标位置)
		if not 点击目标:
			_设置移动目标(鼠标位置)
			return
		if 点击目标.is_in_group("敌人"):_处理敌人点击(点击目标)
		else:_设置移动目标(鼠标位置)

func _设置移动目标(位置: Vector2) -> void:
	当前敌人 = null
	目标位置 = 位置
	切换状态(当前状态, State.MOVE)

func _处理敌人点击(敌人: Node2D) -> void:
	当前敌人 = 敌人
	索敌 = true
	match 当前状态:
		State.IDLE:
			切换状态(State.IDLE , State.CHASE)
			print(  "主动从├ 当前状态: %s" % "追敌")
		State.MOVE:
			切换状态(State.MOVE , State.CHASE)
		State.ATTACK:# 攻击状态下切换目标需要重置攻击计时
			切换状态(State.ATTACK , State.CHASE)

func _physics_process(delta: float) -> void:
	选中标签.visible = 选择状态
	match 当前状态: #在什么状态就做什么的逻辑
		State.IDLE:
			#print("待机中")
			_处理待机状态()
		State.CHASE:
			#print("追敌中")
			_处理追敌状态(delta)
		State.MOVE:
			#print("移动中")
			_处理移动状态(delta)

		State.ATTACK:  
			_处理攻击状态(delta)
	if 选择状态 and velocity.x != 0 : # 设置动画水平翻转（关键优化点）当x分量<0时向左移动，需要翻转精灵
		角色图像.flip_h = velocity.x < 0


func 切换状态(form: State , 新状态 : State): #进入什么状态要做什么
	match 当前状态:# 退出旧状态
		State.CHASE, State.ATTACK:pass
	match 新状态 :# 进入新状态
		State.IDLE:角色动画.play("待机")
		State.CHASE:角色动画.play("移动")
		State.MOVE:角色动画.play("移动")
		State.ATTACK: 角色动画.play("攻击")  # 第三参数为速度倍率

	
	当前状态 = 新状态


func _处理待机状态():
	索敌 = false
	if 当前敌人 and is_instance_valid(当前敌人) and not 索敌:# 自动检测敌人
		var 距离 = global_position.distance_to(当前敌人.global_position)
		if 距离 < 警戒范围 :
			索敌 = true
			print(  "被动├ 当前状态: %s" % "追敌")
			切换状态(State.IDLE , State.CHASE)

func _处理追敌状态(delta: float):
	if not 索敌 :#索敌为假便是待机状态，进行警戒，如果索敌为真，无论是移动还是待机都直接开始追敌
		if not _验证敌人有效性():
			导航代理.velocity = Vector2.ZERO
			切换状态(State.CHASE , State.IDLE)
			return
	if 当前敌人 != null:
		var 敌人方向 = to_local(导航代理.get_next_path_position()).normalized()
		导航代理.velocity = 敌人方向 * 移动速度
		move_and_slide()
		var 距离 = global_position.distance_to(当前敌人.global_position)
		if 距离 <= 攻击范围:# 进入攻击范围判断
			导航代理.velocity = Vector2.ZERO#虽然速度为0，但是索敌仍然为真
			切换状态(State.CHASE , State.ATTACK)
	else:
		导航代理.velocity = Vector2.ZERO
		切换状态(State.CHASE , State.IDLE)#切换到待机，将索敌变为假


func _处理移动状态(delta: float):
	var 剩余距离 = global_position.distance_to(目标位置)
	if 剩余距离 <= 停止阈值:
		导航代理.velocity = Vector2.ZERO
		切换状态(State.MOVE , State.IDLE)
	else:
		移动方向 = to_local(导航代理.get_next_path_position()).normalized()
		导航代理.velocity = 移动方向 * 移动速度
		move_and_slide()
 

func _处理攻击状态(delta: float) -> void:
	if 当前敌人 != null:
		var 敌人位置 = 当前敌人.global_position 
		var 敌人方向 = (敌人位置 - global_position).normalized()
		var 剩余距离 = global_position.distance_to(敌人位置)
		if _验证敌人有效性():
			if 剩余距离 <= 攻击范围 :
				await get_tree().create_timer(0.25).timeout
				角色动画.play("攻击") 
			if 剩余距离 > 攻击范围 :
				await get_tree().create_timer(0.25).timeout
				切换状态(State.ATTACK, State.CHASE)
	if 当前敌人 == null :
		切换状态(State.ATTACK, State.IDLE)
		return


# === 辅助函数 ===
func _获取点击目标(位置: Vector2) -> Node2D:
	var 空间 = get_world_2d().direct_space_state
	var 查询 = PhysicsPointQueryParameters2D.new()
	查询.position = 位置
	查询.collision_mask = 0b0001  # 根据项目设置调整碰撞层
	return 空间.intersect_point(查询)[0].collider if 空间.intersect_point(查询) else null
func _验证敌人有效性() -> bool:
	return is_instance_valid(当前敌人) and \
	global_position.distance_to(当前敌人.global_position) <= 警戒范围
# === 信号处理 ===
func _on_索敌区域_进入(body: Node2D):
	if body.is_in_group("敌人") and not 当前敌人:
		当前敌人 = body
func _on_索敌区域_离开(body: Node2D):
	if body == 当前敌人:
		当前敌人 = null


func _on_寻路计时器_timeout() -> void:
	if 当前敌人 != null:
		导航代理.target_position = 当前敌人.position
	if 当前敌人 == null :
		导航代理.target_position = 目标位置


func _on_导航代理_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()
