extends CanvasLayer

const BACKPACK_SLOT_COUNT: int = 10

const ICON_PATHS: Dictionary = {
	"egg": "res://icon.svg",
	"gold": "res://icon.svg",
}

@export var slot_scene: PackedScene

@onready var _weapon_slot: TextureRect = $CenterPanel/MarginContainer/VBoxContainer/WeaponSlotPanel/WeaponSlot
@onready var _health_stat: Label = $CenterPanel/MarginContainer/VBoxContainer/StatsPanel/StatsGrid/HealthStat
@onready var _armor_stat: Label = $CenterPanel/MarginContainer/VBoxContainer/StatsPanel/StatsGrid/ArmorStat
@onready var _speed_stat: Label = $CenterPanel/MarginContainer/VBoxContainer/StatsPanel/StatsGrid/SpeedStat
@onready var _attack_stat: Label = $CenterPanel/MarginContainer/VBoxContainer/StatsPanel/StatsGrid/AttackStat
@onready var _backpack_grid: GridContainer = $CenterPanel/MarginContainer/VBoxContainer/BackpackGrid
@onready var _close_button: Button = $CenterPanel/MarginContainer/VBoxContainer/CloseButton

var _slots: Array[Node] = []
var _icon_cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	GlobalManager.weapon_changed.connect(_on_weapon_changed)
	GlobalManager.talent_upgraded.connect(_on_stats_refresh_requested)
	_close_button.pressed.connect(_on_close_pressed)
	_init_slots()
	_connect_player_signals()
	refresh_backpack()
	refresh_stats()
	_on_weapon_changed(GlobalManager.current_weapon_id)


func _connect_player_signals() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.has_signal("stats_changed") and not player.stats_changed.is_connected(refresh_stats):
		player.stats_changed.connect(refresh_stats)
	if player.has_signal("health_changed") and not player.health_changed.is_connected(_on_stats_refresh_requested):
		player.health_changed.connect(_on_stats_refresh_requested)
	if player.has_signal("armor_changed") and not player.armor_changed.is_connected(_on_stats_refresh_requested):
		player.armor_changed.connect(_on_stats_refresh_requested)


func _on_stats_refresh_requested(_arg: Variant = null) -> void:
	refresh_stats()


func _init_slots() -> void:
	if slot_scene == null:
		push_error("BackpackUI: slot_scene 未设置")
		return

	for i in BACKPACK_SLOT_COUNT:
		var slot := slot_scene.instantiate()
		_backpack_grid.add_child(slot)
		_slots.append(slot)


func refresh_stats() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("get_stats_text"):
		return

	var stats: Dictionary = player.get_stats_text()
	_health_stat.text = "生命: %s" % stats.get("health", "-")
	_armor_stat.text = "护甲: %s" % stats.get("armor", "-")
	_speed_stat.text = "移速: %s" % stats.get("move_speed", "-")
	_attack_stat.text = "攻击: %s" % stats.get("attack", "-")


func _on_weapon_changed(weapon_id: String) -> void:
	var weapon_data: Dictionary = GlobalManager.WEAPON_DB.get(weapon_id, {})
	if weapon_data.is_empty():
		_weapon_slot.texture = null
		_weapon_slot.tooltip_text = weapon_id
		refresh_stats()
		return

	var icon_path: String = weapon_data.get("icon_path", "res://icon.svg")
	_weapon_slot.texture = load(icon_path)
	_weapon_slot.tooltip_text = "%s\n类型: %s\n攻击力: %d" % [
		weapon_data.get("name", weapon_id),
		weapon_data.get("type_name", ""),
		int(weapon_data.get("atk", 0)),
	]
	refresh_stats()


func refresh_backpack() -> void:
	for slot in _slots:
		slot.set_empty()

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var items: Dictionary = player.backpack
	var item_ids: Array = items.keys()
	item_ids.sort()

	for i in item_ids.size():
		if i >= _slots.size():
			break
		var id: String = item_ids[i]
		_slots[i].set_item(id, items[id], _get_icon(id))


func _get_icon(item_id: String) -> Texture2D:
	if _icon_cache.has(item_id):
		return _icon_cache[item_id]

	var path: String = ICON_PATHS.get(item_id, "res://icon.svg")
	var texture: Texture2D = load(path)
	_icon_cache[item_id] = texture
	return texture


func _on_close_pressed() -> void:
	get_tree().paused = false
	queue_free()
