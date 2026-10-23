extends Node3D
## Expanded graybox office floor (2 m grid) with CC0 props and fluorescent grid.

const PROP_SCALE := 2.8 ## Kenney furniture is small vs 1.8 m player

var mat_wall: StandardMaterial3D
var mat_floor: StandardMaterial3D
var mat_floor_tech: StandardMaterial3D
var mat_ceiling: StandardMaterial3D
var mat_accent: StandardMaterial3D
var mat_door: StandardMaterial3D
var mat_fixture: StandardMaterial3D


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
	mat_fixture = _mat(Color(0.98, 1.0, 0.94))
	mat_fixture.emission_enabled = true
	mat_fixture.emission = Color(0.95, 1.0, 0.88)
	mat_fixture.emission_energy_multiplier = 2.4


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
	# Expanded floor: X -16..30, Z -16..18
	_box(self, Vector3(7, -0.05, 1), Vector3(46, 0.1, 34), mat_floor)
	_box(self, Vector3(7, 3.05, 1), Vector3(46, 0.1, 34), mat_ceiling)
	_box(self, Vector3(7, 1.5, -16), Vector3(46, 3, 0.25), mat_wall)
	_box(self, Vector3(7, 1.5, 18), Vector3(46, 3, 0.25), mat_wall)
	_box(self, Vector3(-16, 1.5, 1), Vector3(0.25, 3, 34), mat_wall)
	_box(self, Vector3(30, 1.5, 1), Vector3(0.25, 3, 34), mat_wall)
	_box(self, Vector3(11, 0.0, -9), Vector3(6, 0.02, 6), mat_floor_tech)
	_box(self, Vector3(-12, 0.0, -10), Vector3(6, 0.02, 6), mat_floor_tech) # storage linoleum patch


func _build_partitions() -> void:
	# Main corridor wall Z=4
	_wall_x_range(-16, -3, 4)
	_wall_x_range(0.5, 3.5, 4)
	_wall_x_range(7, 30, 4)
	# HR
	_wall_z_range(4, 10, -4)
	_wall_x_range(-12, -4, 10)
	# Accounting
	_wall_z_range(-12, -3.5, 8)
	_wall_z_range(-0.5, 4, 8)
	_wall_x_range(8, 10.5, -6)
	_wall_x_range(13, 16, -6)
	_wall_z_range(-6, 2, 16)
	# Server
	_wall_z_range(-12, -6, 8)
	_wall_x_range(8, 14, -12)
	_wall_z_range(-12, -6, 14)
	# Vestibule
	_wall_x_range(-2, 0.5, 8)
	_wall_x_range(3.5, 16, 8)
	_wall_z_range(8, 14, -2)
	_wall_z_range(8, 14, 6)
	# Security / loop
	_wall_z_range(4, 5.2, 16)
	_wall_z_range(7.0, 10, 16)
	_wall_x_range(16, 22, 10)
	_wall_z_range(4, 10, 22)
	_wall_x_range(16, 22, 4)
	# Kitchen west wing: X=-16..-10, Z=-4..4 — wall at X=-10 with gap
	_wall_z_range(-4, -0.8, -10)
	_wall_z_range(0.8, 4, -10)
	_wall_x_range(-16, -10, -4)
	# Meeting room: X=-16..-10, Z=4..12
	_wall_z_range(4, 12, -10)
	_wall_x_range(-16, -10, 12)
	# Archive east: X=22..30, Z=-8..2
	_wall_z_range(-8, 2, 22)
	_wall_x_range(22, 30, -8)
	_wall_x_range(22, 26.5, 2)
	_wall_x_range(28, 30, 2)
	# Storage south: X=-4..6, Z=-16..-10
	_wall_x_range(-4, 1.5, -10)
	_wall_x_range(3.5, 6, -10)
	_wall_z_range(-16, -10, -4)
	_wall_z_range(-16, -10, 6)
	# Break / copy annex near accounting: X=16..22, Z=-2..4
	_wall_z_range(-2, 1.2, 22)
	_wall_x_range(16, 22, -2)


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
	_desk(Vector3(-2, 0, -6), false)
	_desk(Vector3(-7, 0, 7), false)
	_desk(Vector3(12, 0, -1), false)
	_desk(Vector3(-13, 0, 0), false) # kitchen table-ish
	_desk(Vector3(-13, 0, 8), false) # meeting
	_desk(Vector3(26, 0, -4), false) # archive
	_desk(Vector3(0, 0, -13), false) # storage
	_box(self, Vector3(10, 1.0, -9), Vector3(0.8, 2.0, 1.2), mat_door)
	_box(self, Vector3(12, 1.0, -9), Vector3(0.8, 2.0, 1.2), mat_door)
	_box(self, Vector3(25, 1.0, -6), Vector3(1.2, 2.0, 0.6), mat_door) # archive shelves
	_box(self, Vector3(27, 1.0, -6), Vector3(1.2, 2.0, 0.6), mat_door)


func _desk(pos: Vector3, with_monitor: bool = false) -> void:
	var visual_ok := _spawn_model("res://assets/models/kenney/desk.glb", pos, PROP_SCALE)
	if not visual_ok:
		_box(self, pos + Vector3(0, 0.4, 0), Vector3(1.6, 0.08, 0.9), mat_door)
	var col_body := StaticBody3D.new()
	col_body.collision_layer = 1
	col_body.position = pos + Vector3(0, 0.45, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 0.9, 1.0)
	col.shape = shape
	col_body.add_child(col)
	add_child(col_body)
	if with_monitor:
		_spawn_model("res://assets/models/kenney/computerScreen.glb", pos + Vector3(0, 0.95, -0.2), PROP_SCALE)
		_spawn_model("res://assets/models/kenney/computerKeyboard.glb", pos + Vector3(0, 0.92, 0.25), PROP_SCALE)
	_spawn_model("res://assets/models/kenney/chairDesk.glb", pos + Vector3(0, 0, 1.1), PROP_SCALE)
	_add_hide_spot(pos + Vector3(0, 0.35, 0.15), Vector3(1.6, 0.85, 1.2))


func _add_hide_spot(pos: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.name = "HideSpot"
	area.position = pos
	area.monitoring = true
	area.monitorable = true
	area.collision_layer = 0
	area.collision_mask = 2
	area.add_to_group("hide_spot")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)
	add_child(area)


func _spawn_model(path: String, pos: Vector3, scale: float, rot_y_deg: float = 0.0) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var packed: Resource = load(path)
	if packed == null or not (packed is PackedScene):
		return false
	var node: Node = (packed as PackedScene).instantiate()
	if node is Node3D:
		(node as Node3D).position = pos
		(node as Node3D).scale = Vector3.ONE * scale
		(node as Node3D).rotation_degrees.y = rot_y_deg
	add_child(node)
	return true


func _add_lights() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.13, 0.15)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.6)
	e.ambient_light_energy = 0.55
	env.environment = e
	add_child(env)
	# Uniform fluorescent grid — denser and brighter
	var xs := range(-14, 29, 3)
	var zs := range(-14, 17, 3)
	for x in xs:
		for z in zs:
			_fluorescent(Vector3(float(x), 2.85, float(z)), Vector3(2.6, 0.1, 0.4))
	for p in [Vector3(12, 2.85, -2), Vector3(14, 2.85, 0), Vector3(10, 2.85, -1)]:
		var l := _fluorescent(p, Vector3(2.6, 0.1, 0.4), true)
		l.add_to_group("accounting_lights")
	var emerg := _omni(Vector3(13, 2.2, -5), 6.0)
	emerg.light_color = Color(0.4, 0.9, 0.5)
	emerg.light_energy = 0.0
	emerg.visible = false
	emerg.add_to_group("emergency_lights")


func _fluorescent(pos: Vector3, size: Vector3, return_omni: bool = false) -> OmniLight3D:
	_box(self, pos, size, mat_fixture)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, -0.12, 0)
	l.omni_range = 7.0
	l.light_color = Color(0.95, 0.98, 0.9)
	l.light_energy = 1.35
	l.shadow_enabled = false
	add_child(l)
	return l


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
	_spawn_terminal("DeskTerminal", Vector3(-6, 1.05, -3.3), 0)
	_spawn_terminal("HRTerminal", Vector3(-7, 1.05, 7.6), 1)
	_spawn_terminal("AccTerminal", Vector3(12, 1.05, -0.4), 2)
	_spawn_terminal("SecTerminal", Vector3(19, 1.05, 7.6), 3)
	_spawn_document(Vector3(-6.4, 1.05, 6.6), "Заметка HR", "Для доступа в бухгалтерию возьмите пропуск\nна столе отсутствующего коллеги в open space.\n\nПропуск также нужен для турникета и лифта.")
	_spawn_document(Vector3(11.4, 1.05, -0.15), "Инструкция", "Шум оборудования может вызвать проверку.\nПри отключении питания используйте технический щит в серверной.\n\nКурение в здании запрещено — датчики дыма активны.")
	_spawn_document(Vector3(-13, 1.05, 0.4), "Кухня", "Энергетики в автомате / на столе.\nСигареты — только вне здания (но кто-то оставил пачку).")
	_spawn_badge(Vector3(2, 1.05, -3.3))
	_spawn_printer(Vector3(14.5, 0.0, 0.5))
	_spawn_power(Vector3(9.5, 1.0, -10.5))
	_spawn_phone(Vector3(4, 1.0, 6))
	_spawn_poster(Vector3(1, 1.7, 3.85))
	_spawn_door("accounting", Vector3(8, 0, -2), Vector3(0, 90, 0), true, "accounting_access")
	_spawn_door("security_passage", Vector3(16, 0, 6), Vector3(0, 90, 0), true, "")
	_spawn_turnstile(Vector3(2, 0, 12.5))
	_spawn_elevator(Vector3(4.5, 0, 13))
	_spawn_loop_trigger()
	_spawn_consumable(Vector3(-5.2, 1.0, -3.2), "energy_drink", 1, "Взять энергетик")
	_spawn_consumable(Vector3(-13.5, 1.0, -1.0), "energy_drink", 2, "Взять энергетик")
	_spawn_consumable(Vector3(-12.5, 1.0, 8.5), "energy_drink", 1, "Взять энергетик")
	_spawn_consumable(Vector3(0.5, 1.0, -13.2), "cigarettes", 1, "Взять сигареты")
	_spawn_consumable(Vector3(18, 1.0, 0), "cigarettes", 1, "Взять сигареты")
	# Extra hide spots for chase
	_add_hide_spot(Vector3(-13, 0.4, 0), Vector3(2.0, 1.0, 2.0))
	_add_hide_spot(Vector3(0, 0.4, -13), Vector3(2.2, 1.0, 2.2))
	_add_hide_spot(Vector3(26, 0.4, -4), Vector3(2.0, 1.0, 2.0))
	var zone := Area3D.new()
	zone.position = Vector3(12, 1, -2)
	zone.add_to_group("event_zone_lights_out")
	var zcol := CollisionShape3D.new()
	var zshape := BoxShape3D.new()
	zshape.size = Vector3(8, 3, 8)
	zcol.shape = zshape
	zone.add_child(zcol)
	add_child(zone)


func _spawn_consumable(pos: Vector3, item_id: String, amount: int, label: String) -> void:
	var size := Vector3(0.25, 0.35, 0.25)
	var mat := mat_accent
	if item_id == "cigarettes":
		size = Vector3(0.2, 0.08, 0.12)
		mat = mat_door
	var n: Node = _make_interactable_body("Pickup_%s" % item_id, pos, size, mat)
	n.set_script(load("res://scripts/interactions/consumable_pickup.gd"))
	n.set("item_id", item_id)
	n.set("amount", amount)
	n.set("pickup_label", label)
	add_child(n)


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
	if not _spawn_model("res://assets/models/props/keycard.glb", pos, 2.0):
		pass
	var p: Node = _make_interactable_body("Badge", pos, Vector3(0.25, 0.08, 0.18), mat_accent)
	p.set_script(load("res://scripts/interactions/pickup_item.gd"))
	p.set("item_id", "employee_badge")
	p.set("grant_access", "accounting_access")
	p.set("pickup_label", "Взять пропуск")
	add_child(p)


func _spawn_printer(pos: Vector3) -> void:
	var tray: Node = _make_interactable_body("ApplicationTray", pos + Vector3(0.75, 0.85, 0), Vector3(0.28, 0.05, 0.32), mat_ceiling)
	tray.set_script(load("res://scripts/interactions/pickup_item.gd"))
	tray.set("item_id", "printed_application")
	tray.set("pickup_label", "Взять заявление")
	tray.visible = false
	var pr: Node = _make_interactable_body("Printer", pos + Vector3(0, 0.55, 0), Vector3(0.85, 1.0, 0.7), mat_door)
	pr.set_script(load("res://scripts/interactions/printer.gd"))
	pr.set("tray_item_path", NodePath("../ApplicationTray"))
	# Hide box mesh if GLB present — keep collision via body
	_spawn_model("res://assets/models/props/printer.glb", pos, 1.8)
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
	# Visual barriers (CC0)
	_spawn_model("res://assets/models/props/barrier_single.glb", pos + Vector3(-0.7, 0, 0), 1.6, 90)
	_spawn_model("res://assets/models/props/barrier_single.glb", pos + Vector3(0.7, 0, 0), 1.6, -90)
	_spawn_model("res://assets/models/props/barrier_large.glb", pos + Vector3(0, 0, -0.4), 1.2, 0)
	var ibody := StaticBody3D.new()
	ibody.collision_layer = 4
	t.add_child(ibody)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.4, 0.6)
	col.shape = shape
	col.position = Vector3(0, 0.7, 0)
	ibody.add_child(col)
	var blocker := StaticBody3D.new()
	blocker.name = "Blocker"
	blocker.collision_layer = 1
	t.add_child(blocker)
	var bcol := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(1.4, 1.6, 0.35)
	bcol.shape = bshape
	bcol.position = Vector3(0, 0.8, 0)
	blocker.add_child(bcol)
	var bmesh := MeshInstance3D.new()
	var bbox := BoxMesh.new()
	bbox.size = Vector3(1.4, 1.6, 0.35)
	bmesh.mesh = bbox
	bmesh.material_override = mat_door
	bmesh.position = Vector3(0, 0.8, 0)
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
		Vector3(-15.5, 0.05, -15.5), Vector3(29.5, 0.05, -15.5),
		Vector3(29.5, 0.05, 17.5), Vector3(-15.5, 0.05, 17.5)
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
	for p in [
		Vector3(6, 0.1, 6), Vector3(-2, 0.1, 6), Vector3(12, 0.1, 2),
		Vector3(10, 0.1, -8), Vector3(2, 0.1, 10), Vector3(-12, 0.1, 0),
		Vector3(26, 0.1, -3), Vector3(0, 0.1, -12)
	]:
		var m := Marker3D.new()
		m.position = p
		pts.add_child(m)


func _add_fall_kill() -> void:
	var area := Area3D.new()
	area.position = Vector3(7, -6, 1)
	area.collision_mask = 2
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 2, 100)
	col.shape = shape
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(func(body: Node):
		if body.is_in_group("player"):
			for s in get_tree().get_nodes_in_group("checkpoint"):
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
	_sign(Vector3(-13, 2.2, -3.5), "КУХНЯ")
	_sign(Vector3(-13, 2.2, 5.5), "ПЕРЕГОВОРНАЯ")
	_sign(Vector3(26, 2.2, -7.5), "АРХИВ")
	_sign(Vector3(1, 2.2, -9.5), "СКЛАД")


func _sign(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = 64
	l.modulate = Color(0.55, 0.75, 0.58)
	add_child(l)
