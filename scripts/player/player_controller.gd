extends CharacterBody3D
class_name PlayerController
## Movement, crouch, FPS hands, stamina, footsteps, death pose.

signal noise_step(position: Vector3, radius: float)
signal died
signal respawned

const WALK_SPEED := 3.0
const RUN_SPEED := 5.0
const RUN_BOOST_SPEED := 6.2
const CROUCH_SPEED := 1.6
const GRAVITY := 9.8
const RUN_NOISE_RADIUS := 8.0
const WALK_NOISE_RADIUS := 0.0 ## walk silent per spec
const CROUCH_NOISE_RADIUS := 0.0
const RUN_NOISE_INTERVAL := 0.35
const WALK_STEP_INTERVAL := 0.48
const SPRINT_STAMINA_COST := 22.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.05
const STAND_HEAD_Y := 1.6
const CROUCH_HEAD_Y := 0.85

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction: InteractionController = $InteractionController
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var hands: HandsController = $Head/Camera3D/Hands

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


func _ready() -> void:
	add_to_group("player")
	_base_camera_y = camera.position.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	SettingsManager.settings_changed.connect(_on_settings_changed)
	GameState.smoke_alarm.connect(_on_smoke_alarm)
	if hands == null and has_node("Head/Camera3D/Hands"):
		hands = $Head/Camera3D/Hands


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
	if event.is_action_pressed("use_energy"):
		if GameState.use_energy_drink():
			AudioManager.play_sfx("confirm")
		else:
			AudioManager.play_sfx("error")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_cigarettes"):
		if GameState.use_cigarettes(global_position):
			AudioManager.play_sfx("cloth")
		else:
			AudioManager.play_sfx("error")
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		if hands:
			hands.update_motion(delta, false, false, true)
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	_update_crouch(delta)
	_update_hide_state()

	if not input_enabled or GameState.gameplay_paused:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_reset_bob(delta)
		if hands:
			hands.update_motion(delta, false, false, crouching)
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var want_sprint := Input.is_action_pressed("sprint") and direction != Vector3.ZERO and not crouching
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

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	_update_bob(delta, direction != Vector3.ZERO, sprinting)
	_handle_wall_bump(delta)
	_handle_steps(delta, direction != Vector3.ZERO, sprinting)

	if sprinting:
		_noise_cooldown -= delta
		if _noise_cooldown <= 0.0:
			_noise_cooldown = RUN_NOISE_INTERVAL
			AudioManager.emit_noise(global_position, RUN_NOISE_RADIUS, "player_run")
			noise_step.emit(global_position, RUN_NOISE_RADIUS)

	if Input.is_action_just_pressed("interact"):
		if interaction.try_interact():
			if hands:
				hands.play_pickup()

	if hands:
		hands.update_motion(delta, direction != Vector3.ZERO, sprinting, crouching)

	if global_position.y < -10.0:
		_respawn_safe()


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
	elif was and not is_hidden and crouching:
		pass


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
		if hands:
			hands.set_wall_push(1.0)
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
	if hands:
		hands.start_death()
	died.emit()


func finish_respawn() -> void:
	is_dead = false
	input_enabled = true
	look_enabled = true
	crouching = false
	if hands:
		hands.reset_pose()
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
