extends Interactable
class_name CorridorPhone
## Atmospheric only — does not attract enemy in v1.


func _ready() -> void:
	interaction_prompt = "Поднять трубку"
	add_to_group("phone")
	GameState.flag_changed.connect(_on_flag)
	_refresh()


func _on_flag(flag_id: String, _v: bool) -> void:
	if flag_id == GameState.FLAG_PHONE_RINGING or flag_id == GameState.FLAG_PHONE_ANSWERED:
		_refresh()


func _refresh() -> void:
	visible = GameState.get_flag(GameState.FLAG_PHONE_RINGING) or GameState.get_flag(GameState.FLAG_PHONE_ANSWERED)
	if GameState.get_flag(GameState.FLAG_PHONE_ANSWERED):
		interaction_prompt = "Трубка положена"
		enabled = false
	elif GameState.get_flag(GameState.FLAG_PHONE_RINGING):
		interaction_prompt = "Поднять трубку"
		enabled = true
	else:
		enabled = false


func can_interact(_player: Node) -> bool:
	return GameState.get_flag(GameState.FLAG_PHONE_RINGING) and not GameState.get_flag(GameState.FLAG_PHONE_ANSWERED)


func get_deny_reason(_player: Node) -> String:
	return "Телефон молчит"


func _on_interact(_player: Node) -> void:
	GameState.set_flag(GameState.FLAG_PHONE_ANSWERED, true)
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui and ui.has_method("show_document"):
		ui.show_document("Внутренняя линия", "Оставайтесь на линии.\nВаше местоположение уточняется.")
	else:
		GameState.notification_requested.emit("Оставайтесь на линии. Ваше местоположение уточняется.")
	_refresh()
