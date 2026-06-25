extends Area2D

## 牧场天赋终端：靠近后按 E 打开天赋升级面板。

@export var talent_ui_scene: PackedScene

@onready var _hint_label: Label = $HintLabel

var _player_in_range: bool = false
var _ui_open: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _hint_label:
		_hint_label.visible = false


func _process(_delta: float) -> void:
	if not _player_in_range or _ui_open:
		return
	if Input.is_action_just_pressed("interact"):
		_open_talent_ui()


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


func _open_talent_ui() -> void:
	if talent_ui_scene == null:
		push_warning("TalentTerminal: talent_ui_scene 未设置")
		return

	var player := get_tree().get_first_node_in_group("player")
	GlobalManager.deposit_player_items_to_warehouse(player)

	var ui := talent_ui_scene.instantiate()
	get_tree().root.add_child(ui)
	get_tree().paused = true
	_ui_open = true
	ui.tree_exited.connect(_on_ui_closed)


func _on_ui_closed() -> void:
	get_tree().paused = false
	_ui_open = false
