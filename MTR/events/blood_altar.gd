extends Area2D

## 血祭事件：靠近后按 E 消耗 20 血量，获得一个随机未拥有的遗物。

const HP_COST: int = 20

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hint_label: Label = $HintLabel
@onready var _result_label: Label = $ResultLabel

var _player_in_range: bool = false
var _player_ref: Node2D = null
var _used: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_sprite.modulate = Color(0.85, 0.2, 0.35, 1.0)
	_hint_label.visible = false
	if _result_label:
		_result_label.text = ""


func _process(_delta: float) -> void:
	if _used or not _player_in_range or _player_ref == null:
		return
	if Input.is_action_just_pressed("interact"):
		_sacrifice()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = true
	_player_ref = body
	if not _used:
		_hint_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body != _player_ref:
		return
	_player_in_range = false
	_player_ref = null
	_hint_label.visible = false


func _sacrifice() -> void:
	if _player_ref == null or not _player_ref.has_method("apply_health_cost"):
		return

	var relic_id := GlobalManager.get_random_unowned_relic_id()
	if relic_id == "":
		_show_result("已无可用遗物")
		return

	if not _player_ref.apply_health_cost(HP_COST):
		_show_result("血量不足（需要 20）")
		return

	GlobalManager.add_relic(relic_id)
	if _player_ref.has_method("apply_relic_effects"):
		_player_ref.apply_relic_effects()

	_used = true
	_hint_label.visible = false
	monitoring = false

	var relic_name: String = GlobalManager.RELIC_INFO.get(relic_id, {}).get("name", relic_id)
	_show_result("获得遗物：%s" % relic_name)


func _show_result(text: String) -> void:
	if _result_label:
		_result_label.text = text
