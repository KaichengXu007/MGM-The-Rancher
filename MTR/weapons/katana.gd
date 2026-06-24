extends Node2D

## 近战太刀：三段连击，应用 GLOBAL / MELEE 遗物加成。

@export var base_damage: int = 15
@export var combo_window: float = 0.8
@export var slash_duration: float = 0.22
@export var hitbox_offset: float = 40.0

@onready var _hitbox: Area2D = $Hitbox
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _slash_sprite: Sprite2D = $SlashSprite

var _player: CharacterBody2D = null
var combo_step: int = 0
var combo_timer: float = 0.0
var _attacking: bool = false
var _hit_targets: Dictionary = {}
var _current_damage_mult: float = 1.0


func setup(player: CharacterBody2D) -> void:
	_player = player
	_hitbox.monitoring = false
	_hitbox.body_entered.connect(_on_hitbox_body_entered)
	_build_animations()


func _process(delta: float) -> void:
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_step = 0


func attack() -> void:
	if _player == null or _attacking:
		return

	var step := combo_step
	var anim_name := "slash_%d" % (step + 1)
	_perform_slash(step)
	if _animation_player.has_animation(anim_name):
		_animation_player.play(anim_name)

	combo_step = (combo_step + 1) % 3
	combo_timer = combo_window


func _perform_slash(step: int) -> void:
	_attacking = true
	_hit_targets.clear()

	var damage_mults: Array[float] = [1.0, 1.0, 1.5]
	var scale_mults: Array[float] = [1.0, 1.05, 1.35]
	var swing_offsets: Array[float] = [0.7, -0.7, 1.0]
	_current_damage_mult = damage_mults[step]
	var scale_mult: float = scale_mults[step]
	var swing: float = swing_offsets[step]

	# WeaponHolder 已朝向鼠标，本地 +X 即为攻击方向。
	_hitbox.position = Vector2.RIGHT * hitbox_offset
	_hitbox.scale = Vector2(1.15, 1.0) * scale_mult
	_hitbox.rotation = 0.0
	_slash_sprite.rotation = swing
	_slash_sprite.scale = Vector2(0.9, 0.22) * scale_mult
	_slash_sprite.modulate = Color(0.95, 0.98, 1.0, 0.95)

	var slash_tween := create_tween()
	slash_tween.tween_property(
		_slash_sprite, "rotation", -swing, slash_duration * 0.45
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	slash_tween.tween_property(
		_slash_sprite, "rotation", 0.0, slash_duration * 0.55
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	_hitbox.monitoring = true
	await get_tree().create_timer(slash_duration).timeout
	if not is_instance_valid(self):
		return

	_hitbox.monitoring = false
	_slash_sprite.modulate = Color(0.85, 0.9, 1.0, 0.25)
	_attacking = false


func _get_effective_damage(base_mult: float) -> int:
	var multiplier := base_mult
	var glove_stacks := GlobalManager.get_relic_count("boxing_glove")
	if glove_stacks > 0 and GlobalManager.relic_applies("boxing_glove", GlobalManager.WeaponType.MELEE):
		multiplier *= 1.0 + 0.2 * glove_stacks
	return maxi(1, int(round(base_damage * multiplier)))


func _on_hitbox_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemy"):
		return
	if _hit_targets.has(body.get_instance_id()):
		return

	_hit_targets[body.get_instance_id()] = true
	if body.has_method("take_damage"):
		body.take_damage(_get_effective_damage(_current_damage_mult))


func _build_animations() -> void:
	var library := AnimationLibrary.new()
	var peak_scales: Array[float] = [1.0, 1.1, 1.35]

	for i in 3:
		var anim := Animation.new()
		anim.length = slash_duration

		var alpha_track := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(alpha_track, NodePath("SlashSprite:modulate:a"))
		anim.track_insert_key(alpha_track, 0.0, 0.25)
		anim.track_insert_key(alpha_track, slash_duration * 0.35, 1.0)
		anim.track_insert_key(alpha_track, slash_duration, 0.25)

		var scale_track := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(scale_track, NodePath("SlashSprite:scale"))
		var base_scale := Vector2(0.9, 0.22)
		anim.track_insert_key(scale_track, 0.0, base_scale)
		anim.track_insert_key(scale_track, slash_duration * 0.4, base_scale * peak_scales[i])
		anim.track_insert_key(scale_track, slash_duration, base_scale * 0.8)

		library.add_animation("slash_%d" % (i + 1), anim)

	if _animation_player.has_animation_library(""):
		_animation_player.remove_animation_library("")
	_animation_player.add_animation_library("", library)
