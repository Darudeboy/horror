extends Interactable
class_name Turnstile


@onready var blocker: StaticBody3D = $Blocker


func _ready() -> void:
	interaction_prompt = "Проверить турникет"
	add_to_group("turnstile")
	GameState.flag_changed.connect(_on_flag)
	_refresh()


func _on_flag(flag_id: String, _v: bool) -> void:
	if flag_id == GameState.FLAG_EXIT_UNLOCKED or flag_id == GameState.FLAG_EXIT_CHECKED:
		_refresh()


func _refresh() -> void:
	var unlocked := GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED)
	if blocker:
		blocker.set_collision_layer_value(1, not unlocked)
		blocker.visible = not unlocked
	if unlocked:
		interaction_prompt = "Турникет открыт"
	elif GameState.get_flag(GameState.FLAG_EXIT_CHECKED):
		interaction_prompt = "Требуются согласования"
	else:
		interaction_prompt = "Проверить турникет"


func can_interact(_player: Node) -> bool:
	return not GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED)


func get_deny_reason(_player: Node) -> String:
	if GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED):
		return "Турникет открыт"
	return "Для выхода нужны согласования HR, бухгалтерии и безопасности"


func _on_interact(_player: Node) -> void:
	if GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED):
		GameState.notification_requested.emit("Турникет открыт")
		return
	if not GameState.get_flag(GameState.FLAG_EXIT_CHECKED):
		GameState.set_flag(GameState.FLAG_EXIT_CHECKED, true)
		GameState.notification_requested.emit("Нужны согласования: HR, бухгалтерия, безопасность. Начните с HR.")
		SaveManager.save_checkpoint("after_exit_check")
	else:
		GameState.notification_requested.emit("Для выхода нужны согласования HR, бухгалтерии и безопасности")
	_refresh()
