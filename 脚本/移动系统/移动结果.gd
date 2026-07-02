class_name 移动结果 extends Resource
## 描述一次移动的最终结果
## 由运动服务在停止移动时构造并发送给单位

enum 结果类型 {
	已到达,      # 正常到达目标
	卡死,        # 卡死超时无法继续
	目标丢失,    # 追击目标死亡或消失
	被中断,      # 被新命令打断
}

@export var 结果: 结果类型
@export var 附加数据: Dictionary = {}
