extends Control
## Debug overlay — only meaningful in debug builds.


@onready var info: Label = $Panel/VBox/Info


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	var tm: Node = get_tree().get_first_node_in_group("task_manager")
	var enemy: Node = get_tree().get_first_node_in_group("enemy")
	var task: String = "?"
	if tm and tm.has_method("get_current_title"):
		task = str(tm.call("get_current_title"))
	var estate: String = "n/a"
	if enemy and enemy.has_method("get_state_name"):
		estate = str(enemy.call("get_state_name"))
	var flags: PackedStringArray = []
	for f in GameState.ALL_FLAGS:
		if GameState.get_flag(f):
			flags.append(f)
	info.text = "Задача: %s\nЭтап: %s\nВраг: %s\nФлаги: %s\nПредметы: badge=%s app=%s\nCP: %s" % [
		task, GameState.stage, estate, ", ".join(flags),
		str(GameState.has_item("employee_badge")), str(GameState.has_item("printed_application")),
		GameState.checkpoint_id,
	]


func _on_give_badge() -> void:
	GameState.give_item(GameState.ITEM_EMPLOYEE_BADGE)
	GameState.grant_access(GameState.ACCESS_ACCOUNTING)


func _on_give_app() -> void:
	GameState.give_item(GameState.ITEM_PRINTED_APPLICATION)


func _on_approve_hr() -> void:
	GameState.set_flag(GameState.FLAG_HR_APPROVED, true)


func _on_approve_acc() -> void:
	GameState.set_flag(GameState.FLAG_ACCOUNTING_APPROVED, true)


func _on_approve_sec() -> void:
	GameState.set_flag(GameState.FLAG_SECURITY_APPROVED, true)


func _on_goto_cp() -> void:
	var main := get_tree().get_first_node_in_group("main_game")
	if main and main.has_method("apply_world_from_state"):
		main.apply_world_from_state({})


func _on_force_lights() -> void:
	var d := get_tree().get_first_node_in_group("event_director")
	if d and d.has_method("force_event"):
		d.force_event("lights_out")


func _on_reset() -> void:
	GameState.reset_run()
	SaveManager.clear_save()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
