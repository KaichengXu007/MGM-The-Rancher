extends CharacterBody2D

## 基础追踪怪物：加入 "enemy" 分组，朝 "player" 分组中的节点移动。

@export var health: int = 30
@export var speed: float = 150.0
@export var damage: int = 10
@export var attack_range: float = 28.0
@export var knockback_resistance: float = 0.1
@export var monster_id: int = 1
@export var drop_item_scene: PackedScene
@export var damage_text_scene: PackedScene

const MONSTER_EGG_DROP_CHANCE: float = 0.20
const BASE_COIN_DROP_CHANCE: float = 0.50
const BASE_COIN_LARGE_DROP_CHANCE: float = 0.10
const DROP_SPREAD_RADIUS: float = 12.0
const KNOCKBACK_BASE_FORCE: float = 800.0
const KNOCKBACK_STOP_THRESHOLD: float = 10.0
const KNOCKBACK_DECAY: float = 2000.0

var knockback_velocity: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("enemy")


func _physics_process(delta: float) -> void:
	if _process_knockback(delta):
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()

	if distance > attack_range:
		velocity = to_player.normalized() * speed
	else:
		velocity = Vector2.ZERO
		if player.has_method("take_damage"):
			player.take_damage(damage)

	move_and_slide()


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
		_die()


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


func _die() -> void:
	_spawn_drop()
	queue_free()


func _spawn_drop() -> void:
	if drop_item_scene == null:
		return

	var drops: Array[String] = []
	if _roll_drop(_get_monster_egg_drop_chance()):
		drops.append(GlobalManager.get_egg_item_id(monster_id))
	if _roll_drop(BASE_COIN_DROP_CHANCE):
		drops.append("coin_small")
	if _roll_drop(BASE_COIN_LARGE_DROP_CHANCE):
		drops.append("coin_large")

	for i in drops.size():
		if drops[i] == "":
			continue
		_spawn_drop_item(drops[i], i)


func _get_monster_egg_drop_chance() -> float:
	var chance := MONSTER_EGG_DROP_CHANCE
	if GlobalManager.get_relic_count("spirit_ball") > 0:
		chance += 0.25
	return chance


func _roll_drop(chance: float) -> bool:
	return randf() < chance


func _spawn_drop_item(item_id: String, index: int) -> void:
	var drop_item := drop_item_scene.instantiate()
	drop_item.item_id = item_id
	drop_item.amount = 1

	var angle := index * TAU / 6.0
	drop_item.global_position = global_position + Vector2(cos(angle), sin(angle)) * DROP_SPREAD_RADIUS
	get_tree().current_scene.add_child(drop_item)


func _spawn_damage_text(amount: int) -> void:
	if damage_text_scene == null:
		return

	var damage_text: Node2D = damage_text_scene.instantiate()
	damage_text.setup(amount)
	damage_text.global_position = global_position + Vector2(0, -24)

	var world := get_tree().current_scene
	if world == null:
		damage_text.queue_free()
		return
	world.add_child(damage_text)
