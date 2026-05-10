#!/usr/bin/env -S godot -s
## Tests for editor panel logic functions — node lookup, creation,
## connection tracking, and content search.
##
## These test the pure-logic functions from main_panel.gd without
## requiring a live GUI or scene tree with UI nodes.

extends "res://addons/ez_dialogue/dialogue_test/test_runner.gd"

const _DialogueCommand  = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_command.gd")
const _DialogueParser   = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_parser.gd")
const _DialogueNode     = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_node.gd")
const _DialogueResource = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_resource.gd")
const _DialogueResponse = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_response.gd")
const _EzDialogueReader = preload("res://addons/ez_dialogue/dialogue_reader.gd")

# We replicate the logic from main_panel.gd here since the Panel class
# can't be instantiated without its scene. These mirror the exact implementations.

var dialogueNodes: Array[DialogueNode] = []
var nodeToOutputs: Dictionary = {}
var nodeToInputs: Dictionary = {}


func _get_suite_name() -> String:
	return "Editor Logic Tests"


# ── Replicated logic from main_panel.gd ──────────────────────────────────────

func _get_dialogue_node_by_name(node_name: String) -> DialogueNode:
	for node in dialogueNodes:
		if node.name.to_lower() == node_name.to_lower():
			return node
	return null

func _get_dialogue_node_by_id(node_id: int) -> DialogueNode:
	for node in dialogueNodes:
		if node.id == node_id:
			return node
	return null

func _add_dialogue_node(node_name: String = "Diag Node") -> DialogueNode:
	var dialogue := DialogueNode.new()
	dialogue.name = node_name
	if dialogueNodes.is_empty():
		dialogue.id = 0
	else:
		dialogue.id = dialogueNodes[-1].id + 1
	var repeat_count := 1
	while _get_dialogue_node_by_name(dialogue.name) != null:
		dialogue.name = node_name + "_" + str(repeat_count)
		repeat_count += 1
	dialogueNodes.push_back(dialogue)
	return dialogue

func _record_connection_tracker(_from: String, _to: String) -> void:
	var from := _from.to_lower()
	var to := _to.to_lower()
	if !nodeToOutputs.has(from):
		nodeToOutputs[from] = {}
	if !nodeToInputs.has(to):
		nodeToInputs[to] = {}
	nodeToOutputs[from][to] = true
	nodeToInputs[to][from] = true

func _search_content_across_nodes(keyword: String) -> Array[DialogueNode]:
	var results: Array[DialogueNode] = []
	var lower_keyword := keyword.to_lower()
	for node in dialogueNodes:
		if node.commands_raw.to_lower().contains(lower_keyword):
			results.push_back(node)
		elif node.name.to_lower().contains(lower_keyword):
			results.push_back(node)
	return results


# ── Helper ────────────────────────────────────────────────────────────────────

func _reset():
	dialogueNodes = []
	nodeToOutputs = {}
	nodeToInputs = {}

func _setup_sample_nodes():
	_reset()
	var n1 := DialogueNode.new()
	n1.id = 0; n1.name = "start"; n1.commands_raw = "Hello traveller.\n?> Continue -> next"
	var n2 := DialogueNode.new()
	n2.id = 1; n2.name = "next"; n2.commands_raw = "Welcome to the village.\nsignal(play_music,theme)"
	var n3 := DialogueNode.new()
	n3.id = 2; n3.name = "quest_node"; n3.commands_raw = "$if has_quest {\n    The quest is done.\n}"
	dialogueNodes = [n1, n2, n3]


# ── Tests: Node lookup ────────────────────────────────────────────────────────

func test_get_node_by_name_exact() -> void:
	_setup_sample_nodes()
	var result := _get_dialogue_node_by_name("start")
	assert_not_null(result)
	assert_eq(result.id, 0)

func test_get_node_by_name_case_insensitive() -> void:
	_setup_sample_nodes()
	var result := _get_dialogue_node_by_name("START")
	assert_not_null(result)
	assert_eq(result.name, "start")

func test_get_node_by_name_not_found() -> void:
	_setup_sample_nodes()
	var result := _get_dialogue_node_by_name("nonexistent")
	assert_true(result == null, "returns null for missing node")

func test_get_node_by_id() -> void:
	_setup_sample_nodes()
	var result := _get_dialogue_node_by_id(2)
	assert_not_null(result)
	assert_eq(result.name, "quest_node")

func test_get_node_by_id_not_found() -> void:
	_setup_sample_nodes()
	var result := _get_dialogue_node_by_id(99)
	assert_true(result == null, "returns null for missing id")


# ── Tests: Node creation ──────────────────────────────────────────────────────

func test_add_node_first() -> void:
	_reset()
	var node := _add_dialogue_node("my_node")
	assert_eq(node.id, 0, "first node gets id 0")
	assert_eq(node.name, "my_node")
	assert_eq(dialogueNodes.size(), 1)

func test_add_node_increments_id() -> void:
	_reset()
	_add_dialogue_node("first")
	var second := _add_dialogue_node("second")
	assert_eq(second.id, 1, "second node gets id 1")

func test_add_node_duplicate_name_appends_number() -> void:
	_reset()
	_add_dialogue_node("node")
	var dup := _add_dialogue_node("node")
	assert_eq(dup.name, "node_1", "duplicate name gets _1 suffix")

func test_add_node_multiple_duplicates() -> void:
	_reset()
	_add_dialogue_node("node")
	_add_dialogue_node("node")  # becomes node_1
	var third := _add_dialogue_node("node")  # becomes node_2
	assert_eq(third.name, "node_2")


# ── Tests: Connection tracking ────────────────────────────────────────────────

func test_connection_tracker_records_output() -> void:
	_reset()
	_record_connection_tracker("start", "next")
	assert_true(nodeToOutputs.has("start"), "from node recorded")
	assert_true(nodeToOutputs["start"].has("next"), "to node in outputs")

func test_connection_tracker_records_input() -> void:
	_reset()
	_record_connection_tracker("start", "next")
	assert_true(nodeToInputs.has("next"), "to node recorded")
	assert_true(nodeToInputs["next"].has("start"), "from node in inputs")

func test_connection_tracker_case_insensitive() -> void:
	_reset()
	_record_connection_tracker("Start", "NEXT")
	assert_true(nodeToOutputs.has("start"), "lowercased from")
	assert_true(nodeToInputs.has("next"), "lowercased to")

func test_connection_tracker_multiple_outputs() -> void:
	_reset()
	_record_connection_tracker("start", "node_a")
	_record_connection_tracker("start", "node_b")
	assert_true(nodeToOutputs["start"].has("node_a"))
	assert_true(nodeToOutputs["start"].has("node_b"))


# ── Tests: Content search ─────────────────────────────────────────────────────

func test_search_finds_in_content() -> void:
	_setup_sample_nodes()
	var results := _search_content_across_nodes("traveller")
	assert_eq(results.size(), 1)
	assert_eq(results[0].name, "start")

func test_search_case_insensitive() -> void:
	_setup_sample_nodes()
	var results := _search_content_across_nodes("VILLAGE")
	assert_eq(results.size(), 1)
	assert_eq(results[0].name, "next")

func test_search_finds_in_node_name() -> void:
	_setup_sample_nodes()
	var results := _search_content_across_nodes("quest")
	assert_eq(results.size(), 1, "finds by partial name match")
	assert_eq(results[0].name, "quest_node")

func test_search_finds_multiple_nodes() -> void:
	_setup_sample_nodes()
	# "the" appears in "the village" (next) and "The quest" (quest_node)
	var results := _search_content_across_nodes("the")
	assert_true(results.size() >= 2, "finds in multiple nodes")

func test_search_no_results() -> void:
	_setup_sample_nodes()
	var results := _search_content_across_nodes("zzzzz_nonexistent")
	assert_eq(results.size(), 0)

func test_search_finds_signal_params() -> void:
	_setup_sample_nodes()
	var results := _search_content_across_nodes("play_music")
	assert_eq(results.size(), 1)
	assert_eq(results[0].name, "next")

func test_search_finds_command_keywords() -> void:
	_setup_sample_nodes()
	var results := _search_content_across_nodes("has_quest")
	assert_eq(results.size(), 1)
	assert_eq(results[0].name, "quest_node")
