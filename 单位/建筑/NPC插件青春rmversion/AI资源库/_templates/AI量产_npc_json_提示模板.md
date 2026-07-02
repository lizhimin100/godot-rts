# AI 资源库 · AI 量产用 `npc.json` 提示模板

本文档供 **人类策划** 与 **大模型（AI）** 共用：按下列 **封闭枚举** 填写 `meta.style` / `meta.category`，生成的 JSON 可被 **Godot `npc_library_tool` 插件** 正常扫描、过滤与拖入场景。

---

## 一、必须先遵守的约定

| 项 | 要求 |
|----|------|
| 文件位置 | `AI资源库/一图全动作/<角色文件夹>/npc.json` |
| 根字段 | 必须包含：`schemaVersion`、`meta`、`assets`、`spritesheet`、`gameplay`、`ext` |
| `schemaVersion` | 固定为 **数字 `1`**（不是字符串） |
| `meta.id` | 与 **文件夹名** 一致（若文件夹为 `npc_xxx_001`，则 `id` 也为 `npc_xxx_001`） |
| 精灵图 | 标准「一图全动作」为 **252×252**，`spritesheet.layoutVersion` 为 **`yituquan_v1`** 时与插件 Ocad 切帧一致 |

---

## 二、`meta.style`（画风）—— 封闭列表 + 扩展规则

**以下英文 id 为项目已用/插件内有中文映射的推荐值（小写 + 下划线）：**

| 填写值（必须完全一致） | 人类可读含义 |
|------------------------|--------------|
| `gufeng` | 古风 |
| `modern` | 现代风 |
| `medieval` | 中世纪风 |
| `wasteland_scifi` | 废土科幻 |
| `high_fantasy_celestial` | 高魔天国 |

**扩展规则（需全项目统一后再用）：**

- 新增系列时，使用 **小写英文 + 下划线** 的 **snake_case**，例如：`cyber_neon`、`east_island`。
- 新 id 会在插件「资源过滤」里 **按扫描结果动态出现**；团队内应用同一批 id，便于筛选。

**禁止：** 随机中文、空格、大写混写（如 `Wasteland SciFi`）作为 `style` 值。

---

## 三、`meta.category`（主类型）—— 封闭列表（插件过滤 + 语义）

**以下五选一（英文小写）：**

| 填写值 | 人类可读 | 说明 |
|--------|----------|------|
| **`shop`** | 商店类 | **推荐新角色统一使用**（与插件最初设计一致）。 |
| `merchant` | 商店类（同左） | 历史/甲方常用；插件筛选时与 **`shop` 等价**，可不改旧数据。 |
| `function` | 功能类 | |
| `quest` | 任务类 | |
| `combat` | 战斗类 | |

**不要写：** `normal`、`merchant_npc` 等 **非上表值** 作为 `meta.category`（若需表达「路人」，请用 `types` 或其它字段，不要用错 `category`）。

**例外（仅编辑器内「新增 NPC」）：** 选「路人」主类型时 `meta.category` 为 `normal`；选商人/任务/战斗则为 `shop` / `quest` / `combat`；选「自定义」时由你手填主分类。下方商人/任务/战斗区块均可不填；**填写的内容**会写入 **`meta.tags`**（如 `shop`、`quest`、`combat`），资源过滤器会按 `category` 与 `tags` 匹配。

---

## 三（补充）、插件 Dock「新增 NPC」与 AI 模板对齐方式

| 项 | 说明 |
|----|------|
| **画风** | 下拉含：古风/现代/中世纪/废土科幻/高魔天国；另可选 **「自定义…」** 填写 `meta.style`（snake_case）。 |
| **主类型（单选）** | 路人 / 商人 / 任务 / 战斗 / **自定义**。决定 `meta.category`；自定义时在下一行填写主分类字符串。 |
| **商人 / 任务 / 战斗区块** | 默认全部展开，**均非必填**。若填写了商品、任务或主类型为战斗等，生成时会写入 **`meta.tags`** 数组，便于按类型筛选（与 `meta.category` 为自定义时可配合使用）。 |
| **meta.types** | 由 `category` 与 `tags` 去重合并生成，便于兼容旧逻辑。 |

---

## 四、`spritesheet`（一图全动作 `yituquan_v1`）

若精灵图为 **252×252**、与现网角色同规格，**animations 块请直接复制现网范例**（数值与 `npc.json` 中已有角色一致即可），例如：

- `layoutVersion`: `"yituquan_v1"`
- `frameWidth`: `21`，`frameHeight`: `42`，`columns`: `12`，`rows`: `6`，`margin`/`spacing`: `0`，`defaultFps`: `8`
- `animations` 内 `idle_*` / `walk_*` / `run_*` 的 `row` / `from` / `to`：**勿用占位大格子**（如 128×128），否则校验会失败或与 Ocad 真切帧不一致。

**权威范例路径（工程内）：**  
`AI资源库/一图全动作/黑市机械师老贾/npc.json` 中的 `spritesheet` 整段。

---

## 五、可复制：给 AI 的系统提示词（整段粘贴）

```
你是游戏资源策划助手，需要输出符合 Godot 4 项目「npc_library_tool」插件规范的 npc.json 片段。

硬性规则：
1. 根结构必须包含：schemaVersion(数字1)、meta、assets、spritesheet、gameplay、ext。
2. meta.style 只能从以下选一个，或团队统一的 snake_case 新 id：gufeng | modern | medieval | wasteland_scifi | high_fantasy_celestial
3. meta.category 只能是：shop（商店类，推荐）或 merchant（与 shop 等价，商店类）| function | quest | combat
4. meta.id 使用小写+下划线，且必须与资源文件夹名一致。
5. assets.spritePath / thumbPath 使用相对路径如 "./sprite.png" "./thumb.png"
6. 若为一图全动作标准图（252×252），spritesheet.layoutVersion 必须为 "yituquan_v1"，frameWidth=21, frameHeight=42, columns=12, rows=6, margin=0, spacing=0, defaultFps=8，animations 键名与 row/from/to 与项目范例一致（勿编造 128×128 网格）。
7. 只输出合法 JSON，不要 Markdown 代码块外的解释文字。

用户将提供：角色名称、风格、类型、对话要点等；你补全 meta、gameplay、ext 等字段。
```

---

## 六、人类自检清单（量产前扫一眼）

- [ ] `meta.style` 在上表或团队扩展表内  
- [ ] `meta.category` 为 `shop` / `merchant` / `function` / `quest` / `combat` 之一  
- [ ] `spritesheet` 与 **252×252 + yituquan_v1** 范例一致（或你方已单独约定 `json_grid` 流程）  
- [ ] `schemaVersion` 为数字 `1`  
- [ ] 文件名 `npc.json`，且放在「一图全动作」下对应角色文件夹内  

---

*与插件版本：`npc_library_tool`（`addons/npc_library_tool`）配套；筛选逻辑以工程内 `npc_library_dock_v2.gd` 为准。*
