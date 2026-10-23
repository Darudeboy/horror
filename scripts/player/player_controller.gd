extends CharacterBody3D
class_name PlayerController
## Movement, crouch, vault, stamina, footsteps, hotbar 1-4, death.

signal noise_step(position: Vector3, radius: float)
signal died
signal respawned

const WALK_SPEED := 3.2
const RUN_SPEED := 5.2
const RUN_BOOST_SPEED := 6.4
const CROUCH_SPEED := 1.6
const GRAVITY := 9.8
const RUN_NOISE_RADIUS := 8.0
const RUN_NOISE_INTERVAL := 0.35
const WALK_STEP_INTERVAL := 0.48
const SPRINT_STAMINA_COST := 22.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.05
const STAND_HEAD_Y := 1.6
const CROUCH_HEAD_Y := 0.85
const VAULT_MAX_HEIGHT := 1.15
const VAULT_MIN_HEIGHT := 0.35
const VAULT_FORWARD := 1.35
const VAULT_UP := 3.4
const VAULT_STAMINA := 12.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction: InteractionController = $InteractionController
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var input_enabled: bool = true
var look_enabled: bool = true
var crouching: bool = false
var is_hidden: bool = false
var is_dead: bool = false
var _pitch: float = 0.0
var _bob_time: float = 0.0
var _noise_cooldown: float = 0.0
var _step_cooldown: float = 0.0
var _base_camera_y: float = 0.0
var _wall_cooldown: float = 0.0
var _vaulting: bool = false
var _vault_cooldown: float = 0.0
var _phone_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("player")
	_base_camera_y = camera.position.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	SettingsManager.settings_changed.connect(_on_settings_changed)
	GameState.smoke_alarm.connect(_on_smoke_alarm)


func _on_settings_changed() -> void:
	pass


func _on_smoke_alarm(pos: Vector3) -> void:
	AudioManager.play_sfx("alarm", 1.0, -2.0)
	GameState.notification_requested.emit("СИГНАЛИЗАЦИЯ: задымление. Служба соответствия уведомлена.")
	var enemy := get_tree().get_first_node_in_group("enemy")
	if enemy and enemy.has_method("try_activate_safely"):
		if not GameState.get_flag(GameState.FLAG_ENEMY_ACTIVATED):
			if enemy.try_activate_safely():
				GameState.set_flag(GameState.FLAG_ENEMY_ACTIVATED, true)
		elif enemy.has_method("_on_noise"):
			enemy._on_noise(pos, 22.0, "smoke_alarm")


func set_controls_enabled(enabled: bool) -> void:
	input_enabled = enabled
	look_enabled = enabled
	if interaction:
		interaction.set_enabled(enabled)
	if enabled and not is_dead:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if not look_enabled or GameState.gameplay_paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = SettingsManager.mouse_sensitivity
		rotate_y(-event.relative.x * sens * 0.01)
		_pitch = clampf(_pitch - event.relative.y * sens * 0.01, deg_to_rad(-85.0), deg_to_rad(85.0))
		head.rotation.x = _pitch
	# Hotbar: 1 cigarettes, 2 energy, 3 badge, 4 phone
	if event.is_action_pressed("use_slot_1"):
		_use_slot_cigarettes()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_slot_2"):
		_use_slot_energy()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_slot_3"):
		_use_slot_badge()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_slot_4"):
		_use_slot_phone()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("vault"):
		if _try_vault():
			get_viewport().set_input_as_handled()


func _use_slot_cigarettes() -> void:
	if GameState.use_cigarettes(global_position):
		AudioManager.play_sfx("cloth")
	else:
		AudioManager.play_sfx("error")


func _use_slot_energy() -> void:
	if GameState.use_energy_drink():
		AudioManager.play_sfx("confirm")
	else:
		AudioManager.play_sfx("error")


func _use_slot_badge() -> void:
	if GameState.use_badge():
		AudioManager.play_sfx("confirm")
	else:
		AudioManager.play_sfx("error")


func _use_slot_phone() -> void:
	if _phone_cooldown > 0.0:
		GameState.notification_requested.emit("Линия занята…")
		AudioManager.play_sfx("error")
		return
	if GameState.use_phone_distract(global_position):
		_phone_cooldown = 12.0
		AudioManager.play_sfx("creak", 1.0, -4.0)
	else:
		AudioManager.play_sfx("error")


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_vault_cooldown = maxf(0.0, _vault_cooldown - delta)
	_phone_cooldown = maxf(0.0, _phone_cooldown - delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif not _vaulting:
		velocity.y = 0.0

	if _vaulting and is_on_floor() and velocity.y <= 0.05:
		_vaulting = false

	_update_crouch(delta)
	_update_hide_state()

	if not input_enabled or GameState.gameplay_paused:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_reset_bob(delta)
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var want_sprint := Input.is_action_pressed("sprint") and direction != Vector3.ZERO and not crouching and not _vaulting
	var can_sprint := want_sprint and (GameState.stamina > 1.0 or GameState.has_stamina_boost())
	var sprinting := can_sprint
	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
		GameState.regen_stamina(delta, direction == Vector3.ZERO)
	elif sprinting:
		speed = RUN_BOOST_SPEED if GameState.has_stamina_boost() else RUN_SPEED
		GameState.spend_stamina(SPRINT_STAMINA_COST * delta)
	else:
		GameState.regen_stamina(delta, direction == Vector3.ZERO)

	if GameState.anxiety > 70.0:
		speed *= 0.92

	if not _vaulting:
		if direction != Vector3.ZERO:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed)
			velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	_update_bob(delta, direction != Vector3.ZERO and not _vaulting, sprinting)
	_handle_wall_bump(delta)
	_handle_steps(delta, direction != Vector3.ZERO and not _vaulting, sprinting)

	if sprinting:
		_noise_cooldown -= delta
		if _noise_cooldown <= 0.0:
			_noise_cooldown = RUN_NOISE_INTERVAL
			AudioManager.emit_noise(global_position, RUN_NOISE_RADIUS, "player_run")
			noise_step.emit(global_position, RUN_NOISE_RADIUS)

	if Input.is_action_just_pressed("interact"):
		interaction.try_interact()

	if global_position.y < -10.0:
		_respawn_safe()


func _try_vault() -> bool:
	if _vaulting or crouching or not input_enabled or GameState.gameplay_paused:
		return false
	if _vault_cooldown > 0.0 or not is_on_floor():
		return false
	if GameState.stamina < VAULT_STAMINA and not GameState.has_stamina_boost():
		return false
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		return false
	forward = forward.normalized()
	var space := get_world_3d().direct_space_state
	var from_low := global_position + Vector3(0, 0.45, 0)
	var hit_low: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from_low, from_low + forward * 1.1, 1, [get_rid()]))
	if hit_low.is_empty():
		return false
	var obstacle_n: Vector3 = hit_low.normal as Vector3
	if absf(obstacle_n.y) > 0.45:
		return false
	var hit_pos: Vector3 = hit_low.position as Vector3
	var top_probe: Vector3 = hit_pos + forward * 0.15 + Vector3(0, VAULT_MAX_HEIGHT + 0.2, 0)
	var hit_top: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(top_probe, top_probe + Vector3(0, -VAULT_MAX_HEIGHT - 0.3, 0), 1, [get_rid()]))
	if hit_top.is_empty():
		return false
	var top_pos: Vector3 = hit_top.position as Vector3
	var obstacle_h: float = top_pos.y - global_position.y
	if obstacle_h < VAULT_MIN_HEIGHT or obstacle_h > VAULT_MAX_HEIGHT:
		return false
	var land_from: Vector3 = top_pos + forward * 0.55 + Vector3(0, 0.9, 0)
	var blocked: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(land_from, land_from + Vector3(0, -1.4, 0), 1, [get_rid()]))
	if blocked.is_empty():
		return false
	var head_clear: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
		top_pos + Vector3(0, 0.05, 0), top_pos + Vector3(0, 1.1, 0), 1, [get_rid()]
	))
	if not head_clear.is_empty():
		return false

	GameState.spend_stamina(VAULT_STAMINA)
	_vaulting = true
	_vault_cooldown = 0.55
	crouching = false
	velocity = forward * VAULT_FORWARD * 2.4 + Vector3(0, VAULT_UP + obstacle_h * 0.6, 0)
	AudioManager.play_sfx("cloth", 1.1, -4.0)
	AudioManager.emit_noise(global_position, 3.5, "player_vault")
	return true


func _update_crouch(delta: float) -> void:
	var want := Input.is_action_pressed("crouch") and input_enabled and not GameState.gameplay_paused
	if want != crouching:
		AudioManager.play_sfx("cloth", 1.0, -8.0)
	crouching = want
	var shape := collision_shape.shape as CapsuleShape3D
	if shape == null:
		return
	var target_h := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	var target_head := CROUCH_HEAD_Y if crouching else STAND_HEAD_Y
	shape.height = move_toward(shape.height, target_h, delta * 8.0)
	collision_shape.position.y = shape.height * 0.5
	head.position.y = move_toward(head.position.y, target_head, delta * 8.0)


func _update_hide_state() -> void:
	var was := is_hidden
	is_hidden = false
	if crouching:
		for spot in get_tree().get_nodes_in_group("hide_spot"):
			if spot is Area3D and (spot as Area3D).overlaps_body(self):
				is_hidden = true
				break
	if is_hidden and not was:
		GameState.notification_requested.emit("Вы спрятались")


func _handle_wall_bump(delta: float) -> void:
	_wall_cooldown = maxf(0.0, _wall_cooldown - delta)
	if get_slide_collision_count() <= 0:
		return
	var moving := Vector3(velocity.x, 0, velocity.z).length() > 0.4
	if not moving:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_normal().y > 0.5:
			continue
		if _wall_cooldown <= 0.0:
			AudioManager.play_sfx("impact_wall", randf_range(0.9, 1.1), -10.0)
			_wall_cooldown = 0.45
		break


func _handle_steps(delta: float, moving: bool, sprinting: bool) -> void:
	if not moving or not is_on_floor():
		_step_cooldown = 0.0
		return
	_step_cooldown -= delta
	if _step_cooldown > 0.0:
		return
	_step_cooldown = 0.32 if sprinting else (0.55 if crouching else WALK_STEP_INTERVAL)
	AudioManager.play_footstep(sprinting)


func begin_death() -> void:
	if is_dead:
		return
	is_dead = true
	input_enabled = false
	look_enabled = false
	velocity = Vector3.ZERO
	AudioManager.play_sfx("death", 0.85, -1.0)
	died.emit()


func finish_respawn() -> void:
	is_dead = false
	input_enabled = true
	look_enabled = true
	crouching = false
	head.rotation.x = 0.0
	_pitch = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	respawned.emit()


func _update_bob(delta: float, moving: bool, sprinting: bool) -> void:
	if not SettingsManager.camera_bob_enabled or not moving:
		_reset_bob(delta)
		return
	_bob_time += delta * (12.0 if sprinting else 8.0)
	camera.position.y = _base_camera_y + sin(_bob_time) * (0.04 if not crouching else 0.02)


func _reset_bob(delta: float) -> void:
	camera.position.y = move_toward(camera.position.y, _base_camera_y, delta * 2.0)
	_bob_time = 0.0


func _respawn_safe() -> void:
	var spawns := get_tree().get_nodes_in_group("checkpoint")
	for s in spawns:
		if s.has_meta("checkpoint_id") and str(s.get_meta("checkpoint_id")) == GameState.checkpoint_id:
			global_position = s.global_position
			velocity = Vector3.ZERO
			return
	var fallback := get_tree().get_first_node_in_group("player_spawn")
	if fallback:
		global_position = fallback.global_position
		velocity = Vector3.ZERO
