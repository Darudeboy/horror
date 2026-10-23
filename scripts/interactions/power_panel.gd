extends Interactable
class_name PowerPanel


func _ready() -> void:
	interaction_prompt = "Включить питание"
	add_to_group("power_panel")
	GameState.flag_changed.connect(_on_flag)
	_refresh()


func _on_flag(flag_id: String, _value: bool) -> void:
	if flag_id == GameState.FLAG_POWER_RESTORED or flag_id == GameState.FLAG_PRINTER_FAULT:
		_refresh()


func _refresh() -> void:
	if GameState.get_flag(GameState.FLAG_POWER_RESTORED):
		interaction_prompt = "Питание восстановлено"
		enabled = true
	elif GameState.get_flag(GameState.FLAG_PRINTER_FAULT):
		interaction_prompt = "Включить питание"
		enabled = true
	else:
		interaction_prompt = "Электрощит"
		enabled = true


func can_interact(_player: Node) -> bool:
	if GameState.get_flag(GameState.FLAG_POWER_RESTORED):
		return false
	return GameState.get_flag(GameState.FLAG_PRINTER_FAULT)


func get_deny_reason(_player: Node) -> String:
	if GameState.get_flag(GameState.FLAG_POWER_RESTORED):
		return "Питание уже восстановлено"
	return "Щит в дежурном режиме"


func _on_interact(_player: Node) -> void:
	if GameState.get_flag(GameState.FLAG_POWER_RESTORED):
		return
	if not GameState.get_flag(GameState.FLAG_PRINTER_FAULT):
		GameState.notification_requested.emit("Щит в дежурном режиме")
		return
	GameState.set_flag(GameState.FLAG_POWER_RESTORED, true)
	GameState.notification_requested.emit("Питание восстановлено")
	for l in get_tree().get_nodes_in_group("accounting_lights"):
		if l is Light3D:
			(l as Light3D).visible = true
			(l as Light3D).light_energy = 1.0
	for e in get_tree().get_nodes_in_group("emergency_lights"):
		if e is Light3D:
			(e as Light3D).visible = false
			(e as Light3D).light_energy = 0.0
	SaveManager.save_checkpoint("after_power")
	var director := get_tree().get_first_node_in_group("event_director")
	if director and director.has_method("queue_event"):
		director.queue_event("phone_ring")
	_refresh()
