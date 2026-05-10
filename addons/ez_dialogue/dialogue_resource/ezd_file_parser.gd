@tool
class_name EzdFileParser extends RefCounted

## Parses an .ezd plain-text file into a DialogueResource.
##
## The .ezd format uses [node: name] headers to separate dialogue nodes.
## See EZD_FORMAT.md for the full specification.

const NODE_HEADER_PATTERN := "^\\[node:\\s*([^,\\]]+)(?:,\\s*position:\\s*([\\d.]+)\\s*,\\s*([\\d.]+))?\\s*\\]$"

var _header_regex: RegEx


func _init():
	_header_regex = RegEx.new()
	_header_regex.compile(NODE_HEADER_PATTERN)


## Parse an .ezd file from a file path and return a DialogueResource.
func parse_file(path: String) -> DialogueResource:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("EzdFileParser: Could not open file: " + path)
		return null
	var content := file.get_as_text()
	return parse_text(content)


## Parse .ezd content from a string and return a DialogueResource.
func parse_text(content: String) -> DialogueResource:
	var resource := DialogueResource.new()
	var lines := content.replace("\r\n", "\n").replace("\r", "\n").split("\n")

	var current_node: DialogueNode = null
	var current_body_lines: PackedStringArray = []
	var node_id := 0
	var default_x := 100.0
	var default_y := 60.0
	var default_y_step := 140.0

	for line in lines:
		var header_match := _header_regex.search(line)
		if header_match:
			# Finalize previous node
			if current_node != null:
				current_node.commands_raw = _join_body(current_body_lines)
				resource.dialogue_nodes.push_back(current_node)

			# Start new node
			current_node = DialogueNode.new()
			current_node.id = node_id
			current_node.name = header_match.get_string(1).strip_edges()
			current_node.gnode_name = current_node.name.strip_edges().to_lower()

			# Position: use metadata if provided, otherwise auto-layout
			if header_match.get_string(2) != "":
				current_node.position = Vector2(
					float(header_match.get_string(2)),
					float(header_match.get_string(3)))
			else:
				current_node.position = Vector2(default_x, default_y + node_id * default_y_step)

			current_body_lines = []
			node_id += 1
		else:
			if current_node != null:
				current_body_lines.push_back(line)

	# Finalize last node
	if current_node != null:
		current_node.commands_raw = _join_body(current_body_lines)
		resource.dialogue_nodes.push_back(current_node)

	return resource


## Serialize a DialogueResource to .ezd format string.
static func serialize(resource: DialogueResource) -> String:
	var output := ""
	for i in resource.dialogue_nodes.size():
		var node: DialogueNode = resource.dialogue_nodes[i]
		# Header
		if node.position != Vector2.ZERO:
			output += "[node: %s, position: %s, %s]\n" % [
				node.name,
				str(node.position.x),
				str(node.position.y)]
		else:
			output += "[node: %s]\n" % node.name

		# Body
		if not node.commands_raw.is_empty():
			output += node.commands_raw
			if not node.commands_raw.ends_with("\n"):
				output += "\n"

		# Blank line between nodes for readability
		if i < resource.dialogue_nodes.size() - 1:
			output += "\n"

	return output


## Join body lines, stripping leading/trailing blank lines from the body.
func _join_body(lines: PackedStringArray) -> String:
	var joined := "\n".join(lines)
	# Strip leading and trailing blank lines (but preserve internal ones)
	while joined.begins_with("\n"):
		joined = joined.substr(1)
	while joined.ends_with("\n"):
		joined = joined.left(joined.length() - 1)
	return joined
