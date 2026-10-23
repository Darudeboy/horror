extends Node
## Volume buses + CC0 Kenney SFX. Game noise events stay volume-independent.

signal noise_emitted(position: Vector3, radius: float, source: String)

const BUS_MASTER := "Master"
const BUS_SFX := "SFX"
const BUS_AMBIENCE := "Ambience"

var _players: Array[AudioStreamPlayer] = []
var _pool_i: int = 0
var _streams: Dictionary = {}
var _foot_i: int = 0


func _ready() -> void:
	_ensure_buses()
	_load_streams()
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_players.append(p)


func _ensure_buses() -> void:
	if AudioServer.get_bus_index(BUS_SFX) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS_SFX)
		AudioServer.set_bus_send(idx, BUS_MASTER)
	if AudioServer.get_bus_index(BUS_AMBIENCE) == -1:
		AudioServer.add_bus()
		var idx2 := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx2, BUS_AMBIENCE)
		AudioServer.set_bus_send(idx2, BUS_MASTER)


func _load_streams() -> void:
	var files := {
		"foot0": "res://assets/audio/sfx/foot_carpet_0.ogg",
		"foot1": "res://assets/audio/sfx/foot_carpet_1.ogg",
		"foot2": "res://assets/audio/sfx/foot_carpet_2.ogg",
		"foot3": "res://assets/audio/sfx/foot_carpet_3.ogg",
		"door_open": "res://assets/audio/sfx/door_open.ogg",
		"door_close": "res://assets/audio/sfx/door_close.ogg",
		"pickup": "res://assets/audio/sfx/pickup.ogg",
		"click": "res://assets/audio/sfx/click.ogg",
		"error": "res://assets/audio/sfx/error.ogg",
		"confirm": "res://assets/audio/sfx/confirm.ogg",
		"alarm": "res://assets/audio/sfx/alarm.ogg",
		"death": "res://assets/audio/sfx/death.ogg",
		"impact_wall": "res://assets/audio/sfx/impact_wall.ogg",
		"creak": "res://assets/audio/sfx/creak.ogg",
		"cloth": "res://assets/audio/sfx/cloth.ogg",
	}
	for k in files.keys():
		var path: String = files[k]
		if ResourceLoader.exists(path):
			_streams[k] = load(path)


func emit_noise(world_position: Vector3, radius: float, source: String = "") -> void:
	noise_emitted.emit(world_position, radius, source)


func play_sfx(key: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not _streams.has(key) or _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_pool_i]
	_pool_i = (_pool_i + 1) % _players.size()
	p.stream = _streams[key]
	p.pitch_scale = pitch_scale
	p.volume_db = volume_db
	p.play()


func play_footstep(sprinting: bool = false) -> void:
	var key := "foot%d" % (_foot_i % 4)
	_foot_i += 1
	play_sfx(key, 1.15 if sprinting else 1.0, -6.0 if not sprinting else -3.0)


func play_stub_2d(bus: String = BUS_SFX) -> void:
	play_sfx("click")
