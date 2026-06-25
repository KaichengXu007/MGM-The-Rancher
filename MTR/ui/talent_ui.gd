extends CanvasLayer

## 天赋树 UI：动态生成天赋行，消耗仓库金币永久升级。

@onready var _title_label: Label = $CenterPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var _coin_label: Label = $CenterPanel/MarginContainer/VBoxContainer/CoinLabel
@onready var _talent_list: VBoxContainer = $CenterPanel/MarginContainer/VBoxContainer/ScrollContainer/TalentList
@onready var _close_button: Button = $CenterPanel/MarginContainer/VBoxContainer/CloseButton

var _talent_rows: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close_button.pressed.connect(_on_close_pressed)
	GlobalManager.warehouse_updated.connect(_refresh_all)
	GlobalManager.talent_upgraded.connect(_on_talent_upgraded)
	_build_talent_rows()
	_refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()


func _build_talent_rows() -> void:
	for talent_id in GlobalManager.TALENT_DB.keys():
		var info: Dictionary = GlobalManager.TALENT_DB[talent_id]

		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 60)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_talent_list.add_child(row)

		var text_col := VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_col)

		var name_label := Label.new()
		name_label.text = info.get("name", talent_id)
		name_label.add_theme_font_size_override("font_size", 16)
		text_col.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = info.get("desc", "")
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.modulate = Color(0.85, 0.85, 0.85, 1.0)
		text_col.add_child(desc_label)

		var level_label := Label.new()
		level_label.custom_minimum_size = Vector2(72, 0)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(level_label)

		var upgrade_button := Button.new()
		upgrade_button.custom_minimum_size = Vector2(120, 0)
		row.add_child(upgrade_button)

		upgrade_button.pressed.connect(_on_upgrade_pressed.bind(talent_id))

		_talent_rows[talent_id] = {
			"level_label": level_label,
			"upgrade_button": upgrade_button,
		}


func _refresh_all(_arg: Variant = null) -> void:
	_coin_label.text = "当前金币: %d" % GlobalManager.get_warehouse_gold()

	for talent_id in _talent_rows.keys():
		_refresh_row(talent_id)


func _refresh_row(talent_id: String) -> void:
	if not _talent_rows.has(talent_id) or not GlobalManager.TALENT_DB.has(talent_id):
		return

	var info: Dictionary = GlobalManager.TALENT_DB[talent_id]
	var row_data: Dictionary = _talent_rows[talent_id]
	var level_label: Label = row_data["level_label"]
	var upgrade_button: Button = row_data["upgrade_button"]

	var level := GlobalManager.get_talent_level(talent_id)
	var max_level := int(info.get("max_level", 0))
	level_label.text = "Lv.%d/%d" % [level, max_level]

	if GlobalManager.is_talent_maxed(talent_id):
		upgrade_button.text = "已满级"
		upgrade_button.disabled = true
		return

	var cost := GlobalManager.get_talent_cost(talent_id)
	upgrade_button.text = "花费: %d" % cost
	upgrade_button.disabled = GlobalManager.get_warehouse_gold() < cost


func _on_upgrade_pressed(talent_id: String) -> void:
	if not GlobalManager.upgrade_talent(talent_id):
		return

	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("apply_talents"):
		player.apply_talents()


func _on_talent_upgraded(_talent_id: String) -> void:
	_refresh_all()


func _on_close_pressed() -> void:
	queue_free()
