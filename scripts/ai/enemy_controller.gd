extends CharacterBody3D
class_name EnemyController
## Compliance officer — steer around walls (no broken nav mesh through walls).

enum State { DORMANT, PATROL, INVESTIGATE, CHASE, SEARCH }

const PATROL_SPEED := 2.1
const CHASE_SPEED := 4.0
const VISION_RANGE := 14.0
const VISION_ANGLE_DEG := 90.0
const LOSE_SIGHT_TIME := 2.2
const SEARCH_TIME := 8.0
const CATCH_DISTANCE := 1.2
const ARRIVE_DIST := 0.85
const WALL_RAY := 1.15

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
var _move_target: Vector3 = Vector3.ZERO
var _active: bool = false
var _stuck_timer: float = 0.0
var _floor_y: float = 0.1


func _ready() -> void:
	add_to_group("enemy")
	visible = false
	set_physics_process(false)
	floor_snap_length = 0.2
	AudioManager.noise_emitted.connect(_on_noise)
	GameState.smoke_alarm.connect(_on_smoke_alarm)
	_collect_patrol()
	_attach_visual_model()
	if agent:
		agent.avoidance_enabled = false
		agent.path_desired_distance = 0.6
		agent.target_desired_distance = 0.7


func _on_smoke_alarm(pos: Vector3) -> void:
	## Cigarettes / smoke always summon compliance.
	if not _active:
		force_appear_near(pos)
		GameState.set_flag(GameState.FLAG_ENEMY_ACTIVATED, true)
		var director := get_tree().get_first_node_in_group("event_director")
		if director and director.has_method("_flicker_office_lights"):
			director._flicker_office_lights(2.6)
		GameState.notification_requested.emit("СЛУЖБА СООТВЕТСТВИЯ РЕАГИРУЕТ НА ДЫМ")
	_investigate_pos = pos
	_last_known = pos
	state = State.INVESTIGATE
	_set_target(pos)
	_on_noise(pos, 30.0, "smoke_alarm")


func _attach_visual_model() -> void:
	var path := "res://assets/models/enemy/compliance_officer.glb"
	var body := get_node_or_null("Body") as MeshInstance3D
	if ResourceLoader.exists(path):
		var packed: Resource = load(path)
		if packed is PackedScene:
			var visual: Node = (packed as PackedScene).instantiate()
			if visual is Node3D:
				(visual as Node3D).scale = Vector3(1.85, 1.85, 1.85)
				(visual as Node3D).position = Vector3(0, 0.05, 0)
				_darken_meshes(visual)
			add_child(visual)
			if body:
				body.visible = false
	var badge := get_node_or_null("Badge") as MeshInstance3D
	if badge:
		badge.visible = true
		badge.position = Vector3(0.28, 1.55, 0.5)
		badge.scale = Vector3(1.5, 1.5, 1.5)
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.95, 0.85, 0.2)
		bm.emission_enabled = true
		bm.emission = Color(1.0, 0.85, 0.2)
		bm.emission_energy_multiplier = 2.5
		badge.material_override = bm
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
	if container == null and get_parent():
		container = get_parent().get_node_or_null("Floor1/PatrolPoints")
		if container == null:
			container = get_parent().get_node_or_null("PatrolPoints")
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
	_floor_y = global_position.y
	if not _patrol_points.is_empty():
		_set_target(_patrol_points[0])


func force_appear() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := player.global_position if player else Vector3(6, 0.1, 8)
	return force_appear_near(near)


func force_appear_near(anchor: Vector3) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var floor_y := anchor.y
	if player:
		floor_y = player.global_position.y
	var candidates: Array[Vector3] = []
	# Ring of open-corridor candidates around smoke / player
	for ang in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
		var r := 7.0
		var rad := deg_to_rad(ang)
		candidates.append(Vector3(anchor.x + cos(rad) * r, floor_y, anchor.z + sin(rad) * r))
	for p in _patrol_points:
		var pp := p
		pp.y = floor_y
		candidates.append(pp)
	candidates.append_array([
		Vector3(2.0, floor_y, 10.0), Vector3(6.0, floor_y, 8.0),
		Vector3(-4.0, floor_y, 8.0), Vector3(14.0, floor_y, 2.0),
	])
	var best := Vector3(6.0, floor_y, 8.0)
	var best_score := -99999.0
	for p in candidates:
		p.y = floor_y
		if not _is_clear_spawn(p):
			continue
		var score := 5.0
		if player:
			var dist := player.global_position.distance_to(p)
			if dist < 3.5:
				score -= 40.0
			elif dist < 8.0:
				score += 12.0
			elif dist < 14.0:
				score += 6.0
			else:
				score -= 1.0
		score += _clearance_score(p)
		if score > best_score:
			best_score = score
			best = p
	global_position = best
	_floor_y = floor_y
	activate()
	if player:
		_investigate_pos = player.global_position
		_last_known = player.global_position
		state = State.INVESTIGATE
		_set_target(player.global_position)
	return true


func try_activate_safely() -> bool:
	return force_appear()


func _is_clear_spawn(pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	# Sphere-ish checks via short rays in 4 dirs + up
	for offset in [Vector3(0.5, 1.0, 0), Vector3(-0.5, 1.0, 0), Vector3(0, 1.0, 0.5), Vector3(0, 1.0, -0.5)]:
		var from := pos + Vector3(0, 1.0, 0)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + offset.normalized() * 0.55, 1, [get_rid()]))
		if not hit.is_empty():
			return false
	# Standing on floor
	var down: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 1.5, 0), pos + Vector3(0, -0.5, 0), 1, [get_rid()]))
	return not down.is_empty()


func _clearance_score(pos: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var score := 0.0
	for ang in [0.0, 90.0, 180.0, 270.0]:
		var d := Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang)))
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 1, 0), pos + Vector3(0, 1, 0) + d * 2.5, 1, [get_rid()]))
		if hit.is_empty():
			score += 2.0
		else:
			var hp: Vector3 = hit.position as Vector3
			score += clampf(pos.distance_to(hp) * 0.4, 0.0, 2.0)
	return score


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

	# Keep on current floor plane
	if absf(global_position.y - _floor_y) > 0.5:
		global_position.y = _floor_y

	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	var sees := false
	if player and not GameState.is_invulnerable():
		# Only chase on same floor
		if absf(player.global_position.y - global_position.y) < 2.5:
			sees = _can_see(player)

	match state:
		State.PATROL:
			if sees:
				_enter_chase(player)
			else:
				_move_along(delta, PATROL_SPEED)
				if _arrived():
					_patrol_index = (_patrol_index + 1) % maxi(_patrol_points.size(), 1)
					if not _patrol_points.is_empty():
						var pp := _patrol_points[_patrol_index]
						pp.y = _floor_y
						_set_target(pp)
		State.INVESTIGATE:
			if sees:
				_enter_chase(player)
			else:
				_move_along(delta, PATROL_SPEED)
				if _arrived():
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
				if absf(player.global_position.y - global_position.y) < 1.5 and _has_line_to(player.global_position + Vector3(0, 1.0, 0)):
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
					if not _patrol_points.is_empty():
						var pp2 := _patrol_points[_patrol_index]
						pp2.y = _floor_y
						_set_target(pp2)


func _enter_chase(player: Node3D) -> void:
	state = State.CHASE
	_lose_timer = 0.0
	_last_known = player.global_position
	_set_target(_last_known)


func _set_target(pos: Vector3) -> void:
	_move_target = pos
	_move_target.y = _floor_y
	if agent:
		agent.target_position = _move_target


func _arrived() -> bool:
	var d := global_position.distance_to(_move_target)
	return d < ARRIVE_DIST


func _move_along(delta: float, speed: float) -> void:
	var to := _move_target - global_position
	to.y = 0.0
	if to.length() < ARRIVE_DIST:
		velocity = Vector3.ZERO
		move_and_slide()
		_stuck_timer = 0.0
		return
	var desired := to.normalized()
	var steered := _steer_around_walls(desired)
	velocity.x = steered.x * speed
	velocity.z = steered.z * speed
	if steered.length() > 0.05:
		look_at(global_position + Vector3(steered.x, 0, steered.z), Vector3.UP)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	var before := global_position
	move_and_slide()
	# Unstick if barely moved while intending to move
	var moved := Vector3(global_position.x - before.x, 0, global_position.z - before.z).length()
	if moved < 0.02 * speed and to.length() > 1.0:
		_stuck_timer += delta
		if _stuck_timer > 0.55:
			_unstuck(desired)
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0


func _steer_around_walls(desired: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 0.9, 0)
	var candidates: Array[Vector3] = [desired]
	for deg in [35.0, -35.0, 70.0, -70.0, 110.0, -110.0]:
		candidates.append(desired.rotated(Vector3.UP, deg_to_rad(deg)).normalized())
	for dir in candidates:
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + dir * WALL_RAY, 1, [get_rid()]))
		if hit.is_empty():
			# Also check body width slightly offset
			var side := dir.cross(Vector3.UP).normalized() * 0.28
			var hit_l: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin + side, origin + side + dir * WALL_RAY, 1, [get_rid()]))
			var hit_r: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin - side, origin - side + dir * WALL_RAY, 1, [get_rid()]))
			if hit_l.is_empty() and hit_r.is_empty():
				return dir
	# All blocked — slide along nearest wall normal
	var fwd: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + desired * WALL_RAY, 1, [get_rid()]))
	if not fwd.is_empty():
		var n: Vector3 = fwd.normal as Vector3
		n.y = 0.0
		if n.length() > 0.01:
			var slide := desired.slide(n.normalized())
			if slide.length() > 0.05:
				return slide.normalized()
	return desired


func _unstuck(desired: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 0.9, 0)
	for deg in [90.0, -90.0, 180.0, 45.0, -45.0]:
		var dir := desired.rotated(Vector3.UP, deg_to_rad(deg)).normalized()
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + dir * 1.8, 1, [get_rid()]))
		if hit.is_empty():
			global_position += dir * 0.55
			global_position.y = _floor_y
			return
	# Last resort: nudge toward open patrol point
	if not _patrol_points.is_empty():
		var p := _patrol_points[_patrol_index % _patrol_points.size()]
		p.y = _floor_y
		if _is_clear_spawn(p):
			global_position = p


func _can_see(player: Node3D) -> bool:
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
		var p := _patrol_points[0]
		p.y = _floor_y
		global_position = p
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
		var p := _patrol_points[0]
		p.y = _floor_y
		global_position = p
		_patrol_index = 0
		_set_target(p)


func set_floor_y(y: float) -> void:
	_floor_y = y
	global_position.y = y
