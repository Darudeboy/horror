extends Node
## Volume buses and optional procedural placeholder sounds.
## Game noise events are separate from audible volume (see emit_noise).

signal noise_emitted(position: Vector3, radius: float, source: String)

const BUS_MASTER := "Master"
const BUS_SFX := "SFX"
const BUS_AMBIENCE := "Ambience"


func _ready() -> void:
	_ensure_buses()


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


func emit_noise(world_position: Vector3, radius: float, source: String = "") -> void:
	## Gameplay noise for enemy hearing — independent of user volume settings.
	noise_emitted.emit(world_position, radius, source)


func play_stub_2d(bus: String = BUS_SFX) -> void:
	## No audio files yet: avoid missing-resource errors. Visual feedback elsewhere.
	pass
