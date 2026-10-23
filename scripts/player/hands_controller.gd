extends Node3D
class_name HandsController
## Simple FPS hands under camera: walk/run bob, wall push, pickup reach.

@onready var left_hand: Node3D = $LeftHand
@onready var right_hand: Node3D = $RightHand

var _bob_t: float = 0.0
var _wall_push: float = 0.0
var _pickup_t: float = 0.0
var _base_l: Vector3
var _base_r: Vector3
var _dying: bool = false
var _death_t: float = 0.0


func _ready() -> void:
	_base_l = left_hand.position
	_base_r = right_hand.position


func play_pickup() -> void:
	_pickup_t = 0.35
	AudioManager.play_sfx("pickup", 1.0, -2.0)


func set_wall_push(amount: float) -> void:
	_wall_push = clampf(amount, 0.0, 1.0)


func start_death() -> void:
	_dying = true
	_death_t = 0.0


func reset_pose() -> void:
	_dying = false
	_death_t = 0.0
	_pickup_t = 0.0
	_wall_push = 0.0
	left_hand.position = _base_l
	right_hand.position = _base_r
	left_hand.rotation = Vector3.ZERO
	right_hand.rotation = Vector3.ZERO


func update_motion(delta: float, moving: bool, sprinting: bool, crouching: bool) -> void:
	if _dying:
		_death_t += delta
		var k := clampf(_death_t / 0.7, 0.0, 1.0)
		left_hand.position = _base_l.lerp(_base_l + Vector3(-0.1, -0.35, 0.2), k)
		right_hand.position = _base_r.lerp(_base_r + Vector3(0.1, -0.4, 0.15), k)
		left_hand.rotation.z = lerp_angle(0.0, 0.8, k)
		right_hand.rotation.z = lerp_angle(0.0, -1.1, k)
		return

	if _pickup_t > 0.0:
		_pickup_t -= delta
		var u := 1.0 - clampf(_pickup_t / 0.35, 0.0, 1.0)
		var reach := sin(u * PI)
		right_hand.position = _base_r + Vector3(0.0, -0.05, -0.25 * reach)
		left_hand.position = _base_l
		return

	var speed_mul := 14.0 if sprinting else (9.0 if moving else 0.0)
	if crouching:
		speed_mul *= 0.7
	if moving:
		_bob_t += delta * speed_mul
	else:
		_bob_t = move_toward(_bob_t, 0.0, delta * 8.0)

	var amp := 0.035 if sprinting else 0.02
	if crouching:
		amp *= 0.6
	var bob_y := sin(_bob_t) * amp
	var bob_z := cos(_bob_t * 0.5) * amp * 0.5
	var push := Vector3(0, 0, 0.08 * _wall_push)
	left_hand.position = _base_l + Vector3(0, bob_y, bob_z) + push
	right_hand.position = _base_r + Vector3(0, -bob_y, -bob_z) + push
	_wall_push = move_toward(_wall_push, 0.0, delta * 3.0)
