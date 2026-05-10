#!/usr/bin/env -S godot -s
## Tests for the .ezd file format parser and serializer.

extends "res://addons/ez_dialogue/dialogue_test/test_runner.gd"

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


func _get_suite_name() -> String:
	return "EZD Format Tests"


func test_parse_node_count() -> void:
	var resource := EzdFileParser.new().parse_file(SAMPLE_EZD_PATH)
	assert_eq(resource.dialogue_nodes.size(), 3, "3 nodes parsed")


func test_parse_node_names() -> void:
	var resource := EzdFileParser.new().parse_file(SAMPLE_EZD_PATH)
	assert_eq(resource.dialogue_nodes[0].name, "start")
	assert_eq(resource.dialogue_nodes[1].name, "next")
	assert_eq(resource.dialogue_nodes[2].name, "quest_node")


func test_parse_position_metadata() -> void:
	var resource := EzdFileParser.new().parse_file(SAMPLE_EZD_PATH)
	assert_eq(resource.dialogue_nodes[1].position, Vector2(300, 200), "explicit position")
	assert_eq(resource.dialogue_nodes[2].position, Vector2(500, 200), "explicit position")


func test_parse_default_position() -> void:
	var resource := EzdFileParser.new().parse_file(SAMPLE_EZD_PATH)
	var pos: Vector2 = resource.dialogue_nodes[0].position
	assert_true(pos.x > 0, "default x > 0")
	assert_true(pos.y > 0, "default y > 0")


func test_parse_body_content() -> void:
	var resource := EzdFileParser.new().parse_file(SAMPLE_EZD_PATH)
	var body0: String = resource.dialogue_nodes[0].commands_raw
	assert_contains(body0, "Hello traveller")
	assert_contains(body0, "?> Continue -> next")
	assert_contains(body0, "?> Leave {}")

	var body1: String = resource.dialogue_nodes[1].commands_raw
	assert_contains(body1, "signal(play_music,village_theme)")
	assert_contains(body1, "$if has_quest")
	assert_contains(body1, "---")


func test_serialize_roundtrip() -> void:
	var parser := EzdFileParser.new()
	var resource := parser.parse_file(SAMPLE_EZD_PATH)
	var serialized := EzdFileParser.serialize(resource)
	var resource2 := parser.parse_text(serialized)

	assert_eq(resource2.dialogue_nodes.size(), resource.dialogue_nodes.size(), "same node count")
	for i in resource.dialogue_nodes.size():
		assert_eq(resource2.dialogue_nodes[i].name, resource.dialogue_nodes[i].name,
			"node %d name" % i)
		assert_eq(resource2.dialogue_nodes[i].commands_raw, resource.dialogue_nodes[i].commands_raw,
			"node %d body" % i)


func test_runtime_load_ezd() -> void:
	var reader := EzDialogue.new()
	get_root().add_child(reader)
	var tester := DialogueTest.new(reader)
	get_root().add_child(tester)

	tester.set_states({})
	reader.start_dialogue(SAMPLE_EZD_PATH, {}, "start")
	var response: DialogueResponse = await reader.dialogue_generated

	assert_contains(response.text, "Hello traveller")
	assert_eq(response.choices.size(), 2, "2 choices")

	reader.queue_free()
	tester.queue_free()
