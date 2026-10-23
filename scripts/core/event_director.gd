extends Node
## One-shot story events with safe deferred execution.

signal event_started(event_id: String)
signal event_completed(event_id: String)

var completed: Dictionary = {} ## id -> true
var queued: Array[String] = []
var _running: bool = false

const EVENT_DEFS := {
	"lights_out": {"priority": 100, "exclusive_space": true},
	"phone_ring": {"priority": 40, "exclusive_space": false},
	"poster_change": {"priority": 50, "exclusive_space": false},
	"security_door": {"priority": 90, "exclusive_space": true},
	"activate_enemy": {"priority": 80, "exclusive_space": false},
	"loop_setup": {"priority": 70, "exclusive_space": true},
}


func _ready() -> void:
	add_to_group("event_director")
	GameState.flag_changed.connect(_on_flag)


func _on_flag(flag_id: String, value: bool) -> void:
	if not value:
		return
	if flag_id == GameState.FLAG_HR_APPROVED:
		queue_event("poster_change")
		queue_event("security_door")


func queue_event(event_id: String) -> void:
	if completed.get(event_id, false):
		return
	if event_id in queued:
		return
	queued.append(event_id)
	queued.sort_custom(func(a, b): return int(EVENT_DEFS.get(a, {}).get("priority", 0)) > int(EVENT_DEFS.get(b, {}).get("priority", 0)))


func _process(_delta: float) -> void:
	if GameState.gameplay_paused or _running:
		return
	if queued.is_empty():
		return
	var next_id: String = queued[0]
	if not _can_run_safely(next_id):
		return
	queued.pop_front()
	_execute(next_id)


func _can_run_safely(event_id: String) -> bool:
	var def: Dictionary = EVENT_DEFS.get(event_id, {})
	if not def.get("exclusive_space", false):
		return true
	var zone := get_tree().get_first_node_in_group("event_zone_%s" % event_id)
	if zone == null:
		return true
	var player := get_tree().get_first_node_in_group("player")
	var enemy := get_tree().get_first_node_in_group("enemy")
	if player and zone is Area3D and (zone as Area3D).overlaps_body(player):
		return false
	if enemy and zone is Area3D and (zone as Area3D).overlaps_body(enemy):
		return false
	# Geometry change not in player view for security_door
	if event_id == "security_door" and player:
		var door := get_tree().get_first_node_in_group("security_door_visual")
		if door and player is Node3D:
			var to_door: Vector3 = (door as Node3D).global_position - (player as Node3D).global_position
			var forward: Vector3 = -(player as Node3D).global_transform.basis.z
			if to_door.length() < 8.0 and forward.normalized().dot(to_door.normalized()) > 0.5:
				return false
	return true


func _execute(event_id: String) -> void:
	if completed.get(event_id, false):
		return
	_running = true
	event_started.emit(event_id)
	match event_id:
		"lights_out":
			_lights_out()
		"phone_ring":
			_phone_ring()
		"poster_change":
			_poster_change()
		"security_door":
			_security_door()
		"activate_enemy":
			_activate_enemy()
		"loop_setup":
			pass
		_:
			push_warning("Unknown event: %s" % event_id)
	completed[event_id] = true
	event_completed.emit(event_id)
	_running = false


func _lights_out() -> void:
	var lights := get_tree().get_nodes_in_group("accounting_lights")
	for l in lights:
		if l is Light3D:
			(l as Light3D).visible = false
			(l as Light3D).light_energy = 0.0
	var emergency := get_tree().get_nodes_in_group("emergency_lights")
	for e in emergency:
		if e is Light3D:
			(e as Light3D).visible = true
			(e as Light3D).light_energy = 0.6


func _phone_ring() -> void:
	GameState.set_flag(GameState.FLAG_PHONE_RINGING, true)
	GameState.notification_requested.emit("Где-то в коридоре звонит телефон")


func _poster_change() -> void:
	GameState.set_flag(GameState.FLAG_POSTER_CHANGED, true)


func _security_door() -> void:
	GameState.set_flag(GameState.FLAG_SECURITY_DOOR_OPEN, true)
	GameState.notification_requested.emit("Открыт проход к посту безопасности")


func _activate_enemy() -> void:
	var enemy := get_tree().get_first_node_in_group("enemy")
	if enemy and enemy.has_method("try_activate_safely"):
		if enemy.try_activate_safely():
			GameState.set_flag(GameState.FLAG_ENEMY_ACTIVATED, true)
		else:
			# Defer: re-queue without marking complete
			completed.erase("activate_enemy")
			queue_event("activate_enemy")
	elif enemy and enemy.has_method("activate"):
		enemy.activate()
		GameState.set_flag(GameState.FLAG_ENEMY_ACTIVATED, true)


func get_completed_event_ids() -> Array:
	return completed.keys()


func apply_completed(ids: Array) -> void:
	completed.clear()
	for id in ids:
		completed[str(id)] = true
	# Re-apply world side effects without re-queueing
	if completed.get("lights_out", false) and GameState.get_flag(GameState.FLAG_PRINTER_FAULT) and not GameState.get_flag(GameState.FLAG_POWER_RESTORED):
		_lights_out()
	if completed.get("poster_change", false) or GameState.get_flag(GameState.FLAG_HR_APPROVED):
		_poster_change()
	if completed.get("security_door", false) or GameState.get_flag(GameState.FLAG_SECURITY_DOOR_OPEN):
		GameState.set_flag(GameState.FLAG_SECURITY_DOOR_OPEN, true)
	if GameState.get_flag(GameState.FLAG_POWER_RESTORED):
		_restore_lights()


func _restore_lights() -> void:
	var lights := get_tree().get_nodes_in_group("accounting_lights")
	for l in lights:
		if l is Light3D:
			(l as Light3D).visible = true
			(l as Light3D).light_energy = 1.0


func force_event(event_id: String) -> void:
	completed.erase(event_id)
	queued.erase(event_id)
	_execute(event_id)


func reset() -> void:
	completed.clear()
	queued.clear()
	_running = false
