class_name MovementForceProvider
extends RefCounted

## MovementForceProvider — 建议力提供者抽象基类
##
## 每个 Provider 负责计算一个特定方向源的建议力。
## Provider 不允许：
##   - 修改 velocity
##   - 修改 unit.glb_position
##   - 修改任何物理状态
## Provider 应该：
##   - 返回 MovementForce 数据结构
##   - 只依赖传入的 context 信息
##   - 保持幂等（相同输入 → 相同输出）

## 提供者名称（调试标识）
var provider_name: String = "MovementForceProvider"

## Provider 优先级（越小越早执行）
var process_priority: int = 0


## 计算建议力
## @param unit     目标单位
## @param context  上下文字典（包含 intent、请求、路径方向等 Solver 信息）
## @return         建议力（零力表示无贡献）
func calculate_force(unit: Node2D, context: Dictionary) -> MovementForce:
	return MovementForce.new()


## Provider 是否需要激活
## @param unit     目标单位
## @param context  上下文字典
## @return         true=本帧计算力，false=跳过
func is_active(unit: Node2D, context: Dictionary) -> bool:
	return true
