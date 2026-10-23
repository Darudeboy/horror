extends Node3D
class_name Interactable
## Common interaction contract for world objects.

@export var interaction_prompt: String = "Взаимодействовать"
@export var enabled: bool = true

signal interacted(player: Node)


func get_interaction_text(_player: Node) -> String:
	return interaction_prompt


func can_interact(_player: Node) -> bool:
	return enabled


func get_deny_reason(_player: Node) -> String:
	return ""


func interact(player: Node) -> void:
	if not can_interact(player):
		return
	interacted.emit(player)
	_on_interact(player)


func _on_interact(_player: Node) -> void:
	pass


static func resolve_from_collider(collider: Object) -> Interactable:
	## Ray may hit a child CollisionObject; walk up to find Interactable.
	var node: Node = collider as Node
	while node:
		if node is Interactable:
			return node as Interactable
		if node.has_method("get_interaction_text") and node.has_method("can_interact") and node.has_method("interact"):
			return node as Interactable
		node = node.get_parent()
	return null
