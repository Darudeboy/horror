extends Node3D
class_name CorporatePoster

const TEXT_NORMAL := "Мы ценим ваше присутствие"
const TEXT_CHANGED := "Ваше отсутствие будет замечено"

var label: Label3D


func _ready() -> void:
	add_to_group("poster")
	label = get_node_or_null("Label3D") as Label3D
	GameState.flag_changed.connect(_on_flag)
	_refresh()


func _on_flag(flag_id: String, _v: bool) -> void:
	if flag_id == GameState.FLAG_POSTER_CHANGED or flag_id == GameState.FLAG_HR_APPROVED:
		_refresh()


func _refresh() -> void:
	if label == null:
		label = get_node_or_null("Label3D") as Label3D
	if label == null:
		return
	if GameState.get_flag(GameState.FLAG_POSTER_CHANGED) or GameState.get_flag(GameState.FLAG_HR_APPROVED):
		label.text = TEXT_CHANGED
	else:
		label.text = TEXT_NORMAL
