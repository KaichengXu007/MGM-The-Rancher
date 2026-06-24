extends CharacterBody2D

## Top-down 2D 主角：移动 + 单武器槽，攻击委托给当前武器节点。

const MAX_BACKPACK_SLOTS: int = 10
const DEFAULT_WEAPON_PICKUP_SCENE: PackedScene = preload("res://weapons/WeaponPickup.tscn")

@export var move_speed: float = 300.0
@export var acceleration: float = 0.2
@export var friction: float = 0.2
@export var weapon_pickup_scene: PackedScene
@export var max_health: int = 100
@export var current_health: int = 100

@onready var sprite: Sprite2D = $Sprite2D
@onready var _weapon_holder: Marker2D = $WeaponHolder

signal backpack_changed
signal health_changed(current_hp: int, max_hp: int)
signal armor_changed(current_armor: int, max_armor: int)

var current_weapon_id: String = "musket"
var current_weapon_type: GlobalManager.WeaponType = GlobalManager.WeaponType.RANGED
var backpack: Dictionary = {}
var max_armor: int = 0
var current_armor: int = 0
var _base_move_speed: float = 0.0
var _last_aim_direction: Vector2 = Vector2.RIGHT
var _invulnerable: bool = false
var _regen_timer: float = 0.0
var _equipped_weapon: Node = null


func _ready() -> void:
	add_to_group("player")
	_base_move_speed = move_speed
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

	equip_weapon(
		GlobalManager.current_weapon_id,
		GlobalManager.current_weapon_type,
		Vector2.INF,
		false
	)
	_sync_backpack()
	health_changed.emit(current_health, max_health)
	armor_changed.emit(current_armor, max_armor)


func apply_relic_effects() -> void:
	move_speed = _base_move_speed
	var previous_max_armor := max_armor

	if GlobalManager.relic_applies("haste_boot", current_weapon_type):
		move_speed = _base_move_speed * 2.0

	max_armor = 25 if GlobalManager.relic_applies("lock_armor", current_weapon_type) else 0
	if max_armor > previous_max_armor:
		current_armor = max_armor
	current_armor = mini(current_armor, max_armor)
	_sync_run_vitals()
	armor_changed.emit(current_armor, max_armor)


func equip_weapon(
	new_id: String,
	new_type: GlobalManager.WeaponType,
	swap_position: Vector2 = Vector2.INF,
	drop_replaced: bool = true
) -> void:
	if (
		drop_replaced
		and current_weapon_id != ""
		and current_weapon_id != new_id
		and current_weapon_type != GlobalManager.WeaponType.NONE
	):
		var drop_pos := swap_position if swap_position != Vector2.INF else global_position
		_drop_weapon_pickup(current_weapon_id, current_weapon_type, drop_pos)

	_clear_weapon_holder()

	current_weapon_id = new_id
	current_weapon_type = new_type
	_mount_weapon(new_id)

	GlobalManager.set_current_weapon(new_id, new_type)

	apply_relic_effects()


func get_aim_direction() -> Vector2:
	var mouse_dir: Vector2 = get_global_mouse_position() - global_position
	if mouse_dir.length_squared() > 1.0:
		return mouse_dir.normalized()
	return _last_aim_direction


func get_attack_direction() -> Vector2:
	return get_aim_direction()


func _physics_process(delta: float) -> void:
	_update_facing_from_mouse()
	_handle_movement()
	_handle_attack()
	_handle_regen(delta)
	move_and_slide()


func _update_facing_from_mouse() -> void:
	var aim := get_aim_direction()
	if aim.length_squared() < 0.001:
		return

	_last_aim_direction = aim
	var angle := aim.angle()
	sprite.rotation = angle
	_weapon_holder.rotation = angle


func _handle_attack() -> void:
	if _equipped_weapon == null or not _equipped_weapon.has_method("attack"):
		return

	if Input.is_action_pressed("attack"):
		_equipped_weapon.attack()


func _handle_regen(delta: float) -> void:
	if not GlobalManager.relic_applies("avalon", current_weapon_type):
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


func _clear_weapon_holder() -> void:
	for child in _weapon_holder.get_children():
		child.queue_free()
	_equipped_weapon = null


func _mount_weapon(weapon_id: String) -> void:
	var scene_path: String = GlobalManager.WEAPON_SCENES.get(weapon_id, "")
	if scene_path == "":
		push_warning("Player: 未知武器 %s" % weapon_id)
		return

	var weapon: Node = load(scene_path).instantiate()
	_weapon_holder.add_child(weapon)
	_equipped_weapon = weapon
	if weapon.has_method("setup"):
		weapon.setup(self)


func _drop_weapon_pickup(
	weapon_id: String,
	weapon_type: GlobalManager.WeaponType,
	spawn_position: Vector2
) -> void:
	var scene: PackedScene = weapon_pickup_scene if weapon_pickup_scene else DEFAULT_WEAPON_PICKUP_SCENE
	var resolved_type := weapon_type
	if resolved_type == GlobalManager.WeaponType.NONE:
		resolved_type = GlobalManager.get_weapon_type(weapon_id)

	var pickup: Area2D = scene.instantiate()
	pickup.weapon_id = weapon_id
	pickup.weapon_type = resolved_type
	pickup.global_position = spawn_position + Vector2(0, 20)
	pickup.z_index = 5

	var world: Node = get_parent()
	if world == null:
		world = get_tree().current_scene
	world.call_deferred("add_child", pickup)


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
	GlobalManager.notify_run_backpack_changed()
	backpack_changed.emit()


func _sync_backpack() -> void:
	GlobalManager.run_backpack = backpack.duplicate(true)
	GlobalManager.notify_run_backpack_changed()
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


func heal(amount: int) -> void:
	if amount <= 0:
		return

	current_health = mini(current_health + amount, max_health)
	_sync_run_vitals()
	health_changed.emit(current_health, max_health)


func heal_percent(ratio: float) -> int:
	if ratio <= 0.0:
		return 0

	var amount := roundi(max_health * ratio)
	heal(amount)
	return amount


func _die() -> void:
	print("Player Died")
	GlobalManager.clear_run_relics()
	GlobalManager.reset_ranch_weapon()
	clear_backpack()
	get_tree().call_deferred("change_scene_to_file", "res://ranch.tscn")


func _handle_movement() -> void:
	var input_direction := Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)

	if input_direction != Vector2.ZERO:
		var target_velocity := input_direction * move_speed
		velocity = velocity.lerp(target_velocity, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction)
