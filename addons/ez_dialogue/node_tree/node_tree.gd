class_name NodeTree


# max according to godot (https://docs.godotengine.org/en/stable/classes/class_int.html)
const MAX_INT:int = 9223372036854775807 

var rootNode:TreeNode
var dict:Dictionary = {}
var heighest_level:int
var heighest_id:int


######################### GETTERS AND SETTERS
func set_root_node(id:int) -> void:
	add_node(id)
	rootNode = dict[id]


func add_node(nodeId:int,parentId:int = -1) -> void:
	if !dict.has(nodeId):
		var node = TreeNode.new(nodeId)
		dict[nodeId] = node
		
		# connect to parent
		if parentId >= 0 && dict.has(parentId):
			(dict[parentId] as TreeNode).childrenIds.push_back(nodeId)


func remove_node(id:int) -> void:
	if dict.has(id):
		dict.erase(id)


func connect_nodes(nodeId:int,parentId:int) -> void:
	if dict.has(parentId):
		var parent:TreeNode = dict[parentId]
		parent.childrenIds.push_back(nodeId)


func disconnect_nodes(nodeId:int,parentId:int) -> void:
	if dict.has(parentId):
		var parent:TreeNode = dict[parentId]
		parent.childrenIds.erase(nodeId)


######################### TREE SEARCHING
func get_heighest_incomplete_node_id() -> int:
	heighest_id = rootNode.id
	# setting an absurdly large number
	heighest_level = MAX_INT
	check_node_completion(rootNode.id,0)
	return heighest_id


func check_node_completion(id:int,level:int) -> bool:
	# non-existant child means parent is incomplete
	if !dict.has(id):
		return false
	var node:TreeNode = dict[id]
	
	# if node has no children, it cannot be complete
	if node.childrenIds.size() == 0:
		check_level(id,level)
	
	# check all children of current node
	for childId in node.childrenIds:
		var result = check_node_completion(childId,level+1)
		if result == false:
			check_level(id,level)
	
	# node is complete if all children exist
	return true


func check_level(id:int,level:int) -> void:
	# check if node is heighest
	if level < heighest_level:
		heighest_level = level
		heighest_id = id
