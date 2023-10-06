@tool
class_name DialogueResource extends Resource

var dialogue_nodes: Array[DialogueNode] = []

var _name_to_node_cache = {}

func serialize():
	var res = "["
	for i in dialogue_nodes.size():
		res += dialogue_nodes[i].serialize()
		if (i < dialogue_nodes.size() - 1):
			res += ","
	res += "]"
	return res

func loadFromJson(serialized):
	dialogue_nodes = []
	for nodeJson in serialized:
		var node = DialogueNode.new()
		node.loadFromJson(nodeJson)
		dialogue_nodes.push_back(node)
	
func loadFromText(serialized: String):
	loadFromJson(JSON.parse_string(serialized))

func get_node_by_name(name: String) -> DialogueNode:
	var sanitizedQuery = name.strip_edges(true, true).to_lower()
	if !_name_to_node_cache.has(sanitizedQuery):
		for node in dialogue_nodes:
			var sanitizedName = node.name.strip_edges(true, true).to_lower()
			_name_to_node_cache[sanitizedName] = node
	
	return _name_to_node_cache[sanitizedQuery]
	
