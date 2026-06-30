class_name UnitStats
extends Resource

## 单位属性数据 — 纯数据层，不包含逻辑
##
## 用途：
##   - 集中管理所有单位的战斗数值
##   - attack / defense / range 等可热调（通过 Resource 的 property 机制）
##   - 战斗逻辑只读 stats，禁止在 unit script 写死数值
##
## ⭐ 规则：
##   damage = attacker.stats.attack - target.stats.defense
##   只减不乘，至少为 0

# ========== 核心战斗属性 ==========
@export var hp: float = 100.0
@export var attack: float = 10.0
@export var defense: float = 0.0
@export var mp: float = 0.0

# ========== 索敌与攻击范围 ==========
@export var attack_range: float = 45.0     # 攻击距离（近战短/远程长）
@export var aggro_range: float = 250.0     # 自动索敌半径
@export var chase_range: float = 400.0     # 追击上限距离

# ========== 攻击节奏 ==========
@export var attack_cooldown: float = 1.0  # 攻击间隔（秒）

# ========== 移动参数 ==========
@export var move_speed: float = 200.0
@export var max_speed: float = 350.0
@export var acceleration: float = 800.0

# ========== 特殊属性 ==========
@export var attack_type: int = 0  # 0=物理, 1=魔法, 2=真实
@export var armor_type: int = 0  # 0=无甲, 1=轻甲, 2=重甲

# ========== 便利方法 ==========

## 计算伤害（攻击方 stats → 防御方 stats）
static func calculate_damage(attacker: UnitStats, target: UnitStats) -> float:
	if not attacker or not target:
		return 0.0
	var raw: float = attacker.attack - target.defense
	return max(0.0, raw)

## 快速创建常用配置
static func create_剑士_stats() -> UnitStats:
	var s := UnitStats.new()
	s.hp = 100.0
	s.attack = 12.0
	s.defense = 2.0
	s.attack_range = 45.0
	s.aggro_range = 250.0
	s.chase_range = 400.0
	s.attack_cooldown = 1.0
	s.move_speed = 200.0
	return s

static func create_弓箭手_stats() -> UnitStats:
	var s := UnitStats.new()
	s.hp = 80.0
	s.attack = 8.0
	s.defense = 0.0
	s.attack_range = 150.0
	s.aggro_range = 250.0
	s.chase_range = 400.0
	s.attack_cooldown = 0.8
	s.move_speed = 200.0
	return s

static func create_农民_stats() -> UnitStats:
	var s := UnitStats.new()
	s.hp = 60.0
	s.attack = 5.0
	s.defense = 0.0
	s.attack_range = 25.0
	s.aggro_range = 0.0
	s.attack_cooldown = 1.5
	s.move_speed = 200.0
	return s
