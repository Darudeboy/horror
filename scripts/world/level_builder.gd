extends Node3D
## Spacious two-floor office graybox with night-city windows.

const PROP_SCALE := 2.8
const FLOOR_H := 3.2
const FLOOR2_Y := 8.0
## Floor footprint center / size
const CX := 8.0
const CZ := 2.0
const SX := 60.0
const SZ := 48.0

var mat_wall: StandardMaterial3D
var mat_floor: StandardMaterial3D
var mat_floor_tech: StandardMaterial3D
var mat_ceiling: StandardMaterial3D
var mat_accent: StandardMaterial3D
var mat_door: StandardMaterial3D
var mat_fixture: StandardMaterial3D
var mat_glass: StandardMaterial3D
var mat_city: StandardMaterial3D


func build() -> void:
	_make_materials()
	_build_city_backdrop()
	var bank := Node3D.new()
	bank.name = "ElevatorBank"
	bank.set_script(load("res://scripts/interactions/elevator_bank.gd"))
	add_child(bank)
	bank.setup(mat_door, mat_door)
	_build_floor(0.0, 1, bank)
	_build_floor(FLOOR2_Y, 2, bank)
	_add_navigation()
	_add_fall_kill()


func _make_materials() -> void:
	mat_wall = _load_mat("res://assets/materials/wall_plaster.tres", Color(0.86, 0.84, 0.78))
	# Force light beige-gray read even if texture is dark
	mat_wall.albedo_color = Color(1.15, 1.12, 1.05, 1)
	mat_floor = _load_mat("res://assets/materials/floor_carpet.tres", Color(0.14, 0.18, 0.28))
	mat_floor_tech = _load_mat("res://assets/materials/tech_floor_tiles.tres", Color(0.4, 0.41, 0.43))
	mat_ceiling = _load_mat("res://assets/materials/ceiling_plaster.tres", Color(0.92, 0.9, 0.86))
	mat_accent = _load_mat("res://assets/materials/accent_sign.tres", Color(0.45, 0.62, 0.48))
	mat_door = _load_mat("res://assets/materials/door_metal.tres", Color(0.4, 0.44, 0.5))
	mat_fixture = _mat(Color(0.98, 1.0, 0.94))
	mat_fixture.emission_enabled = true
	mat_fixture.emission = Color(0.95, 1.0, 0.88)
	mat_fixture.emission_energy_multiplier = 0.7
	mat_glass = _mat(Color(0.55, 0.7, 0.85, 0.25))
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_glass.roughness = 0.05
	mat_glass.metallic = 0.2
	mat_city = StandardMaterial3D.new()
	mat_city.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if ResourceLoader.exists("res://assets/textures/city/night_city_view.jpg"):
		mat_city.albedo_texture = load("res://assets/textures/city/night_city_view.jpg")
	else:
		mat_city.albedo_color = Color(0.05, 0.08, 0.18)
	mat_city.emission_enabled = true
	mat_city.emission = Color(0.15, 0.2, 0.35)
	mat_city.emission_energy_multiplier = 0.45


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


func _build_city_backdrop() -> void:
	# Large unlit planes outside the south glass wall
	var city := MeshInstance3D.new()
	city.name = "NightCity"
	var plane := QuadMesh.new()
	plane.size = Vector2(90, 28)
	city.mesh = plane
	city.material_override = mat_city
	city.position = Vector3(CX, 10.0, -28.0)
	# Quad faces +Z by default; rotate to face into the building (+Z toward office)
	city.rotation_degrees = Vector3(0, 0, 0)
	add_child(city)
	var glow := OmniLight3D.new()
	glow.position = Vector3(CX, 6.0, -24.0)
	glow.omni_range = 18.0
	glow.light_color = Color(0.35, 0.45, 0.75)
	glow.light_energy = 0.35
	add_child(glow)


func _build_floor(y0: float, floor_id: int, bank: Node = null) -> void:
	var root := Node3D.new()
	root.name = "Floor%d" % floor_id
	root.position = Vector3(0, y0, 0)
	add_child(root)
	_shell(root, floor_id)
	_partitions(root, floor_id)
	_windows(root)
	_furniture(root, floor_id)
	_lights(root, floor_id)
	_interactables(root, floor_id, bank)
	_labels(root, floor_id)
	if floor_id == 1:
		_checkpoints(root)
		_enemy_patrol(root)
		_loop_trigger(root)


func _shell(parent: Node3D, floor_id: int) -> void:
	_box(parent, Vector3(CX, -0.05, CZ), Vector3(SX, 0.1, SZ), mat_floor)
	_box(parent, Vector3(CX, FLOOR_H + 0.05, CZ), Vector3(SX, 0.1, SZ), mat_ceiling)
	# Outer walls — leave south wall open for window strip
	_box(parent, Vector3(CX, FLOOR_H * 0.5, CZ + SZ * 0.5), Vector3(SX, FLOOR_H, 0.3), mat_wall) # north
	_box(parent, Vector3(CX - SX * 0.5, FLOOR_H * 0.5, CZ), Vector3(0.3, FLOOR_H, SZ), mat_wall) # west
	_box(parent, Vector3(CX + SX * 0.5, FLOOR_H * 0.5, CZ), Vector3(0.3, FLOOR_H, SZ), mat_wall) # east
	# South: solid sides + window band in the middle
	_box(parent, Vector3(CX - 22, FLOOR_H * 0.5, CZ - SZ * 0.5), Vector3(16, FLOOR_H, 0.3), mat_wall)
	_box(parent, Vector3(CX + 22, FLOOR_H * 0.5, CZ - SZ * 0.5), Vector3(16, FLOOR_H, 0.3), mat_wall)
	_box(parent, Vector3(CX, 0.35, CZ - SZ * 0.5), Vector3(28, 0.7, 0.3), mat_wall) # sill
	_box(parent, Vector3(CX, FLOOR_H - 0.25, CZ - SZ * 0.5), Vector3(28, 0.5, 0.3), mat_wall) # lintel
	if floor_id == 1:
		_box(parent, Vector3(12, 0.0, -10), Vector3(8, 0.02, 8), mat_floor_tech)
		_box(parent, Vector3(-12, 0.0, -12), Vector3(8, 0.02, 8), mat_floor_tech)


func _windows(parent: Node3D) -> void:
	# Glass panes looking at night city
	for i in 5:
		var x := CX - 10.0 + float(i) * 5.0
		_box(parent, Vector3(x, 1.7, CZ - SZ * 0.5), Vector3(4.4, 2.0, 0.08), mat_glass)
	# Thin mullions
	for i in 6:
		var x2 := CX - 12.0 + float(i) * 5.0
		_box(parent, Vector3(x2, 1.7, CZ - SZ * 0.5), Vector3(0.12, 2.2, 0.2), mat_door)


func _partitions(parent: Node3D, floor_id: int) -> void:
	# Wide corridors (~4 m openings). Less wall clutter.
	# Main east-west spine wall at Z=6 with wide gaps
	_wall_x(parent, -22, -8, 6)
	_wall_x(parent, -4, 2, 6)
	_wall_x(parent, 8, 38, 6)
	# HR wing north-west
	_wall_z(parent, 6, 16, -6)
	_wall_x(parent, -16, -6, 16)
	# Accounting east of open space
	_wall_z(parent, -14, 6, 10)
	_wall_x(parent, 10, 22, -14)
	# Server south of accounting
	_wall_x(parent, 10, 20, -8)
	_wall_z(parent, -14, -8, 20)
	# Vestibule / exit north
	_wall_x(parent, -4, 1, 12)
	_wall_x(parent, 7, 22, 12)
	_wall_z(parent, 12, 22, -4)
	_wall_z(parent, 12, 22, 8)
	# Security east
	_wall_z(parent, 6, 16, 22)
	_wall_x(parent, 22, 32, 16)
	# Kitchen west
	_wall_z(parent, -6, 4, -14)
	_wall_x(parent, -22, -14, -6)
	# Meeting
	_wall_z(parent, 6, 16, -14)
	_wall_x(parent, -22, -14, 16)
	# Archive far east
	_wall_z(parent, -12, 4, 28)
	_wall_x(parent, 28, 38, -12)
	if floor_id == 2:
		# Floor 2: fewer rooms — open loft + archive + meeting
		pass


func _wall_x(parent: Node3D, x0: float, x1: float, z: float) -> void:
	var mid := (x0 + x1) * 0.5
	var len := absf(x1 - x0)
	if len < 0.1:
		return
	_box(parent, Vector3(mid, FLOOR_H * 0.5, z), Vector3(len, FLOOR_H, 0.2), mat_wall)


func _wall_z(parent: Node3D, z0: float, z1: float, x: float) -> void:
	var mid := (z0 + z1) * 0.5
	var len := absf(z1 - z0)
	if len < 0.1:
		return
	_box(parent, Vector3(x, FLOOR_H * 0.5, mid), Vector3(0.2, FLOOR_H, len), mat_wall)


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


func _furniture(parent: Node3D, floor_id: int) -> void:
	# Sparse desks — breathing room between props
	_desk(parent, Vector3(-8, 0, -4), true)
	_desk(parent, Vector3(0, 0, -4), false)
	_desk(parent, Vector3(-10, 0, 10), false) # HR
	_desk(parent, Vector3(14, 0, -2), false) # accounting
	_desk(parent, Vector3(-18, 0, 0), false) # kitchen
	_desk(parent, Vector3(-18, 0, 10), false) # meeting
	_desk(parent, Vector3(32, 0, -4), false) # archive
	_desk(parent, Vector3(24, 0, 10), false) # security
	if floor_id == 2:
		_desk(parent, Vector3(4, 0, 0), false)
		_desk(parent, Vector3(16, 0, 8), false)
		_desk(parent, Vector3(-10, 0, 8), false)
	_box(parent, Vector3(12, 1.0, -11), Vector3(0.9, 2.0, 1.4), mat_door)
	_box(parent, Vector3(15, 1.0, -11), Vector3(0.9, 2.0, 1.4), mat_door)
	_box(parent, Vector3(-2, 0.4, 0), Vector3(1.3, 0.8, 0.55), mat_door)
	_box(parent, Vector3(6, 0.35, 3), Vector3(1.5, 0.7, 0.5), mat_accent)


func _desk(parent: Node3D, pos: Vector3, with_monitor: bool = false) -> void:
	var visual_ok := _spawn_model(parent, "res://assets/models/kenney/desk.glb", pos, PROP_SCALE)
	if not visual_ok:
		_box(parent, pos + Vector3(0, 0.4, 0), Vector3(1.6, 0.08, 0.9), mat_door)
	var col_body := StaticBody3D.new()
	col_body.collision_layer = 1
	col_body.position = pos + Vector3(0, 0.45, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 0.9, 1.0)
	col.shape = shape
	col_body.add_child(col)
	parent.add_child(col_body)
	if with_monitor:
		_spawn_model(parent, "res://assets/models/kenney/computerScreen.glb", pos + Vector3(0, 0.95, -0.2), PROP_SCALE)
		_spawn_model(parent, "res://assets/models/kenney/computerKeyboard.glb", pos + Vector3(0, 0.92, 0.25), PROP_SCALE)
	_spawn_model(parent, "res://assets/models/kenney/chairDesk.glb", pos + Vector3(0, 0, 1.1), PROP_SCALE)
	_add_hide_spot(parent, pos + Vector3(0, 0.35, 0.15), Vector3(1.6, 0.85, 1.2))


func _add_hide_spot(parent: Node3D, pos: Vector3, size: Vector3) -> void:
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
	parent.add_child(area)


func _spawn_model(parent: Node, path: String, pos: Vector3, scale: float, rot_y_deg: float = 0.0) -> bool:
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
	parent.add_child(node)
	return true


func _lights(parent: Node3D, floor_id: int) -> void:
	if floor_id == 1:
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.05, 0.06, 0.08)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.45, 0.44, 0.4)
		e.ambient_light_energy = 0.28
		env.environment = e
		parent.add_child(env)
	var positions: Array[Vector3] = [
		Vector3(-8, FLOOR_H - 0.35, -4), Vector3(2, FLOOR_H - 0.35, -4),
		Vector3(14, FLOOR_H - 0.35, -2), Vector3(24, FLOOR_H - 0.35, 2),
		Vector3(-18, FLOOR_H - 0.35, 0), Vector3(-10, FLOOR_H - 0.35, 10),
		Vector3(2, FLOOR_H - 0.35, 14), Vector3(24, FLOOR_H - 0.35, 10),
		Vector3(32, FLOOR_H - 0.35, -4), Vector3(14, FLOOR_H - 0.35, -11),
		Vector3(CX, FLOOR_H - 0.35, CZ - 10),
	]
	for p in positions:
		var l := _fluorescent(parent, p)
		l.add_to_group("office_lights")
	for p2 in [Vector3(14, FLOOR_H - 0.35, -2), Vector3(16, FLOOR_H - 0.35, 0)]:
		var al := _fluorescent(parent, p2)
		al.add_to_group("accounting_lights")
		al.add_to_group("office_lights")
	if floor_id == 1:
		var emerg := OmniLight3D.new()
		emerg.position = Vector3(14, 2.2, -10)
		emerg.omni_range = 6.0
		emerg.light_color = Color(0.4, 0.9, 0.5)
		emerg.light_energy = 0.0
		emerg.visible = false
		emerg.add_to_group("emergency_lights")
		parent.add_child(emerg)


func _fluorescent(parent: Node3D, pos: Vector3) -> OmniLight3D:
	_box(parent, pos, Vector3(2.4, 0.08, 0.35), mat_fixture)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, -0.12, 0)
	l.omni_range = 10.0
	l.light_color = Color(0.94, 0.96, 0.9)
	l.light_energy = 0.5
	l.shadow_enabled = false
	parent.add_child(l)
	return l


func _interactables(parent: Node3D, floor_id: int, bank: Node = null) -> void:
	var elev_pos := Vector3(5.5, 0, 16)
	_spawn_elevator(parent, elev_pos, floor_id, bank)
	if floor_id != 1:
		_spawn_consumable(parent, Vector3(-8, 1.0, 0), "energy_drink", 1, "Взять энергетик")
		_spawn_document(parent, Vector3(4, 1.05, 0), "2 этаж", "Архив ночной смены.\nЛифт — обратно на 1 этаж с пропуском.")
		return
	_spawn_terminal(parent, "DeskTerminal", Vector3(-8, 1.05, -3.3), 0)
	_spawn_terminal(parent, "HRTerminal", Vector3(-10, 1.05, 10.6), 1)
	_spawn_terminal(parent, "AccTerminal", Vector3(14, 1.05, -1.4), 2)
	_spawn_terminal(parent, "SecTerminal", Vector3(24, 1.05, 10.6), 3)
	_spawn_document(parent, Vector3(-8.4, 1.05, 9.5), "Заметка HR", "Пропуск для турникета и лифта.\nТелефон [4] — внутренние номера отвлекают службу соответствия.")
	_spawn_document(parent, Vector3(13.4, 1.05, -1.15), "Инструкция", "Шум оборудования вызывает проверку.\nКурение поднимает датчики дыма.")
	_spawn_badge(parent, Vector3(2, 1.05, -3.3))
	_spawn_printer(parent, Vector3(17, 0.0, 0.5))
	_spawn_power(parent, Vector3(12, 1.0, -11.5))
	_spawn_phone(parent, Vector3(4, 1.0, 8))
	_spawn_poster(parent, Vector3(1, 1.7, 5.85))
	_spawn_door(parent, "accounting", Vector3(10, 0, -2), Vector3(0, 90, 0), true, "accounting_access")
	_spawn_door(parent, "security_passage", Vector3(22, 0, 8), Vector3(0, 90, 0), true, "")
	_spawn_turnstile(parent, Vector3(2, 0, 15))
	_spawn_street_exit(parent, Vector3(2, 0, 20))
	_spawn_consumable(parent, Vector3(-6.5, 1.0, -3.2), "energy_drink", 1, "Взять энергетик")
	_spawn_consumable(parent, Vector3(-18, 1.0, -1.0), "energy_drink", 2, "Взять энергетик")
	_spawn_consumable(parent, Vector3(0.5, 1.0, -14), "cigarettes", 1, "Взять сигареты")
	_spawn_consumable(parent, Vector3(30, 1.0, 0), "cigarettes", 1, "Взять сигареты")
	_add_hide_spot(parent, Vector3(-18, 0.4, 0), Vector3(2.0, 1.0, 2.0))
	_add_hide_spot(parent, Vector3(32, 0.4, -4), Vector3(2.0, 1.0, 2.0))
	var zone := Area3D.new()
	zone.position = Vector3(14, 1, -2)
	zone.add_to_group("event_zone_lights_out")
	var zcol := CollisionShape3D.new()
	var zshape := BoxShape3D.new()
	zshape.size = Vector3(10, 3, 10)
	zcol.shape = zshape
	zone.add_child(zcol)
	parent.add_child(zone)


func _spawn_consumable(parent: Node3D, pos: Vector3, item_id: String, amount: int, label: String) -> void:
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
	parent.add_child(n)


func _spawn_terminal(parent: Node3D, n: String, pos: Vector3, kind: int) -> void:
	var t: Node = _make_interactable_body(n, pos, Vector3(0.55, 0.45, 0.4), mat_door)
	t.set_script(load("res://scripts/interactions/terminal.gd"))
	t.set("kind", kind)
	t.set("terminal_id", n)
	parent.add_child(t)


func _spawn_document(parent: Node3D, pos: Vector3, title: String, body: String) -> void:
	var d: Node = _make_interactable_body("Document", pos, Vector3(0.3, 0.05, 0.4), mat_ceiling)
	d.set_script(load("res://scripts/interactions/readable_document.gd"))
	d.set("document_title", title)
	d.set("document_body", body)
	parent.add_child(d)


func _spawn_badge(parent: Node3D, pos: Vector3) -> void:
	if not _spawn_model(parent, "res://assets/models/props/keycard.glb", pos, 2.0):
		_box(parent, pos, Vector3(0.2, 0.05, 0.12), mat_accent)
	var n: Node = _make_interactable_body("Badge", pos, Vector3(0.35, 0.2, 0.25), mat_accent)
	n.set_script(load("res://scripts/interactions/pickup_item.gd"))
	n.set("item_id", "employee_badge")
	n.set("grant_access", "accounting_access")
	parent.add_child(n)


func _spawn_printer(parent: Node3D, pos: Vector3) -> void:
	var tray: Node = _make_interactable_body("ApplicationTray", pos + Vector3(0.75, 0.85, 0), Vector3(0.28, 0.05, 0.32), mat_ceiling)
	tray.visible = false
	parent.add_child(tray)
	var p: Node = _make_interactable_body("Printer", pos + Vector3(0, 0.7, 0), Vector3(0.7, 1.0, 0.6), mat_door)
	p.set_script(load("res://scripts/interactions/printer.gd"))
	_spawn_model(parent, "res://assets/models/props/printer.glb", pos, 1.8)
	parent.add_child(p)


func _spawn_power(parent: Node3D, pos: Vector3) -> void:
	var n: Node = _make_interactable_body("PowerPanel", pos, Vector3(0.4, 0.8, 0.2), mat_door)
	n.set_script(load("res://scripts/interactions/power_panel.gd"))
	parent.add_child(n)


func _spawn_phone(parent: Node3D, pos: Vector3) -> void:
	var n: Node = _make_interactable_body("Phone", pos, Vector3(0.25, 0.35, 0.25), mat_accent)
	n.set_script(load("res://scripts/interactions/phone.gd"))
	parent.add_child(n)


func _spawn_poster(parent: Node3D, pos: Vector3) -> void:
	var n: Node = _make_interactable_body("Poster", pos, Vector3(1.0, 1.2, 0.05), mat_accent)
	n.set_script(load("res://scripts/interactions/poster.gd"))
	parent.add_child(n)


func _spawn_door(parent: Node3D, door_id: String, pos: Vector3, rot_deg: Vector3, locked: bool, access: String = "") -> void:
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
	parent.add_child(door)
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
		parent.add_child(zone)


func _spawn_turnstile(parent: Node3D, pos: Vector3) -> void:
	var t := Node3D.new()
	t.name = "Turnstile"
	t.position = pos
	_spawn_model(parent, "res://assets/models/props/barrier_single.glb", pos + Vector3(-0.7, 0, 0), 1.6, 90)
	_spawn_model(parent, "res://assets/models/props/barrier_single.glb", pos + Vector3(0.7, 0, 0), 1.6, -90)
	_spawn_model(parent, "res://assets/models/props/barrier_large.glb", pos + Vector3(0, 0, -0.4), 1.2, 0)
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
	parent.add_child(t)


func _spawn_elevator(parent: Node3D, pos: Vector3, floor_id: int, bank: Node = null) -> void:
	# Clear wall behind shaft so opening reads as a real elevator cutout
	if bank and bank.has_method("register_landing"):
		bank.register_landing(floor_id, parent, pos)
	else:
		var land := Marker3D.new()
		land.position = pos
		land.set_meta("floor", floor_id)
		land.add_to_group("elevator_landing")
		parent.add_child(land)


func _spawn_street_exit(parent: Node3D, pos: Vector3) -> void:
	var e: Node = _make_interactable_body("StreetExit", pos + Vector3(0, 1.0, 0), Vector3(1.8, 2.2, 0.25), mat_accent)
	e.set_script(load("res://scripts/interactions/street_exit.gd"))
	parent.add_child(e)


func _loop_trigger(parent: Node3D) -> void:
	var area := Area3D.new()
	area.name = "LoopTrigger"
	area.position = Vector3(24, 1, 8)
	area.monitoring = true
	area.collision_layer = 0
	area.collision_mask = 2
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2, 2.0)
	col.shape = shape
	area.add_child(col)
	parent.add_child(area)
	area.body_entered.connect(_on_loop_enter)
	var hint := Label3D.new()
	hint.name = "LoopExitHint"
	hint.text = "ВЫХОД →"
	hint.position = Vector3(26, 1.8, 9)
	hint.font_size = 64
	hint.modulate = Color(0.45, 0.75, 0.5)
	hint.visible = false
	hint.add_to_group("loop_exit_hint")
	parent.add_child(hint)
	var ret := Marker3D.new()
	ret.position = Vector3(21, 0.1, 8)
	ret.add_to_group("loop_return")
	parent.add_child(ret)
	var correct := Marker3D.new()
	correct.position = Vector3(26, 0.1, 10)
	correct.add_to_group("loop_correct")
	parent.add_child(correct)


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
	# Floor 1 nav plane
	mesh.vertices = PackedVector3Array([
		Vector3(-21, 0.05, -21), Vector3(37, 0.05, -21),
		Vector3(37, 0.05, 25), Vector3(-21, 0.05, 25),
		# Floor 2
		Vector3(-21, FLOOR2_Y + 0.05, -21), Vector3(37, FLOOR2_Y + 0.05, -21),
		Vector3(37, FLOOR2_Y + 0.05, 25), Vector3(-21, FLOOR2_Y + 0.05, 25),
	])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	mesh.add_polygon(PackedInt32Array([4, 5, 6, 7]))
	region.navigation_mesh = mesh


func _checkpoints(parent: Node3D) -> void:
	_marker(parent, "spawn", Vector3(-8, 0.1, -3), true)
	_marker(parent, "after_exit_check", Vector3(2, 0.1, 14), false)
	_marker(parent, "after_power", Vector3(12, 0.1, -11), false)
	_marker(parent, "after_hr", Vector3(-10, 0.1, 9), false)
	_marker(parent, "after_accounting", Vector3(14, 0.1, -2), false)
	_marker(parent, "after_security", Vector3(24, 0.1, 9), false)


func _marker(parent: Node3D, id: String, pos: Vector3, is_spawn: bool) -> void:
	var m := Marker3D.new()
	m.name = "Checkpoint_%s" % id
	m.position = pos
	m.set_meta("checkpoint_id", id)
	m.add_to_group("checkpoint")
	if is_spawn:
		m.add_to_group("player_spawn")
	parent.add_child(m)


func _enemy_patrol(parent: Node3D) -> void:
	var pts := Node3D.new()
	pts.name = "PatrolPoints"
	parent.add_child(pts)
	for p in [
		Vector3(6, 0.1, 8), Vector3(-4, 0.1, 8), Vector3(14, 0.1, 2),
		Vector3(12, 0.1, -10), Vector3(2, 0.1, 14), Vector3(-16, 0.1, 0),
		Vector3(30, 0.1, -4), Vector3(0, 0.1, -12)
	]:
		var m := Marker3D.new()
		m.position = p
		pts.add_child(m)


func _add_fall_kill() -> void:
	var area := Area3D.new()
	area.position = Vector3(CX, -8, CZ)
	area.collision_mask = 2
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(120, 2, 120)
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


func _labels(parent: Node3D, floor_id: int) -> void:
	if floor_id == 2:
		_sign(parent, Vector3(CX, 2.4, CZ), "ЭТАЖ 2 — АРХИВ")
		return
	_sign(parent, Vector3(-10, 2.4, 6.4), "HR")
	_sign(parent, Vector3(14, 2.4, 2.5), "БУХГАЛТЕРИЯ")
	_sign(parent, Vector3(14, 2.4, -7.5), "СЕРВЕРНАЯ")
	_sign(parent, Vector3(24, 2.4, 6.4), "БЕЗОПАСНОСТЬ")
	_sign(parent, Vector3(2, 2.4, 12.5), "ВЫХОД / ЛИФТ")
	_sign(parent, Vector3(-18, 2.4, -3), "КУХНЯ")
	_sign(parent, Vector3(-18, 2.4, 8), "ПЕРЕГОВОРНАЯ")
	_sign(parent, Vector3(32, 2.4, -8), "АРХИВ")
	_sign(parent, Vector3(CX, 2.2, CZ - SZ * 0.5 + 0.4), "НОЧНОЙ ГОРОД")


func _sign(parent: Node3D, pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = 64
	l.modulate = Color(0.25, 0.3, 0.35)
	parent.add_child(l)
