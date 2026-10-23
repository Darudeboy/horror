extends CharacterBody3D
class_name PlayerController
## Movement, camera, stamina sprint, consumable hotkeys.

signal noise_step(position: Vector3, radius: float)

const WALK_SPEED := 3.0
const RUN_SPEED := 5.0
const RUN_BOOST_SPEED := 6.2
const GRAVITY := 9.8
const RUN_NOISE_RADIUS := 8.0
const RUN_NOISE_INTERVAL := 0.35
const SPRINT_STAMINA_COST := 22.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction: InteractionController = $InteractionController

var input_enabled: bool = true
var look_enabled: bool = true
var _pitch: float = 0.0
var _bob_time: float = 0.0
var _noise_cooldown: float = 0.0
var _base_camera_y: float = 0.0


func _ready() -> void:
	add_to_group("player")
	_base_camera_y = camera.position.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	SettingsManager.settings_changed.connect(_on_settings_changed)
	GameState.smoke_alarm.connect(_on_smoke_alarm)


func _on_settings_changed() -> void:
	pass


func _on_smoke_alarm(pos: Vector3) -> void:
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
	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not look_enabled or GameState.gameplay_paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = SettingsManager.mouse_sensitivity
		rotate_y(-event.relative.x * sens * 0.01)
		_pitch = clampf(_pitch - event.relative.y * sens * 0.01, deg_to_rad(-85.0), deg_to_rad(85.0))
		head.rotation.x = _pitch
	if event.is_action_pressed("use_energy"):
		GameState.use_energy_drink()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_cigarettes"):
		GameState.use_cigarettes(global_position)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if not input_enabled or GameState.gameplay_paused:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_reset_bob(delta)
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var want_sprint := Input.is_action_pressed("sprint") and direction != Vector3.ZERO
	var can_sprint := want_sprint and (GameState.stamina > 1.0 or GameState.has_stamina_boost())
	var sprinting := can_sprint
	var speed := WALK_SPEED
	if sprinting:
		speed = RUN_BOOST_SPEED if GameState.has_stamina_boost() else RUN_SPEED
		GameState.spend_stamina(SPRINT_STAMINA_COST * delta)
	else:
		GameState.regen_stamina(delta, direction == Vector3.ZERO)

	# High anxiety slightly slows walk
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


func _update_bob(delta: float, moving: bool, sprinting: bool) -> void:
	if not SettingsManager.camera_bob_enabled or not moving:
		_reset_bob(delta)
		return
	_bob_time += delta * (12.0 if sprinting else 8.0)
	camera.position.y = _base_camera_y + sin(_bob_time) * 0.05


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
