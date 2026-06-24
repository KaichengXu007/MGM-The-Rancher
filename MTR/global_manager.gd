extends Node

## 全局数据管理器（Autoload 单例）。

enum RoomType { COMBAT, SHOP, EVENT, BOSS }
enum WeaponType { NONE, MELEE, RANGED }
enum RelicScope { GLOBAL, MELEE, RANGED }

const MAX_WAREHOUSE_SLOTS: int = 100
const DEFAULT_RUN_MAX_HEALTH: int = 100
const GOLD_ITEM_ID: String = "gold"

const COIN_PICKUP_VALUES: Dictionary = {
	"coin_small": 1,
	"coin_large": 5,
}

const PRODUCE_ITEM_IDS: Dictionary = {
	"小硬币": "coin_small",
	"大硬币": "coin_large",
}

const MONSTER_DB: Dictionary = {
	1: {
		"name": "小怪1",
		"egg_name": "怪物蛋（小怪1）",
		"produce_item": "小硬币",
		"produce_time": 30.0,
		"tint": Color(0.55, 0.85, 0.55, 1.0),
	},
	2: {
		"name": "Boss1",
		"egg_name": "怪物蛋（Boss1）",
		"produce_item": "大硬币",
		"produce_time": 60.0,
		"tint": Color(0.75, 0.45, 0.95, 1.0),
	},
}

const MAX_INCUBATOR_SLOTS: int = 5

const WEAPON_SCENES: Dictionary = {
	"musket": "res://weapons/Musket.tscn",
	"katana": "res://weapons/Katana.tscn",
}

const WEAPON_DB: Dictionary = {
	"musket": {
		"name": "火枪",
		"type_name": "远程武器",
		"atk": 15,
		"icon_path": "res://assets/musket_icon.svg",
	},
	"katana": {
		"name": "太刀",
		"type_name": "近战武器",
		"atk": 25,
		"icon_path": "res://assets/katana_icon.svg",
	},
}

const RELIC_INFO: Dictionary = {
	"haste_boot": {
		"name": "加速靴",
		"effect": "移动速度 +100%",
		"icon": "res://icon.svg",
		"modulate": Color(0.5, 0.8, 1.0, 1.0),
		"scope": RelicScope.GLOBAL,
	},
	"boxing_glove": {
		"name": "拳套",
		"effect": "攻击力 +20%",
		"icon": "res://icon.svg",
		"modulate": Color(0.95, 0.55, 0.35, 1.0),
		"scope": RelicScope.GLOBAL,
	},
	"throwing_dart": {
		"name": "飞镖",
		"effect": "攻击速度 +20%",
		"icon": "res://icon.svg",
		"modulate": Color(0.75, 0.9, 0.4, 1.0),
		"scope": RelicScope.RANGED,
	},
	"split_arrow": {
		"name": "分裂箭",
		"effect": "弹幕变为三叉弹",
		"icon": "res://icon.svg",
		"modulate": Color(0.85, 0.5, 0.95, 1.0),
		"scope": RelicScope.RANGED,
	},
	"avalon": {
		"name": "阿瓦隆",
		"effect": "每秒恢复 1 点生命",
		"icon": "res://icon.svg",
		"modulate": Color(0.45, 0.95, 0.65, 1.0),
		"scope": RelicScope.GLOBAL,
	},
	"spirit_ball": {
		"name": "精灵球",
		"effect": "小怪掉落怪物蛋几率 +25%",
		"icon": "res://icon.svg",
		"modulate": Color(0.95, 0.25, 0.3, 1.0),
		"scope": RelicScope.GLOBAL,
	},
	"lock_armor": {
		"name": "锁甲",
		"effect": "获得 25 点护甲",
		"icon": "res://icon.svg",
		"modulate": Color(0.75, 0.78, 0.85, 1.0),
		"scope": RelicScope.GLOBAL,
	},
}

signal warehouse_updated
signal run_backpack_changed
signal relics_changed
signal weapon_changed(new_weapon_id: String)
signal egg_hatched(monster_id: int)
signal incubation_changed

var base_warehouse: Dictionary = {}
var run_backpack: Dictionary = {}
var run_max_health: int = DEFAULT_RUN_MAX_HEALTH
var run_current_health: int = DEFAULT_RUN_MAX_HEALTH
var run_max_armor: int = 0
var run_current_armor: int = 0

const RANCH_DEFAULT_WEAPON_ID: String = "musket"
const RANCH_DEFAULT_WEAPON_TYPE: WeaponType = WeaponType.RANGED

var current_weapon_id: String = RANCH_DEFAULT_WEAPON_ID
var current_weapon_type: WeaponType = RANCH_DEFAULT_WEAPON_TYPE

var current_act: int = 1
var current_room: int = 1
var next_room_type: RoomType = RoomType.COMBAT
var active_relics: Dictionary = {}

var incubating_eggs: Array = []
var hatched_monsters: Array = []


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_tick_incubation(delta)


func _tick_incubation(delta: float) -> void:
	var changed := false
	for i in range(incubating_eggs.size() - 1, -1, -1):
		var egg: Dictionary = incubating_eggs[i]
		egg["time_left"] = float(egg.get("time_left", 0.0)) - delta
		if egg["time_left"] > 0.0:
			continue

		var monster_id: int = int(egg.get("id", 0))
		incubating_eggs.remove_at(i)
		hatched_monsters.append(monster_id)
		egg_hatched.emit(monster_id)
		changed = true

	if changed:
		incubation_changed.emit()


func get_egg_item_id(monster_id: int) -> String:
	return MONSTER_DB.get(monster_id, {}).get("egg_name", "")


func get_monster_id_from_egg_item(egg_item_id: String) -> int:
	for monster_id in MONSTER_DB.keys():
		if MONSTER_DB[monster_id].get("egg_name", "") == egg_item_id:
			return int(monster_id)
	return 0


func get_produce_item_id(monster_id: int) -> String:
	var display_name: String = MONSTER_DB.get(monster_id, {}).get("produce_item", "小硬币")
	return PRODUCE_ITEM_IDS.get(display_name, "coin_small")


func is_monster_egg_item(item_id: String) -> bool:
	return get_monster_id_from_egg_item(item_id) > 0


func get_item_display_name(item_id: String) -> String:
	if is_monster_egg_item(item_id):
		return item_id
	return item_id


func try_consume_one_egg(player: Node) -> int:
	for monster_id in MONSTER_DB.keys():
		var egg_id: String = get_egg_item_id(monster_id)
		if egg_id == "":
			continue
		if base_warehouse.get(egg_id, 0) > 0:
			if remove_from_warehouse(egg_id, 1):
				return monster_id
		if player != null and player.has_method("remove_from_backpack"):
			if player.remove_from_backpack(egg_id, 1):
				return monster_id
	return 0


func start_incubation(monster_id: int) -> bool:
	if incubating_eggs.size() >= MAX_INCUBATOR_SLOTS:
		return false
	if not MONSTER_DB.has(monster_id):
		return false

	var hatch_time: float = float(MONSTER_DB[monster_id].get("produce_time", 30.0))
	incubating_eggs.append({"id": monster_id, "time_left": hatch_time})
	incubation_changed.emit()
	return true


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


func get_weapon_type(weapon_id: String) -> WeaponType:
	match weapon_id:
		"musket":
			return WeaponType.RANGED
		"katana":
			return WeaponType.MELEE
		_:
			return WeaponType.NONE


func notify_run_backpack_changed() -> void:
	run_backpack_changed.emit()


func set_current_weapon(new_id: String, new_type: WeaponType) -> void:
	current_weapon_id = new_id
	current_weapon_type = new_type
	weapon_changed.emit(new_id)


func reset_ranch_weapon() -> void:
	set_current_weapon(RANCH_DEFAULT_WEAPON_ID, RANCH_DEFAULT_WEAPON_TYPE)


func clear_run_relics() -> void:
	if active_relics.is_empty():
		return
	active_relics.clear()
	relics_changed.emit()


func get_relic_count(relic_id: String) -> int:
	var entry = active_relics.get(relic_id)
	if entry == null:
		return 0
	if entry is Dictionary:
		return int(entry.get("count", 0))
	return int(entry)


func get_relic_scope(relic_id: String) -> RelicScope:
	var entry = active_relics.get(relic_id)
	if entry is Dictionary and entry.has("scope"):
		return entry.scope
	return RELIC_INFO.get(relic_id, {}).get("scope", RelicScope.GLOBAL)


func relic_applies(relic_id: String, weapon_type: WeaponType) -> bool:
	if get_relic_count(relic_id) <= 0:
		return false

	var scope: RelicScope = get_relic_scope(relic_id)
	match scope:
		RelicScope.GLOBAL:
			return true
		RelicScope.RANGED:
			return weapon_type == WeaponType.RANGED
		RelicScope.MELEE:
			return weapon_type == WeaponType.MELEE
	return false


func add_relic(relic_id: String) -> void:
	var scope: RelicScope = RELIC_INFO.get(relic_id, {}).get("scope", RelicScope.GLOBAL)
	if active_relics.has(relic_id):
		active_relics[relic_id]["count"] = get_relic_count(relic_id) + 1
	else:
		active_relics[relic_id] = {"count": 1, "scope": scope}
	relics_changed.emit()


func get_relic_tooltip(relic_id: String) -> String:
	var info: Dictionary = RELIC_INFO.get(relic_id, {})
	var relic_name: String = info.get("name", relic_id)
	var effect: String = info.get("effect", "")
	return "%s\n%s" % [relic_name, effect]


func get_random_unowned_relic_id() -> String:
	var ids := get_random_unowned_relic_ids(1)
	if ids.is_empty():
		return ""
	return ids[0]


func get_random_unowned_relic_ids(count: int) -> Array[String]:
	var available: Array[String] = []
	for relic_id in RELIC_INFO.keys():
		if get_relic_count(relic_id) <= 0:
			available.append(relic_id)

	available.shuffle()

	var result: Array[String] = []
	var pick_count := mini(count, available.size())
	for i in pick_count:
		result.append(available[i])
	return result


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
