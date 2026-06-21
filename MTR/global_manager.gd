extends Node

## 全局数据管理器（Autoload 单例）。

enum RoomType { COMBAT, SHOP, EVENT, BOSS }

const MAX_WAREHOUSE_SLOTS: int = 100
const DEFAULT_RUN_MAX_HEALTH: int = 100
const GOLD_ITEM_ID: String = "gold"

const COIN_PICKUP_VALUES: Dictionary = {
	"coin_small": 1,
	"coin_large": 5,
}

const RELIC_INFO: Dictionary = {
	"haste_boot": {
		"name": "加速靴",
		"effect": "移动速度 +100%",
		"icon": "res://icon.svg",
		"modulate": Color(0.5, 0.8, 1.0, 1.0),
	},
	"boxing_glove": {
		"name": "拳套",
		"effect": "攻击力 +20%",
		"icon": "res://icon.svg",
		"modulate": Color(0.95, 0.55, 0.35, 1.0),
	},
	"throwing_dart": {
		"name": "飞镖",
		"effect": "攻击速度 +20%",
		"icon": "res://icon.svg",
		"modulate": Color(0.75, 0.9, 0.4, 1.0),
	},
	"split_arrow": {
		"name": "分裂箭",
		"effect": "弹幕变为三叉弹",
		"icon": "res://icon.svg",
		"modulate": Color(0.85, 0.5, 0.95, 1.0),
	},
	"avalon": {
		"name": "阿瓦隆",
		"effect": "每秒恢复 1 点生命",
		"icon": "res://icon.svg",
		"modulate": Color(0.45, 0.95, 0.65, 1.0),
	},
	"spirit_ball": {
		"name": "精灵球",
		"effect": "小怪掉落怪物蛋几率 +25%",
		"icon": "res://icon.svg",
		"modulate": Color(0.95, 0.25, 0.3, 1.0),
	},
	"lock_armor": {
		"name": "锁甲",
		"effect": "获得 25 点护甲",
		"icon": "res://icon.svg",
		"modulate": Color(0.75, 0.78, 0.85, 1.0),
	},
}

signal warehouse_updated
signal run_backpack_changed
signal relics_changed

var base_warehouse: Dictionary = {}
var run_backpack: Dictionary = {}
var run_max_health: int = DEFAULT_RUN_MAX_HEALTH
var run_current_health: int = DEFAULT_RUN_MAX_HEALTH
var run_max_armor: int = 0
var run_current_armor: int = 0

var current_act: int = 1
var current_room: int = 1
var next_room_type: RoomType = RoomType.COMBAT
var active_relics: Dictionary = {}


func reset_run() -> void:
	current_act = 1
	current_room = 1
	next_room_type = RoomType.COMBAT
	run_max_health = DEFAULT_RUN_MAX_HEALTH
	run_current_health = DEFAULT_RUN_MAX_HEALTH
	run_max_armor = 0
	run_current_armor = 0
	clear_run_relics()


func get_current_level_name() -> String:
	return "%d-%d" % [current_act, current_room]


func clear_run_relics() -> void:
	if active_relics.is_empty():
		return
	active_relics.clear()
	relics_changed.emit()


func add_relic(relic_id: String) -> void:
	active_relics[relic_id] = active_relics.get(relic_id, 0) + 1
	relics_changed.emit()


func get_relic_tooltip(relic_id: String) -> String:
	var info: Dictionary = RELIC_INFO.get(relic_id, {})
	var relic_name: String = info.get("name", relic_id)
	var effect: String = info.get("effect", "")
	return "%s\n%s" % [relic_name, effect]


func get_random_unowned_relic_id() -> String:
	var available: Array[String] = []
	for relic_id in RELIC_INFO.keys():
		if active_relics.get(relic_id, 0) <= 0:
			available.append(relic_id)

	if available.is_empty():
		return ""

	return available.pick_random()


func normalize_backpack_item(item_id: String, amount: int) -> Dictionary:
	if COIN_PICKUP_VALUES.has(item_id):
		return {
			"item_id": GOLD_ITEM_ID,
			"amount": COIN_PICKUP_VALUES[item_id] * amount,
		}
	return {"item_id": item_id, "amount": amount}


func migrate_backpack_coins(backpack: Dictionary) -> void:
	var gold_to_add := 0
	for coin_id in COIN_PICKUP_VALUES.keys():
		if not backpack.has(coin_id):
			continue
		gold_to_add += backpack[coin_id] * COIN_PICKUP_VALUES[coin_id]
		backpack.erase(coin_id)

	if gold_to_add > 0:
		backpack[GOLD_ITEM_ID] = backpack.get(GOLD_ITEM_ID, 0) + gold_to_add


func add_to_warehouse(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return false

	if base_warehouse.has(item_id):
		base_warehouse[item_id] += amount
		warehouse_updated.emit()
		return true

	if base_warehouse.size() >= MAX_WAREHOUSE_SLOTS:
		print("仓库已满")
		return false

	base_warehouse[item_id] = amount
	warehouse_updated.emit()
	return true


func remove_from_warehouse(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return false
	if not base_warehouse.has(item_id):
		return false
	if base_warehouse[item_id] < amount:
		return false

	base_warehouse[item_id] -= amount
	if base_warehouse[item_id] <= 0:
		base_warehouse.erase(item_id)

	warehouse_updated.emit()
	return true


func add_egg_to_warehouse() -> void:
	add_to_warehouse("egg", 1)
