extends Area2D

## 牧场养殖场：孵化怪物蛋、生成友好怪物、一键收获产出。

@export var friendly_monster_scene: PackedScene
@export var max_monsters: int = 12

@onready var _hint_label: Label = $HintLabel
@onready var _monsters_root: Node2D = $Monsters
@onready var _nests_root: Node2D = $Nests
@onready var _bounds_shape: CollisionShape2D = $FarmBounds/CollisionShape2D

var _player_in_range: bool = false
var _player_ref: Node2D = null
var _nest_sprites: Array[Sprite2D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GlobalManager.egg_hatched.connect(_on_egg_hatched)
	GlobalManager.incubation_changed.connect(_refresh_nests)
	_collect_nest_sprites()
	_refresh_nests()
	_spawn_saved_monsters()
	if _hint_label:
		_hint_label.visible = false


func _process(_delta: float) -> void:
	if not _player_in_range or _player_ref == null:
		return
	if Input.is_action_just_pressed("confirm"):
		_try_incubate_egg()
	if Input.is_action_just_pressed("interact"):
		_harvest_all_monsters()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = true
	_player_ref = body
	if _hint_label:
		_hint_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body != _player_ref:
		return
	_player_in_range = false
	_player_ref = null
	if _hint_label:
		_hint_label.visible = false


func _try_incubate_egg() -> void:
	if GlobalManager.incubating_eggs.size() >= GlobalManager.MAX_INCUBATOR_SLOTS:
		_show_float_text("孵化槽已满（最多 5 个）")
		return

	var monster_id := GlobalManager.try_consume_one_egg(_player_ref)
	if monster_id <= 0:
		_show_float_text("背包/仓库中没有怪物蛋")
		return

	if not GlobalManager.start_incubation(monster_id):
		_show_float_text("孵化失败")
		return

	var egg_name: String = GlobalManager.get_egg_item_id(monster_id)
	_show_float_text("开始孵化：%s" % egg_name)
	_refresh_nests()


func _harvest_all_monsters() -> void:
	var totals: Dictionary = {}
	for child in _monsters_root.get_children():
		if not child.is_in_group("friendly_monster"):
			continue
		if not child.has_method("harvest"):
			continue

		var amount: int = child.harvest()
		if amount <= 0:
			continue

		var item_id: String = GlobalManager.get_produce_item_id(child.monster_id)
		totals[item_id] = totals.get(item_id, 0) + amount

	if totals.is_empty():
		_show_float_text("没有可收获的硬币")
		return

	var total_coins := 0
	for item_id in totals.keys():
		var count: int = totals[item_id]
		GlobalManager.add_to_warehouse(item_id, count)
		total_coins += count

	_show_float_text("收获 %d 个硬币" % total_coins)


func _on_egg_hatched(monster_id: int) -> void:
	_refresh_nests()
	_spawn_friendly_monster(monster_id)
	_show_float_text("%s 孵化完成！" % GlobalManager.MONSTER_DB.get(monster_id, {}).get("name", "怪物"))


func _spawn_saved_monsters() -> void:
	for monster_id in GlobalManager.hatched_monsters:
		_spawn_friendly_monster(int(monster_id), false)


func _spawn_friendly_monster(monster_id: int, play_feedback: bool = true) -> void:
	if friendly_monster_scene == null:
		push_warning("RanchArea: friendly_monster_scene 未设置")
		return
	if _monsters_root.get_child_count() >= max_monsters:
		if play_feedback:
			_show_float_text("养殖场怪物已满")
		return

	var monster: CharacterBody2D = friendly_monster_scene.instantiate()
	monster.global_position = _get_random_position_in_bounds()
	_monsters_root.add_child(monster)
	if monster.has_method("setup"):
		monster.setup(monster_id, get_farm_bounds())


func get_farm_bounds() -> Rect2:
	if _bounds_shape == null or _bounds_shape.shape == null:
		return Rect2(global_position - Vector2(140, 80), Vector2(280, 160))

	var rect_shape := _bounds_shape.shape as RectangleShape2D
	var size := rect_shape.size
	var center := _bounds_shape.global_position
	return Rect2(center - size * 0.5, size)


func _get_random_position_in_bounds() -> Vector2:
	var bounds := get_farm_bounds()
	return Vector2(
		randf_range(bounds.position.x + 16.0, bounds.end.x - 16.0),
		randf_range(bounds.position.y + 16.0, bounds.end.y - 16.0)
	)


func _collect_nest_sprites() -> void:
	_nest_sprites.clear()
	for child in _nests_root.get_children():
		if child is Sprite2D:
			_nest_sprites.append(child)


func _refresh_nests() -> void:
	for i in _nest_sprites.size():
		var nest := _nest_sprites[i]
		if i < GlobalManager.incubating_eggs.size():
			nest.modulate = Color(0.95, 0.9, 0.35, 1.0)
			nest.scale = Vector2(0.28, 0.28)
		else:
			nest.modulate = Color(0.55, 0.45, 0.35, 0.55)
			nest.scale = Vector2(0.22, 0.22)


func _show_float_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color(1.0, 0.95, 0.6, 1.0)
	label.z_index = 20
	add_child(label)
	label.position = Vector2(-80, -90)

	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 36.0, 1.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free)
