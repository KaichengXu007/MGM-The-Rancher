extends Node2D

## 分支肉鸽地牢：按 next_room_type 生成房间内容，清场后生成分支门。

@export var enemy_scene: PackedScene
@export var boss_scene: PackedScene
@export var branch_door_scene: PackedScene
@export var slot_machine_scene: PackedScene
@export var blood_altar_scene: PackedScene
@export var player_spawn_position: Vector2 = Vector2(320, 324)
@export var boss_spawn_position: Vector2 = Vector2(820, 324)
@export var enemy_spawn_positions: Array[Vector2] = [
	Vector2(800, 200),
	Vector2(900, 400),
	Vector2(700, 450),
]

const DOOR_POSITIONS: Dictionary = {
	"top": Vector2(576, 90),
	"bottom": Vector2(576, 560),
	"right": Vector2(980, 324),
}
const EVENT_SPAWN_POSITION: Vector2 = Vector2(576, 324)

@onready var _level_label: Label = $UICanvas/LevelLabel

var _doors_spawned: bool = false


func _ready() -> void:
	_update_level_ui()
	_setup_room_content()


func _process(_delta: float) -> void:
	if _doors_spawned:
		return

	var room_type := GlobalManager.next_room_type
	if room_type != GlobalManager.RoomType.COMBAT and room_type != GlobalManager.RoomType.BOSS:
		return

	if get_tree().get_nodes_in_group("enemy").size() == 0:
		spawn_doors()


func _update_level_ui() -> void:
	if _level_label:
		_level_label.text = GlobalManager.get_current_level_name()


func _setup_room_content() -> void:
	match GlobalManager.next_room_type:
		GlobalManager.RoomType.COMBAT:
			_spawn_normal_enemies()
		GlobalManager.RoomType.BOSS:
			_place_player_at_spawn()
			_spawn_boss()
		GlobalManager.RoomType.SHOP:
			get_tree().create_timer(1.0).timeout.connect(spawn_doors)
		GlobalManager.RoomType.EVENT:
			_spawn_random_event()
			get_tree().create_timer(1.0).timeout.connect(spawn_doors)


func _place_player_at_spawn() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		player.global_position = player_spawn_position


func _spawn_normal_enemies() -> void:
	if enemy_scene == null:
		push_warning("Dungeon: enemy_scene 未设置")
		return

	for pos in enemy_spawn_positions:
		var enemy := enemy_scene.instantiate()
		enemy.global_position = pos
		add_child(enemy)


func _spawn_boss() -> void:
	if boss_scene == null:
		push_warning("Dungeon: boss_scene 未设置")
		return

	var boss := boss_scene.instantiate()
	boss.global_position = boss_spawn_position
	add_child(boss)


func _spawn_random_event() -> void:
	var event_scenes: Array[PackedScene] = []
	if slot_machine_scene:
		event_scenes.append(slot_machine_scene)
	if blood_altar_scene:
		event_scenes.append(blood_altar_scene)

	if event_scenes.is_empty():
		push_warning("Dungeon: 未设置事件场景")
		return

	var scene: PackedScene = event_scenes.pick_random()
	var event: Node2D = scene.instantiate()
	event.global_position = EVENT_SPAWN_POSITION
	add_child(event)


func spawn_doors() -> void:
	if _doors_spawned or branch_door_scene == null:
		return
	_doors_spawned = true

	var door_types: Array[GlobalManager.RoomType] = _get_door_types_for_progress()
	var slot_names: Array[String] = _get_door_slots(door_types.size())

	for i in door_types.size():
		var door := branch_door_scene.instantiate()
		door.target_room_type = door_types[i]
		door.global_position = DOOR_POSITIONS[slot_names[i]]
		add_child(door)


func _get_door_types_for_progress() -> Array[GlobalManager.RoomType]:
	var result: Array[GlobalManager.RoomType] = []

	if GlobalManager.current_room == 7:
		result.append(GlobalManager.RoomType.BOSS)
	elif GlobalManager.current_room == 8:
		if GlobalManager.current_act == 3:
			result.append(GlobalManager.RoomType.EVENT)
		else:
			result.append(GlobalManager.RoomType.COMBAT)
	else:
		var count := randi_range(2, 3)
		var pool: Array[GlobalManager.RoomType] = [
			GlobalManager.RoomType.COMBAT,
			GlobalManager.RoomType.SHOP,
			GlobalManager.RoomType.EVENT,
		]
		pool.shuffle()
		for i in count:
			result.append(pool[i])

	return result


func _get_door_slots(door_count: int) -> Array[String]:
	var all_slots: Array[String] = ["top", "bottom", "right"]
	all_slots.shuffle()

	var picked: Array[String] = []
	for i in door_count:
		picked.append(all_slots[i])
	return picked
