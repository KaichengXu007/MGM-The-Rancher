extends CanvasLayer

@export var backpack_ui_scene: PackedScene

@onready var _health_bar: ProgressBar = $MarginContainer/HBoxContainer/BarColumn/HealthBar
@onready var _armor_bar: ProgressBar = $MarginContainer/HBoxContainer/BarColumn/ArmorBar
@onready var _backpack_button: Button = $MarginContainer/HBoxContainer/BackpackButton
@onready var _relic_bar: HBoxContainer = $MarginContainer/HBoxContainer/RelicBar

var _backpack_ui_open: bool = false
var _icon_cache: Dictionary = {}


func _ready() -> void:
	GlobalManager.relics_changed.connect(refresh_relics)
	_backpack_button.pressed.connect(_on_backpack_button_pressed)
	call_deferred("_connect_player")
	refresh_relics()


func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.has_signal("health_changed"):
		player.health_changed.connect(update_health)
		update_health(player.current_health, player.max_health)
	if player.has_signal("armor_changed"):
		player.armor_changed.connect(update_armor)
		update_armor(player.current_armor, player.max_armor)


func update_health(current_hp: int, max_hp: int) -> void:
	_health_bar.max_value = max_hp
	_health_bar.value = current_hp


func update_armor(current_armor: int, max_armor: int) -> void:
	_armor_bar.visible = max_armor > 0
	if max_armor <= 0:
		return
	_armor_bar.max_value = max_armor
	_armor_bar.value = current_armor


func refresh_relics() -> void:
	for child in _relic_bar.get_children():
		child.queue_free()

	for relic_id in GlobalManager.active_relics.keys():
		if GlobalManager.get_relic_count(relic_id) <= 0:
			continue
		_add_relic_icon(relic_id)


func _add_relic_icon(relic_id: String) -> void:
	var info: Dictionary = GlobalManager.RELIC_INFO.get(relic_id, {})
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(18, 18)
	slot.tooltip_text = GlobalManager.get_relic_tooltip(relic_id)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_path: String = info.get("icon", "res://icon.svg")
	if not _icon_cache.has(icon_path):
		_icon_cache[icon_path] = load(icon_path)
	icon.texture = _icon_cache[icon_path]
	icon.modulate = info.get("modulate", Color.WHITE)

	slot.add_child(icon)
	_relic_bar.add_child(slot)


func _on_backpack_button_pressed() -> void:
	if _backpack_ui_open or backpack_ui_scene == null:
		return

	var ui := backpack_ui_scene.instantiate()
	get_tree().root.add_child(ui)
	_backpack_ui_open = true
	ui.tree_exited.connect(func() -> void: _backpack_ui_open = false)
