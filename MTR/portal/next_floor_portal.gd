extends Area2D

## 下一层传送门：进入范围后按 F 确认进入下一层。


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
	if Input.is_action_just_pressed("confirm"):
		GlobalManager.current_floor += 1
		get_tree().call_deferred("reload_current_scene")


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
