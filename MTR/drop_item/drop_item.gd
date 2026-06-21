extends Area2D

## 通用掉落物：玩家拾取后进入局内背包。

const ITEM_NAMES: Dictionary = {
	"egg": "怪物蛋",
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
	match item_id:
		"egg":
			sprite.modulate = Color(0.9, 0.95, 0.3)
		"coin_small":
			sprite.modulate = Color(1.0, 0.85, 0.2)
		"coin_large":
			sprite.modulate = Color(1.0, 0.6, 0.1)
		_:
			sprite.modulate = Color.WHITE

	var display_name: String = ITEM_NAMES.get(item_id, item_id)
	if amount > 1:
		_name_label.text = "%s x%d" % [display_name, amount]
	else:
		_name_label.text = display_name


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.has_method("add_to_backpack"):
		return

	if body.add_to_backpack(item_id, amount):
		call_deferred("queue_free")
