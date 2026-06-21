extends CanvasLayer

const BACKPACK_SLOT_COUNT: int = 10

const ICON_PATHS: Dictionary = {
	"egg": "res://icon.svg",
	"gold": "res://icon.svg",
}

@export var slot_scene: PackedScene

@onready var _backpack_grid: GridContainer = $CenterPanel/MarginContainer/VBoxContainer/BackpackGrid
@onready var _close_button: Button = $CenterPanel/MarginContainer/VBoxContainer/CloseButton

var _slots: Array[Node] = []
var _icon_cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	_close_button.pressed.connect(_on_close_pressed)
	_init_slots()
	refresh_backpack()


func _init_slots() -> void:
	if slot_scene == null:
		push_error("BackpackUI: slot_scene 未设置")
		return

	for i in BACKPACK_SLOT_COUNT:
		var slot := slot_scene.instantiate()
		_backpack_grid.add_child(slot)
		_slots.append(slot)


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
