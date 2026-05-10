@tool
class_name EzDialogue extends EzDialogueReader

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	super._process(delta)
	pass


# --- Localization API ---

## Tokenize a DialogueResource and return structured token entries.
## Each entry contains: token, source_text, node_name, index.
func tokenize(resource: DialogueResource) -> Array[Dictionary]:
	return DialogueTokenizer.new().tokenize(resource)


## Tokenize a single DialogueNode and return its token entries.
func tokenize_node(node: DialogueNode) -> Array[Dictionary]:
	return DialogueTokenizer.new().tokenize_node(node)


## Export tokens to a CSV file at the given path.
## Returns OK on success, appropriate error code on failure.
func export_csv(resource: DialogueResource, file_path: String) -> Error:
	return DialogueTokenizer.new().export_csv(resource, file_path)


## Import translations from a CSV file for a given locale.
## Returns OK on success, appropriate error code on failure.
func import_csv(locale: String, file_path: String) -> Error:
	return load_translation_csv(locale, file_path)
