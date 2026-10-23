extends Interactable
class_name ElevatorExit


func _ready() -> void:
	interaction_prompt = "Вызвать лифт: Выйти"
	add_to_group("elevator")


func can_interact(_player: Node) -> bool:
	return GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED) and not GameState.get_flag(GameState.FLAG_GAME_FINISHED)


func get_deny_reason(_player: Node) -> String:
	if GameState.get_flag(GameState.FLAG_GAME_FINISHED):
		return "Смена уже закрыта"
	return "Лифт недоступен до трёх согласований"


func _on_interact(_player: Node) -> void:
	if not GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED):
		GameState.notification_requested.emit(get_deny_reason(_player))
		return
	GameState.set_flag(GameState.FLAG_GAME_FINISHED, true)
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui and ui.has_method("show_ending"):
		ui.show_ending()
