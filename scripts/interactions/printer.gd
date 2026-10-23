extends Interactable
class_name OfficePrinter
## Print flow: first start triggers power fault; after restore prints 12s with noise.

const PRINT_DURATION := 12.0
const PRINT_NOISE_RADIUS := 14.0

@export var tray_item_path: NodePath

var _printing: bool = false
var _print_time: float = 0.0
var _tray: Node


func _ready() -> void:
	interaction_prompt = "Запустить печать"
	add_to_group("printer")
	if tray_item_path != NodePath(""):
		_tray = get_node_or_null(tray_item_path)
	GameState.state_changed.connect(_on_state)
	_sync_from_state()


func _on_state(_k: String, _i: String, _v: Variant) -> void:
	_sync_from_state()


func _sync_from_state() -> void:
	if GameState.get_flag(GameState.FLAG_PRINT_COMPLETED):
		_printing = false
		interaction_prompt = "Печать завершена"
		_show_tray(not GameState.has_item(GameState.ITEM_PRINTED_APPLICATION))
	elif GameState.get_flag(GameState.FLAG_PRINT_STARTED) and not GameState.get_flag(GameState.FLAG_PRINT_COMPLETED):
		_printing = true
		_print_time = GameState.print_progress
		interaction_prompt = "Идёт печать..."
	elif GameState.get_flag(GameState.FLAG_PRINTER_FAULT) and not GameState.get_flag(GameState.FLAG_POWER_RESTORED):
		interaction_prompt = "Нет питания"
	else:
		interaction_prompt = "Запустить печать"
		_show_tray(false)


func _show_tray(show: bool) -> void:
	if _tray:
		_tray.visible = show
		if _tray is Interactable:
			(_tray as Interactable).enabled = show


func can_interact(_player: Node) -> bool:
	if GameState.get_flag(GameState.FLAG_PRINT_COMPLETED):
		return false
	if _printing:
		return false
	if GameState.get_flag(GameState.FLAG_PRINTER_FAULT) and not GameState.get_flag(GameState.FLAG_POWER_RESTORED):
		return false
	return enabled


func get_deny_reason(_player: Node) -> String:
	if GameState.get_flag(GameState.FLAG_PRINT_COMPLETED):
		return "Заявление уже распечатано"
	if _printing:
		return "Идёт печать"
	if GameState.get_flag(GameState.FLAG_PRINTER_FAULT) and not GameState.get_flag(GameState.FLAG_POWER_RESTORED):
		return "Нет питания. Используйте щит в серверной"
	return "Недоступно"


func _on_interact(_player: Node) -> void:
	if GameState.get_flag(GameState.FLAG_PRINT_COMPLETED) or _printing:
		return
	# First start: power fault once
	if not GameState.get_flag(GameState.FLAG_PRINTER_FAULT):
		GameState.set_flag(GameState.FLAG_PRINTER_FAULT, true)
		GameState.notification_requested.emit("Питание в бухгалтерии отключено")
		var director := get_tree().get_first_node_in_group("event_director")
		if director and director.has_method("queue_event"):
			director.queue_event("lights_out")
		_sync_from_state()
		return
	if not GameState.get_flag(GameState.FLAG_POWER_RESTORED):
		GameState.notification_requested.emit("Нет питания. Используйте щит в серверной")
		return
	_start_print()


func _start_print() -> void:
	if GameState.get_flag(GameState.FLAG_PRINT_STARTED) and not GameState.get_flag(GameState.FLAG_PRINT_COMPLETED):
		# Resume existing
		_printing = true
		_print_time = GameState.print_progress
		return
	GameState.set_flag(GameState.FLAG_PRINT_STARTED, true)
	GameState.print_progress = 0.0
	_print_time = 0.0
	_printing = true
	SaveManager.set_blocker("printing", true)
	interaction_prompt = "Идёт печать..."
	GameState.notification_requested.emit("Печать начата (12 сек)")
	var director := get_tree().get_first_node_in_group("event_director")
	if director and director.has_method("queue_event"):
		director.queue_event("activate_enemy")


func _process(delta: float) -> void:
	if not _printing:
		return
	if GameState.gameplay_paused:
		return
	_print_time += delta
	GameState.print_progress = _print_time
	if fmod(_print_time, 0.5) < delta:
		AudioManager.emit_noise(global_position, PRINT_NOISE_RADIUS, "printer")
	if _print_time >= PRINT_DURATION:
		_finish_print()


func _finish_print() -> void:
	_printing = false
	SaveManager.set_blocker("printing", false)
	if GameState.get_flag(GameState.FLAG_PRINT_COMPLETED):
		return
	GameState.set_flag(GameState.FLAG_PRINT_COMPLETED, true)
	GameState.print_progress = PRINT_DURATION
	GameState.notification_requested.emit("Заявление в лотке принтера")
	_show_tray(true)
	_sync_from_state()
