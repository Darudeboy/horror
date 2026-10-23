extends Node
class_name InteractionController
## First-person interaction raycast. Walls block interaction.

signal focus_changed(interactable: Interactable, text: String, can_use: bool, deny_reason: String)

@export var ray_length: float = 2.0
@export var camera_path: NodePath
@export var collide_with_areas: bool = true

var _camera: Camera3D
var _current: Interactable
var _enabled: bool = true
var player: Node


func _ready() -> void:
	player = get_parent()
	if camera_path != NodePath(""):
		_camera = get_node_or_null(camera_path) as Camera3D
	if _camera == null and player:
		_camera = player.get_node_or_null("Head/Camera3D") as Camera3D


func set_enabled(value: bool) -> void:
	_enabled = value
	if not _enabled:
		_set_current(null)


func _physics_process(_delta: float) -> void:
	if not _enabled or _camera == null or GameState.gameplay_paused:
		_set_current(null)
		return
	var space := _camera.get_world_3d().direct_space_state
	var origin := _camera.global_position
	var target := origin + (-_camera.global_transform.basis.z) * ray_length
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.collide_with_areas = collide_with_areas
	query.collide_with_bodies = true
	if player and player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		_set_current(null)
		return
	var interactable := Interactable.resolve_from_collider(hit.collider)
	_set_current(interactable)


func _set_current(interactable: Interactable) -> void:
	if _current == interactable:
		_emit_focus()
		return
	_current = interactable
	_emit_focus()


func _emit_focus() -> void:
	if _current == null:
		focus_changed.emit(null, "", false, "")
		return
	var can_use := _current.can_interact(player)
	var text := _current.get_interaction_text(player)
	var deny := ""
	if not can_use:
		deny = _current.get_deny_reason(player)
		if deny == "":
			deny = "Недоступно"
	focus_changed.emit(_current, text, can_use, deny)


func try_interact() -> bool:
	if not _enabled or _current == null or GameState.gameplay_paused:
		return false
	if _current.can_interact(player):
		_current.interact(player)
		_emit_focus()
		return true
	var reason := _current.get_deny_reason(player)
	if reason != "":
		GameState.notification_requested.emit(reason)
	_emit_focus()
	return false


func get_current() -> Interactable:
	return _current
