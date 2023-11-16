@tool
class_name DialogueNode extends Resource

var id: int = -1
var name: String = ""
var gnode_name: String = ""
var commands_raw: String = ""
var position: Vector2 = Vector2(0, 0)
var _parsed: Array[DialogueCommand] = []

# Serialize the dialogue node resource in JSON format.
func serialize() -> String:
	var res = {
		"id": id,
		"name": name,
		"gnode_name": gnode_name,
		"commands_raw": commands_raw,
		"position": [position.x, position.y]
	}
	return JSON.stringify(res)

# Load current [DialogueNode]'s properties with the given DialogueNode JSON object
func loadFromJson(jsonObj):
	id = jsonObj["id"]
	name = jsonObj["name"]
	if jsonObj.has("gnode_name"):
		gnode_name = jsonObj["gnode_name"]
	else:
		gnode_name = name
	commands_raw = jsonObj["commands_raw"]
	if jsonObj.has("position"):
		position = Vector2(jsonObj["position"][0], jsonObj["position"][1])
	_parsed = []

# Clear the cached parsing result to force re-parse.
func clear_parse():
	_parsed = []

# Get a list of [DialogueCommand] parsed from the property [member DialogueNode.commands_raw].
func get_parse() -> Array[DialogueCommand]:
	if _parsed.is_empty():
		_parsed = DialogueParser.new().parse(commands_raw)

	return _parsed.duplicate(true)

func get_display_texts():
	var text = ""
	for parseItem in get_parse():
		if parseItem.type == DialogueCommand.CommandType.DISPLAY_TEXT:
			text += parseItem.values[0]
	return text.strip_edges(true, true)

# Retrive all the node_names that the current node could transition to based on the dialogue script.
func get_destination_nodes():
	var result = []
	var crawlStack = get_parse()
	while !crawlStack.is_empty():
		var parseItem = crawlStack.pop_front()
		for child in parseItem.children:
			crawlStack.push_front(child)
			
		if parseItem.type == DialogueCommand.CommandType.GOTO:
			var prompt = {}
		
			if !parseItem.values.is_empty():
				result.push_back(parseItem.values[0].strip_edges(true, true))

	return result
