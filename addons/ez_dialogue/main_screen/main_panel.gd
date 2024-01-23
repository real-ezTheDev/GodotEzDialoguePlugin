@tool
class_name MainDiagPanel extends Panel

@onready var name_editor = $HSplitContainer/edit_container/name_editor
@onready var content_editor = $HSplitContainer/edit_container/content_editor
@onready var edit_container = $HSplitContainer/edit_container
@onready var draw_surface = $HSplitContainer/graph_container/draw_container

@onready var dialogueNodes: Array[DialogueNode] = []
@onready var nodeToOutputs = {}
@onready var nodeToInputs = {}
@onready var workingPath = ""

signal working_path_changed(path)

var selectedDialogueNode: DialogueNode
var selectedGraphNodes: Array[GraphNode]

@onready var dialogueGraphNodePrefab = preload("res://addons/ez_dialogue/main_screen/dialogue_graph_node.tscn")
@onready var last_parse_updated_time = 0

const PARSE_UPDATE_WAIT_TIME_IN_MS = 1000 # check for parse/node graph update every 1s.

func _init_state():
	dialogueNodes = []
	nodeToOutputs = {}
	nodeToInputs = {}
	selectedDialogueNode = null
	selectedGraphNodes = []
	working_path_changed.emit("")

func _is_dirty():
	return $HSplitContainer/graph_container/HBoxContainer/dirty_marker.visible

func _mark_dirty():
	$HSplitContainer/graph_container/HBoxContainer/dirty_marker.visible = true
	$HSplitContainer/graph_container/HBoxContainer/save.disabled = false
	
func _mark_saved():
	$HSplitContainer/graph_container/HBoxContainer/dirty_marker.visible = false
	$HSplitContainer/graph_container/HBoxContainer/save.disabled = true
	
func save(force_save: bool = false):
	if !_is_dirty() && !force_save:
		return
	_update_parse()
	if workingPath.is_empty():
		$SaveFileDialog.popup()
	else:
		var save_file = FileAccess.open(workingPath, FileAccess.WRITE)
		var resource: DialogueResource = DialogueResource.new()
		resource.dialogue_nodes = dialogueNodes
		save_file.store_string(resource.serialize())
		_mark_saved()

func reset():
	#clear graph
	draw_surface.clear_connections()
	for childNode in draw_surface.get_children():
		draw_surface.remove_child(childNode)
		childNode.queue_free()
	_init_state()
	_populate_editor_from_selections([])
	#_mark_dirty()
	
func _process(delta):
	# update parse if hasn't been updated in set time.
	var time_since_last_update = Time.get_ticks_msec() - last_parse_updated_time
	if time_since_last_update - PARSE_UPDATE_WAIT_TIME_IN_MS > 0 && _is_dirty():
		_update_parse()
		last_parse_updated_time = Time.get_ticks_msec()

func _record_connection_tracker(_from: String, _to: String):
	var from = _from.to_lower()
	var to = _to.to_lower()

	if !nodeToOutputs.has(from):
		nodeToOutputs[from] = {}
	
	if !nodeToInputs.has(to):
		nodeToInputs[to] = {}
		
	nodeToOutputs[from][to] = true
	nodeToInputs[to][from] = true

func _get_dialogue_node_by_id (node_id: int):
	for node in dialogueNodes:
		if node.id == node_id:
			return node
	
func _get_dialogue_node_by_name(node_name: String) -> DialogueNode:
	for node in dialogueNodes:
		if node.name.to_lower() == node_name.to_lower():
			return node
	
	return null

func _get_dialogue_node_by_gnode_name(gnode_name: String):
	for node in dialogueNodes:
		if node.gnode_name == gnode_name:
			return node

func _add_dialogue_node(node_name = "Diag Node"):
	var dialogue = DialogueNode.new()
	dialogue.name = node_name
	if dialogueNodes.is_empty():
		dialogue.id = 0
	else:
		dialogue.id = dialogueNodes[-1].id + 1
	
	# attach number at the end (increasing by one) if the name already exists.
	var repeat_count = 1
	while (_get_dialogue_node_by_name(dialogue.name) != null):
		dialogue.name = node_name + "_" + str(repeat_count)
		repeat_count += 1
	
	dialogueNodes.push_back(dialogue)
	return dialogue
	
func _add_dialogue_node_graph(dialogue: DialogueNode, focus = false, position = null):
	var node = dialogueGraphNodePrefab.instantiate()
	node.title = dialogue.name + " #" + str(dialogue.id)
	node.name = dialogue.name.strip_edges(true, true).to_lower()
	node.set_meta("dialogue_id", dialogue.id)
	draw_surface.add_child(node)
	if focus:
		draw_surface.set_selected(node)
	if position:
		node.position_offset = position
	else:
		node.position_offset = draw_surface.scroll_offset + (draw_surface.size*0.5)
	dialogue.gnode_name = node.name
	return node

func _populate_editor_from_selections(selections: Array[GraphNode]):
	# single node selection => edit node
	if selections.size() == 1:
		name_editor.editable = true
		content_editor.editable = true
		name_editor.visible = true
		content_editor.visible = true
		
		var selected_id = selections[0].get_meta("dialogue_id")
		
		for dialogue in dialogueNodes:
			if dialogue.id == selected_id:
				selectedDialogueNode = dialogue
				_populate_editor(dialogue)
				break
		
		content_editor.syntax_highlighter.set_parsed_node(selectedDialogueNode)
	
	# 0 or multi-selection => deselect
	else: 
		_clear_editor()
		name_editor.editable = false
		content_editor.editable = false
		name_editor.visible = false
		content_editor.visible = false

func _clear_editor():
	if !name_editor.text.is_empty():
		name_editor.clear()
	if !content_editor.text.is_empty():
		content_editor.clear()

func _populate_editor(dialogue: DialogueNode):
	_clear_editor()
	if dialogue.name:
		name_editor.load_field(dialogue.name)
	
	if dialogue.commands_raw:
		content_editor.text = dialogue.commands_raw

func _process_node_out_connection_on_graph(node: DialogueNode):
		_remove_out_going_connection(node.name)
		for out_node in node.get_destination_nodes():
			var out_dialogue_node = _get_dialogue_node_by_name(out_node)
			if out_dialogue_node:
				_record_connection_tracker(node.name, out_dialogue_node.gnode_name)
				draw_surface.connect_node(node.gnode_name.to_lower(), 0, out_dialogue_node.gnode_name, 0)
			else:
				_record_connection_tracker(node.name, out_node)

func _remove_out_going_connection(nodeName: String):
	for connection in draw_surface.get_connection_list():
		if connection["from_node"] == nodeName.to_lower():
			draw_surface.disconnect_node(nodeName.to_lower(), 0, connection["to_node"].to_lower(), 0)
	
######################### UI SIGNAL RESPONSES
func _on_add_pressed():
	selectedDialogueNode = _add_dialogue_node()
	_add_dialogue_node_graph(selectedDialogueNode, true)
	_mark_dirty()

func _on_remove_pressed():
	var removingIdSet = {}
	if !selectedGraphNodes.is_empty():
		var from_nodes_for_update: Array[DialogueNode] = []
		# remove graph node from draw surface and release reference to graph node.
		for graphNode in selectedGraphNodes:
			removingIdSet[graphNode.get_meta("dialogue_id")] = true
			var in_connections = _get_incoming_connection_names(graphNode)
			from_nodes_for_update.append_array(in_connections)
			_remove_out_going_connection(graphNode.name)
			graphNode.free()

		draw_surface.set_selected(null)
		
		var keptDialogueNodes: Array[DialogueNode] = []
		for dialogueNode in dialogueNodes:
			if !removingIdSet.has(dialogueNode.id):
				keptDialogueNodes.push_back(dialogueNode)
		
		dialogueNodes = keptDialogueNodes
		
		for from_node in from_nodes_for_update:
			_process_node_out_connection_on_graph(from_node)
	
		selectedGraphNodes = []
		
		_mark_dirty()

func _on_save_pressed():
	save(true)

func _on_open_pressed():
	$OpenFileDialog.popup()

func _on_new_pressed():
	# check if save is required (check dirty)
	if _is_dirty():
		save()
	
	reset()
	
######################### EDITOR SIGNAL RESPONSES

func _on_name_editor_name_changed(old_text: String, new_text: String):
	if name_editor.has_focus():
		_mark_dirty()
		nodeToOutputs.erase(old_text.to_lower())
		
		selectedDialogueNode.name = new_text
		selectedGraphNodes[0].name = new_text.to_lower()
		selectedGraphNodes[0].title = selectedDialogueNode.name + " #" + str(selectedDialogueNode.id)
		selectedDialogueNode.gnode_name = selectedGraphNodes[0].name
		
		# error for existing name.
		var existing_diag_node = _get_dialogue_node_by_name(new_text)
		if existing_diag_node.id != selectedDialogueNode.id:
			printerr('Dialogue node name "%s" already exists. Could not resolve node connections.' % new_text)
			return

		if new_text.is_empty():
			printerr('Empty Dialogue node name found.')
			return

		# reconnect current Node to its output
		_process_node_out_connection_on_graph(selectedDialogueNode)
		
		# remove connection from other node to old name
		if nodeToInputs.has(old_text.to_lower()):
			for inputNodeName in nodeToInputs[old_text.to_lower()].keys():
				var diagNode = _get_dialogue_node_by_name(inputNodeName)
				if diagNode:
					_process_node_out_connection_on_graph(diagNode)

		# reconnect existing connection from other nodes to the current node
		if nodeToInputs.has(new_text.to_lower()):
			for inputNodeName in nodeToInputs[new_text.to_lower()].keys():
				var diagNode = _get_dialogue_node_by_name(inputNodeName)
				if diagNode:
					_process_node_out_connection_on_graph(diagNode)

func _on_content_editor_text_changed():
	if content_editor.has_focus():
		_mark_dirty()
		selectedDialogueNode.commands_raw = content_editor.text
	
func _update_parse():
	if selectedGraphNodes.is_empty():
		return

	var editingNodeName = selectedGraphNodes[0].name
	var oldOuts = []
	# Clean Old Output from Current Node Record
	for out_node in selectedDialogueNode.get_destination_nodes():
		oldOuts.push_back(out_node.to_lower())
	nodeToOutputs.erase(editingNodeName.to_lower())

	# update parsing of selected node
	selectedDialogueNode.clear_parse()
	for out_node in selectedDialogueNode.get_destination_nodes():
		while oldOuts.has(out_node):
			oldOuts.erase(out_node)
				
	for oldOut in oldOuts:
		nodeToInputs[oldOut].erase(editingNodeName.to_lower())
		if nodeToInputs[oldOut].is_empty():
			nodeToInputs.erase(oldOut)

	_process_node_out_connection_on_graph(selectedDialogueNode)
	
	if selectedDialogueNode:
		content_editor.syntax_highlighter.set_parsed_node(selectedDialogueNode)

func _get_incoming_connection_names(graphNode: GraphNode) -> Array[DialogueNode]:
	var result: Array[DialogueNode] = []
	for connection in draw_surface.get_connection_list():
		if connection["to_node"] == graphNode.name:
			result.push_back(_get_dialogue_node_by_name(connection["from_node"]))
	return result

######################### GRAPH NODE SIGNAL RESPONSES
func _on_draw_container_node_selected(node):
	selectedGraphNodes.push_front(node)
	
	_populate_editor_from_selections(selectedGraphNodes)
	_on_content_editor_text_changed()

func _on_draw_container_node_deselected(node):
	_update_parse()
	var deselecting_i = selectedGraphNodes.find(node)
	if deselecting_i >= 0:
		selectedGraphNodes.remove_at(deselecting_i)
		
	_populate_editor_from_selections(selectedGraphNodes)
	
func _on_draw_container_end_node_move():
	for gnode in selectedGraphNodes:
		_get_dialogue_node_by_gnode_name(gnode.name).position = gnode.position_offset
	
	_mark_dirty()

######################### FILE HANDLING SIGNAL RESPONSES
func _on_save_file_dialog_file_selected(path):
	var resource: DialogueResource = DialogueResource.new()
	resource.dialogue_nodes = dialogueNodes
	var save_file = FileAccess.open(path, FileAccess.WRITE)
	save_file.store_string(resource.serialize())
	_mark_saved()
	working_path_changed.emit(path)

func _on_open_file_dialog_file_selected(path):
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	var resource: DialogueResource = DialogueResource.new()
	resource.loadFromText(file.get_as_text())

	#clear graph
	draw_surface.clear_connections()
	for childNode in draw_surface.get_children():
		draw_surface.remove_child(childNode)
		childNode.queue_free()
	_init_state()
	
	dialogueNodes = resource.dialogue_nodes

	#redraw graph
	for dialogue in dialogueNodes:
		_add_dialogue_node_graph(dialogue, false, dialogue.position)
		_process_node_out_connection_on_graph(dialogue)

	_mark_saved()
	_populate_editor_from_selections(selectedGraphNodes)
	working_path_changed.emit(path)

func _on_working_path_changed(path: String):
	if path.is_empty():
		#clearing path
		workingPath = ""
		$HSplitContainer/graph_container/HBoxContainer/fileNameLbl.text = "[untitled]"
	else:	
		workingPath = path
		$HSplitContainer/graph_container/HBoxContainer/fileNameLbl.text = workingPath
