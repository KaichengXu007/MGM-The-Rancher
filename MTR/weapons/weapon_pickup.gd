extends Area2D

## 武器拾取物：按 E 拾取，替换玩家当前武器并掉落旧武器。

const DEFAULT_WEAPON_PICKUP_SCENE: PackedScene = preload("res://weapons/WeaponPickup.tscn")

@export var weapon_id: String = "musket"
@export var weapon_type: GlobalManager.WeaponType = GlobalManager.WeaponType.RANGED

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hint_label: Label = $HintLabel
@onready var _name_label: Label = $NameLabel

var _player_in_range: bool = false
var _player_ref: CharacterBody2D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_visual()
	if _hint_label:
		_hint_label.visible = false


func _apply_visual() -> void:
	var info: Dictionary = GlobalManager.WEAPON_DB.get(weapon_id, {})
	_name_label.text = info.get("name", weapon_id)

	var icon_path: String = info.get("icon_path", "res://icon.svg")
	var icon_texture: Texture2D = load(icon_path)
	if icon_texture:
		_sprite.texture = icon_texture

	match weapon_type:
		GlobalManager.WeaponType.RANGED:
			_sprite.modulate = Color(0.75, 0.8, 0.95, 1.0)
		GlobalManager.WeaponType.MELEE:
			_sprite.modulate = Color(0.95, 0.75, 0.55, 1.0)
		_:
			_sprite.modulate = Color.WHITE


func _process(_delta: float) -> void:
	if not _player_in_range or _player_ref == null:
		return
	if Input.is_action_just_pressed("interact"):
		_pickup()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = true
	_player_ref = body as CharacterBody2D
	if _hint_label:
		_hint_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body != _player_ref:
		return
	_player_in_range = false
	_player_ref = null
	if _hint_label:
		_hint_label.visible = false


func _pickup() -> void:
	if _player_ref == null or not _player_ref.has_method("equip_weapon"):
		return

	_player_ref.equip_weapon(weapon_id, weapon_type, global_position, true)
	queue_free()


static func spawn_weapon_pickup(
	parent: Node,
	pickup_weapon_id: String,
	pickup_weapon_type: GlobalManager.WeaponType,
	spawn_position: Vector2,
	scene: PackedScene = null
) -> void:
	var pickup_scene: PackedScene = scene if scene else DEFAULT_WEAPON_PICKUP_SCENE
	var pickup := pickup_scene.instantiate()
	pickup.weapon_id = pickup_weapon_id
	pickup.weapon_type = pickup_weapon_type
	pickup.global_position = spawn_position
	parent.add_child(pickup)
