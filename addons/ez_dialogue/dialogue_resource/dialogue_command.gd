@tool
class_name DialogueCommand extends Resource

var start_line: int = 0
var start_pos: int = 0
var type: CommandType = CommandType.UNKNOWN
var values: Array = []
var children: Array[DialogueCommand] = []

enum CommandType {
	UNKNOWN, #0
	DISPLAY_TEXT, #1
	PAGE_BREAK, #2
	PROMPT, #3
	NEW_LINE, #4
	BRACKET, #5
	SPECIAL, #6
	GOTO, #7
	CONDITIONAL, #8
	EXPRESSION, #9
	ROOT, #10
	SIGNAL, #11
	ELSE, #12
	ELIF, #13
}

func _init(_line: int= 0,
	_pos: int = 0,
	_type: CommandType = CommandType.UNKNOWN,
	_values = [],
	_children: Array[DialogueCommand] = []):
	start_line = _line
	start_pos = _pos
	type = _type
	values = _values
	children = _children
	
func serialize():
	var serialized_children = []
	for i in children.size():
		serialized_children.push_back(children[i].serialize())
	return JSON.stringify({
		"start_line": start_line,
		"start_pos": start_pos,
		"type": type,
		"values": values,
		"children": serialized_children	
	}, " ")
	
func loadFromJson(jsonObj):
	start_line = jsonObj["start_line"]
	start_pos = jsonObj["start_pos"]
	type = jsonObj["type"]
	values = jsonObj["values"]
	children = []
	
	for parseJson in jsonObj["children"]:
		var parsed_item = DialogueCommand.new()
		parsed_item.loadFromJson(JSON.parse_string(parseJson))
		children.push_back(parsed_item)	

func _to_string():
	return JSON.stringify(serialize(), " ")
