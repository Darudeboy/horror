extends Interactable
class_name PickupItem
## Key item pickup. Items are not consumable or droppable.

@export var item_id: String = ""
@export var grant_access: String = ""
@export var pickup_label: String = "Подобрать"


func _ready() -> void:
	interaction_prompt = pickup_label
	add_to_group("pickups")
	GameState.item_changed.connect(_on_item)
	_refresh_visibility()


func _on_item(changed_id: String, _owned: bool) -> void:
	if changed_id == item_id:
		_refresh_visibility()


func _refresh_visibility() -> void:
	# Key items only once; consumables handled by ConsumablePickup
	if item_id != "" and GameState.items.get(item_id, false):
		visible = false
		enabled = false
	else:
		visible = true
		enabled = true


func can_interact(_player: Node) -> bool:
	return enabled and not GameState.items.get(item_id, false)


func get_deny_reason(_player: Node) -> String:
	return "Уже подобрано"


func _on_interact(_player: Node) -> void:
	if GameState.items.get(item_id, false):
		return
	GameState.give_item(item_id)
	if grant_access != "":
		GameState.grant_access(grant_access)
	_refresh_visibility()
