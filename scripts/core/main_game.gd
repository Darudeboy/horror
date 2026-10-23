extends Node3D
## Main gameplay scene controller.

@onready var level_root: Node3D = $Level
@onready var player: CharacterBody3D = $Player
@onready var enemy: CharacterBody3D = $Enemy
@onready var task_manager: Node = $TaskManager
@onready var event_director: Node = $EventDirector
@onready var game_ui: CanvasLayer = $GameUI


func _ready() -> void:
	add_to_group("main_game")
	if level_root.has_method("build"):
		level_root.build()
	_place_player()
	_setup_enemy()
	if game_ui and game_ui.has_method("_find_player"):
		game_ui._find_player()
	# Restore if continuing
	if get_tree().get_meta("load_save", false):
		get_tree().set_meta("load_save", false)
		var data := SaveManager.load_checkpoint()
		apply_world_from_state(data)
	else:
		# Fresh run unless already mid-state
		if not GameState.get_flag(GameState.FLAG_WORKDAY_STARTED):
			pass
	task_manager.reset()
	# Starting hint
	GameState.notification_requested.emit("Рабочий день завершён. Проверьте терминал на столе.")


func _place_player() -> void:
	var spawn := get_tree().get_first_node_in_group("player_spawn")
	if spawn and player:
		player.global_position = spawn.global_position + Vector3(0, 0.1, 0)


func _setup_enemy() -> void:
	if enemy and enemy.has_method("_collect_patrol"):
		enemy.patrol_points_path = enemy.get_path_to(level_root.get_node("PatrolPoints"))
		enemy._collect_patrol()
		enemy.global_position = Vector3(6, 0.1, 6)
		if GameState.get_flag(GameState.FLAG_ENEMY_ACTIVATED):
			enemy.activate()


func apply_world_from_state(data: Dictionary = {}) -> void:
	# Reposition player at checkpoint
	var cp := GameState.checkpoint_id
	for s in get_tree().get_nodes_in_group("checkpoint"):
		if s.has_meta("checkpoint_id") and str(s.get_meta("checkpoint_id")) == cp:
			player.global_position = s.global_position + Vector3(0, 0.1, 0)
			break
	# Pickups visibility via their own listeners
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.has_method("_refresh_visibility"):
			p._refresh_visibility()
	# Events
	if event_director and event_director.has_method("apply_completed"):
		var done: Array = data.get("events_done", [])
		event_director.apply_completed(done)
	# Enemy
	if enemy:
		if GameState.get_flag(GameState.FLAG_ENEMY_ACTIVATED):
			if enemy.has_method("reset_to_safe_patrol"):
				if not enemy.visible:
					enemy.activate()
				enemy.reset_to_safe_patrol()
		else:
			enemy.visible = false
			enemy.set_physics_process(false)
	# Printer sync
	for pr in get_tree().get_nodes_in_group("printer"):
		if pr.has_method("_sync_from_state"):
			pr._sync_from_state()
	# Lights restore if power on
	if GameState.get_flag(GameState.FLAG_POWER_RESTORED):
		for l in get_tree().get_nodes_in_group("accounting_lights"):
			if l is Light3D:
				l.visible = true
				(l as Light3D).light_energy = 1.0
	elif GameState.get_flag(GameState.FLAG_PRINTER_FAULT):
		if event_director and event_director.has_method("_lights_out"):
			event_director._lights_out()
	# Turnstile / doors listen to flags
	for d in get_tree().get_nodes_in_group("doors"):
		if d.has_method("_on_state"):
			d._on_state("", "", null)
	task_manager.reset()
	GameState.grant_spawn_protection(3.0)
