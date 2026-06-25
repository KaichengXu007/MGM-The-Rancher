extends Control

## 主菜单：继续 / 新游戏 / 退出。

@onready var _continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var _new_game_button: Button = $CenterContainer/VBoxContainer/NewGameButton
@onready var _quit_button: Button = $CenterContainer/VBoxContainer/QuitButton


func _ready() -> void:
	get_tree().paused = false
	GlobalManager.is_paused = false

	var has_save := FileAccess.file_exists(GlobalManager.SAVE_PATH)
	_continue_button.disabled = not has_save
	_continue_button.visible = has_save

	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func _on_continue_pressed() -> void:
	if not GlobalManager.load_game():
		return
	get_tree().change_scene_to_file("res://ranch.tscn")


func _on_new_game_pressed() -> void:
	GlobalManager.reset_to_default_state()
	GlobalManager.save_game()
	get_tree().change_scene_to_file("res://ranch.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
