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
const CATCH_DISTANCE := 1.15
const MIN_SPAWN_PATH_DIST := 7.0

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
	## Quaternius Ghost (CC0) + dark overlay so silhouette reads in dim offices.
	var path := "res://assets/models/enemy/compliance_officer.glb"
	var body := get_node_or_null("Body") as MeshInstance3D
	if ResourceLoader.exists(path):
		var packed: Resource = load(path)
		if packed is PackedScene:
			var visual: Node = (packed as PackedScene).instantiate()
			if visual is Node3D:
				(visual as Node3D).scale = Vector3(2.05, 2.05, 2.05)
				(visual as Node3D).position = Vector3(0, 0.05, 0)
				_darken_meshes(visual)
			add_child(visual)
			if body:
				body.visible = false
	# Always keep badge + eye glow readable
	var badge := get_node_or_null("Badge") as MeshInstance3D
	if badge:
		badge.visible = true
		badge.position = Vector3(0.28, 1.55, 0.5)
		badge.scale = Vector3(1.6, 1.6, 1.6)
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.95, 0.85, 0.2)
		bm.emission_enabled = true
		bm.emission = Color(1.0, 0.85, 0.2)
		bm.emission_energy_multiplier = 2.5
		badge.material_override = bm
	# Eye glow (visible even if mesh fails)
	var eyes := MeshInstance3D.new()
	eyes.name = "Eyes"
	var eye_mesh := BoxMesh.new()
	eye_mesh.size = Vector3(0.28, 0.08, 0.06)
	eyes.mesh = eye_mesh
	eyes.position = Vector3(0, 1.85, 0.42)
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.7, 0.05, 0.05)
	em.emission_enabled = true
	em.emission = Color(1.0, 0.15, 0.1)
	em.emission_energy_multiplier = 3.5
	eyes.material_override = em
	add_child(eyes)
	# Soft point light so figure is never fully invisible in dark
	var aura := OmniLight3D.new()
	aura.name = "PresenceLight"
	aura.position = Vector3(0, 1.4, 0)
	aura.omni_range = 3.5
	aura.light_color = Color(0.55, 0.15, 0.12)
	aura.light_energy = 0.55
	aura.shadow_enabled = false
	add_child(aura)


func _darken_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.09, 0.12)
		mat.roughness = 0.85
		mi.material_override = mat
	for c in node.get_children():
		_darken_meshes(c)


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
	if not _patrol_points.is_empty():
		_set_target(_patrol_points[0])


func force_appear() -> bool:
	## Always spawn somewhere useful near the exit corridor so the player can see them.
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var candidates: Array[Vector3] = [
		Vector3(2.0, 0.1, 8.5),
		Vector3(-2.0, 0.1, 6.0),
		Vector3(6.0, 0.1, 6.0),
		Vector3(2.0, 0.1, 4.5),
	]
	for p in _patrol_points:
		candidates.append(p)
	var best := Vector3(6.0, 0.1, 6.0)
	var best_score := -9999.0
	for p in candidates:
		var score := 10.0
		if player:
			var dist := player.global_position.distance_to(p)
			if dist < 4.0:
				score -= 20.0
			elif dist < 9.0:
				score += 8.0 # prefer "visible but not on top of player"
			elif dist < 16.0:
				score += 4.0
			else:
				score -= 2.0
			var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
			if cam:
				var local := cam.to_local(p)
				# Prefer slightly off-center in front so first appearance is seen
				if local.z < -2.0 and absf(local.x) < 6.0:
					score += 6.0
		if score > best_score:
			best_score = score
			best = p
	global_position = best
	activate()
	# Immediately investigate toward player / turnstile area
	if player:
		_investigate_pos = player.global_position
		_last_known = player.global_position
		state = State.INVESTIGATE
		_set_target(player.global_position)
	return true


func try_activate_safely() -> bool:
	return force_appear()


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
	# Crouched inside hide_spot = not visible
	if "is_hidden" in player and bool(player.get("is_hidden")):
		return false
	var eye_y := 0.9 if ("crouching" in player and bool(player.get("crouching"))) else 1.4
	var to_player := player.global_position + Vector3(0, eye_y, 0) - head.global_position
	var dist := to_player.length()
	if dist > VISION_RANGE or dist < 0.05:
		return false
	var forward := -global_transform.basis.z
	var angle := rad_to_deg(forward.angle_to(to_player.normalized()))
	if angle > VISION_ANGLE_DEG * 0.5:
		return false
	return _has_line_to(player.global_position + Vector3(0, eye_y, 0))


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
	var player := get_tree().get_first_node_in_group("player")
	if player and "is_hidden" in player and bool(player.get("is_hidden")):
		return
	if player and player.has_method("begin_death"):
		player.begin_death()
	GameState.notification_requested.emit("Проверка соответствия...")
	AudioManager.play_sfx("alarm", 0.9, -4.0)
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
