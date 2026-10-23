extends Node
## Activates and completes tasks from resource definitions. Signal-driven, not per-frame.

signal task_activated(task_id: String)
signal task_completed(task_id: String)
signal current_task_changed(task_id: String, title: String, description: String)

@export var task_dir: String = "res://resources/tasks"

var tasks: Dictionary = {} ## id -> TaskData dict
var active_ids: Array[String] = []
var completed_ids: Array[String] = []
var current_id: String = ""


func _ready() -> void:
	add_to_group("task_manager")
	_load_tasks()
	GameState.state_changed.connect(_on_state_changed)
	_reevaluate()


func _load_tasks() -> void:
	tasks.clear()
	# Built-in task table (also mirrored as .tres later if needed)
	_register({
		"id": "check_exit",
		"title": "Проверить выход",
		"description": "Рабочий день завершён. Проверьте турникет в вестибюле.",
		"activate_flags_any": ["workday_started"],
		"complete_flags_any": ["exit_checked"],
		"priority": 10,
	})
	_register({
		"id": "visit_hr",
		"title": "Обратиться в HR",
		"description": "Для выхода нужны согласования. Начните с отдела кадров.",
		"activate_flags_any": ["exit_checked"],
		"complete_flags_any": ["hr_briefed"],
		"priority": 20,
	})
	_register({
		"id": "get_badge",
		"title": "Найти пропуск",
		"description": "Для доступа в бухгалтерию нужен пропуск отсутствующего коллеги.",
		"activate_flags_any": ["hr_briefed"],
		"complete_items_any": ["employee_badge"],
		"priority": 25,
	})
	_register({
		"id": "print_application",
		"title": "Распечатать заявление",
		"description": "В бухгалтерии распечатайте заявление. При сбое питания используйте щит в серверной.",
		"activate_any": true, # after badge or accounting access
		"activate_items_any": ["employee_badge"],
		"complete_flags_any": ["print_completed"],
		"priority": 30,
	})
	_register({
		"id": "restore_power",
		"title": "Восстановить питание",
		"description": "Включите электрощит в серверной, затем повторите печать.",
		"activate_flags_any": ["printer_fault_triggered"],
		"complete_flags_any": ["power_restored"],
		"priority": 35,
	})
	_register({
		"id": "submit_hr",
		"title": "Получить согласование HR",
		"description": "Вернитесь в HR с распечатанным заявлением.",
		"activate_flags_any": ["print_completed"],
		"complete_flags_any": ["hr_approved"],
		"priority": 40,
	})
	_register({
		"id": "submit_accounting",
		"title": "Получить согласование бухгалтерии",
		"description": "После HR подтвердите выход в терминале бухгалтерии.",
		"activate_flags_any": ["hr_approved"],
		"complete_flags_any": ["accounting_approved"],
		"priority": 45,
	})
	_register({
		"id": "submit_security",
		"title": "Получить согласование безопасности",
		"description": "Пройдите к посту безопасности и завершите процедуру.",
		"activate_flags_any": ["security_door_open", "hr_approved"],
		"complete_flags_any": ["security_approved"],
		"priority": 50,
	})
	_register({
		"id": "leave_building",
		"title": "Покинуть здание",
		"description": "Пройдите через турникет и вызовите лифт.",
		"activate_flags_any": ["exit_unlocked"],
		"complete_flags_any": ["game_finished"],
		"priority": 60,
	})


func _register(def: Dictionary) -> void:
	tasks[def["id"]] = def


func _on_state_changed(_kind: String, _id: String, _value: Variant) -> void:
	_reevaluate()


func reevaluate() -> void:
	_reevaluate()


func _reevaluate() -> void:
	for id in tasks.keys():
		var t: Dictionary = tasks[id]
		if id in completed_ids:
			continue
		if _is_complete(t):
			_complete(id)
			continue
		if id not in active_ids and _can_activate(t):
			_activate(id)
	_refresh_current()


func _can_activate(t: Dictionary) -> bool:
	if t.get("activate_any", false) and t.has("activate_items_any"):
		for item_id in t["activate_items_any"]:
			if GameState.has_item(item_id):
				return true
	if t.has("activate_flags_any"):
		for flag_id in t["activate_flags_any"]:
			if GameState.get_flag(flag_id):
				return true
		return false
	if t.has("activate_items_any"):
		for item_id in t["activate_items_any"]:
			if GameState.has_item(item_id):
				return true
		return false
	return false


func _is_complete(t: Dictionary) -> bool:
	if t.has("complete_flags_any"):
		for flag_id in t["complete_flags_any"]:
			if GameState.get_flag(flag_id):
				return true
	if t.has("complete_items_any"):
		for item_id in t["complete_items_any"]:
			if GameState.has_item(item_id):
				return true
	return false


func _activate(id: String) -> void:
	if id in active_ids or id in completed_ids:
		return
	active_ids.append(id)
	task_activated.emit(id)


func _complete(id: String) -> void:
	if id in completed_ids:
		return
	active_ids.erase(id)
	completed_ids.append(id)
	task_completed.emit(id)


func _refresh_current() -> void:
	var best_id := ""
	var best_pri := -999
	for id in active_ids:
		if id in completed_ids:
			continue
		var pri: int = int(tasks[id].get("priority", 0))
		if pri > best_pri:
			best_pri = pri
			best_id = id
	if best_id == "":
		# Fallback: highest incomplete that could be next
		for id in tasks.keys():
			if id in completed_ids:
				continue
			var pri2: int = int(tasks[id].get("priority", 0))
			if pri2 > best_pri and _can_activate(tasks[id]):
				best_pri = pri2
				best_id = id
	if best_id != current_id:
		current_id = best_id
		if current_id == "":
			current_task_changed.emit("", "Нет активных задач", "")
		else:
			var t: Dictionary = tasks[current_id]
			current_task_changed.emit(current_id, t["title"], t["description"])


func get_current_title() -> String:
	if current_id == "" or not tasks.has(current_id):
		return "Нет активных задач"
	return tasks[current_id]["title"]


func get_current_description() -> String:
	if current_id == "" or not tasks.has(current_id):
		return ""
	return tasks[current_id]["description"]


func get_journal_entries() -> Array:
	var entries: Array = []
	for id in active_ids:
		if id in completed_ids:
			continue
		var t: Dictionary = tasks[id]
		entries.append({"id": id, "title": t["title"], "description": t["description"], "done": false})
	for id in completed_ids:
		var t2: Dictionary = tasks[id]
		entries.append({"id": id, "title": t2["title"], "description": t2["description"], "done": true})
	return entries


func reset() -> void:
	active_ids.clear()
	completed_ids.clear()
	current_id = ""
	_reevaluate()
