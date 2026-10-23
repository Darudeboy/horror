extends Node
## Global gameplay state: items, access, flags, stamina/anxiety, consumables.

signal state_changed(kind: String, id: String, value: Variant)
signal item_changed(item_id: String, owned: bool)
signal access_changed(access_id: String, granted: bool)
signal flag_changed(flag_id: String, value: bool)
signal stage_changed(stage: String)
signal notification_requested(text: String)
signal meters_changed(stamina: float, anxiety: float)
signal smoke_alarm(position: Vector3)

const ITEM_EMPLOYEE_BADGE := "employee_badge"
const ITEM_PRINTED_APPLICATION := "printed_application"
const ITEM_ENERGY_DRINK := "energy_drink"
const ITEM_CIGARETTES := "cigarettes"

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
const FLAG_SMOKE_ALARM := "smoke_alarm_triggered"

const ALL_KEY_ITEMS := [ITEM_EMPLOYEE_BADGE, ITEM_PRINTED_APPLICATION]
const ALL_CONSUMABLES := [ITEM_ENERGY_DRINK, ITEM_CIGARETTES]
const ALL_ITEMS := [ITEM_EMPLOYEE_BADGE, ITEM_PRINTED_APPLICATION, ITEM_ENERGY_DRINK, ITEM_CIGARETTES]
const ALL_ACCESS := [ACCESS_ACCOUNTING]
const ALL_FLAGS := [
	FLAG_WORKDAY_STARTED, FLAG_EXIT_CHECKED, FLAG_HR_BRIEFED,
	FLAG_PRINTER_FAULT, FLAG_POWER_RESTORED, FLAG_PRINT_STARTED, FLAG_PRINT_COMPLETED,
	FLAG_HR_APPROVED, FLAG_ACCOUNTING_APPROVED, FLAG_SECURITY_APPROVED, FLAG_EXIT_UNLOCKED,
	FLAG_ENEMY_ACTIVATED, FLAG_PHONE_RINGING, FLAG_PHONE_ANSWERED, FLAG_POSTER_CHANGED,
	FLAG_SECURITY_DOOR_OPEN, FLAG_LOOP_COMPLETED, FLAG_GAME_FINISHED, FLAG_SMOKE_ALARM,
]

const STAMINA_MAX := 100.0
const ANXIETY_MAX := 100.0

var items: Dictionary = {} ## key items bool
var consumables: Dictionary = {} ## id -> count
var access: Dictionary = {}
var flags: Dictionary = {}
var stage: String = "A_start"
var checkpoint_id: String = "spawn"
var print_progress: float = 0.0
var loop_count: int = 0
var invulnerable_until: float = 0.0
var gameplay_paused: bool = false
var ai_enabled: bool = true
var stamina: float = STAMINA_MAX
var anxiety: float = 15.0
var stamina_boost_until: float = 0.0
var last_smoke_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	reset_run()


func reset_run() -> void:
	items.clear()
	consumables.clear()
	access.clear()
	flags.clear()
	for id in ALL_KEY_ITEMS:
		items[id] = false
	for id in ALL_CONSUMABLES:
		consumables[id] = 0
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
	stamina = STAMINA_MAX
	anxiety = 15.0
	stamina_boost_until = 0.0
	last_smoke_position = Vector3.ZERO
	state_changed.emit("reset", "", null)
	meters_changed.emit(stamina, anxiety)


func has_item(item_id: String) -> bool:
	if ALL_CONSUMABLES.has(item_id):
		return int(consumables.get(item_id, 0)) > 0
	return items.get(item_id, false)


func get_consumable_count(item_id: String) -> int:
	return int(consumables.get(item_id, 0))


func give_item(item_id: String, amount: int = 1) -> void:
	if ALL_CONSUMABLES.has(item_id):
		consumables[item_id] = int(consumables.get(item_id, 0)) + amount
		item_changed.emit(item_id, true)
		state_changed.emit("item", item_id, consumables[item_id])
		notification_requested.emit("Получено: %s ×%d" % [_item_name(item_id), amount])
		return
	if not ALL_KEY_ITEMS.has(item_id):
		push_warning("Unknown item: %s" % item_id)
		return
	if items.get(item_id, false):
		return
	items[item_id] = true
	item_changed.emit(item_id, true)
	state_changed.emit("item", item_id, true)
	notification_requested.emit("Получено: %s" % _item_name(item_id))


func _item_name(item_id: String) -> String:
	var names := {
		ITEM_EMPLOYEE_BADGE: "Пропуск сотрудника",
		ITEM_PRINTED_APPLICATION: "Распечатанное заявление",
		ITEM_ENERGY_DRINK: "Энергетик",
		ITEM_CIGARETTES: "Сигареты",
	}
	return names.get(item_id, item_id)


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
		notification_requested.emit("Турникет разблокирован — приложите пропуск")


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


func has_stamina_boost() -> bool:
	return Time.get_ticks_msec() / 1000.0 < stamina_boost_until


func use_energy_drink() -> bool:
	if get_consumable_count(ITEM_ENERGY_DRINK) <= 0:
		notification_requested.emit("Нет энергетика")
		return false
	consumables[ITEM_ENERGY_DRINK] -= 1
	stamina = STAMINA_MAX
	stamina_boost_until = Time.get_ticks_msec() / 1000.0 + 45.0
	anxiety = clampf(anxiety + 18.0, 0.0, ANXIETY_MAX)
	item_changed.emit(ITEM_ENERGY_DRINK, has_item(ITEM_ENERGY_DRINK))
	notification_requested.emit("Энергетик: выносливость↑, тревожность↑")
	meters_changed.emit(stamina, anxiety)
	return true


func use_cigarettes(at_position: Vector3) -> bool:
	if get_consumable_count(ITEM_CIGARETTES) <= 0:
		notification_requested.emit("Нет сигарет")
		return false
	consumables[ITEM_CIGARETTES] -= 1
	anxiety = clampf(anxiety - 25.0, 0.0, ANXIETY_MAX)
	item_changed.emit(ITEM_CIGARETTES, has_item(ITEM_CIGARETTES))
	notification_requested.emit("Сигарета: тревожность↓… дым поднимает тревогу датчиков")
	meters_changed.emit(stamina, anxiety)
	last_smoke_position = at_position
	set_flag(FLAG_SMOKE_ALARM, true)
	smoke_alarm.emit(at_position)
	# Large noise + force enemy response
	AudioManager.emit_noise(at_position, 20.0, "smoke_alarm")
	return true


func spend_stamina(amount: float) -> bool:
	if stamina < amount and not has_stamina_boost():
		return false
	if not has_stamina_boost():
		stamina = maxf(0.0, stamina - amount)
		meters_changed.emit(stamina, anxiety)
	return true


func regen_stamina(delta: float, resting: bool) -> void:
	var rate := 18.0 if resting else 6.0
	if has_stamina_boost():
		rate *= 1.5
	stamina = minf(STAMINA_MAX, stamina + rate * delta)
	# Anxiety slowly rises in empty office, faster if high
	var anx_rate := 0.8 + anxiety * 0.002
	anxiety = clampf(anxiety + anx_rate * delta * 0.15, 0.0, ANXIETY_MAX)
	meters_changed.emit(stamina, anxiety)


func get_owned_item_labels() -> PackedStringArray:
	var result: PackedStringArray = []
	if has_item(ITEM_EMPLOYEE_BADGE):
		result.append("Пропуск")
	if has_item(ITEM_PRINTED_APPLICATION):
		result.append("Заявление")
	var ed := get_consumable_count(ITEM_ENERGY_DRINK)
	if ed > 0:
		result.append("Энергетик×%d [1]" % ed)
	var cig := get_consumable_count(ITEM_CIGARETTES)
	if cig > 0:
		result.append("Сигареты×%d [2]" % cig)
	return result


func to_save_dict() -> Dictionary:
	return {
		"items": items.duplicate(),
		"consumables": consumables.duplicate(),
		"access": access.duplicate(),
		"flags": flags.duplicate(),
		"stage": stage,
		"checkpoint_id": checkpoint_id,
		"print_progress": print_progress,
		"loop_count": loop_count,
		"stamina": stamina,
		"anxiety": anxiety,
	}


func apply_save_dict(data: Dictionary) -> void:
	reset_run()
	var saved_items: Dictionary = data.get("items", {})
	for id in ALL_KEY_ITEMS:
		items[id] = bool(saved_items.get(id, false))
	var saved_cons: Dictionary = data.get("consumables", {})
	for id in ALL_CONSUMABLES:
		consumables[id] = int(saved_cons.get(id, 0))
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
	stamina = float(data.get("stamina", STAMINA_MAX))
	anxiety = float(data.get("anxiety", 15.0))
	state_changed.emit("load", "", null)
	meters_changed.emit(stamina, anxiety)
