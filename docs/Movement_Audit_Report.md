# Movement Audit Report — 移动控制耦合分析

> 生成日期：2026-07-05
> 范围：E:\自定义游戏\RTS 全部 .gd 源码（排除 addons/ 插件目录、test/ 测试目录）
> 方法：全文扫描 velocity 写入点、speed 修改点、状态机-移动接口、子系统力投送
> 约束：未修改任何代码

---

## 一、velocity 写入点清单

按"谁写 velocity"分类，共 **20 个写入点，分布 7 个系统**。

### 🔴 高危 — 直接写 `velocity =` / `velocity = ... * 移动速度`

这类写入点完全绕过运动服务，是"最终速度由谁决定"冲突的根源。

| # | 文件 | 行 | 代码 | 触发场景 |
|---|------|----|------|----------|
| 1 | `角色/敌人.gd` | 12 | `velocity = 移动方向 * 移动速度` | 每帧直接写入 |
| 2 | `代码/角色基础/主角控制器.gd` | 63 | `velocity = 方向 * 移动速度` | 移动中每帧 |
| 3 | `代码/角色基础/主角控制器.gd` | 70 | `velocity = velocity.move_toward(Vector2.ZERO, ...)` | 减速中每帧 |
| 4 | `代码/兵种/人族步兵.gd` | 135 | `velocity = 移动控制器.compute_velocity(...)` | 追敌状态 |
| 5 | `代码/兵种/人族步兵.gd` | 139 | `velocity = 目标方向 * 移动速度` | 追敌无控制器回退 |
| 6 | `代码/兵种/人族农民.gd` | 128 | `velocity = 移动控制器.compute_velocity(...)` | 追敌状态 |
| 7 | `代码/角色基础/移动基类.gd` | 242 | `velocity = velocity.move_toward(目标速度.limit_length(...))` | 导航移动中 |
| 8 | `代码/角色基础/移动基类.gd` | 232 | `velocity = velocity.move_toward(Vector2.ZERO, ...)` | 导航减速 |
| 9 | `systems/UnitController.gd` | 382 | `velocity = recovery` | 卡死解卡 |

### 🟡 中危 — 清零 `velocity = Vector2.ZERO`

清零本身不冲突，但暗示"此系统认为自己有权管速度"。

| # | 文件 | 行 | 代码 | 场景 |
|---|------|----|------|------|
| 10 | `代码/角色基础/移动基类.gd` | 140 | `velocity = Vector2.ZERO` | 命令停止 |
| 11 | `代码/角色基础/移动基类.gd` | 152 | `velocity = Vector2.ZERO` | 命令驻守 |
| 12 | `代码/角色基础/移动基类.gd` | 234 | `velocity = Vector2.ZERO` | 导航到达 |
| 13 | `代码/角色基础/主角控制器.gd` | 43 | `velocity = Vector2.ZERO` | 命令停止 |
| 14 | `code/士兵.gd` | 74 | `velocity = Vector2.ZERO` | 停止移动 |
| 15 | `systems/UnitController.gd` | 151 | `velocity = Vector2.ZERO` | lock_arrival |
| 16 | `systems/UnitController.gd` | 398 | `velocity = Vector2.ZERO` | reset |

### 🟢 低危 — 运动服务内部写入（授权写入点）

运动服务是唯一被授权的 velocity 写入者。

| # | 文件 | 行 | 代码 | 场景 |
|---|------|----|------|------|
| 17 | `脚本/移动系统/运动服务.gd` | 321 | `单位.velocity = 最终速度` | **主循环速度合成** |
| 18 | `脚本/移动系统/运动服务.gd` | 136,141,188,198,213,225,302 | `单位.velocity = Vector2.ZERO` | 停止/到达/卡死 |
| 19 | `脚本/移动系统/运动服务.gd` | 186 | `单位.velocity = return_dir * return_speed` | SLOT_LOCKED 锚点回归 |
| 20 | `代码/unit/UnitBase.gd` | 261 | `move_and_slide()` | **唯一 move_and_slide 入口** |

---

## 二、speed 修改点清单

### 带 `@export` 的静态速度参数

| # | 文件 | 声明 | 默认值 |
|---|------|------|--------|
| 1 | `代码/unit/UnitBase.gd:28` | `@export var 移动速度: float` | 200.0 |
| 2 | `代码/unit/UnitBase.gd:30` | `@export var 最大速度: float` | 350.0 |
| 3 | `代码/角色基础/移动基类.gd:16` | `@export var 移动速度: float` | 200.0 |
| 4 | `代码/角色基础/移动基类.gd:17` | `@export var 最大速度: float` | 350.0 |
| 5 | `代码/角色基础/主角控制器.gd:10` | `@export var 移动速度: float` | 450.0 |
| 6 | `代码/兵种/敌人.gd:10` | `@export var 移动速度: float` | 20.0 |

### 运行期赋值

| # | 文件 | 代码 | 说明 |
|---|------|------|------|
| 7 | `代码/兵种/兵种：人族步兵.gd:10` | `移动速度 = 100` | 子类覆盖基类默认值 |
| 8 | `代码/士兵.gd:31` | `移动速度 = 270` | 旧单位设置 |
| 9 | `代码/小兵.gd:17` | `移动速度 = 速度` | 参数传递 |

**分析**：速度目前全部是在 _ready 时设定或 Inspector 拖拽，没有运行时 speed modifer 链条（技能加速/减速尚未接入）。因此 speed 修改不是当前耦合问题——但 **一旦接入"技能改变速度"就必须统一入口**，否则多个系统同时改 `移动速度` 会互相覆盖。

### 最大速度限幅点

| # | 文件 | 行 | 代码 |
|---|------|----|------|
| 1 | `运动服务.gd` | 257-259 | `最大速度: float = 单位.最大速度 ... 最终速度.normalized() * 最大速度` |
| 2 | `运动服务.gd` | 184-185 | `最大速度: float = 单位.最大速度 ... return_speed = ... 最大速度 * 0.25` |
| 3 | `避障系统.gd` | 57-58 | `move_speed = 单位.移动速度 ... max_avoid = move_speed * 0.35` |
| 4 | `队形系统.gd` | 211-213 | `移动速度 = 单位.移动速度 ... 最大力 = 移动速度 * 0.45` |

**问题**：每个子系统各自独立读取 `单位.移动速度` / `单位.最大速度`，没有统一的速度快照——如果单位速度在中途被技能修改，各子系统看到的可能不一致。

---

## 三、移动控制路径图

### 新版路径（UnitBase 体系 — 正确解耦）

```
玩家右键/命令管理器
    │
    ▼
[命令管理器] 发出命令(type, pos, target)
    │ 设置 _pending_formation_offset / slot
    ▼
[UnitBase] 设置命令() → 通知状态机
    │
    ▼
[单元状态机] 决定下一状态
    │ 根据状态创建 移动请求
    │ 调用 单位.应用移动请求(请求)
    ▼
[运动服务] 请求移动(单位, 请求)
    │ 存为 _移动中单位[单位] = 移动数据
    │ 构建 移动策略
    │
    ▼ 每帧 _physics_process:
    │
    ├─ ① 重建空间哈希网格
    │
    ├─ ② 遍历 _移动中单位
    │   ├── SLOT_LOCKED → 锚点回归速度 (运动服务 L186)
    │   ├── 已到达 → velocity = 0
    │   └── MOVING/无队形 →
    │       ├── 路径力 = 策略.计算速度()
    │       │   ├── 流场管理器.获取方向() → FFManager → FFGrid.sample()
    │       │   └── 刹车/展开逻辑
    │       ├── 队形力 = 队形系统.计算队形力() × 0.6
    │       ├── 分离力 = 避障系统.计算让路修正() × 0.4
    │       ├── 最终速度 = 路径力 + 队形力 + 分离力
    │       ├── 卡死检测 → 回退/放弃
    │       └── ★ 单位.velocity = 最终速度 (L321)
    │
    ▼
[UnitBase._physics_process] move_and_slide() (L261)
    │
    ▼
[运动服务] 到达检测 → 发送移动完成信号
    │
    ▼
[单元状态机] _on_移动完成() → 状态切换
```

**正确之处**：
- `velocity =` 仅出现在 `运动服务.gd` 和 `UnitBase.gd(move_and_slide)`
- 状态机不碰 velocity，只发请求
- 子系统（队形/避障/流场）只提供"力/方向"，不写 velocity
- 策略模式隔离了"怎么走"与"走到哪"

### 旧版路径（移动基类/UnitController 体系 — 已部分退役但残存）

```
┌─ [移动基类] (被标记 @deprecated)
│   ├── 命令停止/驻守 → 直接 velocity = Vector2.ZERO (L140,152)
│   ├── _导航移动到() → 直接 velocity = ... (L232,242)
│   └── 无 _physics_process, 子类自行管理
│
├─ [人族步兵.gd / 人族农民.gd]
│   ├── extends 单位基类 (新基类!)
│   └── 但 _physics_process 中:
│       ├── 旧枚举状态机 (State.IDLE/CHASE/MOVE/ATTACK) 直接写 velocity
│       │   └── velocity = 移动控制器.compute_velocity(...)
│       │   └── velocity = 目标方向 * 移动速度 (回退)
│       └── 最后 super._physics_process() → move_and_slide()
│           ★ 新旧冲突! 状态机 + 运动服务 + UnitController 三方混合
│
├─ [UnitController.gd] (按单位旧版控制器)
│   ├── 有自己的 velocity 成员变量
│   ├── compute_velocity() 内: 流场+分离+让路+卡死 → 返回 Vector2
│   ├── 卡死恢复直接写 self.velocity (L382)
│   └── 与 运动服务 功能完全重叠，但互不知晓
│
└─ [主角控制器.gd] (独立 CharacterBody2D)
    └── 完全独立，不受运动服务管理
```

### 独立实体

```
[角色/敌人.gd] (extends CharacterBody2D)
    └── 每帧 velocity = 方向 * 速度 → move_and_slide()
        ★ 完全独立，不使用运动服务或状态机

[代码/士兵.gd] (旧单位)
    └── velocity = Vector2.ZERO 直接清零 (L74)
```

---

## 四、子系统投送分析

每个子系统对最终速度的影响方式和权重：

| 子系统 | 输入 | 输出 | 权重 | 写入方式 | 耦合评估 |
|--------|------|------|------|----------|----------|
| **流场管理器** | global_position, target | 归一化方向 Vector2 | 全速 × 方向 | 返回方向（不写 velocity） | ✅ 纯意图输入 |
| **FFManager** | target | FFGrid.sample() | 全速 × 方向 | 返回方向 | ✅ 纯数据 |
| **队形系统** | 单位位置, 固定偏移 | 修正力 Vector2 | ×0.6 | 返回力向量 | ✅ 可接受（运动服务汇总） |
| **避障系统** | 周围单位, 期望方向 | 分离力 Vector2 | ×0.4 | 返回力向量 | ✅ 可接受（运动服务汇总） |
| **运动服务** | 以上全部 | 最终速度 | 1.0 | `单位.velocity =` | ✅ 唯一授权写入口 |
| **移动策略** | 单位, 请求 | 路径速度 Vector2 | 1.0 | 返回速度（运动服务汇总） | ✅ 纯策略输出 |

**问题不在子系统，而在 3 个并行 velocity 写入者**：

```
          ┌── 运动服务 (新系统) ←── 正确写入 velocity
          │
velocity  ──├── UnitController (旧系统) ←── 与人族步兵/农民共存
          │
          └── 移动基类._导航移动到() (旧旧系统) ←── 旧单位在用
```

这三个写入者运行在不同单位上，但**同一个单位可能同时被多个系统修改**（如人族步兵的 `_physics_process` 中既有旧状态机写 velocity，最后又调 `super._physics_process()` 让运动服务覆盖，造成帧内覆盖和逻辑冲突）。

---

## 五、状态机 — 移动耦合分析

### 新状态机（单元状态机）✅ 正确解耦

```
单元状态机.状态:
    待机 → 停止（不发移动请求）
    移动 → 创建移动请求 → 单位.应用移动请求()
    追击 → 创建移动请求（追击类型）
    移动攻击 → 创建移动请求（移动攻击类型）
    攻击 → 停止（不发移动请求）
```

- **不写 velocity**：所有速度管理完全委托给 运动服务
- **不碰 move_and_slide**：由 UnitBase._physics_process 统一调用
- **职责清晰**：决策层（状态机） ↔ 执行层（运动服务）

### 旧状态机（人族步兵/农民 State enum）⚠️ 耦合

```
State.IDLE  → 移动控制器.stop()
State.CHASE →  velocity = 移动控制器.compute_velocity(...)  ← 直接写!
State.MOVE  → 依赖 super._physics_process 的流场
State.ATTACK → 移动控制器.stop()
```

- 直接写 `velocity =`
- 混合使用 `super._physics_process`（运动服务写入）和状态内直接写入
- **帧内冲突链**：
  1. 运动服务写入 `单位.velocity = 最终速度`
  2. `super._physics_process(delta)` 调用 `move_and_slide()`
  3. 下一帧人族步兵状态机 **覆盖** velocity：

  ```
  帧 N:  运动服务写 velocity → move_and_slide()
  帧 N+1: 人族步兵._physics_process →
           同步命令状态 →
           进入 CHASE →
           velocity = 移动控制器.compute_velocity(...)  // ← 覆盖运动服务的值
           调用 super._physics_process() →
           move_and_slide()  // ← 用的是被覆盖后的 velocity
  帧 N+2: 运动服务继续写 velocity → ...
  ```

  结果：两个系统交替写入 velocity，**没有一帧的 velocity 是双方协商后的结果**。

### 状态机与运动服务的信号耦合

```
状态机 ←── 运动完成信号 ──→ 运动服务
```

状态机监听 `运动服务.移动完成` 信号来做状态切换（到达→待机、卡死→保留命令），这是正确的异步通知模式。

**但**：状态机在 `_on_移动完成` 中调用 `_单位.当前命令 = 命令管理器.命令类型.无` 来"消费"到达事件。如果命令管理器在到达前又发了新命令，状态机的到达处理可能会错误地覆盖新命令。

---

## 六、风险评估

### 🔴 必须拆（高优先级）

| 系统 | 位置 | 问题 | 风险 |
|------|------|------|------|
| **人族步兵/农民** | `代码/兵种/*.gd` | 混合使用旧枚举状态机 + 新 UnitBase + 直接写 velocity | **最高**：帧内 velocity 覆盖、双重状态机逻辑冲突 |
| **角色/敌人.gd** | `角色/敌人.gd` | 独立 CharacterBody2D，完全不受运动服务管理 | 敌人不受队形/避障/流场管理 |
| **主角控制器.gd** | `代码/角色基础/主角控制器.gd` | 独立 CharacterBody2D，自管 velocity + move_and_slide | 主角不受运动服务管理 |

### 🟡 应拆（中优先级）

| 系统 | 位置 | 问题 | 风险 |
|------|------|------|------|
| **UnitController.gd** | `systems/UnitController.gd` | 与运动服务功能完全重叠（流场+分离+让路+卡死+到达检测） | 新旧双系统维护负担，人族步兵/农民依赖它 |
| **移动基类.gd** | `代码/角色基础/移动基类.gd` | 标记 @deprecated 但仍有 velocity 操作 | 未迁移的旧单位仍在使用 |
| **士兵.gd** | `代码/士兵.gd` | 直接 velocity = Vector2.ZERO | 旧单位残存 |

### 🟢 可保留（低风险）

| 系统 | 原因 |
|------|------|
| **运动服务 + 策略体系** | 唯一授权 velocity 写入者，解耦设计正确 |
| **单元状态机** | 不写 velocity，仅决策，信号驱动 |
| **队形系统** | 只返回力，不写 velocity |
| **避障系统** | 只返回力，不写 velocity |
| **流场管理器** | 只返回方向，不写 velocity |
| **FFManager** | 只返回方向/FFGrid，不写 velocity |

---

## 七、耦合总结

### 当前 velocity 写入者的冲突图

```
                 运动服务 (新)
                /     |     \
   写入 velocity  写入 velocity   写入 velocity
       ↑              ↑              ↑
       |              |              |
   [UnitBase]    [人族步兵]     [移动基类]
   (新单位)      (混合旧逻辑)   (旧单位)
                    ↑
                    |
              UnitController
              (旧系统残存)
```

### 子系统的"意图 → 速度"转化链

```
                    ┌── 状态机（决策层）
                    │   读命令 → 选策略
                    │
                    ▼
   移动请求 ──→ 移动策略（意图层）
                    │  计算路径速度 (px/s)
                    │
                    ▼
   流场方向 ◄── FFManager/流场管理器（导航层）
                    │  每帧采样方向
                    │
                    ▼
   路径力 + 队形力×0.6 + 分离力×0.4
                    │
                    ▼
   运动服务（合成层）
                    │  velocity = 合成结果
                    │  卡死检测 + 限幅
                    ▼
   UnitBase（执行层）
                    │  move_and_slide()
                    ▼
   Godot Physics
```

### 关键数据

| 指标 | 值 |
|------|-----|
| velocity 写入点总数 | 20 (分布在 8 个文件) |
| 授权写入点（运动服务） | 9 |
| 非授权写入点 | 11 |
| 独立 move_and_slide 调用 | 3 (UnitBase, 主角控制器, 敌人) |
| 并行 velocity 写入者 | 3 (运动服务, UnitController, 移动基类) |
| 新旧状态机并行 | 2 (单元状态机 + 人族步兵State enum) |

---

## 八、建议迁移顺序（仅供参考，未修改代码）

如果未来决定统一，建议按此顺序：

1. **Phase 1** — 统一 `move_and_slide` 入口
   - 让所有 CharacterBody2D 单位通过 `UnitBase._physics_process` 的 `move_and_slide()` 执行物理移动
   - 消除 `主角控制器.gd` 和 `敌人.gd` 中的独立 `move_and_slide()`

2. **Phase 2** — 迁移旧单位到新状态机
   - 让人族步兵/人族农民移除各自的 `State enum`，改用 `单元状态机` 子节点
   - 移除它们 `_physics_process` 中的 velocity 赋值

3. **Phase 3** — 退役 UnitController
   - 功能已完全被 运动服务 + 避障系统 + 队形系统 覆盖
   - 迁移卡死检测到运动服务（已有内联版本）

4. **Phase 4** — 退役 移动基类
   - 所有旧单位迁移到 UnitBase 后删除
