extends Area2D

## 调试修改器：靠近后按 E 增加 500 金币。

const COIN_BONUS: int = 500

@onready var _hint_label: Label = $HintLabel

var _player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _hint_label:
		_hint_label.visible = false


func _process(_delta: float) -> void:
	if not _player_in_range:
		return
	if Input.is_action_just_pressed("interact"):
		_grant_coins()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if _hint_label:
			_hint_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if _hint_label:
			_hint_label.visible = false


func _grant_coins() -> void:
	GlobalManager.add_warehouse_gold(COIN_BONUS)
	GlobalManager.save_game()
	_show_feedback("+%d 金币（仓库 %d）" % [COIN_BONUS, GlobalManager.get_warehouse_gold()])


func _show_feedback(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45, 1.0))
	label.z_index = 20
	add_child(label)
	label.position = Vector2(-90, -80)

	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 32.0, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)
