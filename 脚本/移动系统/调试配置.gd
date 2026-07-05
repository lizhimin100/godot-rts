class_name 调试配置
## 移动系统调试开关 — 正常运行时应全部设为 false
##
## ⚠ 作为静态变量，修改后仅本次运行生效，重启引擎会恢复为 false。

## 移动总开关：路径日志、方向日志、到达日志、卡死恢复日志
## 影响：运动服务.gd、前往位置移动.gd、流场管理器.gd、空间哈希网格.gd、命令管理器.gd
static var DEBUG_MOVE: bool = false

## 队形系统开关：[FORM-SLOTS] [FORM-IDEAL] [FORM-FORCE] 等详细日志
## 影响：队形系统.gd
static var DEBUG_FORMATION: bool = false

## 避障系统开关：[AVOID] [AVOID-IGNORE] 等详细日志
## 影响：避障系统.gd
static var DEBUG_AVOID: bool = false
