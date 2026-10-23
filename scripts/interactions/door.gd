extends Interactable
class_name GameDoor
## Controlled slide open/close. Optional access requirement.

@export var door_id: String = ""
@export var starts_open: bool = false
@export var locked: bool = false
@export var required_access: String = ""
@export var required_flag: String = ""
@export var required_item: String = ""
@export var locked_message: String = "Дверь заблокирована"
@export var open_offset: Vector3 = Vector3(1.2, 0, 0)
@export var open_speed: float = 3.0

@onready var pivot: Node3D = $Pivot

var _open: bool = false
var _closed_pos: Vector3
var _target_pos: Vector3


func _ready() -> void:
	interaction_prompt = "Открыть"
	_closed_pos = pivot.position
	_open = starts_open
	_target_pos = _closed_pos + open_offset if _open else _closed_pos
	pivot.position = _target_pos
	_update_prompt()
	GameState.state_changed.connect(_on_state)
	add_to_group("doors")
	if door_id != "":
		set_meta("door_id", door_id)


func _on_state(_k: String, _i: String, _v: Variant) -> void:
	if door_id == "accounting" and GameState.has_access(GameState.ACCESS_ACCOUNTING):
		locked = false
	if door_id == "security_passage" and GameState.get_flag(GameState.FLAG_SECURITY_DOOR_OPEN):
		locked = false
		if not _open:
			set_open(true)
	_update_prompt()


func _process(delta: float) -> void:
	if pivot.position.distance_to(_target_pos) > 0.001:
		pivot.position = pivot.position.move_toward(_target_pos, open_speed * delta)


func is_open() -> bool:
	return _open


func set_open(value: bool) -> void:
	_open = value
	_target_pos = _closed_pos + open_offset if _open else _closed_pos
	_update_prompt()


func set_locked(value: bool, message: String = "") -> void:
	locked = value
	if message != "":
		locked_message = message
	_update_prompt()


func _update_prompt() -> void:
	interaction_prompt = "Закрыть" if _open else "Открыть"


func _requirements_met() -> bool:
	if required_access != "" and not GameState.has_access(required_access):
		return false
	if required_item != "" and not GameState.has_item(required_item):
		return false
	if required_flag != "" and not GameState.get_flag(required_flag):
		return false
	return true


func can_interact(_player: Node) -> bool:
	if not enabled:
		return false
	if locked and not _requirements_met():
		return false
	# Locked with unmet soft lock (flag/access) already handled; if still locked without met requirements
	if locked and required_flag != "" and not GameState.get_flag(required_flag):
		return false
	return true


func get_deny_reason(_player: Node) -> String:
	if required_access != "" and not GameState.has_access(required_access):
		if required_access == GameState.ACCESS_ACCOUNTING:
			return "Нужен пропуск сотрудника"
		return "Недостаточно прав доступа"
	if required_item != "" and not GameState.has_item(required_item):
		return "Не хватает нужного предмета"
	if required_flag != "" and not GameState.get_flag(required_flag):
		return locked_message
	if locked:
		return locked_message
	return "Недоступно"


func _on_interact(_player: Node) -> void:
	if locked and not _requirements_met():
		GameState.notification_requested.emit(get_deny_reason(_player))
		return
	if locked and _requirements_met():
		locked = false
	set_open(not _open)
	AudioManager.play_stub_2d()
