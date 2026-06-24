extends Area2D

## 通用物品拾取物（与 DropItem 相同逻辑，用于怪物蛋等）。

const ITEM_NAMES: Dictionary = {
	"coin_small": "小硬币",
	"coin_large": "大硬币",
}

@export var item_id: String = ""
@export var amount: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var _name_label: Label = $NameLabel


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visual()


func _apply_visual() -> void:
	if GlobalManager.is_monster_egg_item(item_id):
		sprite.modulate = Color(0.9, 0.95, 0.35)
	elif item_id == "coin_small":
		sprite.modulate = Color(1.0, 0.85, 0.2)
	elif item_id == "coin_large":
		sprite.modulate = Color(1.0, 0.6, 0.1)
	else:
		sprite.modulate = Color.WHITE

	var display_name := _get_display_name()
	if amount > 1:
		_name_label.text = "%s x%d" % [display_name, amount]
	else:
		_name_label.text = display_name


func _get_display_name() -> String:
	if GlobalManager.is_monster_egg_item(item_id):
		return item_id
	return ITEM_NAMES.get(item_id, item_id)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.has_method("add_to_backpack"):
		return

	if body.add_to_backpack(item_id, amount):
		call_deferred("queue_free")
