# OLD BEHAVIOR SPEC

> 基于 origin/master（commit 7ab6b26 = "旧版"）对照。
> 新架构版本为 战斗系统 branch（commit afa4c7a）。

---

## 1. 旧版架构总览

旧版（origin/master）没有独立战斗组件。全部战斗逻辑内联在：
- `代码/unit/UnitBase.gd` — 基类含受伤/死亡/索敌/伤害数字/屏幕震动
- `代码/角色基础/移动基类.gd` — 另一基类也含相同战斗系统（向下兼容）
- `单位/剑士/剑士.gd` — 状态机 + 自管理冷却 + 自管理伤害
- `单位/弓箭手/弓箭手.gd` — 状态机 + 自管理冷却 + 弹道

**层次关系：**
```
UnitBase (extends CharacterBody2D)
  ├── 剑士.gd  (状态机 IDLE/MOVE/ATTACK)
  ├── 弓箭手.gd (状态机 IDLE/MOVE/ATTACK)
  └── 农民.gd
移动基类 (extends CharacterBody2D) ← 遗留旧基类，7ab6b26 中未被引用
建筑基类 (extends StaticBody2D, 独立树)
```

---

## 2. OLD BEHAVIOR: 剑士（近战）

### 2.1 攻击流程

```
执行攻击() → await 0.2s → _进行伤害判定() → _攻击冷却 = 攻击间隔 → await 0.2s → 后处理
```

### 2.2 核心行为规则

| 行为 | 旧版表现 |
|------|----------|
| **攻击时移动锁定** | 完全锁定。`ATTACK` 状态 `velocity = velocity.move_toward(Vector2.ZERO, 移动速度 * 12.0 * delta)` |
| **攻击期间重新寻路** | 禁止。不会进入 MOVE 状态 |
| **微调位置** | 不允许。朝向固定，只有 `flip_h` 镜像 |
| **Damage 触发时机** | 进入 ATTACK 后 **0.2s**（`await 0.2`） |
| **攻击后停顿** | 伤害判定后 **0.2s**（`await 0.2`） |
| **总攻击锁定时间** | ~0.4s（0.2s 前摇 + 0.2s 后摇） |
| **冷却计时器位置** | 单位自身的 `_攻击冷却` 变量 |
| **冷却开始时间** | 伤害判定的那一刻（`_攻击冷却 = 攻击间隔`） |
| **冷却递减** | `_physics_process` 中 `_攻击冷却 -= delta` |
| **伤害方式** | 直接调用 `目标.受伤(攻击力, self)` |
| **伤害护甲** | 无护甲计算，裸攻 |
| **索敌方式** | 手动遍历 `移动单位` + `建筑` group |
| **攻击范围检查** | `global_position.distance_to(target) <= 攻击范围`（精确） |

### 2.3 ATTACK ↔ MOVE 切换规则

旧版切换逻辑（在 `执行攻击()` 的后处理部分）：
```
执行攻击() 中：
  ① 如果目标有效 & 在攻击范围内 → 保持 ATTACK（继续攻击）
  ② 如果目标有效 & 超出攻击范围 → 切换到 MOVE（追击）
  ③ 如果目标无效 → 检查 _原始目标位置 决定行为
```

### 2.4 详细时序

```
t=0.0    执行攻击() 被调用（在 MOVE 状态的 _处理移动状态 中检测到距离≤攻击范围）
          → 目标位置 = global_position
          → 切换状态(ATTACK)
t=0.0    进入 ATTACK physics: velocity 趋向 0
t=0.2    await 结束
          → _进行伤害判定()
          → 目标.受伤(攻击力, self)
          → _攻击冷却 = 攻击间隔
t=0.4    await 结束
          → 检查目标状态决定: 继续 ATTACK ↔ 切换 MOVE
t>=0.4   如果继续 ATTACK，下次 CombatComponent 检测到冷却就绪 → 重复流程
```

### 2.5 旧版索敌搜索

`_寻找最近的敌对目标(搜索范围)`：
1. 遍历所有 `移动单位` group
2. 排除自身、无效、非敌对、已死亡
3. 搜索最近距离
4. 同样遍历 `建筑` group
5. 返回最近目标（敌方单位或建筑）

---

## 3. OLD BEHAVIOR: 弓箭手（远程）

### 3.1 攻击流程

```
执行攻击() → await 0.15s → 发射箭矢 → _攻击冷却 = 攻击间隔 → await 0.25s → 后处理
```

### 3.2 核心行为规则

| 行为 | 旧版表现 |
|------|----------|
| **攻击时移动锁定** | 完全锁定。同剑士：`velocity.move_toward(Vector2.ZERO)` |
| **攻击期间重新寻路** | 禁止 |
| **微调位置** | 不允许 |
| **箭矢生成时机** | 进入 ATTACK 后 **0.15s**（`await 0.15`） |
| **箭矢生成位置** | `global_position + Vector2(20 if not flip_h else -20, -10)` |
| **箭矢目标** | **追踪目标 node 引用**（`箭.目标 = 攻击目标`） |
| **箭矢速度** | 600.0 |
| **箭矢伤害方式** | `目标.受伤(伤害, 攻击者)` 直接调用 |
| **箭矢命中检测** | 每帧检测 `移动距离 >= 到目标距离` |
| **攻击后停顿** | 0.25s（`await 0.25`） |
| **总攻击锁定时间** | ~0.4s（0.15s 前摇 + 0.25s 后摇） |
| **冷却开始时间** | 箭矢发射那一刻（`_攻击冷却 = 攻击间隔`） |
| **冷却递减** | `_physics_process` 中 `_攻击冷却 -= delta` |

### 3.3 箭矢行为（旧版代码 `单位/弓箭手/箭矢.gd`）

```gdscript
var 目标: Node2D = null   # 追踪目标引用！
var 伤害: float = 1.0
var 攻击者: Node2D = null

func _physics_process(delta):
    # ⭐ 每帧朝目标当前位置飞行（追踪目标）
    var 当前方向 := (目标.global_position - global_position).normalized()
    var 移动距离 := 速度 * delta
    var 到目标距离 := global_position.distance_to(目标.global_position)
    if 移动距离 >= 到目标距离:
        global_position = 目标.global_position
        _命中()
    else:
        global_position += 当前方向 * 移动距离
```

**⚠️ 注意：旧版箭矢也追踪目标 node！** 这是一个旧版就存在的设计问题。

---

## 4. OLD BEHAVIOR: 动画规则

| 行为 | 旧版表现 |
|------|----------|
| **动画是否驱动位移** | 否。动画只是视觉，`velocity` 完全由 `_physics_process` 控制 |
| **是否 root motion** | 否。没有使用 Godot RootMotion |
| **动画切换** | `_切换动画("待机/移动/攻击")`，`角色动画.play(动画名)` |
| **攻击动画重播** | 每次 `执行攻击()` 调用 `切换状态(State.ATTACK)` 触发动画重播 |
| **动画结束处理** | 无专用处理。攻击动画结束后留在最后一帧，直到下次状态切换 |

---

## 5. OLD BEHAVIOR: 受伤/死亡/视觉反馈

### 5.1 受伤流程
```
目标.受伤(伤害, 攻击来源):
  当前生命值 -= 伤害
  _播放受击效果(攻击来源)
  创建伤害数字 Label (add_child)
  if 当前生命值 <= 0: 死亡()
```

### 5.2 受击效果（闪红+缩放+抖动）
```
modulate = Color(2, 0.2, 0.2, 1)     # 闪红
scale *= 1.15                         # 放大
position += randf_range(-5,5)         # 抖动
await 0.06s
modulate = Color(1.5, 0.4, 0.4, 1)   # 半恢复
scale *= 1.08
await 0.06s
modulate = 原色调                      # 完全恢复
scale = 原缩放
```

### 5.3 死亡效果（缩放+淡出）
```
第1阶段: modulate=白, scale*=1.3 (0.08s)
第2阶段: alpha→0, scale→0.3, rotation±0.3 (0.35s)
→ queue_free()
```

---

## 6. 新旧架构关键行为差异

| 行为点 | 旧版 (origin/master) | 新版 (战斗系统 branch) |
|--------|---------------------|----------------------|
| 冷却管理 | 单位 self `_攻击冷却` | CombatComponent `_cooldown_timer` |
| 冷却递减 | 每帧 `_physics_process` | CombatComponent `_process` |
| 攻击检测 | MOVE 状态中 `距离≤攻击范围 → 执行攻击()` | CombatComponent._process 错峰检测 |
| 攻击触发频率 | 每次 phys frame 检查（全速） | 每 3 帧错峰检测 |
| 伤害管道 | `目标.受伤(攻击力, self)` 直接调用 | DamageSystem.apply_damage(packet) |
| 护甲计算 | 无 | DamageResolver 支持护甲类型 |
| 索敌实现 | 手动遍历 group `移动单位` + `建筑` | TargetingComponent + Strategy 模式 |
| 索敌范围检查 | `distance_squared` 精确 | TargetingComponent.chase_range |
| ATTACK→MOVE 阈值 | 精确范围（不超范围就继续） | 1.3x hysteresis 缓冲区 |
| 攻击后冷却起始 | 伤害判定瞬间 | 攻击发动的瞬间（略早） |
| 箭矢追踪 | 追踪目标 node | 追踪目标 node（相同行为） |
| 箭矢伤害 | `目标.受伤(伤害, 攻击者)` | DamageSystem.apply_damage(packet) |
| 伤害数字类 | Label 直接创建 | 在 DeathHandler 中创建 |
| 受击效果 | UnitBase 内联 | DeathHandler 管理 |
| 屏幕震动 | UnitBase 内联 | DeathHandler 管理 |
| 建筑基础生命 | `当前生命值` 属性自管理 | HealthComponent 托管 |

---

## 7. 建筑 UI 对比

| 行为 | 旧版 | 新版 |
|------|------|------|
| 训练队列显示 | 城堡.gd 内 `_队列图标容器` / `_倒计时标签` | 同旧版（未变） |
| 建造进度条 UI | 建造UI/建造ui.tscn | 同旧版 |
| 组件化管理生命 | 建筑基类自管理 | HealthComponent |
| 训练倒计时 | 城堡.gd 内 `_训练计时器` | 同旧版 |

---

## 8. 已确认 bugs 汇总

| # | Bug 描述 | 影响范围 | 严重度 |
|---|----------|----------|--------|
| B1 | 剑士攻击后 0.1s 等待 vs 旧版 0.2s（时序偏差） | 近战攻击节奏 | 中 |
| B2 | CombatComponent 错峰检测（每3帧）导致攻击响应延迟 | 所有单位 | 高 |
| B3 | ATTACK→MOVE 使用 1.3x hysteresis vs 旧版精确范围 | 追敌行为 | 中 |
| B4 | 箭矢追踪 target node（旧版存在的一致行为，但用户要求修正） | 远程 | 高 |
| B5 | 受击效果/伤害数字/屏幕震动从 UnitBase 移至 DeathHandler，行为需要验证 | 视觉反馈 | 中 |

---

## 9. 修复优先级

```
P0（破坏性错误）:
  B2 - CombatComponent 错峰导致攻击延迟（改回全帧检查）
  B4 - 箭矢追踪 target → 改为 snapshot 位置

P1（行为偏差）:
  B1 - 剑士攻击后等待 0.1→0.2（对齐旧版）
  B3 - ATTACK→MOVE 阈值 hysteresis → 精确范围

P2（视觉反馈）:
  B5 - 验证 DeathHandler 受击/死亡效果与旧版一致
```
