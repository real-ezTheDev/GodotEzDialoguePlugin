extends Node2D

@export var test_dialogue: JSON
@export var dialogue_reader: EzDialogue

var tester: DialogueTest

var tests: Array[Callable] = [
	_test_single_line_plain_text,
	_test_multi_line_plain_text,
	_test_conditional_base_case,
	_test_conditional_missing_variable,
	_test_plain_transition,
	_test_conditional_transition,
	_test_choice_based_transition,
	_test_node_visited_tester
]

func _ready():
	tester = DialogueTest.new(dialogue_reader)
	
	for test in tests:
		print ("Running \"" + test.get_method() + "\"...")
		var test_result = await test.call()
		if test_result == null: 
			print_rich("[color=red][b]FAILED[/b][/color]")
		else:
			print_rich("[color=green][b]PASSED[/b][/color]")
		

func _test_single_line_plain_text():
	var test_name = "plain_text_test_single_line"
	tester.set_states({})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("this is a single line test.", [])
	return true
	
func _test_multi_line_plain_text():
	var test_name = "plain_text_test_multi_line"
	tester.set_states({})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("this is a multi line text.\nWhere the consequent lines are put parsed together.", [])
	return true
	
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

	return true
	
func _test_conditional_missing_variable():
	var test_name = "base_conditional_display"
	tester.set_states({})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("starting test.\nvariable is not true.\npost conditional text pick up.", [])
	return true

func _test_plain_transition():
	var test_name = "plain_transition_test"
	tester.set_states({})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("this is base transition test.\ntransition successful.", [])
	return true
	
func _test_conditional_transition():
	var test_name = "conditional_transition_test"
	tester.set_states({"test_variable":true})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("conditional transition test.\ntrue target reached.", [])
	
	tester.set_states({"test_variable":false})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_response("conditional transition test.\nelse target reached.", [])
	return true
	
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
	return true
	
# Tests assert_node_visited function of dialogue tester.
func _test_node_visited_tester():
	var test_name = "node_visit_test"
	tester.set_states({})
	tester.start_test(test_dialogue, test_name)
	await tester.assert_dialogue_node_visited("node_visit_test")
	
	tester.resume_with_choice(0)
	await tester.assert_dialogue_node_visited("start_two_nodes_flow")
	await tester.assert_dialogue_node_visited("two_nodes_second_node")
	await tester.assert_dialogue_node_not_visited("node_visit_test")

	return true


