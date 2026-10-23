extends Node3D
class_name ElevatorBank
## Shared elevator: shaft doors, call button, arrows, cabin light, floor travel.

const CABIN_SIZE := Vector3(1.9, 2.5, 1.8)
const DOOR_W := 0.92
const DOOR_H := 2.2
const DOOR_T := 0.06

var mat_metal: StandardMaterial3D
var mat_door: StandardMaterial3D
var mat_glow: StandardMaterial3D
var mat_arrow_off: StandardMaterial3D
var mat_arrow_on: StandardMaterial3D

var _busy: bool = false
var _doors: Dictionary = {} ## floor_id -> {left, right, light_up, light_down, cabin_light, button}
var _cabin_root: Node3D
var _cabin_light: OmniLight3D
var _player_inside: bool = false


func setup(metal: StandardMaterial3D, door_mat: StandardMaterial3D) -> void:
	add_to_group("elevator_bank")
	mat_metal = metal.duplicate() if metal else _solid(Color(0.18, 0.2, 0.23))
	mat_metal.metallic = 0.85
	mat_metal.roughness = 0.32
	mat_door = door_mat.duplicate() if door_mat else _solid(Color(0.12, 0.13, 0.15))
	mat_door.metallic = 0.9
	mat_door.roughness = 0.28
	# Red call LED like the reference
	mat_glow = _solid(Color(0.85, 0.12, 0.1))
	mat_glow.emission_enabled = true
	mat_glow.emission = Color(1.0, 0.15, 0.08)
	mat_glow.emission_energy_multiplier = 4.5
	mat_arrow_off = _solid(Color(0.15, 0.18, 0.15))
	mat_arrow_on = _solid(Color(0.3, 0.95, 0.35))
	mat_arrow_on.emission_enabled = true
	mat_arrow_on.emission = Color(0.2, 1.0, 0.3)
	mat_arrow_on.emission_energy_multiplier = 3.0
	_cabin_root = Node3D.new()
	_cabin_root.name = "MovingCabin"
	add_child(_cabin_root)
	_build_cabin_interior(_cabin_root)
	_cabin_root.visible = false


func _solid(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.55
	m.metallic = 0.35
	return m


func register_landing(floor_id: int, parent: Node3D, pos: Vector3) -> void:
	## pos = threshold in front of shaft, doors open toward +Z (corridor).
	var root := Node3D.new()
	root.name = "ElevatorLanding_%d" % floor_id
	root.position = pos
	parent.add_child(root)

	# Hollow shaft / cabin (open toward +Z / corridor)
	var cz := -CABIN_SIZE.z * 0.5 - 0.05
	var ch := CABIN_SIZE.y
	var cw := CABIN_SIZE.x
	var cd := CABIN_SIZE.z
	_box(root, Vector3(0, 0.05, cz), Vector3(cw, 0.1, cd), mat_metal) # floor
	_box(root, Vector3(0, ch, cz), Vector3(cw, 0.1, cd), mat_metal) # ceiling
	_box(root, Vector3(-cw * 0.5, ch * 0.5, cz), Vector3(0.1, ch, cd), mat_metal) # left
	_box(root, Vector3(cw * 0.5, ch * 0.5, cz), Vector3(0.1, ch, cd), mat_metal) # right
	_box(root, Vector3(0, ch * 0.5, cz - cd * 0.5), Vector3(cw, ch, 0.1), mat_metal) # back
	# Recessed dark metal frame (screenshot look)
	_box(root, Vector3(-(DOOR_W + 0.22), 1.2, 0.0), Vector3(0.28, 2.55, 0.35), mat_metal)
	_box(root, Vector3(DOOR_W + 0.22, 1.2, 0.0), Vector3(0.28, 2.55, 0.35), mat_metal)
	_box(root, Vector3(0, 2.45, 0.0), Vector3(DOOR_W * 2.15 + 0.55, 0.28, 0.35), mat_metal)
	_box(root, Vector3(0, 0.06, 0.0), Vector3(DOOR_W * 2.15 + 0.55, 0.14, 0.35), mat_metal)
	# Inner reveal
	_box(root, Vector3(0, 1.2, -0.12), Vector3(DOOR_W * 2.05, 2.45, 0.08), mat_metal)

	# Sliding brushed-metal doors
	var door_l := _mesh_box(root, Vector3(-DOOR_W * 0.5, DOOR_H * 0.5 + 0.05, 0.1), Vector3(DOOR_W, DOOR_H, DOOR_T), mat_door)
	door_l.name = "DoorL"
	var door_r := _mesh_box(root, Vector3(DOOR_W * 0.5, DOOR_H * 0.5 + 0.05, 0.1), Vector3(DOOR_W, DOOR_H, DOOR_T), mat_door)
	door_r.name = "DoorR"
	# Door seam / handle strips
	_mesh_box(root, Vector3(-0.02, 1.15, 0.14), Vector3(0.03, 0.35, 0.02), mat_metal)
	_mesh_box(root, Vector3(0.02, 1.15, 0.14), Vector3(0.03, 0.35, 0.02), mat_metal)

	# Arrow indicators above door
	var arrow_up := _mesh_box(root, Vector3(-0.25, 2.55, 0.12), Vector3(0.28, 0.22, 0.05), mat_arrow_off)
	arrow_up.name = "ArrowUp"
	var arrow_dn := _mesh_box(root, Vector3(0.25, 2.55, 0.12), Vector3(0.28, 0.22, 0.05), mat_arrow_off)
	arrow_dn.name = "ArrowDown"
	var lbl_up := Label3D.new()
	lbl_up.text = "▲"
	lbl_up.font_size = 48
	lbl_up.position = Vector3(-0.25, 2.55, 0.16)
	lbl_up.modulate = Color(0.4, 0.9, 0.4)
	root.add_child(lbl_up)
	var lbl_dn := Label3D.new()
	lbl_dn.text = "▼"
	lbl_dn.font_size = 48
	lbl_dn.position = Vector3(0.25, 2.55, 0.16)
	lbl_dn.modulate = Color(0.4, 0.9, 0.4)
	root.add_child(lbl_dn)

	# Cabin interior light (per landing visual when doors open)
	var clight := OmniLight3D.new()
	clight.name = "CabinLight"
	clight.position = Vector3(0, 2.1, -0.9)
	clight.omni_range = 4.0
	clight.light_color = Color(1.0, 0.95, 0.8)
	clight.light_energy = 0.85
	clight.shadow_enabled = false
	root.add_child(clight)

	# Floor display
	var floor_lbl := Label3D.new()
	floor_lbl.name = "FloorDisplay"
	floor_lbl.text = str(floor_id)
	floor_lbl.font_size = 64
	floor_lbl.position = Vector3(0, 2.55, 0.16)
	floor_lbl.modulate = Color(0.9, 0.95, 0.5)
	root.add_child(floor_lbl)

	# Call button panel to the left of doors (reference shot)
	var panel := _make_button(root, Vector3(-1.35, 1.2, 0.18), floor_id)
	root.add_child(panel)

	# Landing marker (where player exits)
	var land := Marker3D.new()
	land.name = "LandingPad"
	land.position = Vector3(0, 0.1, 0.9)
	land.set_meta("floor", floor_id)
	land.add_to_group("elevator_landing")
	root.add_child(land)

	# Interior stand point
	var inside := Marker3D.new()
	inside.name = "CabinStand"
	inside.position = Vector3(0, 0.1, -0.85)
	inside.set_meta("floor", floor_id)
	inside.add_to_group("elevator_cabin_stand")
	root.add_child(inside)

	# Physical door blocker when closed
	var blocker := StaticBody3D.new()
	blocker.name = "DoorBlocker"
	blocker.collision_layer = 1
	blocker.position = Vector3(0, DOOR_H * 0.5 + 0.05, 0.08)
	var bcol := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(DOOR_W * 2.0, DOOR_H, 0.12)
	bcol.shape = bshape
	blocker.add_child(bcol)
	root.add_child(blocker)

	_doors[floor_id] = {
		"root": root,
		"left": door_l,
		"right": door_r,
		"arrow_up": arrow_up,
		"arrow_down": arrow_dn,
		"cabin_light": clight,
		"blocker": blocker,
		"pos": pos,
	}
	# Start with doors closed
	_set_doors_open(floor_id, false, 0.0)


func _make_button(parent: Node3D, local_pos: Vector3, floor_id: int) -> Node3D:
	var btn := Node3D.new()
	btn.name = "CallButton"
	btn.position = local_pos
	# Visual plate
	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.35, 0.06)
	plate.mesh = box
	plate.material_override = mat_metal
	btn.add_child(plate)
	var led := MeshInstance3D.new()
	led.name = "Led"
	var led_mesh := BoxMesh.new()
	led_mesh.size = Vector3(0.08, 0.08, 0.04)
	led.mesh = led_mesh
	led.position = Vector3(0, 0.08, 0.04)
	led.material_override = mat_glow
	btn.add_child(led)
	var body := StaticBody3D.new()
	body.collision_layer = 4
	btn.add_child(body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.28, 0.4, 0.15)
	col.shape = shape
	body.add_child(col)
	var hint := Label3D.new()
	hint.text = "▲▼"
	hint.font_size = 28
	hint.position = Vector3(0, -0.05, 0.05)
	btn.add_child(hint)
	btn.set_meta("floor_id", floor_id)
	btn.set_meta("elevator_bank", self)
	btn.set_script(load("res://scripts/interactions/elevator_button.gd"))
	return btn


func _build_cabin_interior(cabin: Node3D) -> void:
	_cabin_light = OmniLight3D.new()
	_cabin_light.position = Vector3(0, 2.2, 0)
	_cabin_light.omni_range = 3.5
	_cabin_light.light_color = Color(1.0, 0.96, 0.85)
	_cabin_light.light_energy = 1.1
	cabin.add_child(_cabin_light)
	var rail := _mesh_box(cabin, Vector3(0.85, 1.0, 0), Vector3(0.06, 0.08, 1.4), mat_door)
	rail.name = "Handrail"


func call_elevator(from_floor: int, player: Node) -> void:
	if _busy:
		GameState.notification_requested.emit("Лифт занят")
		return
	if not GameState.has_item(GameState.ITEM_EMPLOYEE_BADGE):
		GameState.notification_requested.emit("Приложите пропуск к считывателю")
		AudioManager.play_sfx("error")
		return
	if GameState.get_flag(GameState.FLAG_GAME_FINISHED):
		return
	var dest := 2 if from_floor == 1 else 1
	# If player is already on this floor landing, travel to other floor
	_run_trip(from_floor, dest, player)


func _run_trip(from_floor: int, dest_floor: int, player: Node) -> void:
	_busy = true
	var p := player as Node3D
	if p == null:
		_busy = false
		return
	var from_data: Dictionary = _doors.get(from_floor, {})
	var dest_data: Dictionary = _doors.get(dest_floor, {})
	if from_data.is_empty() or dest_data.is_empty():
		GameState.notification_requested.emit("Лифт неисправен")
		_busy = false
		return

	# Light arrows
	_set_arrow(from_floor, dest_floor > from_floor, true)
	_set_arrow(dest_floor, dest_floor > from_floor, true)
	AudioManager.play_sfx("click")
	GameState.notification_requested.emit("Лифт вызван…")

	# Open doors on current floor
	await _animate_doors(from_floor, true)
	AudioManager.play_sfx("door_open", 0.95, -3.0)

	# Pull player into cabin if nearby
	var stand: Node3D = (from_data["root"] as Node3D).get_node_or_null("CabinStand") as Node3D
	if stand and p.global_position.distance_to((from_data["root"] as Node3D).global_position) < 4.5:
		p.global_position = stand.global_position
		if "velocity" in p:
			p.velocity = Vector3.ZERO
		_player_inside = true
	else:
		# Still allow remote call: wait then move when they enter — for simplicity teleport if close enough after open
		await get_tree().create_timer(0.8).timeout
		if stand and p.global_position.distance_to((from_data["root"] as Node3D).global_position) < 3.8:
			p.global_position = stand.global_position
			_player_inside = true

	if not _player_inside:
		GameState.notification_requested.emit("Войдите в кабину лифта")
		# Leave doors open briefly then close
		await get_tree().create_timer(2.5).timeout
		if stand and p.global_position.distance_to(stand.global_position) < 1.4:
			_player_inside = true
			p.global_position = stand.global_position
		if not _player_inside:
			await _animate_doors(from_floor, false)
			_set_arrow(from_floor, true, false)
			_set_arrow(dest_floor, true, false)
			_busy = false
			return

	# Close doors
	await _animate_doors(from_floor, false)
	AudioManager.play_sfx("door_close", 0.9, -3.0)

	# Travel: dim cabin light pulse, ding
	var cl: OmniLight3D = from_data["cabin_light"]
	var tw := create_tween()
	tw.tween_property(cl, "light_energy", 0.15, 0.4)
	tw.tween_property(cl, "light_energy", 1.0, 0.35)
	tw.tween_property(cl, "light_energy", 0.2, 0.4)
	tw.tween_property(cl, "light_energy", 0.9, 0.3)
	AudioManager.play_sfx("creak", 0.7, -6.0)
	await get_tree().create_timer(1.6).timeout

	# Arrive: move player to dest cabin
	GameState.current_floor = dest_floor
	var dest_stand: Node3D = (dest_data["root"] as Node3D).get_node_or_null("CabinStand") as Node3D
	if dest_stand:
		p.global_position = dest_stand.global_position
		if "velocity" in p:
			p.velocity = Vector3.ZERO
	# Sync enemy floor
	var enemy := get_tree().get_first_node_in_group("enemy")
	if enemy and GameState.get_flag(GameState.FLAG_ENEMY_ACTIVATED):
		var dest_root: Node3D = dest_data["root"] as Node3D
		if enemy.has_method("set_floor_y"):
			enemy.set_floor_y(dest_root.global_position.y + 0.1)
		if enemy is Node3D:
			(enemy as Node3D).global_position = dest_root.global_position + Vector3(3.5, 0.1, 2.0)

	AudioManager.play_sfx("confirm", 1.0, -4.0)
	GameState.notification_requested.emit("Этаж %d" % dest_floor)
	await _animate_doors(dest_floor, true)
	AudioManager.play_sfx("door_open", 1.0, -3.0)

	# Exit nudge
	var pad: Node3D = (dest_data["root"] as Node3D).get_node_or_null("LandingPad") as Node3D
	await get_tree().create_timer(0.35).timeout
	if pad and _player_inside:
		p.global_position = pad.global_position
	_player_inside = false

	await get_tree().create_timer(1.2).timeout
	await _animate_doors(dest_floor, false)
	_set_arrow(from_floor, true, false)
	_set_arrow(dest_floor, true, false)
	_busy = false


func _set_arrow(floor_id: int, going_up: bool, on: bool) -> void:
	var data: Dictionary = _doors.get(floor_id, {})
	if data.is_empty():
		return
	var up: MeshInstance3D = data["arrow_up"]
	var dn: MeshInstance3D = data["arrow_down"]
	up.material_override = mat_arrow_on if (on and going_up) else mat_arrow_off
	dn.material_override = mat_arrow_on if (on and not going_up) else mat_arrow_off


func _set_doors_open(floor_id: int, open: bool, _t: float) -> void:
	var data: Dictionary = _doors.get(floor_id, {})
	if data.is_empty():
		return
	var left: MeshInstance3D = data["left"]
	var right: MeshInstance3D = data["right"]
	if open:
		left.position.x = -DOOR_W * 0.5 - DOOR_W * 0.95
		right.position.x = DOOR_W * 0.5 + DOOR_W * 0.95
	else:
		left.position.x = -DOOR_W * 0.5
		right.position.x = DOOR_W * 0.5
	var blocker: StaticBody3D = data.get("blocker")
	if blocker:
		blocker.collision_layer = 0 if open else 1


func _animate_doors(floor_id: int, open: bool) -> void:
	var data: Dictionary = _doors.get(floor_id, {})
	if data.is_empty():
		return
	var left: MeshInstance3D = data["left"]
	var right: MeshInstance3D = data["right"]
	var blocker: StaticBody3D = data.get("blocker")
	if open and blocker:
		blocker.collision_layer = 0
	var lx := -DOOR_W * 0.5 - DOOR_W * 0.95 if open else -DOOR_W * 0.5
	var rx := DOOR_W * 0.5 + DOOR_W * 0.95 if open else DOOR_W * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(left, "position:x", lx, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(right, "position:x", rx, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	if not open and blocker:
		blocker.collision_layer = 1


func _box(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	parent.add_child(body)
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body


func _mesh_box(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
