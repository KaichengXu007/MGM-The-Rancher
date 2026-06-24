extends CharacterBody2D

## 养殖场友好怪物：漫游、定时产出硬币，可被一键收获。

@export var roam_speed: float = 35.0
@export var roam_duration: float = 1.2
@export var idle_duration: float = 2.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _produce_timer: Timer = $ProduceTimer
@onready var _roam_timer: Timer = $RoamTimer

var monster_id: int = 1
var uncollected_coins: int = 0

var _farm_bounds: Rect2 = Rect2()
var _move_time_left: float = 0.0
var _move_direction: Vector2 = Vector2.ZERO


func setup(new_monster_id: int, farm_bounds: Rect2) -> void:
	monster_id = new_monster_id
	_farm_bounds = farm_bounds

	var info: Dictionary = GlobalManager.MONSTER_DB.get(monster_id, {})
	_sprite.modulate = info.get("tint", Color.WHITE)

	var produce_time: float = float(info.get("produce_time", 30.0))
	_produce_timer.wait_time = produce_time
	_produce_timer.start()

	_roam_timer.wait_time = idle_duration
	_roam_timer.start()


func harvest() -> int:
	var amount := uncollected_coins
	uncollected_coins = 0
	return amount


func _ready() -> void:
	add_to_group("friendly_monster")
	_produce_timer.timeout.connect(_on_produce_timer_timeout)
	_roam_timer.timeout.connect(_on_roam_timer_timeout)


func _physics_process(delta: float) -> void:
	if _move_time_left > 0.0:
		_move_time_left -= delta
		velocity = _move_direction * roam_speed
		move_and_slide()
		_clamp_to_bounds()
	else:
		velocity = Vector2.ZERO


func _on_produce_timer_timeout() -> void:
	uncollected_coins += 1


func _on_roam_timer_timeout() -> void:
	if _move_time_left > 0.0:
		_roam_timer.wait_time = idle_duration
		_roam_timer.start()
		return

	_move_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	_move_time_left = roam_duration
	_roam_timer.wait_time = roam_duration
	_roam_timer.start()


func _clamp_to_bounds() -> void:
	if _farm_bounds.size == Vector2.ZERO:
		return

	var pos := global_position
	pos.x = clampf(pos.x, _farm_bounds.position.x, _farm_bounds.end.x)
	pos.y = clampf(pos.y, _farm_bounds.position.y, _farm_bounds.end.y)
	global_position = pos
