extends Node2D

## 远程武器：四向射击，应用 GLOBAL / RANGED 遗物加成。

const DEFAULT_BULLET_SCENE: PackedScene = preload("res://bullet/Bullet.tscn")

@export var bullet_scene: PackedScene
@export var base_fire_rate: float = 0.3
@export var base_damage: int = 10

var _player: CharacterBody2D = null
var _fire_cooldown: float = 0.0


func setup(player: CharacterBody2D) -> void:
	_player = player


func _process(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)


func attack() -> void:
	if _player == null or _fire_cooldown > 0.0:
		return

	var direction: Vector2 = _player.get_attack_direction()

	var directions: Array[Vector2] = [direction]
	if GlobalManager.relic_applies("split_arrow", GlobalManager.WeaponType.RANGED):
		var spread := deg_to_rad(18.0)
		directions = [
			direction,
			direction.rotated(spread),
			direction.rotated(-spread),
		]

	for shoot_dir in directions:
		_spawn_bullet(shoot_dir)

	_fire_cooldown = _get_effective_fire_rate()


func _get_effective_fire_rate() -> float:
	var rate := base_fire_rate
	var dart_stacks := GlobalManager.get_relic_count("throwing_dart")
	if dart_stacks > 0 and GlobalManager.relic_applies("throwing_dart", GlobalManager.WeaponType.RANGED):
		rate /= 1.0 + 0.2 * dart_stacks
	return rate


func _get_effective_damage() -> int:
	var multiplier := 1.0
	var glove_stacks := GlobalManager.get_relic_count("boxing_glove")
	if glove_stacks > 0 and GlobalManager.relic_applies("boxing_glove", GlobalManager.WeaponType.RANGED):
		multiplier += 0.2 * glove_stacks
	return maxi(1, int(round(base_damage * multiplier)))


func _spawn_bullet(direction: Vector2) -> void:
	var scene: PackedScene = bullet_scene if bullet_scene else DEFAULT_BULLET_SCENE
	var bullet := scene.instantiate()
	bullet.direction = direction
	bullet.damage = _get_effective_damage()
	bullet.global_position = _player.global_position
	get_tree().current_scene.add_child(bullet)
