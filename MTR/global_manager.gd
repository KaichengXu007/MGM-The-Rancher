extends Node

## 全局数据管理器（Autoload 单例）。

enum RoomType { COMBAT, SHOP, EVENT, BOSS }
enum WeaponType { NONE, MELEE, RANGED }
enum RelicScope { GLOBAL, MELEE, RANGED }

const MAX_WAREHOUSE_SLOTS: int = 100
const DEFAULT_RUN_MAX_HEALTH: int = 100
const GOLD_ITEM_ID: String = "gold"
const SAVE_PATH: String = "user://mtr_save.dat"
const ENCRYPTION_KEY: String = "MTR_Secret_2026"
const PAUSE_MENU_SCENE: PackedScene = preload("res://ui/PauseMenu.tscn")
const MAIN_MENU_SCENE_PATH: String = "res://MainMenu.tscn"

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
signal talent_upgraded(talent_id: String)

const TALENT_DB: Dictionary = {
	"hp_up": {
		"name": "体能特训",
		"desc": "初始最大生命值 +10",
		"max_level": 5,
		"base_cost": 50,
		"cost_multiplier": 1.5,
	},
	"atk_up": {
		"name": "力量强化",
		"desc": "所有武器基础攻击力 +2",
		"max_level": 5,
		"base_cost": 80,
		"cost_multiplier": 1.5,
	},
	"speed_up": {
		"name": "迅捷步伐",
		"desc": "基础移动速度 +5%",
		"max_level": 3,
		"base_cost": 100,
		"cost_multiplier": 2.0,
	},
}

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
var unlocked_talents: Dictionary = {
	"hp_up": 0,
	"atk_up": 0,
	"speed_up": 0,
}
var is_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	var current_scene := get_tree().current_scene
	if current_scene == null or current_scene.name == "MainMenu":
		return
	if _has_blocking_ui():
		return
	if _is_pause_menu_open():
		return
	if get_tree().paused:
		return

	open_pause_menu()


func open_pause_menu() -> void:
	if _is_pause_menu_open():
		return

	var menu: CanvasLayer = PAUSE_MENU_SCENE.instantiate()
	menu.name = "PauseMenu"
	get_tree().root.add_child(menu)
	get_tree().paused = true
	is_paused = true
	menu.tree_exited.connect(_on_pause_menu_closed)


func _on_pause_menu_closed() -> void:
	is_paused = false


func _is_pause_menu_open() -> bool:
	return get_tree().root.get_node_or_null("PauseMenu") != null


func _has_blocking_ui() -> bool:
	for child in get_tree().root.get_children():
		if child.name in ["BackpackUI", "TalentUI", "WarehouseUI"]:
			return true
	return false


func reset_to_default_state() -> void:
	_init_default_save_data()
	reset_run()
	reset_ranch_weapon()
	run_backpack.clear()
	clear_run_relics()
	is_paused = false
	notify_run_backpack_changed()
	warehouse_updated.emit()


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
		save_game()


func save_game() -> void:
	var save_data: Dictionary = {
		"total_coins": get_warehouse_gold(),
		"unlocked_talents": unlocked_talents.duplicate(true),
		"base_warehouse": base_warehouse.duplicate(true),
		"hatched_monsters": hatched_monsters.duplicate(true),
		"incubating_eggs": incubating_eggs.duplicate(true),
	}

	var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, ENCRYPTION_KEY)
	if file == null:
		push_error("[存档] 写入失败: %s" % FileAccess.get_open_error())
		return

	file.store_string(var_to_str(save_data))
	file.close()
	print("[存档] 游戏数据已安全加密保存。")


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("未找到存档，启动全新游戏")
		return false

	var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, ENCRYPTION_KEY)
	if file == null:
		push_error("[读档] 打开失败: %s" % FileAccess.get_open_error())
		return false

	var content := file.get_as_text()
	file.close()
	if content.is_empty():
		push_error("[读档] 存档内容为空")
		return false

	var parsed: Variant = str_to_var(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[读档] 存档格式无效")
		return false

	_apply_save_data(parsed)
	print("[读档] 成功加载本地加密存档。")
	return true


func _init_default_save_data() -> void:
	base_warehouse.clear()
	unlocked_talents = {
		"hp_up": 0,
		"atk_up": 0,
		"speed_up": 0,
	}
	hatched_monsters.clear()
	incubating_eggs.clear()


func _apply_save_data(save_data: Dictionary) -> void:
	if save_data.has("base_warehouse") and save_data["base_warehouse"] is Dictionary:
		base_warehouse = save_data["base_warehouse"].duplicate(true)
	else:
		base_warehouse.clear()

	if save_data.has("total_coins"):
		var saved_gold: int = int(save_data["total_coins"])
		if saved_gold > 0 and get_warehouse_gold() <= 0:
			base_warehouse[GOLD_ITEM_ID] = saved_gold

	_apply_unlocked_talents(save_data.get("unlocked_talents", {}))
	hatched_monsters = _sanitize_monster_id_array(save_data.get("hatched_monsters", []))
	incubating_eggs = _sanitize_incubating_eggs(save_data.get("incubating_eggs", []))
	normalize_warehouse_coins()
	warehouse_updated.emit()


func _apply_unlocked_talents(raw_talents: Variant) -> void:
	unlocked_talents = {
		"hp_up": 0,
		"atk_up": 0,
		"speed_up": 0,
	}
	if raw_talents is Dictionary:
		for talent_id in TALENT_DB.keys():
			if raw_talents.has(talent_id):
				unlocked_talents[talent_id] = int(raw_talents[talent_id])


func _sanitize_monster_id_array(raw_value: Variant) -> Array:
	var result: Array = []
	if raw_value is Array:
		for entry in raw_value:
			result.append(int(entry))
	return result


func _sanitize_incubating_eggs(raw_value: Variant) -> Array:
	var result: Array = []
	if not raw_value is Array:
		return result

	for entry in raw_value:
		if entry is Dictionary:
			result.append({
				"id": int(entry.get("id", 0)),
				"time_left": float(entry.get("time_left", 0.0)),
			})
	return result


func return_to_ranch_and_save(player: Node = null) -> void:
	deposit_player_items_to_warehouse(player)
	save_game()


func manual_save(player: Node = null) -> void:
	deposit_player_items_to_warehouse(player)
	save_game()


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
	run_max_health = get_talent_max_health()
	run_current_health = run_max_health
	run_max_armor = 0
	run_current_armor = 0
	clear_run_relics()


func get_talent_max_health() -> int:
	return DEFAULT_RUN_MAX_HEALTH + unlocked_talents.get("hp_up", 0) * 10


func get_talent_attack_bonus() -> int:
	return unlocked_talents.get("atk_up", 0) * 2


func get_talent_speed_multiplier() -> float:
	return 1.0 + unlocked_talents.get("speed_up", 0) * 0.05


func get_talent_level(talent_id: String) -> int:
	return int(unlocked_talents.get(talent_id, 0))


func is_talent_maxed(talent_id: String) -> bool:
	if not TALENT_DB.has(talent_id):
		return true
	return get_talent_level(talent_id) >= int(TALENT_DB[talent_id].get("max_level", 0))


func get_talent_cost(talent_id: String) -> int:
	if not TALENT_DB.has(talent_id):
		return 0

	var info: Dictionary = TALENT_DB[talent_id]
	var level := get_talent_level(talent_id)
	if level >= int(info.get("max_level", 0)):
		return 0

	var base_cost: float = float(info.get("base_cost", 0))
	var multiplier: float = float(info.get("cost_multiplier", 1.0))
	return int(floor(base_cost * pow(multiplier, level)))


func get_warehouse_gold() -> int:
	return int(base_warehouse.get(GOLD_ITEM_ID, 0))


func add_warehouse_gold(amount: int) -> bool:
	if amount <= 0:
		return false
	return add_to_warehouse(GOLD_ITEM_ID, amount)


func remove_warehouse_gold(amount: int) -> bool:
	if amount <= 0:
		return false
	return remove_from_warehouse(GOLD_ITEM_ID, amount)


func deposit_player_items_to_warehouse(player: Node = null) -> void:
	if player != null and player.has_method("remove_from_backpack"):
		var backpack_gold: int = int(player.backpack.get(GOLD_ITEM_ID, 0))
		if backpack_gold > 0 and player.remove_from_backpack(GOLD_ITEM_ID, backpack_gold):
			add_warehouse_gold(backpack_gold)
	normalize_warehouse_coins()


func normalize_warehouse_coins() -> void:
	var gold_to_add := 0
	for coin_id in COIN_PICKUP_VALUES.keys():
		if not base_warehouse.has(coin_id):
			continue
		gold_to_add += base_warehouse[coin_id] * COIN_PICKUP_VALUES[coin_id]
		base_warehouse.erase(coin_id)

	if gold_to_add > 0:
		base_warehouse[GOLD_ITEM_ID] = base_warehouse.get(GOLD_ITEM_ID, 0) + gold_to_add
		warehouse_updated.emit()


func upgrade_talent(talent_id: String) -> bool:
	if not TALENT_DB.has(talent_id):
		return false
	if is_talent_maxed(talent_id):
		return false

	var cost := get_talent_cost(talent_id)
	if get_warehouse_gold() < cost:
		return false
	if not remove_warehouse_gold(cost):
		return false

	unlocked_talents[talent_id] = get_talent_level(talent_id) + 1
	talent_upgraded.emit(talent_id)
	save_game()
	return true


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
