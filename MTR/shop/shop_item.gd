extends Area2D
class_name ShopItem

## 商店单个商品：靠近后按 F 购买，购买后消失。

enum ProductType { HEALTH_PACK, RELIC }

const GOLD_ITEM_ID: String = "gold"
const HEALTH_PACK_HEAL_RATIO: float = 0.5

@export var product_type: ProductType = ProductType.HEALTH_PACK
@export var relic_id: String = ""
@export var price: int = 2

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _name_label: Label = $NameLabel
@onready var _price_label: Label = $PriceLabel
@onready var _hint_label: Label = $HintLabel

var _sold: bool = false
var _player_in_range: bool = false
var _player_ref: Node2D = null


func setup(type: ProductType, relic: String, cost: int) -> void:
	product_type = type
	relic_id = relic
	price = cost
	if is_node_ready():
		_refresh_display()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_display()
	if _hint_label:
		_hint_label.visible = false


func _refresh_display() -> void:
	if _name_label == null or _price_label == null or _sprite == null:
		return

	match product_type:
		ProductType.HEALTH_PACK:
			_name_label.text = "血包（+50%）"
			_sprite.modulate = Color(0.95, 0.35, 0.4, 1.0)
		ProductType.RELIC:
			var info: Dictionary = GlobalManager.RELIC_INFO.get(relic_id, {})
			_name_label.text = info.get("name", relic_id)
			_sprite.modulate = info.get("modulate", Color.WHITE)

	_price_label.text = "%d 金币" % price


func _process(_delta: float) -> void:
	if _sold or not _player_in_range or _player_ref == null:
		return
	if Input.is_action_just_pressed("confirm"):
		_try_purchase()


func _on_body_entered(body: Node2D) -> void:
	if _sold or not body.is_in_group("player"):
		return
	_player_in_range = true
	_player_ref = body
	if _hint_label:
		_hint_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body != _player_ref:
		return
	_player_in_range = false
	_player_ref = null
	if _hint_label:
		_hint_label.visible = false


func _try_purchase() -> void:
	if _sold or _player_ref == null:
		return
	if not _player_ref.has_method("remove_from_backpack"):
		return

	if not _player_ref.remove_from_backpack(GOLD_ITEM_ID, price):
		_show_feedback("金币不足（需要 %d）" % price)
		return

	match product_type:
		ProductType.HEALTH_PACK:
			var healed := 0
			if _player_ref.has_method("heal_percent"):
				healed = _player_ref.heal_percent(HEALTH_PACK_HEAL_RATIO)
			_show_feedback("恢复 %d 生命值（50%%）" % healed)
		ProductType.RELIC:
			GlobalManager.add_relic(relic_id)
			if _player_ref.has_method("apply_relic_effects"):
				_player_ref.apply_relic_effects()
			var relic_name: String = GlobalManager.RELIC_INFO.get(relic_id, {}).get("name", relic_id)
			_show_feedback("获得遗物：%s" % relic_name)

	_mark_sold()


func _mark_sold() -> void:
	_sold = true
	monitoring = false
	if _hint_label:
		_hint_label.visible = false
	queue_free()


func _show_feedback(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 1.0))
	label.z_index = 30

	var world := get_tree().current_scene
	if world == null:
		world = get_parent()
	world.add_child(label)
	label.global_position = global_position + Vector2(-70, -56)

	var tween := label.create_tween()
	tween.tween_property(label, "global_position:y", label.global_position.y - 28.0, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)
