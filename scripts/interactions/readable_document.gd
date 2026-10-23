extends Interactable
class_name ReadableDocument
## Opens a document overlay and pauses single-player gameplay.

@export var document_id: String = "note"
@export_multiline var document_title: String = "Документ"
@export_multiline var document_body: String = "Текст документа."
@export var one_shot_flag: String = ""
@export var set_flag_on_read: String = ""


func _ready() -> void:
	interaction_prompt = "Прочитать"
	add_to_group("documents")


func can_interact(_player: Node) -> bool:
	return enabled


func _on_interact(_player: Node) -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui and ui.has_method("show_document"):
		ui.show_document(document_title, document_body)
	if set_flag_on_read != "":
		GameState.set_flag(set_flag_on_read, true)
