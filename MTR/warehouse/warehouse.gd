extends Area2D

## 基地仓库实体：玩家靠近后按互动键打开 WarehouseUI。

@export var warehouse_ui_scene: PackedScene

@onready var _hint_label: Label = $HintLabel

var _player_in_range: bool = false
var _ui_open: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_hint_label.visible = false


func _process(_delta: float) -> void:
	if not _player_in_range or _ui_open:
		return

	if Input.is_action_just_pressed("interact"):
		_open_warehouse_ui()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_hint_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_hint_label.visible = false


func _open_warehouse_ui() -> void:
	if warehouse_ui_scene == null:
		push_warning("Warehouse: warehouse_ui_scene 未设置")
		return

	var ui := warehouse_ui_scene.instantiate()
	get_tree().root.add_child(ui)
	_ui_open = true
	ui.tree_exited.connect(_on_ui_closed)


func _on_ui_closed() -> void:
	_ui_open = false
