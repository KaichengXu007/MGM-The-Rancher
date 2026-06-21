extends PanelContainer

const ITEM_NAMES: Dictionary = {
	"egg": "怪物蛋",
	"gold": "金币",
	"coin_small": "小硬币",
	"coin_large": "大硬币",
}

signal slot_clicked(item_id: String)

var item_id: String = ""

@onready var _icon: TextureRect = $SlotRoot/Icon
@onready var _amount_label: Label = $SlotRoot/AmountLabel
@onready var _click_button: Button = $SlotRoot/ClickButton


func _ready() -> void:
	_click_button.pressed.connect(_on_click_button_pressed)
	set_empty()


func set_empty() -> void:
	item_id = ""
	_icon.texture = null
	_amount_label.visible = false
	_click_button.disabled = true
	_set_tooltip("")


func set_item(id: String, amount: int, icon: Texture2D) -> void:
	item_id = id
	_icon.texture = icon
	_amount_label.text = str(amount)
	_amount_label.visible = true
	_click_button.disabled = false

	var display_name: String = ITEM_NAMES.get(id, id)
	_set_tooltip("%s (x%d)" % [display_name, amount])


func _set_tooltip(text: String) -> void:
	tooltip_text = text
	_click_button.tooltip_text = text


func _on_click_button_pressed() -> void:
	if item_id != "":
		slot_clicked.emit(item_id)
