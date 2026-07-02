# AI资源库读取规范（插件实现基线）

## 1) 扫描规则

- 根目录：`AI资源库/一图全动作/`
- 递归匹配：`**/npc_*/npc.json`
- 目录名需匹配：`npc_[a-z0-9_]+`
- `meta.id` 必须与上级目录名一致

## 2) 分类映射规则

- 风格目录映射：
  - `古风` -> `gufeng`
  - `中世纪风` -> `medieval`
  - `现代风` -> `modern`
- 类别目录映射：
  - `商店类` -> `shop`
  - `功能类` -> `function`
  - `任务类` -> `quest`
  - `战斗类` -> `combat`

扫描时目录映射值必须等于 `meta.style` 和 `meta.category`。

### 2.1) 风格字段语义（硬性约束）

- `meta.style` 仅用于标记美术外观风格（精灵图/立绘分组与筛选）。
- `meta.style` 不参与行为逻辑、交互逻辑、台词协议判断。
- 不允许按风格分叉 `npc.json` 字段结构；三种风格必须共用同一 schema。
- 允许同一套 `gameplay` 与台词内容跨风格复用，仅替换 `assets` 资源与 `meta.style`。

## 3) 校验规则

1. 必须通过 `AI资源库/_schema/npc.schema.v1.json` 校验
2. `spritesheet` 子对象必须通过 `AI资源库/_schema/spritesheet.schema.v1.json`
3. 文件存在性检查：
   - `assets.spritePath` 必须存在且可加载
   - `assets.thumbPath` 若不存在则可降级为 `spritePath` 缩略图
4. 时间字段检查：`createdAt`、`updatedAt` 需为 ISO-8601

## 4) 预览规则

- 载入 `assets.spritePath`
- 按 `spritesheet.animations` 的 `row/from/to` 切帧
- 预览动作至少包含：
  - `idle_down`
  - `walk_down`
  - `idle_left`
  - `walk_left`
  - `idle_up`
  - `walk_up`
- 默认 FPS 使用 `spritesheet.defaultFps`

## 5) 应用到场景规则

- 应用目标：当前选中 NPC 节点或批量选中节点
- 字段应用优先级：
  1. `gameplay`（同名属性优先）
  2. `meta.displayName`（名称/UI展示字段）
  3. 动画资源（`spritesheet`）
- 应用策略：
  - 默认为覆盖模式
  - 可选仅填空模式（已有值不覆盖）

## 6) 错误处理

- 单条 JSON 校验失败时不中断全量扫描
- 在插件列表中显示错误原因（路径、字段、期望值）
- 提供“导出错误报告”用于批量修复

## 7) 版本策略

- 当前版本：`schemaVersion = 1`
- 未来升级：
  - 新字段：保持向后兼容
  - 结构变化：`schemaVersion + 1` 并提供迁移脚本

## 8) 台词复用规范（跨风格）

- 台词协议在三种风格下完全一致，统一使用同一结构。
- 可复用台词块模板：`AI资源库/_templates/dialogue/npc.base.dialogue.json`
- 建议用占位符（如 `{npcName}`）进行批量替换，减少重复维护。
- 若 NPC 台词较短，可直接内联在 `npc.json`；若要统一运营文案，优先复用模板块再展开。

## 9) 跨风格批量扩库命名规范

- 同逻辑跨风格复用时，保持 `category` 与 `role` 不变，仅替换：
  - `meta.style`
  - `meta.id`
  - `meta.displayName`（可选）
  - `assets.spritePath` / `assets.thumbPath`
- 推荐 ID 结构：`npc_<role>_<style>_<3位序号>`
  - 例如：`npc_quest_gufeng_001`、`npc_quest_medieval_001`、`npc_quest_modern_001`
- 若沿用既有 ID（不含 style），必须确保全库唯一且目录不冲突。
