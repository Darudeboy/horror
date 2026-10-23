extends Interactable
class_name StreetExit
## Building exit after three approvals + badge.


func _ready() -> void:
	interaction_prompt = "Выход на улицу"
	GameState.flag_changed.connect(func(_a, _b): _refresh())
	GameState.item_changed.connect(func(_a, _b): _refresh())
	_refresh()


func _refresh() -> void:
	if GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED) and GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE):
		interaction_prompt = "Выйти из здания"
	elif GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED):
		interaction_prompt = "Выход: нужен пропуск"
	else:
		interaction_prompt = "Выход закрыт (нужны согласования)"


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
		return "Нужны согласования HR, бухгалтерии и безопасности"
	if not GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE):
		return "Приложите пропуск"
	return "Недоступно"


func _on_interact(_player: Node) -> void:
	if not can_interact(_player):
		GameState.notification_requested.emit(get_deny_reason(_player))
		return
	GameState.set_flag(GameState.FLAG_GAME_FINISHED, true)
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui and ui.has_method("show_ending"):
		ui.show_ending()
