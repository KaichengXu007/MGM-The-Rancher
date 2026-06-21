extends CharacterBody2D

## Boss 实体：预留状态机结构，死亡后掉落遗物；出口由地牢分支门统一生成。

enum State { IDLE, CHASE, ATTACK, SKILL }

const DEFAULT_RELIC_SCENE: PackedScene = preload("res://relic/Relic.tscn")

@export var health: int = 500
@export var speed: float = 120.0
@export var damage: int = 20
@export var attack_range: float = 36.0
@export var spawn_attack_delay: float = 1.5
@export var relic_scene: PackedScene
@export var drop_item_scene: PackedScene

@onready var sprite: Sprite2D = $Sprite2D

var _state: State = State.CHASE
var _can_attack: bool = false


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	get_tree().create_timer(spawn_attack_delay).timeout.connect(func() -> void: _can_attack = true)


func _physics_process(_delta: float) -> void:
	if not _can_attack:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	match _state:
		State.IDLE:
			velocity = Vector2.ZERO
		State.CHASE:
			_chase_player()
		State.ATTACK:
			pass
		State.SKILL:
			pass

	move_and_slide()


func _chase_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		velocity = Vector2.ZERO
		return

	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()

	if distance > attack_range:
		velocity = to_player.normalized() * speed
	else:
		velocity = Vector2.ZERO
		if player.has_method("take_damage"):
			player.take_damage(damage)


func take_damage(amount: int) -> void:
	health -= amount

	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self):
		return
	sprite.modulate = Color.WHITE

	if health <= 0:
		die()


func _spawn_relic(at_position: Vector2) -> void:
	var relic_id := GlobalManager.get_random_unowned_relic_id()
	if relic_id == "":
		return

	var scene: PackedScene = relic_scene if relic_scene else DEFAULT_RELIC_SCENE
	var relic := scene.instantiate()
	relic.relic_id = relic_id
	relic.global_position = at_position + Vector2(0, -24)
	get_tree().current_scene.call_deferred("add_child", relic)


func _spawn_coin_large(at_position: Vector2) -> void:
	if drop_item_scene == null:
		return

	var drop_item := drop_item_scene.instantiate()
	drop_item.item_id = "coin_large"
	drop_item.amount = 1
	drop_item.global_position = at_position + Vector2(16, 0)
	get_tree().current_scene.call_deferred("add_child", drop_item)


func die() -> void:
	var death_position := global_position
	_spawn_relic(death_position)
	_spawn_coin_large(death_position)
	queue_free()
