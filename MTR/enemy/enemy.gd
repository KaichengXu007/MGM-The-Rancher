extends CharacterBody2D

## 基础追踪怪物：加入 "enemy" 分组，朝 "player" 分组中的节点移动。
## 伤害通过距离判定，不与玩家发生物理推挤（避免黏住玩家）。

@export var health: int = 30
@export var speed: float = 150.0
@export var damage: int = 10
@export var attack_range: float = 28.0
@export var drop_item_scene: PackedScene

const BASE_EGG_DROP_CHANCE: float = 0.30
const BASE_COIN_DROP_CHANCE: float = 0.50
const BASE_COIN_LARGE_DROP_CHANCE: float = 0.10
const DROP_SPREAD_RADIUS: float = 12.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("enemy")


func _physics_process(_delta: float) -> void:
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


func take_damage(amount: int) -> void:
	health -= amount

	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self):
		return
	sprite.modulate = Color.WHITE

	if health <= 0:
		_die()


func _die() -> void:
	_spawn_drop()
	queue_free()


func _spawn_drop() -> void:
	if drop_item_scene == null:
		return

	var drops: Array[String] = []
	if _roll_drop(_get_egg_drop_chance()):
		drops.append("egg")
	if _roll_drop(BASE_COIN_DROP_CHANCE):
		drops.append("coin_small")
	if _roll_drop(BASE_COIN_LARGE_DROP_CHANCE):
		drops.append("coin_large")

	for i in drops.size():
		_spawn_drop_item(drops[i], i)


func _get_egg_drop_chance() -> float:
	var chance := BASE_EGG_DROP_CHANCE
	if GlobalManager.active_relics.get("spirit_ball", 0) > 0:
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
