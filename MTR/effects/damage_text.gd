extends Node2D

## 伤害飘字：向上飘动并淡出，动画结束后自动销毁。

@onready var _label: Label = $Label

var _damage_amount: int = 0
var _is_critical: bool = false
var _configured: bool = false


func setup(damage_amount: int, is_critical: bool = false) -> void:
	_damage_amount = damage_amount
	_is_critical = is_critical
	_configured = true

	if is_node_ready():
		_apply_setup()


func _ready() -> void:
	if _configured:
		_apply_setup()


func _apply_setup() -> void:
	if not _configured or _label == null:
		return

	_label.text = str(_damage_amount)
	position.x += randf_range(-10.0, 10.0)

	if _is_critical:
		_label.add_theme_font_size_override("font_size", 24)
		_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
	else:
		_label.add_theme_font_size_override("font_size", 18)
		_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))

	z_index = 50
	_play_tween()


func _play_tween() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 45.0, 0.6)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)\
		.set_delay(0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(queue_free)
