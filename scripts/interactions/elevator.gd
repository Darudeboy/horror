extends Interactable
class_name ElevatorCabin
## Floor travel with badge. Street exit when approvals unlocked.


func _ready() -> void:
	add_to_group("elevator")
	GameState.item_changed.connect(func(_a, _b): _update_prompt())
	GameState.flag_changed.connect(func(_a, _b): _update_prompt())
	_update_prompt()


func _update_prompt() -> void:
	if not GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE):
		interaction_prompt = "Лифт: нужен пропуск"
		return
	var other := 2 if GameState.current_floor == 1 else 1
	if GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED) and GameState.current_floor == 1:
		interaction_prompt = "Лифт: этаж %d / Выйти из здания" % other
	else:
		interaction_prompt = "Лифт: на этаж %d" % other


func can_interact(_player: Node) -> bool:
	return GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE) and not GameState.get_flag(GameState.FLAG_GAME_FINISHED)


func get_deny_reason(_player: Node) -> String:
	if GameState.get_flag(GameState.FLAG_GAME_FINISHED):
		return "Смена уже закрыта"
	if not GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE):
		return "Для лифта нужен пропуск сотрудника"
	return "Недоступно"


func _on_interact(player: Node) -> void:
	if not can_interact(player):
		GameState.notification_requested.emit(get_deny_reason(player))
		return
	# If exit unlocked on floor 1: first use travels OR we prefer travel; ending via separate prompt logic —
	# Hold: if exit unlocked and already on floor that matches "leave", show choice via second interact near exit panel.
	# Travel floors by default.
	_travel_floors(player)


func _travel_floors(player: Node) -> void:
	var dest_floor := 2 if GameState.current_floor == 1 else 1
	var markers := get_tree().get_nodes_in_group("elevator_landing")
	var dest: Node3D = null
	for m in markers:
		if m.has_meta("floor") and int(m.get_meta("floor")) == dest_floor:
			dest = m as Node3D
			break
	if dest == null:
		GameState.notification_requested.emit("Лифт неисправен")
		return
	AudioManager.play_sfx("door_close", 0.9, -4.0)
	GameState.current_floor = dest_floor
	if player is Node3D:
		(player as Node3D).global_position = dest.global_position + Vector3(0, 0.1, 1.2)
	GameState.notification_requested.emit("Этаж %d" % dest_floor)
	AudioManager.play_sfx("door_open", 1.0, -4.0)
	_update_prompt()
	# Move enemy to same floor if active
	var enemy := get_tree().get_first_node_in_group("enemy") as Node3D
	if enemy and GameState.get_flag(GameState.FLAG_ENEMY_ACTIVATED):
		var e_land: Node3D = null
		for m2 in markers:
			if m2.has_meta("floor") and int(m2.get_meta("floor")) == dest_floor:
				e_land = m2 as Node3D
				break
		if e_land:
			enemy.global_position = e_land.global_position + Vector3(3, 0, 0)
