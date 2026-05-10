#!/usr/bin/env -S godot -s
## Tests for the .ezd file format parser and serializer.

extends SceneTree

const _DialogueCommand  = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_command.gd")
const _DialogueParser   = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_parser.gd")
const _DialogueNode     = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_node.gd")
const _DialogueResource = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_resource.gd")
const _DialogueResponse = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_response.gd")
const _EzDialogueReader = preload("res://addons/ez_dialogue/dialogue_reader.gd")
const _EzDialogue       = preload("res://addons/ez_dialogue/ez_dialogue_node.gd")
const _EzdFileParser    = preload("res://addons/ez_dialogue/dialogue_resource/ezd_file_parser.gd")
const _DialogueTest     = preload("res://addons/ez_dialogue/dialogue_test/dialogue_test.gd")

const SAMPLE_EZD_PATH := "res://test/sample_dialogue.ezd"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run_all_tests.call_deferred()


func _run_all_tests() -> void:
	_test_parse_node_count()
	_test_parse_node_names()
	_test_parse_position_metadata()
	_test_parse_default_position()
	_test_parse_body_content()
	_test_serialize_roundtrip()
	_test_runtime_load_ezd()

	print("")
	print("=".repeat(50))
	print("EZD Format Tests: %d passed, %d failed" % [_passed, _failed])
	print("=".repeat(50))
	quit(1 if _failed > 0 else 0)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _assert_eq(actual, expected, context: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		printerr("[ FAIL ] %s — expected: %s, got: %s" % [context, str(expected), str(actual)])

func _assert_true(condition: bool, context: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("[ FAIL ] %s" % context)


# ── Tests ─────────────────────────────────────────────────────────────────────

func _test_parse_node_count() -> void:
	print("[ RUN  ] _test_parse_node_count")
	var parser := EzdFileParser.new()
	var resource := parser.parse_file(SAMPLE_EZD_PATH)
	_assert_eq(resource.dialogue_nodes.size(), 3, "ezd parse: 3 nodes")
	print("[ PASS ] _test_parse_node_count")


func _test_parse_node_names() -> void:
	print("[ RUN  ] _test_parse_node_names")
	var parser := EzdFileParser.new()
	var resource := parser.parse_file(SAMPLE_EZD_PATH)
	_assert_eq(resource.dialogue_nodes[0].name, "start", "ezd node 0 name")
	_assert_eq(resource.dialogue_nodes[1].name, "next", "ezd node 1 name")
	_assert_eq(resource.dialogue_nodes[2].name, "quest_node", "ezd node 2 name")
	print("[ PASS ] _test_parse_node_names")


func _test_parse_position_metadata() -> void:
	print("[ RUN  ] _test_parse_position_metadata")
	var parser := EzdFileParser.new()
	var resource := parser.parse_file(SAMPLE_EZD_PATH)
	# "next" has explicit position: 300, 200
	_assert_eq(resource.dialogue_nodes[1].position, Vector2(300, 200), "ezd node 'next' position")
	# "quest_node" has explicit position: 500, 200
	_assert_eq(resource.dialogue_nodes[2].position, Vector2(500, 200), "ezd node 'quest_node' position")
	print("[ PASS ] _test_parse_position_metadata")


func _test_parse_default_position() -> void:
	print("[ RUN  ] _test_parse_default_position")
	var parser := EzdFileParser.new()
	var resource := parser.parse_file(SAMPLE_EZD_PATH)
	# "start" has no position metadata — should get auto-layout default
	var pos: Vector2 = resource.dialogue_nodes[0].position
	_assert_true(pos.x > 0, "ezd default position: x > 0")
	_assert_true(pos.y > 0, "ezd default position: y > 0")
	print("[ PASS ] _test_parse_default_position")


func _test_parse_body_content() -> void:
	print("[ RUN  ] _test_parse_body_content")
	var parser := EzdFileParser.new()
	var resource := parser.parse_file(SAMPLE_EZD_PATH)
	# "start" node body should contain the prompt commands
	var body: String = resource.dialogue_nodes[0].commands_raw
	_assert_true(body.contains("Hello traveller"), "ezd body: contains text")
	_assert_true(body.contains("?> Continue -> next"), "ezd body: contains prompt")
	_assert_true(body.contains("?> Leave {}"), "ezd body: contains dead-end choice")
	# "next" node body should contain signal and conditional
	var body2: String = resource.dialogue_nodes[1].commands_raw
	_assert_true(body2.contains("signal(play_music,village_theme)"), "ezd body: contains signal")
	_assert_true(body2.contains("$if has_quest"), "ezd body: contains conditional")
	_assert_true(body2.contains("---"), "ezd body: contains page break")
	print("[ PASS ] _test_parse_body_content")


func _test_serialize_roundtrip() -> void:
	print("[ RUN  ] _test_serialize_roundtrip")
	var parser := EzdFileParser.new()
	var resource := parser.parse_file(SAMPLE_EZD_PATH)
	# Serialize back to .ezd format
	var serialized := EzdFileParser.serialize(resource)
	# Re-parse the serialized output
	var resource2 := parser.parse_text(serialized)
	# Should produce the same number of nodes with same names
	_assert_eq(resource2.dialogue_nodes.size(), resource.dialogue_nodes.size(),
		"roundtrip: same node count")
	for i in resource.dialogue_nodes.size():
		_assert_eq(resource2.dialogue_nodes[i].name, resource.dialogue_nodes[i].name,
			"roundtrip: node %d name matches" % i)
		_assert_eq(resource2.dialogue_nodes[i].commands_raw, resource.dialogue_nodes[i].commands_raw,
			"roundtrip: node %d body matches" % i)
	print("[ PASS ] _test_serialize_roundtrip")


func _test_runtime_load_ezd() -> void:
	print("[ RUN  ] _test_runtime_load_ezd")
	# Test that EzDialogueReader can load an .ezd file at runtime
	var reader := EzDialogue.new()
	get_root().add_child(reader)
	var tester := DialogueTest.new(reader)
	get_root().add_child(tester)

	# Load .ezd by path string
	tester.set_states({})
	reader.start_dialogue(SAMPLE_EZD_PATH, {}, "start")
	var response: DialogueResponse = await reader.dialogue_generated
	_assert_true(response.text.contains("Hello traveller"), "runtime ezd: start node text")
	_assert_true(response.choices.size() == 2, "runtime ezd: 2 choices")

	reader.queue_free()
	tester.queue_free()
	print("[ PASS ] _test_runtime_load_ezd")
