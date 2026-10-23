extends Interactable
class_name ElevatorButton
## Call panel beside elevator doors.


func _ready() -> void:
	interaction_prompt = "Вызвать лифт"
	GameState.item_changed.connect(func(_a, _b): _refresh())
	_refresh()


func _refresh() -> void:
	if GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE):
		var other := 2 if GameState.current_floor == int(get_meta("floor_id", 1)) else 1
		# Button's floor_id is the landing we're standing at
		var here := int(get_meta("floor_id", 1))
		other = 2 if here == 1 else 1
		interaction_prompt = "Лифт → этаж %d" % other
	else:
		interaction_prompt = "Лифт: нужен пропуск"


func can_interact(_player: Node) -> bool:
	return enabled and not GameState.get_flag(GameState.FLAG_GAME_FINISHED)


func get_deny_reason(_player: Node) -> String:
	if not GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE):
		return "Для вызова лифта нужен пропуск"
	return "Недоступно"


func _on_interact(player: Node) -> void:
	if not GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE):
		GameState.notification_requested.emit(get_deny_reason(player))
		AudioManager.play_sfx("error")
		return
	var bank = get_meta("elevator_bank", null)
	if bank == null:
		bank = get_tree().get_first_node_in_group("elevator_bank")
	if bank and bank.has_method("call_elevator"):
		var floor_id := int(get_meta("floor_id", 1))
		bank.call_elevator(floor_id, player)
	else:
		GameState.notification_requested.emit("Лифт неисправен")
