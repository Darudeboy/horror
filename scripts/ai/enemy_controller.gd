extends CharacterBody3D
class_name EnemyController
## Compliance officer — state machine with vision and hearing.

enum State { DORMANT, PATROL, INVESTIGATE, CHASE, SEARCH }

const PATROL_SPEED := 2.0
const CHASE_SPEED := 4.2
const VISION_RANGE := 12.0
const VISION_ANGLE_DEG := 80.0
const LOSE_SIGHT_TIME := 2.0
const SEARCH_TIME := 8.0
const CATCH_DISTANCE := 1.0
const MIN_SPAWN_PATH_DIST := 12.0

@export var patrol_points_path: NodePath

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var head: Node3D = $Head

var state: State = State.DORMANT
var _patrol_points: Array[Vector3] = []
var _patrol_index: int = 0
var _last_known: Vector3 = Vector3.ZERO
var _lose_timer: float = 0.0
var _search_timer: float = 0.0
var _investigate_pos: Vector3 = Vector3.ZERO
var _active: bool = false


func _ready() -> void:
	add_to_group("enemy")
	visible = false
	set_physics_process(false)
	AudioManager.noise_emitted.connect(_on_noise)
	GameState.smoke_alarm.connect(func(pos: Vector3): _on_noise(pos, 22.0, "smoke_alarm"))
	_collect_patrol()
	_attach_visual_model()
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 0.5
	agent.avoidance_enabled = false


func _attach_visual_model() -> void:
	## Quaternius Ghost (CC0) as compliance silhouette; fallback keeps capsule.
	var path := "res://assets/models/enemy/compliance_officer.glb"
	if not ResourceLoader.exists(path):
		return
	var packed: Resource = load(path)
	if packed == null or not (packed is PackedScene):
		return
	var visual: Node = (packed as PackedScene).instantiate()
	if visual is Node3D:
		(visual as Node3D).scale = Vector3(1.9, 1.9, 1.9)
		(visual as Node3D).position = Vector3(0, 0, 0)
	add_child(visual)
	var body := get_node_or_null("Body")
	if body:
		body.visible = false
	var badge := get_node_or_null("Badge")
	if badge:
		badge.visible = true
		if badge is Node3D:
			(badge as Node3D).position = Vector3(0.35, 1.5, 0.45)
			(badge as Node3D).scale = Vector3(1.4, 1.4, 1.4)


func _collect_patrol() -> void:
	_patrol_points.clear()
	var container: Node = self
	if patrol_points_path != NodePath(""):
		container = get_node_or_null(patrol_points_path)
	if container == null:
		container = get_parent().get_node_or_null("PatrolPoints") if get_parent() else null
	if container:
		for c in container.get_children():
			if c is Node3D:
				_patrol_points.append((c as Node3D).global_position)
	if _patrol_points.is_empty():
		_patrol_points.append(global_position)


func activate() -> void:
	_active = true
	visible = true
	set_physics_process(true)
	state = State.PATROL
	_set_target(_patrol_points[0])


func try_activate_safely() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		activate()
		return true
	# Prefer patrol points out of view and far enough
	var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
	var best: Vector3 = Vector3.ZERO
	var found := false
	for p in _patrol_points:
		var dist := player.global_position.distance_to(p)
		if dist < MIN_SPAWN_PATH_DIST:
			continue
		if cam:
			var local := cam.to_local(p)
			if local.z < 0.0: # in front of camera (Godot camera looks -Z)
				var fov_ok := absf(rad_to_deg(atan2(local.x, -local.z))) < 50.0
				if fov_ok and dist < VISION_RANGE + 4.0:
					continue
		best = p
		found = true
		break
	if not found:
		return false
	global_position = best
	activate()
	return true


func get_state_name() -> String:
	return State.keys()[state]


func _on_noise(pos: Vector3, radius: float, _source: String) -> void:
	if not _active or state == State.DORMANT:
		return
	if GameState.gameplay_paused or not GameState.ai_enabled:
		return
	if state == State.CHASE:
		return
	if global_position.distance_to(pos) <= radius:
		_investigate_pos = pos
		_last_known = pos
		state = State.INVESTIGATE
		_set_target(pos)


func _physics_process(delta: float) -> void:
	if not _active or state == State.DORMANT:
		return
	if GameState.gameplay_paused or not GameState.ai_enabled:
		velocity = Vector3.ZERO
		return

	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	var sees := false
	if player and not GameState.is_invulnerable():
		sees = _can_see(player)

	match state:
		State.PATROL:
			if sees:
				_enter_chase(player)
			else:
				_move_along(delta, PATROL_SPEED)
				if agent.is_navigation_finished():
					_patrol_index = (_patrol_index + 1) % _patrol_points.size()
					_set_target(_patrol_points[_patrol_index])
		State.INVESTIGATE:
			if sees:
				_enter_chase(player)
			else:
				_move_along(delta, PATROL_SPEED)
				if agent.is_navigation_finished():
					state = State.SEARCH
					_search_timer = SEARCH_TIME
					_last_known = _investigate_pos
		State.CHASE:
			if sees:
				_lose_timer = 0.0
				_last_known = player.global_position
				_set_target(player.global_position)
			else:
				_lose_timer += delta
				_set_target(_last_known)
				if _lose_timer >= LOSE_SIGHT_TIME:
					state = State.SEARCH
					_search_timer = SEARCH_TIME
			_move_along(delta, CHASE_SPEED)
			if player and global_position.distance_to(player.global_position) < CATCH_DISTANCE:
				if _has_line_to(player.global_position):
					_catch_player()
		State.SEARCH:
			if sees:
				_enter_chase(player)
			else:
				_search_timer -= delta
				_set_target(_last_known)
				_move_along(delta, PATROL_SPEED)
				if _search_timer <= 0.0:
					state = State.PATROL
					_set_target(_patrol_points[_patrol_index])


func _enter_chase(player: Node3D) -> void:
	state = State.CHASE
	_lose_timer = 0.0
	_last_known = player.global_position
	_set_target(_last_known)


func _set_target(pos: Vector3) -> void:
	agent.target_position = pos


func _move_along(delta: float, speed: float) -> void:
	if agent.is_navigation_finished():
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var next_pos := agent.get_next_path_position()
	var direction := next_pos - global_position
	direction.y = 0.0
	if direction.length() > 0.01:
		direction = direction.normalized()
		velocity = direction * speed
		look_at(global_position + direction, Vector3.UP)
	else:
		velocity = Vector3.ZERO
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()


func _can_see(player: Node3D) -> bool:
	var to_player := player.global_position + Vector3(0, 1.4, 0) - head.global_position
	var dist := to_player.length()
	if dist > VISION_RANGE or dist < 0.05:
		return false
	var forward := -global_transform.basis.z
	var angle := rad_to_deg(forward.angle_to(to_player.normalized()))
	if angle > VISION_ANGLE_DEG * 0.5:
		return false
	return _has_line_to(player.global_position + Vector3(0, 1.4, 0))


func _has_line_to(target: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(head.global_position, target)
	query.exclude = [get_rid()]
	var player := get_tree().get_first_node_in_group("player")
	if player and player is CollisionObject3D:
		# Allow hitting player; block on world
		pass
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider = hit.collider
	if collider == player or (collider is Node and player and player.is_ancestor_of(collider)):
		return true
	if collider is Node and (collider as Node).is_in_group("player"):
		return true
	return false


func _catch_player() -> void:
	if GameState.is_invulnerable():
		return
	GameState.notification_requested.emit("Проверка соответствия...")
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui and ui.has_method("on_player_caught"):
		ui.on_player_caught()
	else:
		_fallback_respawn()


func _fallback_respawn() -> void:
	GameState.grant_spawn_protection(3.0)
	state = State.PATROL
	if not _patrol_points.is_empty():
		global_position = _patrol_points[0]
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var spawn := get_tree().get_first_node_in_group("checkpoint")
	for s in get_tree().get_nodes_in_group("checkpoint"):
		if s.has_meta("checkpoint_id") and str(s.get_meta("checkpoint_id")) == GameState.checkpoint_id:
			spawn = s
			break
	if player and spawn:
		player.global_position = spawn.global_position


func reset_to_safe_patrol() -> void:
	if not _active:
		return
	state = State.PATROL
	if not _patrol_points.is_empty():
		global_position = _patrol_points[0]
		_patrol_index = 0
		_set_target(_patrol_points[0])
