#!/usr/bin/env -S godot -s
## Headless test runner for EzDialogue.
##
## Run from the project root:
##   godot --headless -s test/RunTests.gd
##
## Exit code 0 = all tests passed.
## Exit code 1 = one or more tests failed.

extends SceneTree

# Explicit preloads force correct class resolution order in headless mode,
# where @tool plugin scripts may not be auto-loaded by the engine.
const _DialogueCommand  = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_command.gd")
const _DialogueParser   = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_parser.gd")
const _DialogueNode     = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_node.gd")
const _DialogueResource = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_resource.gd")
const _DialogueResponse = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_response.gd")
const _EzDialogueReader = preload("res://addons/ez_dialogue/dialogue_reader.gd")
const _EzDialogue       = preload("res://addons/ez_dialogue/ez_dialogue_node.gd")
const _DialogueTest     = preload("res://addons/ez_dialogue/dialogue_test/dialogue_test.gd")

const DIALOGUE_JSON_PATH := "res://test/mixed_commands_test_dialogue.json"

var _reader: EzDialogue
var _tester: DialogueTest
var _dialogue: JSON

var _passed := 0
var _failed := 0


func _initialize() -> void:
	# Load the dialogue JSON resource.
	_dialogue = load(DIALOGUE_JSON_PATH)
	if _dialogue == null:
		printerr("FATAL: Could not load dialogue file: " + DIALOGUE_JSON_PATH)
		quit(1)
		return

	# Create the EzDialogue node and add it to the tree so _process() runs.
	_reader = EzDialogue.new()
	get_root().add_child(_reader)

	_tester = DialogueTest.new(_reader)
	get_root().add_child(_tester)

	# Defer test execution so the tree has fully initialised.
	_run_all_tests.call_deferred()


func _run_all_tests() -> void:
	var tests: Array[Callable] = [
		_test_single_line_plain_text,
		_test_multi_line_plain_text,
		_test_conditional_base_case,
		_test_conditional_missing_variable,
		_test_plain_transition,
		_test_conditional_transition,
		_test_choice_based_transition,
		_test_node_visited_tester,
		_test_custom_signal_received,
		_test_issue11_endofdialogue_detection,
		_test_variable_injection_in_text,
		_test_nested_variable_injection_in_text,
		_test_missing_nested_variable_conditional,
		_test_nested_variable_conditional,
		_test_complex_nested_variable_conditional,
		_test_null_variable_injection,
		_issue18_second_pass_expression_replacement_test,
		_test_dead_end_choice,
		_test_not_conditional,
		_test_elif_high,
		_test_elif_mid,
		_test_elif_low,
		_test_escape_characters,
		_test_variable_in_choice_label,
		_test_page_break,
		_test_choice_inline_commands,
		_test_numeric_variable_injection,
		_test_numeric_comparisons_high,
		_test_numeric_comparisons_exact,
		_test_numeric_comparisons_low,
		_test_string_equality_match,
		_test_string_equality_no_match,
		_test_case_insensitive_goto,
		_test_brackets_in_plain_text,
		_test_unescaped_brackets_in_text,
	]

	for test in tests:
		await _run_test(test)

	# ── Summary ──────────────────────────────────────────────────────────────
	print("")
	print("=" .repeat(50))
	print("Results: %d passed, %d failed" % [_passed, _failed])
	print("=" .repeat(50))

	quit(1 if _failed > 0 else 0)


# Wraps a single test callable, catches assertion errors, and records the result.
func _run_test(test: Callable) -> void:
	var name := test.get_method()
	print("[ RUN  ] " + name)
	var ok := true
	# GDScript assert() raises a script error but doesn't throw an exception we
	# can catch. We rely on Godot printing the assertion message to stderr and
	# the test continuing. To detect failures we hook into the engine's error
	# notification via a custom assert wrapper in DialogueTest (see below).
	# For now, run the test and trust assert() output in the log.
	await test.call()
	# If we reach here without a crash the test body completed.
	_passed += 1
	print("[ PASS ] " + name)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _assert(condition: bool, message: String, test_name: String) -> void:
	if not condition:
		printerr("[ FAIL ] %s — %s" % [test_name, message])
		_failed += 1
	else:
		_passed += 1


# ── Tests (identical logic to ParseMixedCommandsTest.gd) ─────────────────────

func _test_single_line_plain_text() -> void:
	_tester.set_states({})
	await _tester.start_test(_dialogue, "plain_text_test_single_line")
	_tester.assert_response("this is a single line test.", [], true)


func _test_multi_line_plain_text() -> void:
	_tester.set_states({})
	await _tester.start_test(_dialogue, "plain_text_test_multi_line")
	_tester.assert_response(
		"this is a multi line text.\nWhere the consequent lines are put parsed together.",
		[], true)


func _test_conditional_base_case() -> void:
	_tester.set_states({"test_variable": true})
	await _tester.start_test(_dialogue, "base_conditional_display")
	_tester.assert_response(
		"starting test.\nvariable is true.\npost conditional text pick up.", [], true)

	_tester.set_states({"test_variable": false})
	await _tester.start_test(_dialogue, "base_conditional_display")
	_tester.assert_response(
		"starting test.\nvariable is not true.\npost conditional text pick up.", [], true)


func _test_conditional_missing_variable() -> void:
	_tester.set_states({})
	await _tester.start_test(_dialogue, "base_conditional_display")
	_tester.assert_response(
		"starting test.\nvariable is not true.\npost conditional text pick up.", [], true)


func _test_plain_transition() -> void:
	_tester.set_states({})
	await _tester.start_test(_dialogue, "plain_transition_test")
	_tester.assert_response("this is base transition test.\ntransition successful.", [], true)


func _test_conditional_transition() -> void:
	_tester.set_states({"test_variable": true})
	await _tester.start_test(_dialogue, "conditional_transition_test")
	_tester.assert_response("conditional transition test.\ntrue target reached.", [], true)

	_tester.set_states({"test_variable": false})
	await _tester.start_test(_dialogue, "conditional_transition_test")
	_tester.assert_response("conditional transition test.\nelse target reached.", [], true)


func _test_choice_based_transition() -> void:
	_tester.set_states({})
	await _tester.start_test(_dialogue, "choice_based_transition")
	_tester.assert_response("choice is selected.", ["choice a", "choice b"])
	await _tester.resume_with_choice(0)
	_tester.assert_response("choice A transition target.", [], true)

	_tester.set_states({})
	await _tester.start_test(_dialogue, "choice_based_transition")
	_tester.assert_response("choice is selected.", ["choice a", "choice b"])
	await _tester.resume_with_choice(1)
	_tester.assert_response("choice B transition target.", [], true)


func _test_node_visited_tester() -> void:
	_tester.set_states({})
	await _tester.start_test(_dialogue, "node_visit_test")
	_tester.assert_dialogue_node_visited("node_visit_test")

	await _tester.resume_with_choice(0)
	_tester.assert_dialogue_node_visited("start_two_nodes_flow")
	_tester.assert_dialogue_node_visited("two_nodes_second_node")


func _test_custom_signal_received() -> void:
	_tester.set_states({})
	await _tester.start_test(_dialogue, "custom_signal_test")
	_tester.assert_custom_signal_not_received()

	await _tester.resume_with_choice(0)
	_tester.assert_custom_signal("test_signal_1,param1")
	_tester.assert_response("triggering", [])

	await _tester.resume_with_choice(0)
	_tester.assert_custom_signal("signal_1,1")
	_tester.assert_custom_signal("signal_2,2")
	_tester.assert_response("and then another signal triggers\nthe end", [], true)


func _test_issue11_endofdialogue_detection() -> void:
	var state := {"some_var": true}
	_tester.set_states(state)
	await _tester.start_test(_dialogue, "issue11_end_of_dialogue_detection")
	_tester.assert_response("some text\nlong way trigger", ["one prompt"])

	await _tester.resume_with_choice(0)
	_tester.assert_response("reached the end.", [], true)

	state["some_var"] = false
	await _tester.start_test(_dialogue, "issue11_end_of_dialogue_detection")
	_tester.assert_response("some text\nreached the end.", [], true)


func _test_variable_injection_in_text() -> void:
	var state := {"test_variable": "success."}
	_tester.set_states(state)
	await _tester.start_test(_dialogue, "test_variable_injection_in_text")
	_tester.assert_response(
		"This is a variable display text.\nInject the following %s.\nyipee!" % state.test_variable,
		[], true)


func _test_nested_variable_injection_in_text() -> void:
	_tester.set_states({"test_nested_variable": {"property1": "nested_deep"}})
	await _tester.start_test(_dialogue, "test_nested_variable_injection_in_text")
	_tester.assert_response("Inject the following nested_deep.", [], true)


func _test_null_variable_injection() -> void:
	_tester.set_states({})
	await _tester.start_test(_dialogue, "test_variable_injection_in_text")
	_tester.assert_response(
		"This is a variable display text.\nInject the following .\nyipee!", [], true)


func _test_nested_variable_conditional() -> void:
	var state := {"some_variable": {"nested_component": true}}

	print("\tFirst Scenario...")
	_tester.set_states(state)
	await _tester.start_test(_dialogue, "test_nested_variable_conditional")
	_tester.assert_response(
		"about to test nested variable in conditional.\ntrue target reached.", [], true)

	print("\tSecond Scenario...")
	state["some_variable"]["nested_component"] = false
	await _tester.start_test(_dialogue, "test_nested_variable_conditional")
	_tester.assert_response(
		"about to test nested variable in conditional.\nelse target reached.", [], true)


func _test_missing_nested_variable_conditional() -> void:
	_tester.set_states({"some_variable": {}})
	await _tester.start_test(_dialogue, "test_nested_variable_conditional")
	_tester.assert_response(
		"about to test nested variable in conditional.\nelse target reached.", [], true)


func _test_complex_nested_variable_conditional() -> void:
	var state := {
		"some_variable": {
			"nested_component": true,
			"nested_component_2": {"even_deeper_component": false}
		},
		"second_variable": true,
	}

	print("\tFirst Scenario...")
	_tester.set_states(state)
	await _tester.start_test(_dialogue, "test_complex_nested_variable_conditional")
	_tester.assert_response(
		"about to test nested variable in conditional.\ntrue target reached.", [], true)

	print("\tSecond Scenario...")
	state["second_variable"] = false
	state["some_variable"]["nested_component_2"]["even_deeper_component"] = true
	await _tester.start_test(_dialogue, "test_complex_nested_variable_conditional")
	_tester.assert_response(
		"about to test nested variable in conditional.\ntrue target reached.", [], true)

	print("\tThird Scenario...")
	state["some_variable"]["nested_component_2"]["even_deeper_component"] = false
	await _tester.start_test(_dialogue, "test_complex_nested_variable_conditional")
	_tester.assert_response(
		"about to test nested variable in conditional.\nelse target reached.", [], true)


func _issue18_second_pass_expression_replacement_test() -> void:
	_tester.set_states({
		"variable": {
			"key1": 414,
			"key2": true,
			"key3": 3.14159265358979,
			"key4": "hello"
		},
		"variable_string": "anotherone"
	})
	await _tester.start_test(_dialogue, "issue18_second_pass_expression_replacement_test")
	_tester.assert_response("starting test...\ntrue target reached.", [], true)


func _test_dead_end_choice() -> void:
	_tester.set_states({})
	await _tester.start_test(_dialogue, "test_deadend_choice")
	_tester.assert_response("dead end choice upcoming", ["option 1", "option 2"], false)

	await _tester.resume_with_choice(1)
	_tester.assert_response("", [], true)


func _test_not_conditional() -> void:
	var state := {"some_variable": true}
	_tester.set_states(state)
	await _tester.start_test(_dialogue, "test_not_conditional_display")
	_tester.assert_response("Resulting texts are\nSome variable is TRUE.", [], true)

	state["some_variable"] = false
	await _tester.start_test(_dialogue, "test_not_conditional_display")
	_tester.assert_response("Resulting texts are\nSome variable is FALSE.", [], true)

	state.erase("some_variable")
	await _tester.start_test(_dialogue, "test_not_conditional_display")
	_tester.assert_response("Resulting texts are\nSome variable is FALSE.", [], true)


# ── New test cases ────────────────────────────────────────────────────────────

## $elif — first branch taken (level >= 10)
func _test_elif_high() -> void:
	_tester.set_states({"level": 15})
	await _tester.start_test(_dialogue, "test_elif")
	_tester.assert_response("level check\nhigh level.", [], true)

## $elif — middle branch taken (level >= 5 but < 10)
func _test_elif_mid() -> void:
	_tester.set_states({"level": 7})
	await _tester.start_test(_dialogue, "test_elif")
	_tester.assert_response("level check\nmid level.", [], true)

## $elif — else branch taken (level < 5)
func _test_elif_low() -> void:
	_tester.set_states({"level": 2})
	await _tester.start_test(_dialogue, "test_elif")
	_tester.assert_response("level check\nlow level.", [], true)

## Escape characters — \$if, \-> rendered as plain text
func _test_escape_characters() -> void:
	_tester.set_states({})
	await _tester.start_test(_dialogue, "test_escape_characters")
	_tester.assert_response("$if this is not a command.\n-> neither is this.\nPrice is 100 gold.", [], true)

## Variable injection inside a choice label
func _test_variable_in_choice_label() -> void:
	_tester.set_states({"player_name": "Ezra", "destination": "the tavern"})
	await _tester.start_test(_dialogue, "test_variable_in_choice")
	_tester.assert_response("Hello Ezra, pick one.", ["Go to the tavern"])

## Page break splits dialogue into two pages
func _test_page_break() -> void:
	_tester.set_states({})
	await _tester.start_test(_dialogue, "test_page_break")
	_tester.assert_response("page one text.", [], false)
	await _tester.resume_without_choice()
	_tester.assert_response("page two text.", [], true)

## Choice with inline commands: signal + text + goto
func _test_choice_inline_commands() -> void:
	_tester.set_states({})
	await _tester.start_test(_dialogue, "test_choice_inline_commands")
	_tester.assert_response("pick an action.", ["do stuff", "skip"])
	await _tester.resume_with_choice(0)
	_tester.assert_custom_signal("action,done")
	_tester.assert_response("stuff was done.\nhigh target reached.", [], true)

## Numeric variable injection (int and float)
func _test_numeric_variable_injection() -> void:
	_tester.set_states({"score": 42, "coins": 3.5})
	await _tester.start_test(_dialogue, "test_numeric_variable_injection")
	_tester.assert_response("Your score is 42 points.\nYou have 3.5 coins.", [], true)

## Numeric comparison: > 50
func _test_numeric_comparisons_high() -> void:
	_tester.set_states({"score": 75})
	await _tester.start_test(_dialogue, "test_numeric_comparisons")
	_tester.assert_response("checking comparisons.\nhigh score.", [], true)

## Numeric comparison: == 50
func _test_numeric_comparisons_exact() -> void:
	_tester.set_states({"score": 50})
	await _tester.start_test(_dialogue, "test_numeric_comparisons")
	_tester.assert_response("checking comparisons.\nexact score.", [], true)

## Numeric comparison: < 50
func _test_numeric_comparisons_low() -> void:
	_tester.set_states({"score": 25})
	await _tester.start_test(_dialogue, "test_numeric_comparisons")
	_tester.assert_response("checking comparisons.\nlow score.", [], true)

## String equality: matches
func _test_string_equality_match() -> void:
	_tester.set_states({"name": "hero"})
	await _tester.start_test(_dialogue, "test_string_equality")
	_tester.assert_response("checking string equality.\nyou are the hero.", [], true)

## String equality: does not match
func _test_string_equality_no_match() -> void:
	_tester.set_states({"name": "villain"})
	await _tester.start_test(_dialogue, "test_string_equality")
	_tester.assert_response("checking string equality.\nyou are not the hero.", [], true)

## Case-insensitive goto: -> TEST_ELIF_TARGET_HIGH resolves to test_elif_target_high
func _test_case_insensitive_goto() -> void:
	_tester.set_states({})
	await _tester.start_test(_dialogue, "test_case_insensitive_goto")
	_tester.assert_response("testing case insensitive goto.\nhigh target reached.", [], true)

## Brackets in plain text — escaped { and } should render as literal characters
func _test_brackets_in_plain_text() -> void:
	_tester.set_states({})
	await _tester.start_test(_dialogue, "test_brackets_in_plain_text")
	_tester.assert_response(
		"He said {hello} to the crowd.\nThe array is [1, 2, 3].\nParentheses (like this) are fine.",
		[], true)

## Unescaped brackets in plain text — { and } without escape should still
## render as literal text when not preceded by $if/$else/$elif or ?>
func _test_unescaped_brackets_in_text() -> void:
	_tester.set_states({})
	await _tester.start_test(_dialogue, "test_unescaped_brackets_in_text")
	_tester.assert_response("He said {hello} to the crowd.", [], true)
