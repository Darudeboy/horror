extends CanvasLayer
## HUD, pause, journal, document overlay, ending.

signal pause_changed(paused: bool)

@onready var crosshair: Label = $HUD/Crosshair
@onready var prompt_label: Label = $HUD/Prompt
@onready var task_label: Label = $HUD/TaskLabel
@onready var items_label: Label = $HUD/ItemsLabel
@onready var notify_label: Label = $HUD/Notify
@onready var pause_panel: Control = $PauseMenu
@onready var journal_panel: Control = $Journal
@onready var document_panel: Control = $Document
@onready var document_title: Label = $Document/Panel/VBox/Title
@onready var document_body: Label = $Document/Panel/VBox/Body
@onready var journal_list: VBoxContainer = $Journal/Panel/VBox/List
@onready var ending_panel: Control = $Ending
@onready var fade: ColorRect = $Fade
@onready var settings_panel: Control = $Settings
@onready var debug_panel: Control = $DebugPanel

var _notify_time: float = 0.0
var player: Node


func _ready() -> void:
	add_to_group("game_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.visible = false
	journal_panel.visible = false
	document_panel.visible = false
	ending_panel.visible = false
	settings_panel.visible = false
	debug_panel.visible = false
	fade.modulate.a = 0.0
	GameState.notification_requested.connect(show_notification)
	GameState.item_changed.connect(func(_a, _b): _refresh_items())
	var tm := get_tree().get_first_node_in_group("task_manager")
	if tm and tm.has_signal("current_task_changed"):
		tm.current_task_changed.connect(_on_task)
	_refresh_items()
	_find_player()
	# Debug only outside release export
	if OS.has_feature("template") and not OS.is_debug_build():
		debug_panel.queue_free()


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("InteractionController"):
		var ic: Node = player.get_node("InteractionController")
		if ic.has_signal("focus_changed") and not ic.focus_changed.is_connected(_on_focus):
			ic.focus_changed.connect(_on_focus)


func _process(delta: float) -> void:
	if _notify_time > 0.0:
		_notify_time -= delta
		if _notify_time <= 0.0:
			notify_label.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if ending_panel.visible:
		return
	if event.is_action_pressed("pause_menu"):
		_handle_escape()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_journal"):
		if document_panel.visible or pause_panel.visible or settings_panel.visible:
			return
		_toggle_journal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_toggle"):
		if is_instance_valid(debug_panel) and OS.is_debug_build():
			debug_panel.visible = not debug_panel.visible
			if debug_panel.visible:
				_open_overlay_cursor()
			elif not _any_overlay():
				_close_overlays_restore()


func _handle_escape() -> void:
	if document_panel.visible:
		close_document()
	elif journal_panel.visible:
		_toggle_journal(false)
	elif settings_panel.visible:
		settings_panel.visible = false
		pause_panel.visible = true
	elif pause_panel.visible:
		set_paused(false)
	else:
		set_paused(true)


func _any_overlay() -> bool:
	return pause_panel.visible or journal_panel.visible or document_panel.visible or settings_panel.visible or ending_panel.visible


func set_paused(value: bool) -> void:
	pause_panel.visible = value
	GameState.gameplay_paused = value or document_panel.visible or journal_panel.visible or ending_panel.visible
	get_tree().paused = GameState.gameplay_paused
	if value:
		_open_overlay_cursor()
	else:
		if not document_panel.visible and not journal_panel.visible and not ending_panel.visible:
			_close_overlays_restore()
	pause_changed.emit(value)


func _open_overlay_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player and player.has_method("set_controls_enabled"):
		player.set_controls_enabled(false)


func _close_overlays_restore() -> void:
	GameState.gameplay_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if player and player.has_method("set_controls_enabled"):
		player.set_controls_enabled(true)


func show_document(title: String, body: String) -> void:
	document_title.text = title
	document_body.text = body
	document_panel.visible = true
	GameState.gameplay_paused = true
	get_tree().paused = true
	_open_overlay_cursor()


func close_document() -> void:
	document_panel.visible = false
	if not pause_panel.visible and not journal_panel.visible:
		_close_overlays_restore()


func _toggle_journal(force: Variant = null) -> void:
	var show := not journal_panel.visible if force == null else bool(force)
	journal_panel.visible = show
	if show:
		_populate_journal()
		GameState.gameplay_paused = true
		get_tree().paused = true
		_open_overlay_cursor()
	else:
		if not pause_panel.visible and not document_panel.visible:
			_close_overlays_restore()


func _populate_journal() -> void:
	for c in journal_list.get_children():
		c.queue_free()
	var tm := get_tree().get_first_node_in_group("task_manager")
	if tm == null:
		return
	for entry in tm.get_journal_entries():
		var l := Label.new()
		var mark := "[x] " if entry["done"] else "[ ] "
		l.text = mark + entry["title"] + "\n" + entry["description"]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		journal_list.add_child(l)


func _on_focus(_interactable: Interactable, text: String, can_use: bool, deny: String) -> void:
	if text == "" and deny == "":
		prompt_label.text = ""
		return
	if can_use:
		prompt_label.text = "[E] %s" % text
	else:
		prompt_label.text = "%s — %s" % [text, deny]


func _on_task(_id: String, title: String, desc: String) -> void:
	task_label.text = "Задача: %s" % title
	task_label.tooltip_text = desc


func _refresh_items() -> void:
	var labels := GameState.get_owned_item_labels()
	if labels.is_empty():
		items_label.text = "Предметы: —"
	else:
		items_label.text = "Предметы: " + ", ".join(labels)


func show_notification(text: String) -> void:
	notify_label.text = text
	_notify_time = 4.0


func show_ending() -> void:
	ending_panel.visible = true
	GameState.gameplay_paused = true
	get_tree().paused = true
	_open_overlay_cursor()
	var msg: Label = ending_panel.get_node("Panel/VBox/Message")
	msg.text = "Ваша следующая смена уже началась"


func on_player_caught() -> void:
	SaveManager.set_blocker("caught", true)
	fade.modulate.a = 0.0
	fade.visible = true
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.6)
	tw.tween_callback(_respawn_after_catch)
	tw.tween_property(fade, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		SaveManager.set_blocker("caught", false)
		fade.visible = false
	)


func _respawn_after_catch() -> void:
	# Reload checkpoint state into world
	var data := {}
	if SaveManager.has_valid_save():
		data = SaveManager.load_checkpoint()
	var main := get_tree().get_first_node_in_group("main_game")
	if main and main.has_method("apply_world_from_state"):
		main.apply_world_from_state(data)
	GameState.grant_spawn_protection(3.0)
	var enemy := get_tree().get_first_node_in_group("enemy")
	if enemy and enemy.has_method("reset_to_safe_patrol"):
		enemy.reset_to_safe_patrol()


func _on_resume_pressed() -> void:
	set_paused(false)


func _on_settings_pressed() -> void:
	pause_panel.visible = false
	settings_panel.visible = true


func _on_menu_pressed() -> void:
	get_tree().paused = false
	GameState.gameplay_paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_restart_pressed() -> void:
	get_tree().paused = false
	GameState.reset_run()
	SaveManager.clear_save()
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_close_document_pressed() -> void:
	close_document()


func _on_close_journal_pressed() -> void:
	_toggle_journal(false)


func _on_settings_back() -> void:
	settings_panel.visible = false
	if not ending_panel.visible:
		pause_panel.visible = true
