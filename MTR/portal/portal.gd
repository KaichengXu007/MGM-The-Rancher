extends Area2D

## 场景传送门：玩家进入范围后按 F 确认传送。

@export var target_scene_path: String = ""
@export var hint_text: String = "按 F 传送"

@onready var _hint_label: Label = $HintLabel

var _player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _hint_label:
		_hint_label.text = hint_text
		_hint_label.visible = false


func _process(_delta: float) -> void:
	if not _player_in_range:
		return
	if Input.is_action_just_pressed("confirm"):
		_teleport()


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


func _teleport() -> void:
	if target_scene_path == "":
		return

	if target_scene_path == "res://dungeon.tscn":
		GlobalManager.reset_run()
	elif target_scene_path == "res://ranch.tscn":
		GlobalManager.clear_run_relics()

	get_tree().call_deferred("change_scene_to_file", target_scene_path)
