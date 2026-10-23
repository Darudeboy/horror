extends Control


@onready var continue_btn: Button = $Center/VBox/ContinueButton
@onready var status: Label = $Center/VBox/Status


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	GameState.gameplay_paused = false
	continue_btn.disabled = not SaveManager.has_valid_save()
	if continue_btn.disabled:
		status.text = "Нет сохранённого прохождения"
	else:
		status.text = "Найдена контрольная точка"


func _on_new_game() -> void:
	GameState.reset_run()
	SaveManager.clear_save()
	get_tree().set_meta("load_save", false)
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_continue() -> void:
	if not SaveManager.has_valid_save():
		status.text = SaveManager.last_error if SaveManager.last_error != "" else "Сохранение недоступно"
		return
	GameState.reset_run()
	get_tree().set_meta("load_save", true)
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_settings() -> void:
	$Settings.visible = true


func _on_quit() -> void:
	get_tree().quit()


func _on_close_settings() -> void:
	$Settings.visible = false
