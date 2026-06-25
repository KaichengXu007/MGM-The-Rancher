extends CharacterBody2D

## Boss 实体：预留状态机结构，死亡后掉落遗物；出口由地牢分支门统一生成。

enum State { IDLE, CHASE, ATTACK, SKILL }

const DEFAULT_RELIC_SCENE: PackedScene = preload("res://relic/Relic.tscn")
const KNOCKBACK_BASE_FORCE: float = 800.0
const KNOCKBACK_STOP_THRESHOLD: float = 10.0
const KNOCKBACK_DECAY: float = 2000.0

@export var health: int = 500
@export var speed: float = 120.0
@export var damage: int = 20
@export var attack_range: float = 36.0
@export var spawn_attack_delay: float = 1.5
@export var knockback_resistance: float = 0.2
@export var monster_id: int = 2
@export var relic_scene: PackedScene
@export var drop_item_scene: PackedScene
@export var damage_text_scene: PackedScene

const MONSTER_EGG_DROP_CHANCE: float = 0.20

var knockback_velocity: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D

var _state: State = State.CHASE
var _can_attack: bool = false


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	get_tree().create_timer(spawn_attack_delay).timeout.connect(func() -> void: _can_attack = true)


func _physics_process(delta: float) -> void:
	if _process_knockback(delta):
		return

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


func take_damage(amount: int, weapon_knockback: float, attacker_pos: Vector2) -> void:
	health -= amount
	_apply_knockback(weapon_knockback, attacker_pos)
	_spawn_damage_text(amount)

	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self):
		return
	sprite.modulate = Color.WHITE

	if health <= 0:
		die()


func _apply_knockback(weapon_knockback: float, attacker_pos: Vector2) -> void:
	if weapon_knockback <= knockback_resistance:
		return

	var force_factor: float = weapon_knockback - knockback_resistance
	var knockback_dir: Vector2 = global_position - attacker_pos
	if knockback_dir.length_squared() < 0.001:
		knockback_dir = Vector2.RIGHT
	else:
		knockback_dir = knockback_dir.normalized()

	knockback_velocity = knockback_dir * force_factor * KNOCKBACK_BASE_FORCE


func _process_knockback(delta: float) -> bool:
	if knockback_velocity.length() <= KNOCKBACK_STOP_THRESHOLD:
		knockback_velocity = Vector2.ZERO
		return false

	velocity = knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	return true


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
	_try_spawn_monster_egg(death_position)
	queue_free()


func _try_spawn_monster_egg(at_position: Vector2) -> void:
	if drop_item_scene == null:
		return
	if randf() >= MONSTER_EGG_DROP_CHANCE:
		return

	var egg_id := GlobalManager.get_egg_item_id(monster_id)
	if egg_id == "":
		return

	var drop_item := drop_item_scene.instantiate()
	drop_item.item_id = egg_id
	drop_item.amount = 1
	drop_item.global_position = at_position + Vector2(-16, 0)
	get_tree().current_scene.call_deferred("add_child", drop_item)


func _spawn_damage_text(amount: int) -> void:
	if damage_text_scene == null:
		return

	var damage_text: Node2D = damage_text_scene.instantiate()
	damage_text.setup(amount)
	damage_text.global_position = global_position + Vector2(0, -32)

	var world := get_tree().current_scene
	if world == null:
		damage_text.queue_free()
		return
	world.add_child(damage_text)
