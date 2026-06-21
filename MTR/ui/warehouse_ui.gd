extends CanvasLayer

const BACKPACK_SLOT_COUNT: int = 10
const WAREHOUSE_SLOT_COUNT: int = 100

const ICON_PATHS: Dictionary = {
	"egg": "res://icon.svg",
	"coin_small": "res://icon.svg",
	"coin_large": "res://icon.svg",
}

@export var slot_scene: PackedScene

@onready var _backpack_grid: GridContainer = $CenterPanel/MarginContainer/VBoxContainer/HBoxContainer/BackpackPanel/BackpackGrid
@onready var _warehouse_grid: GridContainer = $CenterPanel/MarginContainer/VBoxContainer/HBoxContainer/WarehousePanel/WarehouseGrid
@onready var _close_button: Button = $CenterPanel/MarginContainer/VBoxContainer/CloseButton

var _backpack_slots: Array[Node] = []
var _warehouse_slots: Array[Node] = []
var _icon_cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close_button.pressed.connect(queue_free)
	_init_slots()
	refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()


func _init_slots() -> void:
	if slot_scene == null:
		push_error("WarehouseUI: slot_scene 未设置")
		return

	for i in BACKPACK_SLOT_COUNT:
		var slot := slot_scene.instantiate()
		_backpack_grid.add_child(slot)
		slot.slot_clicked.connect(_on_backpack_slot_clicked)
		_backpack_slots.append(slot)

	for i in WAREHOUSE_SLOT_COUNT:
		var slot := slot_scene.instantiate()
		_warehouse_grid.add_child(slot)
		slot.slot_clicked.connect(_on_warehouse_slot_clicked)
		_warehouse_slots.append(slot)


func refresh_ui() -> void:
	for slot in _backpack_slots:
		slot.set_empty()
	for slot in _warehouse_slots:
		slot.set_empty()

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	_fill_slots(_backpack_slots, player.backpack)
	_fill_slots(_warehouse_slots, GlobalManager.base_warehouse)


func _fill_slots(slots: Array[Node], items: Dictionary) -> void:
	var item_ids: Array = items.keys()
	item_ids.sort()

	for i in item_ids.size():
		if i >= slots.size():
			break
		var id: String = item_ids[i]
		var amount: int = items[id]
		var icon := _get_icon(id)
		slots[i].set_item(id, amount, icon)


func _get_icon(item_id: String) -> Texture2D:
	if _icon_cache.has(item_id):
		return _icon_cache[item_id]

	var path: String = ICON_PATHS.get(item_id, "res://icon.svg")
	var texture: Texture2D = load(path)
	_icon_cache[item_id] = texture
	return texture


func _on_backpack_slot_clicked(item_id: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if not player.remove_from_backpack(item_id, 1):
		return

	if GlobalManager.add_to_warehouse(item_id, 1):
		refresh_ui()
		return

	# 仓库满则退回背包
	player.add_to_backpack(item_id, 1)
	refresh_ui()


func _on_warehouse_slot_clicked(item_id: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	if not GlobalManager.remove_from_warehouse(item_id, 1):
		return

	if player.add_to_backpack(item_id, 1):
		refresh_ui()
		return

	# 背包满则退回仓库
	GlobalManager.add_to_warehouse(item_id, 1)
	refresh_ui()
