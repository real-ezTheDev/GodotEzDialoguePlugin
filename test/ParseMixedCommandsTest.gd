extends Node2D

@export var test_dialogue: JSON
@export var dialogue_reader: EzDialogue

var tester: DialogueTest

func _ready():
	tester = DialogueTest.new(dialogue_reader)
	
	print("Running plain_text_test_single_line...")
	await _test_single_line_plain_text()
	print("PASSED.")
	
	print("Running _test_multi_line_plain_text...")
	await _test_multi_line_plain_text()
	print("PASSED.")
	
	print("Running _test_conditional_base_case...")
	await _test_conditional_base_case()
	print("PASSED.")
	
	print("Running _test_conditional_missing_variable...")
	await _test_conditional_missing_variable()
	print("PASSED.")
	
	print("running _test_plain_transition")
	await _test_plain_transition()
	print("PASSED.")
	
	print("running _test_conditional_transition")
	await _test_conditional_transition()
	print("PASSED.")
	
	print("running _test_choice_based_transition")
	await _test_choice_based_transition()
	print("PASSED.")

func _test_single_line_plain_text():
	var test_name = "plain_text_test_single_line"
	tester.set_states({})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("this is a single line test.", [])
	
func _test_multi_line_plain_text():
	var test_name = "plain_text_test_multi_line"
	tester.set_states({})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("this is a multi line text.\nWhere the consequent lines are put parsed together.", [])

func _test_conditional_base_case():
	var test_name = "base_conditional_display"
	
	# conditional truthy
	tester.set_states({"test_variable": true})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("starting test.\nvariable is true.\npost conditional text pick up.", [])
	
	# conditional falsy
	tester.set_states({"test_variable": false})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("starting test.\nvariable is not true.\npost conditional text pick up.", [])

func _test_conditional_missing_variable():
	var test_name = "base_conditional_display"
	tester.set_states({})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("starting test.\nvariable is not true.\npost conditional text pick up.", [])

func _test_plain_transition():
	var test_name = "plain_transition_test"
	tester.set_states({})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("this is base transition test.\ntransition successful.", [])
	
func _test_conditional_transition():
	var test_name = "conditional_transition_test"
	tester.set_states({"test_variable":true})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("conditional transition test.\ntrue target reached.", [])
	
	tester.set_states({"test_variable":false})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("conditional transition test.\nelse target reached.", [])
	
func _test_choice_based_transition():
	var test_name = "choice_based_transition"
	tester.set_states({})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("choice is selected.", ["choice a", "choice b"])
	tester.resume_with_choice(0)
	await tester.assert_response("choice A transition target.", [])
	
	tester.set_states({})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("choice is selected.", ["choice a", "choice b"])
	tester.resume_with_choice(1)
	await tester.assert_response("choice B transition target.", [])

