extends Node
## Versioned JSON checkpoints in user://. No executable resources from saves.

signal save_completed(ok: bool)
signal load_completed(ok: bool)

const SAVE_PATH := "user://checkpoint.json"
const SCHEMA_VERSION := 1

var last_error: String = ""
var _busy_blockers: Dictionary = {}


func set_blocker(id: String, active: bool) -> void:
	if active:
		_busy_blockers[id] = true
	else:
		_busy_blockers.erase(id)


func can_save() -> bool:
	if not _busy_blockers.is_empty():
		return false
	if GameState.gameplay_paused:
		return false
	return true


func has_valid_save() -> bool:
	var data: Variant = _read_raw()
	return data != null and typeof(data) == TYPE_DICTIONARY and _validate(data)


func save_checkpoint(checkpoint_id: String = "") -> bool:
	if not can_save():
		last_error = "Сохранение недоступно сейчас"
		save_completed.emit(false)
		return false
	if checkpoint_id != "":
		GameState.checkpoint_id = checkpoint_id
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"state": GameState.to_save_dict(),
		"events_done": [],
	}
	var director := get_tree().get_first_node_in_group("event_director")
	if director and director.has_method("get_completed_event_ids"):
		payload["events_done"] = director.get_completed_event_ids()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		last_error = "Не удалось записать файл сохранения"
		save_completed.emit(false)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	last_error = ""
	save_completed.emit(true)
	GameState.notification_requested.emit("Контрольная точка сохранена")
	return true


func load_checkpoint() -> Dictionary:
	var data: Variant = _read_raw()
	if data == null or typeof(data) != TYPE_DICTIONARY or not _validate(data):
		load_completed.emit(false)
		return {}
	var dict: Dictionary = data
	GameState.apply_save_dict(dict.get("state", {}))
	load_completed.emit(true)
	return dict


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _read_raw() -> Variant:
	last_error = ""
	if not FileAccess.file_exists(SAVE_PATH):
		last_error = "Нет файла сохранения"
		return null
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		last_error = "Не удалось прочитать сохранение"
		return null
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "Повреждённый файл сохранения"
		return null
	return parsed


func _validate(data: Dictionary) -> bool:
	if int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		last_error = "Несовместимая версия сохранения"
		return false
	if not data.has("state") or typeof(data["state"]) != TYPE_DICTIONARY:
		last_error = "Повреждённый файл сохранения"
		return false
	return true
