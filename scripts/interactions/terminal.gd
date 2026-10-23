extends Interactable
class_name GameTerminal
## Story terminals: desk, HR, accounting, security.

enum TerminalKind { DESK, HR, ACCOUNTING, SECURITY, GENERIC }

@export var kind: TerminalKind = TerminalKind.GENERIC
@export var terminal_id: String = ""


func _ready() -> void:
	interaction_prompt = "Использовать терминал"
	add_to_group("terminals")
	GameState.state_changed.connect(func(_a, _b, _c): _update_prompt())
	_update_prompt()


func _update_prompt() -> void:
	match kind:
		TerminalKind.DESK:
			interaction_prompt = "Прочитать сообщение"
		TerminalKind.HR:
			interaction_prompt = "Терминал HR"
		TerminalKind.ACCOUNTING:
			interaction_prompt = "Терминал бухгалтерии"
		TerminalKind.SECURITY:
			interaction_prompt = "Терминал безопасности"
		_:
			interaction_prompt = "Использовать терминал"


func can_interact(_player: Node) -> bool:
	return enabled


func get_deny_reason(_player: Node) -> String:
	match kind:
		TerminalKind.HR:
			if not GameState.has_item(GameState.ITEM_PRINTED_APPLICATION) and not GameState.get_flag(GameState.FLAG_HR_APPROVED):
				if GameState.get_flag(GameState.FLAG_HR_BRIEFED):
					return "Требуется распечатанное заявление"
		TerminalKind.ACCOUNTING:
			if not GameState.get_flag(GameState.FLAG_HR_APPROVED) and not GameState.get_flag(GameState.FLAG_ACCOUNTING_APPROVED):
				return "Сначала требуется согласование HR"
		_:
			pass
	return "Недоступно"


func _on_interact(player: Node) -> void:
	match kind:
		TerminalKind.DESK:
			_desk()
		TerminalKind.HR:
			_hr()
		TerminalKind.ACCOUNTING:
			_accounting()
		TerminalKind.SECURITY:
			_security()
		_:
			GameState.notification_requested.emit("Нет активных запросов")


func _desk() -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	var body := "Рабочий день завершён.\nНе забудьте согласовать выход.\n\nСтатус: смена не закрыта."
	if ui and ui.has_method("show_document"):
		ui.show_document("Рабочий терминал", body)
	GameState.set_flag(GameState.FLAG_WORKDAY_STARTED, true)


func _hr() -> void:
	if not GameState.get_flag(GameState.FLAG_HR_BRIEFED):
		GameState.set_flag(GameState.FLAG_HR_BRIEFED, true)
		var ui := get_tree().get_first_node_in_group("game_ui")
		var body := "Для закрытия смены требуется:\n1) Согласование HR\n2) Согласование бухгалтерии\n3) Согласование службы безопасности\n\nДля подачи в HR необходимо распечатанное заявление.\nПропуск для бухгалтерии — на столе отсутствующего коллеги в open space."
		if ui and ui.has_method("show_document"):
			ui.show_document("Отдел кадров", body)
		return
	if GameState.get_flag(GameState.FLAG_HR_APPROVED):
		GameState.notification_requested.emit("HR: согласование уже получено")
		return
	if not GameState.has_item(GameState.ITEM_PRINTED_APPLICATION):
		GameState.notification_requested.emit("Требуется распечатанное заявление")
		return
	GameState.set_flag(GameState.FLAG_HR_APPROVED, true)
	GameState.notification_requested.emit("Согласование HR получено")
	SaveManager.save_checkpoint("after_hr")


func _accounting() -> void:
	if GameState.get_flag(GameState.FLAG_ACCOUNTING_APPROVED):
		GameState.notification_requested.emit("Бухгалтерия: согласование уже получено")
		return
	if not GameState.get_flag(GameState.FLAG_HR_APPROVED):
		GameState.notification_requested.emit("Сначала требуется согласование HR")
		return
	GameState.set_flag(GameState.FLAG_ACCOUNTING_APPROVED, true)
	GameState.notification_requested.emit("Согласование бухгалтерии получено")
	SaveManager.save_checkpoint("after_accounting")


func _security() -> void:
	if GameState.get_flag(GameState.FLAG_SECURITY_APPROVED):
		GameState.notification_requested.emit("Безопасность: согласование уже получено")
		return
	GameState.set_flag(GameState.FLAG_SECURITY_APPROVED, true)
	GameState.notification_requested.emit("Согласование безопасности получено")
	SaveManager.save_checkpoint("after_security")
