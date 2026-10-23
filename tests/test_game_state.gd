extends SceneTree
## Headless smoke checks for GameState.
## Run: godot --headless --path . -s res://tests/test_game_state.gd


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		print("FAIL no GameState autoload")
		quit(1)
		return
	var ok := true
	ok = _check_items(gs) and ok
	ok = _check_approvals(gs) and ok
	ok = _check_save_roundtrip(gs) and ok
	if ok:
		print("TEST_OK")
		quit(0)
	else:
		print("TEST_FAIL")
		quit(1)


func _check_items(gs: Node) -> bool:
	gs.reset_run()
	gs.give_item(gs.ITEM_EMPLOYEE_BADGE)
	gs.give_item(gs.ITEM_EMPLOYEE_BADGE)
	if not gs.has_item(gs.ITEM_EMPLOYEE_BADGE):
		print("FAIL item")
		return false
	gs.grant_access(gs.ACCESS_ACCOUNTING)
	if not gs.has_access(gs.ACCESS_ACCOUNTING):
		print("FAIL access")
		return false
	print("PASS items")
	return true


func _check_approvals(gs: Node) -> bool:
	gs.reset_run()
	gs.set_flag(gs.FLAG_HR_APPROVED, true)
	gs.set_flag(gs.FLAG_ACCOUNTING_APPROVED, true)
	gs.set_flag(gs.FLAG_SECURITY_APPROVED, true)
	if not gs.get_flag(gs.FLAG_EXIT_UNLOCKED):
		print("FAIL exit unlock")
		return false
	print("PASS approvals")
	return true


func _check_save_roundtrip(gs: Node) -> bool:
	gs.reset_run()
	gs.give_item(gs.ITEM_PRINTED_APPLICATION)
	gs.set_flag(gs.FLAG_POWER_RESTORED, true)
	gs.checkpoint_id = "after_power"
	var d: Dictionary = gs.to_save_dict()
	gs.reset_run()
	gs.apply_save_dict(d)
	if not gs.has_item(gs.ITEM_PRINTED_APPLICATION):
		print("FAIL save item")
		return false
	if not gs.get_flag(gs.FLAG_POWER_RESTORED):
		print("FAIL save flag")
		return false
	if gs.checkpoint_id != "after_power":
		print("FAIL save cp")
		return false
	print("PASS save")
	return true
