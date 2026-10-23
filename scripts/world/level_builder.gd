extends Node3D
## Graybox office floor from primitives (2 m grid). Partition walls with door gaps.

var mat_wall: StandardMaterial3D
var mat_floor: StandardMaterial3D
var mat_floor_tech: StandardMaterial3D
var mat_ceiling: StandardMaterial3D
var mat_accent: StandardMaterial3D
var mat_door: StandardMaterial3D


func build() -> void:
	_make_materials()
	_build_shell()
	_build_partitions()
	_add_furniture()
	_add_lights()
	_add_interactables()
	_add_navigation()
	_add_checkpoints()
	_add_enemy_patrol()
	_add_fall_kill()
	_add_labels()


func _make_materials() -> void:
	mat_wall = _load_mat("res://assets/materials/wall_plaster.tres", Color(0.78, 0.74, 0.68))
	mat_floor = _load_mat("res://assets/materials/floor_carpet.tres", Color(0.12, 0.18, 0.32))
	mat_floor_tech = _load_mat("res://assets/materials/tech_floor_tiles.tres", Color(0.35, 0.36, 0.38))
	mat_ceiling = _load_mat("res://assets/materials/ceiling_plaster.tres", Color(0.85, 0.85, 0.82))
	mat_accent = _load_mat("res://assets/materials/accent_sign.tres", Color(0.45, 0.62, 0.48))
	mat_door = _load_mat("res://assets/materials/door_metal.tres", Color(0.35, 0.4, 0.48))


func _load_mat(path: String, fallback: Color) -> StandardMaterial3D:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is StandardMaterial3D:
			return (res as StandardMaterial3D).duplicate() as StandardMaterial3D
	return _mat(fallback)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


func _build_shell() -> void:
	# One large floor: X -12..24, Z -12..14
	_box(self, Vector3(6, -0.05, 1), Vector3(36, 0.1, 26), mat_floor)
	_box(self, Vector3(6, 3.05, 1), Vector3(36, 0.1, 26), mat_ceiling)
	# Outer walls
	_box(self, Vector3(6, 1.5, -12), Vector3(36, 3, 0.25), mat_wall) # south
	_box(self, Vector3(6, 1.5, 14), Vector3(36, 3, 0.25), mat_wall) # north
	_box(self, Vector3(-12, 1.5, 1), Vector3(0.25, 3, 26), mat_wall) # west
	_box(self, Vector3(24, 1.5, 1), Vector3(0.25, 3, 26), mat_wall) # east
	# Tech floor patch in server
	_box(self, Vector3(11, 0.0, -9), Vector3(6, 0.02, 6), mat_floor_tech)


func _build_partitions() -> void:
	# Horizontal wall Z=4 between open space and corridor, gap at X=-2..0 and X=4..6
	_wall_x_range(-12, -3, 4)
	_wall_x_range(0.5, 3.5, 4)
	_wall_x_range(7, 24, 4)
	# HR enclosure: X=-4 line from Z=4..10, gap none on east of HR for entry from south gap
	_wall_z_range(4, 10, -4)
	_wall_x_range(-12, -4, 10)
	# Accounting west wall X=8, Z=-6..2 with door gap Z=-3..-1
	_wall_z_range(-12, -3.5, 8)
	_wall_z_range(-0.5, 4, 8)
	_wall_x_range(8, 16, -6) # accounting south toward server — gap later
	_wall_x_range(8, 10.5, -6)
	_wall_x_range(13, 16, -6)
	_wall_z_range(-6, 2, 16) # accounting east
	# Server walls
	_wall_z_range(-12, -6, 8)
	_wall_x_range(8, 14, -12)
	_wall_z_range(-12, -6, 14)
	# Vestibule south is corridor north Z=8 partially
	_wall_x_range(-2, 0.5, 8)
	_wall_x_range(3.5, 16, 8)
	_wall_z_range(8, 14, -2)
	_wall_z_range(8, 14, 6)
	# Security room
	_wall_z_range(4, 10, 16) # with gap for door around Z=6
	# reopen: remove solid, use segments
	# Actually rebuild security west with gap
	# Loop / security approach at X=16
	_wall_z_range(4, 5.2, 16)
	_wall_z_range(7.0, 10, 16)
	_wall_x_range(16, 22, 10)
	_wall_z_range(4, 10, 22)
	_wall_x_range(16, 22, 4)


func _wall_x_range(x0: float, x1: float, z: float) -> void:
	var mid := (x0 + x1) * 0.5
	var len := absf(x1 - x0)
	if len < 0.1:
		return
	_box(self, Vector3(mid, 1.5, z), Vector3(len, 3, 0.2), mat_wall)


func _wall_z_range(z0: float, z1: float, x: float) -> void:
	var mid := (z0 + z1) * 0.5
	var len := absf(z1 - z0)
	if len < 0.1:
		return
	_box(self, Vector3(x, 1.5, mid), Vector3(0.2, 3, len), mat_wall)


func _box(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
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


func _add_furniture() -> void:
	_desk(Vector3(-6, 0, -4), true)
	_desk(Vector3(2, 0, -4), false)
	_desk(Vector3(-7, 0, 7), false)
	_desk(Vector3(12, 0, -1), false)
	# Printer niche: textured primitive body (no third-party printer mesh — keep CC0-safe)
	var printer_mat := _load_mat("res://assets/materials/printer_body.tres", Color(0.78, 0.8, 0.82))
	_box(self, Vector3(14.5, 0.5, 0.5), Vector3(1.0, 1.0, 0.8), printer_mat)
	_box(self, Vector3(10, 1.0, -9), Vector3(0.8, 2.0, 1.2), mat_door)
	_box(self, Vector3(12, 1.0, -9), Vector3(0.8, 2.0, 1.2), mat_door)


func _desk(pos: Vector3, with_monitor: bool = false) -> void:
	## Visual: Kenney CC0 desk (+ optional screen). Collision stays a simple box.
	var visual_ok := _spawn_kenney("desk", pos, 1.0)
	if not visual_ok:
		_box(self, pos + Vector3(0, 0.4, 0), Vector3(1.4, 0.08, 0.8), mat_door)
		_box(self, pos + Vector3(-0.55, 0.2, 0), Vector3(0.08, 0.4, 0.7), mat_door)
		_box(self, pos + Vector3(0.55, 0.2, 0), Vector3(0.08, 0.4, 0.7), mat_door)
	# Invisible collision for desk volume (does not replace interactables on top)
	var col_body := StaticBody3D.new()
	col_body.collision_layer = 1
	col_body.position = pos + Vector3(0, 0.4, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 0.75, 0.8)
	col.shape = shape
	col_body.add_child(col)
	add_child(col_body)
	if with_monitor:
		_spawn_kenney("computerScreen", pos + Vector3(0, 0.75, -0.15), 1.0)
		_spawn_kenney("computerKeyboard", pos + Vector3(0, 0.72, 0.15), 1.0)
	_spawn_kenney("chairDesk", pos + Vector3(0, 0, 0.85), 1.0)


func _spawn_kenney(model_name: String, pos: Vector3, scale: float) -> bool:
	var path := "res://assets/models/kenney/%s.glb" % model_name
	if not ResourceLoader.exists(path):
		return false
	var packed: Resource = load(path)
	if packed == null:
		return false
	var node: Node = null
	if packed is PackedScene:
		node = (packed as PackedScene).instantiate()
	else:
		return false
	if node is Node3D:
		(node as Node3D).position = pos
		(node as Node3D).scale = Vector3.ONE * scale
	add_child(node)
	return true


func _add_lights() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.08, 0.09, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.38, 0.42)
	e.ambient_light_energy = 0.4
	env.environment = e
	add_child(env)
	_omni(Vector3(-2, 2.7, -2), 12.0)
	_omni(Vector3(6, 2.7, 6), 10.0)
	_omni(Vector3(-7, 2.7, 7), 7.0)
	var acc := _omni(Vector3(12, 2.7, -2), 8.0)
	acc.add_to_group("accounting_lights")
	var acc2 := _omni(Vector3(14, 2.7, 0.5), 5.0)
	acc2.add_to_group("accounting_lights")
	var emerg := _omni(Vector3(13, 2.2, -5), 6.0)
	emerg.light_color = Color(0.4, 0.9, 0.5)
	emerg.light_energy = 0.0
	emerg.visible = false
	emerg.add_to_group("emergency_lights")
	_omni(Vector3(11, 2.7, -9), 6.0)
	_omni(Vector3(19, 2.7, 7), 6.0)
	_omni(Vector3(2, 2.7, 11), 7.0)


func _omni(pos: Vector3, dist: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.omni_range = dist
	l.light_color = Color(0.85, 0.9, 0.95)
	l.light_energy = 1.0
	l.shadow_enabled = false
	add_child(l)
	return l


func _add_interactables() -> void:
	_spawn_terminal("DeskTerminal", Vector3(-6, 0.85, -3.55), 0)
	_spawn_terminal("HRTerminal", Vector3(-7, 0.85, 7.45), 1)
	_spawn_terminal("AccTerminal", Vector3(12, 0.85, -0.55), 2)
	_spawn_terminal("SecTerminal", Vector3(19, 0.85, 7.45), 3)
	_spawn_document(Vector3(-6.4, 0.85, 6.6), "Заметка HR", "Для доступа в бухгалтерию возьмите пропуск\nна столе отсутствующего коллеги в open space.")
	_spawn_document(Vector3(11.4, 0.85, -0.15), "Инструкция", "Шум оборудования может вызвать проверку.\nПри отключении питания используйте технический щит в серверной.")
	_spawn_badge(Vector3(2, 0.85, -3.55))
	_spawn_printer(Vector3(14.5, 0.0, 0.5))
	_spawn_power(Vector3(9.5, 1.0, -10.5))
	_spawn_phone(Vector3(4, 1.0, 6))
	_spawn_poster(Vector3(1, 1.7, 3.85))
	_spawn_door("accounting", Vector3(8, 0, -2), Vector3(0, 90, 0), true, "accounting_access")
	_spawn_door("security_passage", Vector3(16, 0, 6), Vector3(0, 90, 0), true, "")
	_spawn_turnstile(Vector3(2, 0, 12.5))
	_spawn_elevator(Vector3(4.5, 0, 13))
	_spawn_loop_trigger()
	# Event zone for lights
	var zone := Area3D.new()
	zone.position = Vector3(12, 1, -2)
	zone.add_to_group("event_zone_lights_out")
	var zcol := CollisionShape3D.new()
	var zshape := BoxShape3D.new()
	zshape.size = Vector3(8, 3, 8)
	zcol.shape = zshape
	zone.add_child(zcol)
	add_child(zone)


func _spawn_terminal(n: String, pos: Vector3, kind: int) -> void:
	var t: Node = _make_interactable_body(n, pos, Vector3(0.5, 0.4, 0.4), mat_accent)
	t.set_script(load("res://scripts/interactions/terminal.gd"))
	t.set("kind", kind)
	t.set("terminal_id", n)
	add_child(t)


func _spawn_document(pos: Vector3, title: String, body: String) -> void:
	var d: Node = _make_interactable_body("Document", pos, Vector3(0.3, 0.05, 0.4), mat_ceiling)
	d.set_script(load("res://scripts/interactions/readable_document.gd"))
	d.set("document_title", title)
	d.set("document_body", body)
	add_child(d)


func _spawn_badge(pos: Vector3) -> void:
	var p: Node = _make_interactable_body("Badge", pos, Vector3(0.2, 0.05, 0.12), mat_accent)
	p.set_script(load("res://scripts/interactions/pickup_item.gd"))
	p.set("item_id", "employee_badge")
	p.set("grant_access", "accounting_access")
	p.set("pickup_label", "Взять пропуск")
	add_child(p)


func _spawn_printer(pos: Vector3) -> void:
	var tray: Node = _make_interactable_body("ApplicationTray", pos + Vector3(0.65, 0.7, 0), Vector3(0.25, 0.04, 0.3), mat_ceiling)
	tray.set_script(load("res://scripts/interactions/pickup_item.gd"))
	tray.set("item_id", "printed_application")
	tray.set("pickup_label", "Взять заявление")
	tray.visible = false
	var pr: Node = _make_interactable_body("Printer", pos + Vector3(0, 0.5, 0), Vector3(0.7, 0.9, 0.6), mat_door)
	pr.set_script(load("res://scripts/interactions/printer.gd"))
	pr.set("tray_item_path", NodePath("../ApplicationTray"))
	add_child(tray)
	add_child(pr)


func _spawn_power(pos: Vector3) -> void:
	var p: Node = _make_interactable_body("PowerPanel", pos, Vector3(0.4, 1.2, 0.2), mat_accent)
	p.set_script(load("res://scripts/interactions/power_panel.gd"))
	add_child(p)


func _spawn_phone(pos: Vector3) -> void:
	var p: Node = _make_interactable_body("Phone", pos, Vector3(0.2, 0.2, 0.25), mat_door)
	p.set_script(load("res://scripts/interactions/phone.gd"))
	p.visible = false
	add_child(p)


func _spawn_poster(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Poster"
	root.position = pos
	var label := Label3D.new()
	label.name = "Label3D"
	label.text = "Мы ценим ваше присутствие"
	label.font_size = 42
	label.modulate = Color(0.9, 0.9, 0.85)
	root.add_child(label)
	root.set_script(load("res://scripts/interactions/poster.gd"))
	add_child(root)


func _spawn_door(door_id: String, pos: Vector3, rot_deg: Vector3, locked: bool, access: String = "") -> void:
	var door := Node3D.new()
	door.name = "Door_%s" % door_id
	door.position = pos
	door.rotation_degrees = rot_deg
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	door.add_child(pivot)
	var body := StaticBody3D.new()
	body.name = "DoorBody"
	body.collision_layer = 5
	pivot.add_child(body)
	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	var box := BoxMesh.new()
	box.size = Vector3(1.1, 2.2, 0.12)
	mesh.mesh = box
	mesh.material_override = mat_door
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 2.2, 0.12)
	col.shape = shape
	body.add_child(col)
	door.set_script(load("res://scripts/interactions/door.gd"))
	add_child(door)
	door.set("door_id", door_id)
	door.set("locked", locked)
	door.set("required_access", access)
	door.set("open_offset", Vector3(1.15, 0, 0))
	if door_id == "security_passage":
		door.set("required_flag", "security_door_open")
		door.set("locked_message", "Проход закрыт. Требуется согласование HR")
		door.add_to_group("security_door_visual")
		var zone := Area3D.new()
		zone.position = pos
		zone.add_to_group("event_zone_security_door")
		var zcol := CollisionShape3D.new()
		var zshape := BoxShape3D.new()
		zshape.size = Vector3(3, 3, 3)
		zcol.shape = zshape
		zone.add_child(zcol)
		add_child(zone)


func _spawn_turnstile(pos: Vector3) -> void:
	var t := Node3D.new()
	t.name = "Turnstile"
	t.position = pos
	var ibody := StaticBody3D.new()
	ibody.collision_layer = 4
	t.add_child(ibody)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 1.2, 0.4)
	col.shape = shape
	col.position = Vector3(0, 0.6, 0)
	ibody.add_child(col)
	var frame_mesh := MeshInstance3D.new()
	var fbox := BoxMesh.new()
	fbox.size = Vector3(1.6, 1.2, 0.4)
	frame_mesh.mesh = fbox
	frame_mesh.material_override = mat_accent
	frame_mesh.position = Vector3(0, 0.6, 0)
	ibody.add_child(frame_mesh)
	var blocker := StaticBody3D.new()
	blocker.name = "Blocker"
	blocker.collision_layer = 1
	t.add_child(blocker)
	var bcol := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(1.2, 1.5, 0.3)
	bcol.shape = bshape
	bcol.position = Vector3(0, 0.75, 0)
	blocker.add_child(bcol)
	var bmesh := MeshInstance3D.new()
	var bbox := BoxMesh.new()
	bbox.size = Vector3(1.2, 1.5, 0.3)
	bmesh.mesh = bbox
	bmesh.material_override = mat_door
	bmesh.position = Vector3(0, 0.75, 0)
	blocker.add_child(bmesh)
	t.set_script(load("res://scripts/interactions/turnstile.gd"))
	add_child(t)


func _spawn_elevator(pos: Vector3) -> void:
	var e: Node = _make_interactable_body("Elevator", pos + Vector3(0, 1.0, 0), Vector3(1.5, 2.2, 0.2), mat_door)
	e.set_script(load("res://scripts/interactions/elevator.gd"))
	add_child(e)
	_box(self, pos + Vector3(0, 1.1, -0.8), Vector3(1.6, 2.2, 1.4), mat_wall)


func _spawn_loop_trigger() -> void:
	var area := Area3D.new()
	area.name = "LoopTrigger"
	area.position = Vector3(17.5, 1, 5)
	area.monitoring = true
	area.collision_layer = 0
	area.collision_mask = 2
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 2, 1.8)
	col.shape = shape
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(_on_loop_enter)
	var hint := Label3D.new()
	hint.name = "LoopExitHint"
	hint.text = "ВЫХОД →"
	hint.position = Vector3(19.2, 1.8, 5.5)
	hint.font_size = 64
	hint.modulate = Color(0.45, 0.75, 0.5)
	hint.visible = false
	hint.add_to_group("loop_exit_hint")
	add_child(hint)
	var ret := Marker3D.new()
	ret.position = Vector3(15.2, 0.1, 5)
	ret.add_to_group("loop_return")
	add_child(ret)
	var correct := Marker3D.new()
	correct.position = Vector3(19, 0.1, 7)
	correct.add_to_group("loop_correct")
	add_child(correct)


func _on_loop_enter(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if not GameState.get_flag("security_door_open"):
		return
	if GameState.get_flag("loop_corridor_completed"):
		return
	if GameState.loop_count >= 2:
		GameState.set_flag("loop_corridor_completed", true)
		var hint := get_tree().get_first_node_in_group("loop_exit_hint")
		if hint:
			hint.visible = true
		var correct := get_tree().get_first_node_in_group("loop_correct")
		if correct:
			body.global_position = (correct as Node3D).global_position
		GameState.notification_requested.emit("Указатель выхода активирован")
		return
	GameState.loop_count += 1
	var ret := get_tree().get_first_node_in_group("loop_return")
	if ret:
		body.global_position = (ret as Node3D).global_position
	GameState.notification_requested.emit("Кажется, вы здесь уже были... (%d/2)" % GameState.loop_count)


func _make_interactable_body(n: String, pos: Vector3, size: Vector3, mat: Material) -> Node3D:
	## Build offline, then caller attaches script and add_child so _ready runs with script.
	var root := Node3D.new()
	root.name = n
	root.position = pos
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	root.add_child(body)
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
	return root


func _add_navigation() -> void:
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	add_child(region)
	var mesh := NavigationMesh.new()
	mesh.cell_size = 0.25
	mesh.agent_radius = 0.4
	mesh.agent_height = 1.8
	mesh.vertices = PackedVector3Array([
		Vector3(-11.5, 0.05, -11.5), Vector3(23.5, 0.05, -11.5),
		Vector3(23.5, 0.05, 13.5), Vector3(-11.5, 0.05, 13.5)
	])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = mesh


func _add_checkpoints() -> void:
	_marker("spawn", Vector3(-6, 0.1, -3), true)
	_marker("after_exit_check", Vector3(2, 0.1, 11), false)
	_marker("after_power", Vector3(11, 0.1, -9), false)
	_marker("after_hr", Vector3(-7, 0.1, 6), false)
	_marker("after_accounting", Vector3(12, 0.1, -2), false)
	_marker("after_security", Vector3(19, 0.1, 6), false)


func _marker(id: String, pos: Vector3, is_spawn: bool) -> void:
	var m := Marker3D.new()
	m.name = "Checkpoint_%s" % id
	m.position = pos
	m.set_meta("checkpoint_id", id)
	m.add_to_group("checkpoint")
	if is_spawn:
		m.add_to_group("player_spawn")
	add_child(m)


func _add_enemy_patrol() -> void:
	var pts := Node3D.new()
	pts.name = "PatrolPoints"
	add_child(pts)
	for p in [Vector3(6, 0.1, 6), Vector3(-2, 0.1, 6), Vector3(12, 0.1, 2), Vector3(10, 0.1, -8), Vector3(2, 0.1, 10)]:
		var m := Marker3D.new()
		m.position = p
		pts.add_child(m)


func _add_fall_kill() -> void:
	var area := Area3D.new()
	area.position = Vector3(6, -6, 1)
	area.collision_mask = 2
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80, 2, 80)
	col.shape = shape
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(func(body: Node):
		if body.is_in_group("player"):
			var spawns := get_tree().get_nodes_in_group("checkpoint")
			for s in spawns:
				if s.has_meta("checkpoint_id") and str(s.get_meta("checkpoint_id")) == GameState.checkpoint_id:
					body.global_position = s.global_position
					return
	)


func _add_labels() -> void:
	_sign(Vector3(-7, 2.2, 4.3), "HR")
	_sign(Vector3(12, 2.2, 2.0), "БУХГАЛТЕРИЯ")
	_sign(Vector3(11, 2.2, -6.3), "СЕРВЕРНАЯ")
	_sign(Vector3(19, 2.2, 4.3), "БЕЗОПАСНОСТЬ")
	_sign(Vector3(2, 2.2, 8.3), "ВЫХОД")


func _sign(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = 64
	l.modulate = Color(0.55, 0.75, 0.58)
	add_child(l)
