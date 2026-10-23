extends Node
## Global gameplay state: items, access rights, progress flags, scenario stage.

signal state_changed(kind: String, id: String, value: Variant)
signal item_changed(item_id: String, owned: bool)
signal access_changed(access_id: String, granted: bool)
signal flag_changed(flag_id: String, value: bool)
signal stage_changed(stage: String)
signal notification_requested(text: String)

const ITEM_EMPLOYEE_BADGE := "employee_badge"
const ITEM_PRINTED_APPLICATION := "printed_application"

const ACCESS_ACCOUNTING := "accounting_access"

const FLAG_WORKDAY_STARTED := "workday_started"
const FLAG_EXIT_CHECKED := "exit_checked"
const FLAG_HR_BRIEFED := "hr_briefed"
const FLAG_PRINTER_FAULT := "printer_fault_triggered"
const FLAG_POWER_RESTORED := "power_restored"
const FLAG_PRINT_STARTED := "print_started"
const FLAG_PRINT_COMPLETED := "print_completed"
const FLAG_HR_APPROVED := "hr_approved"
const FLAG_ACCOUNTING_APPROVED := "accounting_approved"
const FLAG_SECURITY_APPROVED := "security_approved"
const FLAG_EXIT_UNLOCKED := "exit_unlocked"
const FLAG_ENEMY_ACTIVATED := "enemy_activated"
const FLAG_PHONE_RINGING := "phone_ringing"
const FLAG_PHONE_ANSWERED := "phone_answered"
const FLAG_POSTER_CHANGED := "poster_changed"
const FLAG_SECURITY_DOOR_OPEN := "security_door_open"
const FLAG_LOOP_COMPLETED := "loop_corridor_completed"
const FLAG_GAME_FINISHED := "game_finished"

const ALL_ITEMS := [ITEM_EMPLOYEE_BADGE, ITEM_PRINTED_APPLICATION]
const ALL_ACCESS := [ACCESS_ACCOUNTING]
const ALL_FLAGS := [
	FLAG_WORKDAY_STARTED, FLAG_EXIT_CHECKED, FLAG_HR_BRIEFED,
	FLAG_PRINTER_FAULT, FLAG_POWER_RESTORED, FLAG_PRINT_STARTED, FLAG_PRINT_COMPLETED,
	FLAG_HR_APPROVED, FLAG_ACCOUNTING_APPROVED, FLAG_SECURITY_APPROVED, FLAG_EXIT_UNLOCKED,
	FLAG_ENEMY_ACTIVATED, FLAG_PHONE_RINGING, FLAG_PHONE_ANSWERED, FLAG_POSTER_CHANGED,
	FLAG_SECURITY_DOOR_OPEN, FLAG_LOOP_COMPLETED, FLAG_GAME_FINISHED,
]

var items: Dictionary = {}
var access: Dictionary = {}
var flags: Dictionary = {}
var stage: String = "A_start"
var checkpoint_id: String = "spawn"
var print_progress: float = 0.0
var loop_count: int = 0
var invulnerable_until: float = 0.0
var gameplay_paused: bool = false
var ai_enabled: bool = true


func _ready() -> void:
	reset_run()


func reset_run() -> void:
	items.clear()
	access.clear()
	flags.clear()
	for id in ALL_ITEMS:
		items[id] = false
	for id in ALL_ACCESS:
		access[id] = false
	for id in ALL_FLAGS:
		flags[id] = false
	stage = "A_start"
	checkpoint_id = "spawn"
	print_progress = 0.0
	loop_count = 0
	invulnerable_until = 0.0
	gameplay_paused = false
	ai_enabled = true
	state_changed.emit("reset", "", null)


func has_item(item_id: String) -> bool:
	return items.get(item_id, false)


func give_item(item_id: String) -> void:
	if not ALL_ITEMS.has(item_id):
		push_warning("Unknown item: %s" % item_id)
		return
	if items.get(item_id, false):
		return
	items[item_id] = true
	item_changed.emit(item_id, true)
	state_changed.emit("item", item_id, true)
	var names := {
		ITEM_EMPLOYEE_BADGE: "Пропуск сотрудника",
		ITEM_PRINTED_APPLICATION: "Распечатанное заявление",
	}
	notification_requested.emit("Получено: %s" % names.get(item_id, item_id))


func has_access(access_id: String) -> bool:
	return access.get(access_id, false)


func grant_access(access_id: String) -> void:
	if not ALL_ACCESS.has(access_id):
		push_warning("Unknown access: %s" % access_id)
		return
	if access.get(access_id, false):
		return
	access[access_id] = true
	access_changed.emit(access_id, true)
	state_changed.emit("access", access_id, true)
	if access_id == ACCESS_ACCOUNTING:
		notification_requested.emit("Доступ: бухгалтерия")


func get_flag(flag_id: String) -> bool:
	return flags.get(flag_id, false)


func set_flag(flag_id: String, value: bool = true) -> void:
	if not ALL_FLAGS.has(flag_id):
		# Allow documented technical flags added later
		pass
	var prev: bool = flags.get(flag_id, false)
	if prev == value:
		return
	flags[flag_id] = value
	flag_changed.emit(flag_id, value)
	state_changed.emit("flag", flag_id, value)
	_update_exit_unlock()
	_maybe_advance_stage()


func _update_exit_unlock() -> void:
	var all_ok := get_flag(FLAG_HR_APPROVED) and get_flag(FLAG_ACCOUNTING_APPROVED) and get_flag(FLAG_SECURITY_APPROVED)
	if all_ok and not get_flag(FLAG_EXIT_UNLOCKED):
		set_flag(FLAG_EXIT_UNLOCKED, true)
		notification_requested.emit("Турникет разблокирован")


func set_stage(new_stage: String) -> void:
	if stage == new_stage:
		return
	stage = new_stage
	stage_changed.emit(stage)
	state_changed.emit("stage", stage, null)


func _maybe_advance_stage() -> void:
	if get_flag(FLAG_GAME_FINISHED):
		set_stage("F_finished")
	elif get_flag(FLAG_EXIT_UNLOCKED):
		set_stage("F_finale")
	elif get_flag(FLAG_SECURITY_APPROVED) or get_flag(FLAG_SECURITY_DOOR_OPEN):
		set_stage("E_security")
	elif get_flag(FLAG_HR_APPROVED) or get_flag(FLAG_ACCOUNTING_APPROVED):
		set_stage("D_approvals")
	elif get_flag(FLAG_PRINT_COMPLETED) or get_flag(FLAG_PRINT_STARTED) or get_flag(FLAG_PRINTER_FAULT):
		set_stage("C_print")
	elif get_flag(FLAG_EXIT_CHECKED) or has_item(ITEM_EMPLOYEE_BADGE) or get_flag(FLAG_HR_BRIEFED):
		set_stage("B_hr")
	elif get_flag(FLAG_WORKDAY_STARTED):
		set_stage("A_start")


func is_invulnerable() -> bool:
	return Time.get_ticks_msec() / 1000.0 < invulnerable_until


func grant_spawn_protection(seconds: float = 3.0) -> void:
	invulnerable_until = Time.get_ticks_msec() / 1000.0 + seconds


func get_owned_item_labels() -> PackedStringArray:
	var result: PackedStringArray = []
	if has_item(ITEM_EMPLOYEE_BADGE):
		result.append("Пропуск")
	if has_item(ITEM_PRINTED_APPLICATION):
		result.append("Заявление")
	return result


func to_save_dict() -> Dictionary:
	return {
		"items": items.duplicate(),
		"access": access.duplicate(),
		"flags": flags.duplicate(),
		"stage": stage,
		"checkpoint_id": checkpoint_id,
		"print_progress": print_progress,
		"loop_count": loop_count,
	}


func apply_save_dict(data: Dictionary) -> void:
	reset_run()
	var saved_items: Dictionary = data.get("items", {})
	for id in ALL_ITEMS:
		items[id] = bool(saved_items.get(id, false))
	var saved_access: Dictionary = data.get("access", {})
	for id in ALL_ACCESS:
		access[id] = bool(saved_access.get(id, false))
	var saved_flags: Dictionary = data.get("flags", {})
	for id in ALL_FLAGS:
		flags[id] = bool(saved_flags.get(id, false))
	stage = str(data.get("stage", "A_start"))
	checkpoint_id = str(data.get("checkpoint_id", "spawn"))
	print_progress = float(data.get("print_progress", 0.0))
	loop_count = int(data.get("loop_count", 0))
	state_changed.emit("load", "", null)
