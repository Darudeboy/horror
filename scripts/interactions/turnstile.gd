extends Interactable
class_name Turnstile
## Exit gate: check requirements, then badge to open permanently after approvals.


@onready var blocker: StaticBody3D = $Blocker


func _ready() -> void:
	interaction_prompt = "Проверить турникет"
	add_to_group("turnstile")
	GameState.flag_changed.connect(_on_flag)
	GameState.item_changed.connect(func(_a, _b): _refresh())
	_refresh()


func _on_flag(flag_id: String, _v: bool) -> void:
	if flag_id == GameState.FLAG_EXIT_UNLOCKED or flag_id == GameState.FLAG_EXIT_CHECKED:
		_refresh()


func _refresh() -> void:
	var unlocked := GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED)
	var has_badge := GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE)
	var open := unlocked and has_badge
	if blocker:
		blocker.set_collision_layer_value(1, not open)
		blocker.visible = not open
	if open:
		interaction_prompt = "Турникет открыт (пропуск принят)"
	elif unlocked and not has_badge:
		interaction_prompt = "Приложить пропуск"
	elif GameState.get_flag(GameState.FLAG_EXIT_CHECKED):
		interaction_prompt = "Требуются согласования"
	else:
		interaction_prompt = "Проверить турникет"


func can_interact(_player: Node) -> bool:
	var unlocked := GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED)
	var has_badge := GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE)
	if unlocked and has_badge:
		return false # already open
	return true


func get_deny_reason(_player: Node) -> String:
	if GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED) and GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE):
		return "Турникет открыт"
	if GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED) and not GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE):
		return "Нужен пропуск сотрудника"
	return "Для выхода нужны согласования HR, бухгалтерии и безопасности"


func _on_interact(_player: Node) -> void:
	if GameState.get_flag(GameState.FLAG_EXIT_UNLOCKED):
		if not GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE):
			GameState.notification_requested.emit("Приложите пропуск к считывателю")
		else:
			GameState.notification_requested.emit("Пропуск принят. Проход открыт")
		_refresh()
		return
	if not GameState.get_flag(GameState.FLAG_EXIT_CHECKED):
		GameState.set_flag(GameState.FLAG_EXIT_CHECKED, true)
		GameState.notification_requested.emit("Нужны согласования: HR, бухгалтерия, безопасность. Начните с HR.")
		SaveManager.save_checkpoint("after_exit_check")
		# Monster is summoned by smoke / cigarettes, not the turnstile itself
		AudioManager.play_sfx("creak")
	else:
		GameState.notification_requested.emit(get_deny_reason(_player))
		AudioManager.play_sfx("error")
	_refresh()
