extends Node
## Settings persist separately from run progress.

signal settings_changed

const SETTINGS_PATH := "user://settings.json"
const SCHEMA_VERSION := 1

var mouse_sensitivity: float = 0.12
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var fullscreen: bool = false
var camera_bob_enabled: bool = true
var flicker_enabled: bool = true


func _ready() -> void:
	load_settings()
	apply_settings()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		return
	mouse_sensitivity = float(data.get("mouse_sensitivity", mouse_sensitivity))
	master_volume = clampf(float(data.get("master_volume", master_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(data.get("fullscreen", fullscreen))
	camera_bob_enabled = bool(data.get("camera_bob_enabled", camera_bob_enabled))
	flicker_enabled = bool(data.get("flicker_enabled", flicker_enabled))


func save_settings() -> void:
	var data := {
		"schema_version": SCHEMA_VERSION,
		"mouse_sensitivity": mouse_sensitivity,
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"fullscreen": fullscreen,
		"camera_bob_enabled": camera_bob_enabled,
		"flicker_enabled": flicker_enabled,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Cannot write settings")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func apply_settings() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(maxf(master_volume, 0.0001)))
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(maxf(sfx_volume, 0.0001)))
	settings_changed.emit()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.02, 0.5)
	save_settings()
	settings_changed.emit()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_settings()
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply_settings()
	save_settings()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_settings()
	save_settings()


func set_camera_bob(value: bool) -> void:
	camera_bob_enabled = value
	save_settings()
	settings_changed.emit()


func set_flicker(value: bool) -> void:
	flicker_enabled = value
	save_settings()
	settings_changed.emit()
