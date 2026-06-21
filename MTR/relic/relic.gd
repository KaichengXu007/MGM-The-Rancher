extends Area2D

## 遗物拾取物：进入范围后按 F 确认拾取。

@export var relic_id: String = "haste_boot"
@export var pickup_delay: float = 0.8

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _name_label: Label = $NameLabel
@onready var _hint_label: Label = $HintLabel

var _can_pickup: bool = false
var _player_in_range: bool = false
var _player_ref: Node2D = null


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var info: Dictionary = GlobalManager.RELIC_INFO.get(relic_id, {})
	_sprite.modulate = info.get("modulate", Color.WHITE)
	_name_label.text = info.get("name", relic_id)
	if _hint_label:
		_hint_label.visible = false

	get_tree().create_timer(pickup_delay).timeout.connect(_enable_pickup)


func _enable_pickup() -> void:
	_can_pickup = true
	if _player_in_range and _hint_label:
		_hint_label.visible = true


func _process(_delta: float) -> void:
	if not _can_pickup or not _player_in_range or _player_ref == null:
		return
	if Input.is_action_just_pressed("confirm"):
		_pickup()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = true
	_player_ref = body
	if _can_pickup and _hint_label:
		_hint_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body != _player_ref:
		return
	_player_in_range = false
	_player_ref = null
	if _hint_label:
		_hint_label.visible = false


func _pickup() -> void:
	GlobalManager.add_relic(relic_id)
	if _player_ref and _player_ref.has_method("apply_relic_effects"):
		_player_ref.apply_relic_effects()
	queue_free()
