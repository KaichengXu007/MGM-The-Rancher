extends Area2D

## 分支传送门：按 F 确认后更新路由并进入下一房间。

@export var target_room_type: GlobalManager.RoomType = GlobalManager.RoomType.COMBAT

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hint_label: Label = $HintLabel

var _player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_door_style()
	if _hint_label:
		_hint_label.visible = false


func _apply_door_style() -> void:
	var label_text := "按 F 进入"
	var tint := Color.WHITE

	match target_room_type:
		GlobalManager.RoomType.COMBAT:
			label_text = "战斗房\n按 F 进入"
			tint = Color(0.9, 0.35, 0.35, 0.9)
		GlobalManager.RoomType.SHOP:
			label_text = "商店\n按 F 进入"
			tint = Color(0.95, 0.85, 0.25, 0.9)
		GlobalManager.RoomType.EVENT:
			if GlobalManager.current_act == 3 and GlobalManager.current_room == 8:
				label_text = "通关回城\n按 F 进入"
				tint = Color(0.35, 0.95, 0.55, 0.9)
			else:
				label_text = "事件房\n按 F 进入"
				tint = Color(0.65, 0.45, 0.95, 0.9)
		GlobalManager.RoomType.BOSS:
			label_text = "Boss 房\n按 F 进入"
			tint = Color(0.85, 0.15, 0.55, 0.95)

	if _hint_label:
		_hint_label.text = label_text
	if _sprite:
		_sprite.modulate = tint


func _process(_delta: float) -> void:
	if not _player_in_range:
		return
	if Input.is_action_just_pressed("confirm"):
		_travel()


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


func _travel() -> void:
	GlobalManager.next_room_type = target_room_type

	var is_run_complete := (
		GlobalManager.current_act == 3 and GlobalManager.current_room == 8
	)

	if not is_run_complete:
		if GlobalManager.current_room < 8:
			GlobalManager.current_room += 1
		elif GlobalManager.current_act < 3:
			GlobalManager.current_act += 1
			GlobalManager.current_room = 1

	if is_run_complete:
		GlobalManager.clear_run_relics()
		GlobalManager.reset_ranch_weapon()
		get_tree().call_deferred("change_scene_to_file", "res://ranch.tscn")
	else:
		get_tree().call_deferred("reload_current_scene")
