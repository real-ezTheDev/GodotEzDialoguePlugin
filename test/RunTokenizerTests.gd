#!/usr/bin/env -S godot -s
## Headless test runner for DialogueTokenizer.
##
## Run from the project root:
##   godot --headless -s test/RunTokenizerTests.gd

extends "res://addons/ez_dialogue/dialogue_test/test_runner.gd"

const _DialogueCommand   = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_command.gd")
const _DialogueParser    = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_parser.gd")
const _DialogueNode      = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_node.gd")
const _DialogueResource  = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_resource.gd")
const _DialogueTokenizer = preload("res://addons/ez_dialogue/dialogue_tokenizer.gd")


func _get_suite_name() -> String:
	return "Tokenizer Tests"


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_node(node_name: String, script: String) -> DialogueNode:
	var node := DialogueNode.new()
	node.name = node_name
	node.commands_raw = script
	return node

func _new_tokenizer():
	return _DialogueTokenizer.new()


# ── Tests ─────────────────────────────────────────────────────────────────────

func test_single_display_text() -> void:
	var node := _make_node("Start", "Hello world")
	var tokenizer = _new_tokenizer()
	var result = tokenizer.tokenize_node(node)

	assert_eq(result.size(), 1, "should produce 1 token entry")
	assert_eq(result[0]["token"], "start_1", "token format")
	assert_eq(result[0]["source_text"], "Hello world", "source text")
	assert_eq(result[0]["node_name"], "Start", "node name preserved")
	assert_eq(result[0]["index"], 1, "index starts at 1")


func test_multiple_display_texts() -> void:
	var node := _make_node("Quest Node", "First line\n---\nSecond line")
	var tokenizer = _new_tokenizer()
	var result = tokenizer.tokenize_node(node)

	assert_eq(result.size(), 2, "should produce 2 token entries")
	assert_eq(result[0]["token"], "quest_node_1", "first token normalized")
	assert_eq(result[1]["token"], "quest_node_2", "second token sequential")
	assert_eq(result[0]["index"], 1, "first index")
	assert_eq(result[1]["index"], 2, "second index")


func test_prompt_tokens() -> void:
	var node := _make_node("Choices", "Pick one\n?> Option A {}\n?> Option B {}")
	var tokenizer = _new_tokenizer()
	var result = tokenizer.tokenize_node(node)

	# Should have 1 display text + 2 prompts
	assert_eq(result.size(), 3, "should produce 3 entries")
	assert_eq(result[0]["token"], "choices_1", "display text token")
	assert_eq(result[1]["token"], "choices_choice_1", "first choice token")
	assert_eq(result[2]["token"], "choices_choice_2", "second choice token")
	assert_eq(result[1]["source_text"], " Option A ", "choice source text")
	assert_eq(result[2]["source_text"], " Option B ", "choice source text")


func test_name_normalization() -> void:
	var node := _make_node("My Cool Node", "Hello")
	var tokenizer = _new_tokenizer()
	var result = tokenizer.tokenize_node(node)

	assert_eq(result[0]["token"], "my_cool_node_1", "spaces to underscores, lowercase")
	assert_eq(result[0]["node_name"], "My Cool Node", "original name preserved")


func test_empty_node() -> void:
	var node := _make_node("Empty", "")
	var tokenizer = _new_tokenizer()
	var result = tokenizer.tokenize_node(node)

	assert_eq(result.size(), 0, "empty node produces no tokens")


func test_conditional_display_text() -> void:
	var node := _make_node("Branch", "Before\n$if some_var{True text}\n$else{False text}\nAfter")
	var tokenizer = _new_tokenizer()
	var result = tokenizer.tokenize_node(node)

	# Should find display texts inside conditionals
	assert_true(result.size() >= 3, "should find texts in conditionals")
	# Verify tokens are sequential
	var display_indices: Array = []
	for entry in result:
		if not "_choice_" in entry["token"]:
			display_indices.append(entry["index"])
	for i in range(display_indices.size()):
		assert_eq(display_indices[i], i + 1, "sequential index %d" % (i + 1))


func test_variable_placeholder_preserved() -> void:
	var node := _make_node("Vars", "Hello ${player_name}, welcome!")
	var tokenizer = _new_tokenizer()
	var result = tokenizer.tokenize_node(node)

	assert_eq(result.size(), 1, "should produce 1 entry")
	assert_contains(result[0]["source_text"], "${player_name}", "placeholder preserved")
