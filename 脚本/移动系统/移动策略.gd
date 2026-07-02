class_name 移动策略 extends Resource
## 移动策略抽象基类
##
## 每种策略实现一套完整的"如何移动"逻辑：
##   - 计算速度：返回期望速度向量
##   - 是否已到达：决定何时停止
##
## 策略对象由运动服务根据移动请求类型自动构建，
## 单位不直接持有策略实例。

## 计算当前帧的期望速度
## @param 单位  移动中的单位节点（必须有 velocity、global_position）
## @param 请求  本次移动的请求参数
## @return      期望速度向量（运动服务会叠加避障修正后写入单位.velocity）
func 计算速度(单位: Node2D, 请求: 移动请求) -> Vector2:
	return Vector2.ZERO


## 检查是否应该结束本次移动
## @param 单位  移动中的单位节点
## @param 请求  本次移动的请求参数
## @return      true=移动结束，运动服务将触发停止流程
func 是否已到达(单位: Node2D, 请求: 移动请求) -> bool:
	return false


## 获取最终目标位置（考虑队形偏移后）
func 获取最终目标(请求: 移动请求) -> Vector2:
	return 请求.目标位置 + 请求.队形偏移
