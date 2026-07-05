RTS Movement 2.0 总体目标

未来支持：

普通移动

攻击移动

追击

巡逻

驻守

运输

编队

自动补位

技能位移

击退

冲锋

传送

AI移动

但：

最终速度

永远由：

MovementSolver

统一生成。

RTS Movement 2.0 核心原则
Principle 1

唯一运动决策层

MovementSolver

唯一允许：

velocity =
Principle 2

其它系统只能提供意图

例如：

FlowField

提供：

desired_direction

Formation

提供：

slot_offset

Avoidance

提供：

obstacle_info

Strategy

提供：

target
Principle 3

命令与移动解耦

Command：

我要去哪

Movement：

怎么去
Principle 4

移动模式可扩展

未来：

Patrol
Guard
Transport
Dash
Knockback

不修改：

MovementSolver

只新增：

MovementStrategy
RTS Movement 2.0 模块图
Player Command
        │
        ▼
Command System
        │
        ▼
Movement Request
        │
        ▼
Movement Strategy
        │
        ▼
Target Provider
        │
        ▼
Movement Solver
 ┌──────┼─────────┐
 │      │         │
 ▼      ▼         ▼
Flow   Formation Avoidance
Field
 └──────┼─────────┘
        ▼
 Velocity Solve
        ▼
 move_and_slide()
职责边界
Command System

负责：

接收命令
取消旧命令
创建新命令

不负责：

移动
Movement Strategy

负责：

目标是谁

例如：

MoveTo
AttackMove
Patrol
Guard
Transport

不负责：

速度
路径
避障
Formation System

负责：

Anchor
Slot
补位

不负责：

velocity
FlowField

负责：

全局方向

不负责：

局部避障
Avoidance

负责：

告诉Solver前面有什么

不负责：

移动单位
Movement Solver

负责：

最终方向

最终速度

最终位置修正

唯一允许：

velocity=
状态机

我建议最终状态机保持极简。

Idle

Moving

Arriving

TemporaryYield

Disabled

不要出现：

FormationMoving

Avoiding

ObstacleBypass

Repathing

SlotLocked

SlotWaiting

这些都应该是：

MovementSolver内部逻辑

不是状态。

更新顺序

每帧：

1 获取当前命令

2 获取目标

3 计算队形Slot

4 读取FlowField

5 检测障碍

6 Local Avoidance

7 Velocity Solve

8 move_and_slide

9 到达检测

10 状态更新

顺序固定。

未来功能预留接口
巡逻
PatrolStrategy

接口：

get_target_position()

返回：

巡逻点A/B
驻守
GuardStrategy

返回：

守卫目标附近位置
运输
TransportStrategy

返回：

载具位置
卸载位置
技能位移

新增：

MotionOverride

例如：

Dash

Blink

Knockback

优先级高于：

MoveTo
自动补位

Formation模块提供：

request_slot_rebalance()

不影响：

MovementSolver