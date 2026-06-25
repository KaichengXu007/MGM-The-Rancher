extends CanvasLayer

## 全局暂停菜单：继续游戏 / 手动存档 / 回到主菜单。

@onready var _resume_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var _save_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SaveButton
@onready var _main_menu_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MainMenuButton
@onready var _status_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume_button.pressed.connect(_on_resume_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	if _status_label:
		_status_label.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()


func _on_resume_pressed() -> void:
	get_tree().paused = false
	GlobalManager.is_paused = false
	queue_free()


func _on_save_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	GlobalManager.manual_save(player)
	if _status_label:
		_status_label.text = "存档成功！"
		_status_label.modulate = Color(0.85, 1.0, 0.75, 1.0)


func _on_main_menu_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	GlobalManager.return_to_ranch_and_save(player)
	get_tree().paused = false
	GlobalManager.is_paused = false
	get_tree().change_scene_to_file(GlobalManager.MAIN_MENU_SCENE_PATH)
	queue_free()
