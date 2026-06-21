extends Area2D

## 老虎机事件：靠近后按 E 消耗 2 金币抽奖。

const GOLD_ITEM_ID: String = "gold"
const SPIN_COST: int = 2

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hint_label: Label = $HintLabel
@onready var _result_label: Label = $ResultLabel

var _player_in_range: bool = false
var _player_ref: Node2D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_sprite.modulate = Color(1.0, 0.85, 0.3, 1.0)
	_hint_label.visible = false
	if _result_label:
		_result_label.text = ""


func _process(_delta: float) -> void:
	if not _player_in_range or _player_ref == null:
		return
	if Input.is_action_just_pressed("interact"):
		_spin()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = true
	_player_ref = body
	_hint_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body != _player_ref:
		return
	_player_in_range = false
	_player_ref = null
	_hint_label.visible = false


func _spin() -> void:
	if _player_ref == null or not _player_ref.has_method("remove_from_backpack"):
		return

	if not _player_ref.remove_from_backpack(GOLD_ITEM_ID, SPIN_COST):
		_show_result("金币不足（需要 2）")
		return

	var roll := randf()
	var reward := 0
	if roll < 0.10:
		reward = 5
	elif roll < 0.30:
		reward = 3
	elif roll < 0.50:
		reward = 1

	if reward > 0:
		_player_ref.add_to_backpack(GOLD_ITEM_ID, reward)
		_show_result("获得 %d 金币！" % reward)
	else:
		_show_result("什么也没有…")


func _show_result(text: String) -> void:
	if _result_label:
		_result_label.text = text
