extends Interactable
class_name ElevatorExit
## Finale: three approvals + employee badge required.


func _ready() -> void:
	interaction_prompt = "Вызвать лифт: Выйти"
	add_to_group("elevator")
	GameState.item_changed.connect(func(_a, _b): _update_prompt())
	GameState.flag_changed.connect(func(_a, _b): _update_prompt())
	_update_prompt()


func _update_prompt() -> void:
	if GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED) and GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE):
		interaction_prompt = "Вызвать лифт: Выйти"
	elif GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED):
		interaction_prompt = "Лифт: нужен пропуск"
	else:
		interaction_prompt = "Лифт недоступен"


func can_interact(_player: Node) -> bool:
	return (
		GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED)
		and GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE)
		and not GameState.get_flag(GameState.FLAG_GAME_FINISHED)
	)


func get_deny_reason(_player: Node) -> String:
	if GameState.get_flag(GameState.FLAG_GAME_FINISHED):
		return "Смена уже закрыта"
	if not GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED):
		return "Лифт недоступен до трёх согласований"
	if not GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE):
		return "Для вызова лифта нужен пропуск"
	return "Недоступно"


func _on_interact(_player: Node) -> void:
	if not can_interact(_player):
		GameState.notification_requested.emit(get_deny_reason(_player))
		return
	GameState.set_flag(GameState.FLAG_GAME_FINISHED, true)
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui and ui.has_method("show_ending"):
		ui.show_ending()
