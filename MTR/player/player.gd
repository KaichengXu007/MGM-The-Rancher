extends CharacterBody2D

## Top-down 2D 主角控制器（类似《以撒的结合》俯视角）。
## 移动：move_left / move_right / move_up / move_down（建议 WASD）
## 射击：shoot_left / shoot_right / shoot_up / shoot_down（建议方向键）

const MAX_BACKPACK_SLOTS: int = 10

@export var move_speed: float = 300.0
@export var acceleration: float = 0.2
@export var friction: float = 0.2
@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.3
@export var bullet_damage: int = 10
@export var max_health: int = 100
@export var current_health: int = 100

@onready var sprite: Sprite2D = $Sprite2D

signal backpack_changed
signal health_changed(current_hp: int, max_hp: int)
signal armor_changed(current_armor: int, max_armor: int)

var backpack: Dictionary = {}
var max_armor: int = 0
var current_armor: int = 0
var _base_move_speed: float = 0.0
var _base_fire_rate: float = 0.0
var _base_bullet_damage: int = 10
var _damage_multiplier: float = 1.0
var _has_split_arrow: bool = false
var _last_input_direction: Vector2 = Vector2.RIGHT
var _fire_cooldown: float = 0.0
var _invulnerable: bool = false
var _regen_timer: float = 0.0


func _ready() -> void:
	add_to_group("player")
	_base_move_speed = move_speed
	_base_fire_rate = fire_rate
	_base_bullet_damage = bullet_damage
	backpack = GlobalManager.run_backpack.duplicate(true)
	GlobalManager.migrate_backpack_coins(backpack)

	if _is_in_dungeon():
		max_health = GlobalManager.run_max_health
		current_health = GlobalManager.run_current_health
		max_armor = GlobalManager.run_max_armor
		current_armor = GlobalManager.run_current_armor
	else:
		current_health = max_health
		max_armor = 0
		current_armor = 0

	apply_relic_effects()
	_sync_backpack()
	health_changed.emit(current_health, max_health)
	armor_changed.emit(current_armor, max_armor)


func apply_relic_effects() -> void:
	move_speed = _base_move_speed
	fire_rate = _base_fire_rate
	_damage_multiplier = 1.0
	_has_split_arrow = false

	var relics := GlobalManager.active_relics
	var previous_max_armor := max_armor

	if relics.get("haste_boot", 0) > 0:
		move_speed = _base_move_speed * 2.0

	var glove_stacks: int = relics.get("boxing_glove", 0)
	if glove_stacks > 0:
		_damage_multiplier = 1.0 + 0.2 * glove_stacks

	var dart_stacks: int = relics.get("throwing_dart", 0)
	if dart_stacks > 0:
		fire_rate = _base_fire_rate / (1.0 + 0.2 * dart_stacks)

	if relics.get("split_arrow", 0) > 0:
		_has_split_arrow = true

	max_armor = 25 if relics.get("lock_armor", 0) > 0 else 0
	if max_armor > previous_max_armor:
		current_armor = max_armor
	current_armor = mini(current_armor, max_armor)
	_sync_run_vitals()
	armor_changed.emit(current_armor, max_armor)


func _physics_process(delta: float) -> void:
	_handle_movement()
	_handle_shooting(delta)
	_handle_regen(delta)
	move_and_slide()


func _handle_regen(delta: float) -> void:
	if GlobalManager.active_relics.get("avalon", 0) <= 0:
		return
	if current_health >= max_health:
		_regen_timer = 0.0
		return

	_regen_timer += delta
	while _regen_timer >= 1.0 and current_health < max_health:
		_regen_timer -= 1.0
		current_health += 1
		_sync_run_vitals()
		health_changed.emit(current_health, max_health)


func add_to_backpack(item_id: String, amount: int) -> bool:
	var normalized: Dictionary = GlobalManager.normalize_backpack_item(item_id, amount)
	item_id = normalized.item_id
	amount = normalized.amount

	if backpack.has(item_id):
		backpack[item_id] += amount
		_sync_backpack()
		return true

	if backpack.size() >= MAX_BACKPACK_SLOTS:
		print("背包已满")
		return false

	backpack[item_id] = amount
	_sync_backpack()
	return true


func remove_from_backpack(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return false
	if not backpack.has(item_id):
		return false
	if backpack[item_id] < amount:
		return false

	backpack[item_id] -= amount
	if backpack[item_id] <= 0:
		backpack.erase(item_id)

	_sync_backpack()
	return true


func clear_backpack() -> void:
	backpack.clear()
	GlobalManager.run_backpack.clear()
	GlobalManager.run_backpack_changed.emit()
	backpack_changed.emit()


func _sync_backpack() -> void:
	GlobalManager.run_backpack = backpack.duplicate(true)
	GlobalManager.run_backpack_changed.emit()
	backpack_changed.emit()


func _is_in_dungeon() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == "res://dungeon.tscn"


func _sync_run_vitals() -> void:
	if not _is_in_dungeon():
		return
	GlobalManager.run_current_health = current_health
	GlobalManager.run_max_health = max_health
	GlobalManager.run_current_armor = current_armor
	GlobalManager.run_max_armor = max_armor


func take_damage(amount: int) -> void:
	if _invulnerable:
		return

	var remaining := amount
	if current_armor > 0 and remaining > 0:
		var absorbed := mini(current_armor, remaining)
		current_armor -= absorbed
		remaining -= absorbed

	if remaining > 0:
		current_health -= remaining

	_sync_run_vitals()
	health_changed.emit(current_health, max_health)
	armor_changed.emit(current_armor, max_armor)
	_invulnerable = true
	sprite.modulate = Color(1.0, 0.4, 0.4)

	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self):
		return

	_invulnerable = false
	sprite.modulate = Color.WHITE

	if current_health <= 0:
		_die()


func apply_health_cost(amount: int) -> bool:
	if amount <= 0 or current_health < amount:
		return false

	current_health -= amount
	_sync_run_vitals()
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		_die()

	return true


func _die() -> void:
	print("Player Died")
	GlobalManager.clear_run_relics()
	clear_backpack()
	get_tree().call_deferred("change_scene_to_file", "res://ranch.tscn")


func _handle_movement() -> void:
	var input_direction := Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)

	if input_direction != Vector2.ZERO:
		_last_input_direction = input_direction
		var target_velocity := input_direction * move_speed
		velocity = velocity.lerp(target_velocity, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction)

	var facing := input_direction
	if facing == Vector2.ZERO and velocity.length_squared() > 1.0:
		facing = velocity.normalized()
	elif facing == Vector2.ZERO:
		facing = _last_input_direction

	_update_facing(facing)


func _handle_shooting(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)

	if _fire_cooldown > 0.0 or bullet_scene == null:
		return

	var shoot_direction := _get_shoot_direction()
	if shoot_direction == Vector2.ZERO:
		return

	_fire_bullet(shoot_direction)


func _get_shoot_direction() -> Vector2:
	if Input.is_action_pressed("shoot_up"):
		return Vector2.UP
	if Input.is_action_pressed("shoot_down"):
		return Vector2.DOWN
	if Input.is_action_pressed("shoot_left"):
		return Vector2.LEFT
	if Input.is_action_pressed("shoot_right"):
		return Vector2.RIGHT
	return Vector2.ZERO


func _fire_bullet(direction: Vector2) -> void:
	var directions: Array[Vector2] = [direction]
	if _has_split_arrow:
		var spread := deg_to_rad(18.0)
		directions = [
			direction,
			direction.rotated(spread),
			direction.rotated(-spread),
		]

	for shoot_dir in directions:
		_spawn_bullet(shoot_dir)
	_fire_cooldown = fire_rate


func _spawn_bullet(direction: Vector2) -> void:
	var bullet := bullet_scene.instantiate()
	bullet.direction = direction
	bullet.damage = maxi(1, int(round(_base_bullet_damage * _damage_multiplier)))
	bullet.global_position = global_position
	get_tree().current_scene.add_child(bullet)


func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) > 0.001:
		sprite.flip_h = direction.x < 0.0
