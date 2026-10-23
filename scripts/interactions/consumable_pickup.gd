extends Interactable
class_name ConsumablePickup
## World pickup that adds stackable consumables.

@export var item_id: String = "energy_drink"
@export var amount: int = 1
@export var pickup_label: String = "Взять"


func _ready() -> void:
	interaction_prompt = pickup_label
	add_to_group("pickups")


func can_interact(_player: Node) -> bool:
	return enabled and visible


func _on_interact(_player: Node) -> void:
	GameState.give_item(item_id, amount)
	visible = false
	enabled = false
	queue_free()
