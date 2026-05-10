@tool
class_name MainDiagPanel extends Panel

@onready var name_editor = $HSplitContainer/edit_container/name_editor
@onready var content_editor = $HSplitContainer/edit_container/content_editor
@onready var edit_container = $HSplitContainer/edit_container
@onready var draw_surface = $HSplitContainer/graph_container/draw_container
@onready var search_text_input: LineEdit = $HSplitContainer/graph_container/SearchBar/MarginContainer/HBoxContainer/LineEdit
@onready var search_bar = $HSplitContainer/graph_container/SearchBar

@onready var dialogueNodes: Array[DialogueNode] = []
@onready var nodeToOutputs = {}
@onready var nodeToInputs = {}
@onready var workingPath = ""
@onready var dialogueGraphNodePrefab = preload("res://addons/ez_dialogue/main_screen/dialogue_graph_node.tscn")
@onready var last_parse_updated_time = 0

signal working_path_changed(path)

var selectedDialogueNode: DialogueNode
var selectedGraphNodes: Array[GraphNode]

const PARSE_UPDATE_WAIT_TIME_IN_MS = 1000

# Search state
var _search_results: Array[DialogueNode] = []
var _search_index: int = -1
var _search_keyword: String = ""
var _search_is_jumping: bool = false


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _init_state():
	dialogueNodes = []
	nodeToOutputs = {}
	nodeToInputs = {}
	selectedDialogueNode = null
	selectedGraphNodes = []
	working_path_changed.emit("")

func _process(_delta):
	var elapsed: int = Time.get_ticks_msec() - last_parse_updated_time
	if elapsed > PARSE_UPDATE_WAIT_TIME_IN_MS and _is_dirty():
		_update_parse()
		last_parse_updated_time = Time.get_ticks_msec()

func _unhandled_key_input(event: InputEvent):
	if event is InputEventKey and event.pressed \
			and event.ctrl_pressed and event.keycode == KEY_F:
		search_text_input.grab_focus()
		search_text_input.select_all()
		get_viewport().set_input_as_handled()


# ── Dirty state ───────────────────────────────────────────────────────────────

func _is_dirty() -> bool:
	return $HSplitContainer/graph_container/HBoxContainer/dirty_marker.visible

func _mark_dirty():
	$HSplitContainer/graph_container/HBoxContainer/dirty_marker.visible = true
	$HSplitContainer/graph_container/HBoxContainer/save.disabled = false

func _mark_saved():
	$HSplitContainer/graph_container/HBoxContainer/dirty_marker.visible = false
	$HSplitContainer/graph_container/HBoxContainer/save.disabled = true


# ── File operations ───────────────────────────────────────────────────────────

func save(force_save: bool = false):
	if not _is_dirty() and not force_save:
		return
	_update_parse()
	if workingPath.is_empty():
		$SaveFileDialog.popup()
	else:
		_write_dialogue_file(workingPath)
		_mark_saved()

func reset():
	_clear_graph()
	_populate_editor_from_selections([])

func _clear_graph():
	draw_surface.clear_connections()
	for child in draw_surface.get_children():
		if child is GraphNode:
			draw_surface.remove_child(child)
			child.queue_free()
	_init_state()

## Write the current dialogue to disk in the appropriate format.
func _write_dialogue_file(path: String):
	var resource := DialogueResource.new()
	resource.dialogue_nodes = dialogueNodes
	var file := FileAccess.open(path, FileAccess.WRITE)
	if path.ends_with(".ezd"):
		file.store_string(EzdFileParser.serialize(resource))
	else:
		file.store_string(resource.serialize())

## Load a dialogue file (auto-detects format by extension).
func _load_dialogue_file(path: String) -> DialogueResource:
	if path.ends_with(".ezd"):
		return EzdFileParser.new().parse_file(path)
	else:
		var file := FileAccess.open(path, FileAccess.READ)
		var resource := DialogueResource.new()
		resource.loadFromText(file.get_as_text())
		return resource


# ── Node management ───────────────────────────────────────────────────────────

func _get_dialogue_node_by_id(node_id: int):
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
	var dialogue := DialogueNode.new()
	dialogue.name = node_name
	dialogue.id = 0 if dialogueNodes.is_empty() else dialogueNodes[-1].id + 1

	var repeat_count := 1
	while _get_dialogue_node_by_name(dialogue.name) != null:
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
	node.position_offset = position if position else draw_surface.get_center_of_graph_position()
	dialogue.gnode_name = node.name
	return node


# ── Connection tracking ───────────────────────────────────────────────────────

func _record_connection_tracker(_from: String, _to: String):
	var from := _from.to_lower()
	var to := _to.to_lower()
	if not nodeToOutputs.has(from):
		nodeToOutputs[from] = {}
	if not nodeToInputs.has(to):
		nodeToInputs[to] = {}
	nodeToOutputs[from][to] = true
	nodeToInputs[to][from] = true

func _process_node_out_connection_on_graph(node: DialogueNode):
	_remove_out_going_connection(node.name)
	for out_node in node.get_destination_nodes():
		var out_dialogue := _get_dialogue_node_by_name(out_node)
		if out_dialogue:
			_record_connection_tracker(node.name, out_dialogue.gnode_name)
			draw_surface.connect_node(node.gnode_name.to_lower(), 0, out_dialogue.gnode_name, 0)
		else:
			_record_connection_tracker(node.name, out_node)

func _remove_out_going_connection(nodeName: String):
	for conn in draw_surface.get_connection_list():
		var from := _conn_key(conn, "from")
		var to := _conn_key(conn, "to")
		if from == nodeName.to_lower():
			draw_surface.disconnect_node(nodeName.to_lower(), 0, to.to_lower(), 0)

func _get_incoming_connection_names(graphNode: GraphNode) -> Array[DialogueNode]:
	var result: Array[DialogueNode] = []
	for conn in draw_surface.get_connection_list():
		if _conn_key(conn, "to") == graphNode.name:
			result.push_back(_get_dialogue_node_by_name(_conn_key(conn, "from")))
	return result

## Extract a connection key, handling both old and new Godot 4.x formats.
func _conn_key(conn: Dictionary, which: String) -> String:
	var full_key := which + "_node"  # old format: "from_node" / "to_node"
	return conn[full_key] if conn.has(full_key) else conn[which]


# ── Editor panel ──────────────────────────────────────────────────────────────

func _populate_editor_from_selections(selections: Array[GraphNode]):
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
	else:
		_clear_editor()
		name_editor.editable = false
		content_editor.editable = false
		name_editor.visible = false
		content_editor.visible = false

func _clear_editor():
	if not name_editor.text.is_empty():
		name_editor.clear()
	if not content_editor.text.is_empty():
		content_editor.clear()

func _populate_editor(dialogue: DialogueNode):
	_clear_editor()
	if dialogue.name:
		name_editor.load_field(dialogue.name)
	if dialogue.commands_raw:
		content_editor.text = dialogue.commands_raw

func _update_parse():
	if selectedGraphNodes.is_empty():
		return

	var editing_name := selectedGraphNodes[0].name
	var old_outs := []
	for out_node in selectedDialogueNode.get_destination_nodes():
		old_outs.push_back(out_node.to_lower())
	nodeToOutputs.erase(editing_name.to_lower())

	selectedDialogueNode.clear_parse()
	for out_node in selectedDialogueNode.get_destination_nodes():
		while old_outs.has(out_node):
			old_outs.erase(out_node)

	for old_out in old_outs:
		nodeToInputs[old_out].erase(editing_name.to_lower())
		if nodeToInputs[old_out].is_empty():
			nodeToInputs.erase(old_out)

	_process_node_out_connection_on_graph(selectedDialogueNode)
	if selectedDialogueNode:
		content_editor.syntax_highlighter.set_parsed_node(selectedDialogueNode)


# ── UI signal handlers ────────────────────────────────────────────────────────

func _on_add_pressed():
	selectedDialogueNode = _add_dialogue_node()
	_add_dialogue_node_graph(selectedDialogueNode, true)
	_mark_dirty()

func _on_remove_pressed():
	if selectedGraphNodes.is_empty():
		return

	var removing_ids := {}
	var from_nodes_for_update: Array[DialogueNode] = []

	for gnode in selectedGraphNodes:
		removing_ids[gnode.get_meta("dialogue_id")] = true
		from_nodes_for_update.append_array(_get_incoming_connection_names(gnode))
		_remove_out_going_connection(gnode.name)
		gnode.free()

	draw_surface.set_selected(null)
	dialogueNodes = dialogueNodes.filter(func(n): return not removing_ids.has(n.id))

	for from_node in from_nodes_for_update:
		_process_node_out_connection_on_graph(from_node)

	selectedGraphNodes = []
	_mark_dirty()

func _on_save_pressed():
	save(true)

func _on_open_pressed():
	$OpenFileDialog.popup()

func _on_new_pressed():
	if _is_dirty():
		save()
	reset()

func _on_name_editor_name_changed(old_text: String, new_text: String):
	if not name_editor.has_focus():
		return

	_mark_dirty()
	nodeToOutputs.erase(old_text.to_lower())

	selectedDialogueNode.name = new_text
	selectedGraphNodes[0].name = new_text.to_lower()
	selectedGraphNodes[0].title = selectedDialogueNode.name + " #" + str(selectedDialogueNode.id)
	selectedDialogueNode.gnode_name = selectedGraphNodes[0].name

	var existing := _get_dialogue_node_by_name(new_text)
	if existing and existing.id != selectedDialogueNode.id:
		printerr('Dialogue node name "%s" already exists.' % new_text)
		return
	if new_text.is_empty():
		printerr('Empty Dialogue node name found.')
		return

	_process_node_out_connection_on_graph(selectedDialogueNode)

	# Reconnect nodes that reference the old or new name.
	for node_name in [old_text, new_text]:
		if nodeToInputs.has(node_name.to_lower()):
			for input_name in nodeToInputs[node_name.to_lower()].keys():
				var diag := _get_dialogue_node_by_name(input_name)
				if diag:
					_process_node_out_connection_on_graph(diag)

func _on_content_editor_text_changed():
	if content_editor.has_focus():
		_mark_dirty()
		selectedDialogueNode.commands_raw = content_editor.text

func _on_draw_container_node_selected(node):
	selectedGraphNodes.push_front(node)
	_populate_editor_from_selections(selectedGraphNodes)
	if not _search_is_jumping:
		_on_content_editor_text_changed()

func _on_draw_container_node_deselected(node):
	_update_parse()
	var idx := selectedGraphNodes.find(node)
	if idx >= 0:
		selectedGraphNodes.remove_at(idx)
	_populate_editor_from_selections(selectedGraphNodes)

func _on_draw_container_end_node_move():
	for gnode in selectedGraphNodes:
		_get_dialogue_node_by_gnode_name(gnode.name).position = gnode.position_offset
	_mark_dirty()

func _on_save_file_dialog_file_selected(path):
	if not path.ends_with(".ezd") and not path.ends_with(".json"):
		path += ".ezd"
	_write_dialogue_file(path)
	_mark_saved()
	working_path_changed.emit(path)

func _on_open_file_dialog_file_selected(path):
	var resource := _load_dialogue_file(path)
	_clear_graph()
	dialogueNodes = resource.dialogue_nodes
	for dialogue in dialogueNodes:
		_add_dialogue_node_graph(dialogue, false, dialogue.position)
		_process_node_out_connection_on_graph(dialogue)
	_mark_saved()
	_populate_editor_from_selections(selectedGraphNodes)
	working_path_changed.emit(path)

func _on_working_path_changed(path: String):
	workingPath = path if not path.is_empty() else ""
	$HSplitContainer/graph_container/HBoxContainer/fileNameLbl.text = \
		workingPath if not workingPath.is_empty() else "[untitled]"


# ── Search ────────────────────────────────────────────────────────────────────

func _on_node_search_text_submitted(text: String):
	if _search_results.is_empty() or text != _search_keyword:
		return
	_search_index = (_search_index + 1) % _search_results.size()
	_jump_to_search_result()
	search_bar.set_result_count(_search_results.size(), _search_index + 1)

func _on_node_search_text_changed(text: String):
	if text.is_empty():
		_clear_search()
		return

	_clear_search_highlights()
	_search_keyword = text
	_search_index = 0

	var exact := _get_dialogue_node_by_name(text)
	_search_results = [exact] if exact else _search_content_across_nodes(text)

	if _search_results.is_empty():
		search_bar.warn_not_found()
		return

	_apply_search_highlights()
	search_bar.set_result_count(_search_results.size(), _search_index + 1)

func _jump_to_search_result():
	if _search_results.is_empty():
		return
	var target: DialogueNode = _search_results[_search_index]
	draw_surface.center_on_node(target)
	_search_is_jumping = true
	_select_graph_node_by_dialogue(target)
	_search_is_jumping = false
	_highlight_search_in_editor(_search_keyword)

func _apply_search_highlights():
	var ids := {}
	for node in _search_results:
		ids[node.id] = true
	for child in draw_surface.get_children():
		if child is GraphNode and ids.has(child.get_meta("dialogue_id")):
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.7, 1.0, 0.15)
			style.border_color = Color(0.3, 0.7, 1.0, 0.8)
			style.set_border_width_all(2)
			style.set_corner_radius_all(4)
			child.add_theme_stylebox_override("panel", style)

func _clear_search_highlights():
	for child in draw_surface.get_children():
		if child is GraphNode:
			child.remove_theme_stylebox_override("panel")

func _clear_search():
	_clear_search_highlights()
	_search_results = []
	_search_index = -1
	_search_keyword = ""
	search_bar.clear_warn()

func _search_content_across_nodes(keyword: String) -> Array[DialogueNode]:
	var results: Array[DialogueNode] = []
	var lower := keyword.to_lower()
	for node in dialogueNodes:
		if node.commands_raw.to_lower().contains(lower) \
				or node.name.to_lower().contains(lower):
			results.push_back(node)
	return results

func _select_graph_node_by_dialogue(dialogue: DialogueNode):
	for child in draw_surface.get_children():
		if child is GraphNode and child.get_meta("dialogue_id") == dialogue.id:
			draw_surface.set_selected(child)
			break

func _highlight_search_in_editor(keyword: String):
	if content_editor.visible:
		content_editor.set_search_text(keyword)
