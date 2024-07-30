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
	_test_node_visited_tester,
	_test_custom_signal_received,
	_test_issue11_endofdialogue_detection,
	_test_variable_injection_in_text,
	_test_nested_variable_injection_in_text,
	_test_missing_nested_variable_conditional,
	_test_nested_variable_conditional,
	_test_complex_nested_variable_conditional,
	_test_null_variable_injection,
	_issue18_second_pass_expression_replacement_test
]

func _ready():
	tester = DialogueTest.new(dialogue_reader)
	add_child(tester)

	for test in tests:
		print ("Running \"" + test.get_method() + "\"...")
		await test.call()

func _test_single_line_plain_text():
	var test_name = "plain_text_test_single_line"
	tester.set_states({})
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("this is a single line test.", [], true)
	
func _test_multi_line_plain_text():
	var test_name = "plain_text_test_multi_line"
	tester.set_states({})
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("this is a multi line text.\nWhere the consequent lines are put parsed together.", [], true)
	
func _test_conditional_base_case():
	var test_name = "base_conditional_display"
	
	# conditional truthy
	tester.set_states({"test_variable": true})
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("starting test.\nvariable is true.\npost conditional text pick up.", [], true)
	
	# conditional falsy
	tester.set_states({"test_variable": false})
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("starting test.\nvariable is not true.\npost conditional text pick up.", [], true)
	
func _test_conditional_missing_variable():
	var test_name = "base_conditional_display"
	tester.set_states({})
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("starting test.\nvariable is not true.\npost conditional text pick up.", [], true)

func _test_plain_transition():
	var test_name = "plain_transition_test"
	tester.set_states({})
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("this is base transition test.\ntransition successful.", [], true)
	
func _test_conditional_transition():
	var test_name = "conditional_transition_test"
	tester.set_states({"test_variable":true})
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("conditional transition test.\ntrue target reached.", [], true)
	
	tester.set_states({"test_variable":false})
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("conditional transition test.\nelse target reached.", [], true)
	
func _test_choice_based_transition():
	var test_name = "choice_based_transition"
	tester.set_states({})
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("choice is selected.", ["choice a", "choice b"])
	await tester.resume_with_choice(0)
	tester.assert_response("choice A transition target.", [], true)
	
	tester.set_states({})
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("choice is selected.", ["choice a", "choice b"])
	await tester.resume_with_choice(1)
	tester.assert_response("choice B transition target.", [], true)
	
# Tests assert_node_visited function of dialogue tester.
func _test_node_visited_tester():
	var test_name = "node_visit_test"
	tester.set_states({})
	await tester.start_test(test_dialogue, test_name)
	tester.assert_dialogue_node_visited("node_visit_test")
	
	await tester.resume_with_choice(0)
	tester.assert_dialogue_node_visited("start_two_nodes_flow")
	tester.assert_dialogue_node_visited("two_nodes_second_node")
	tester.assert_dialogue_node_not_visited("node_visit_test")

func _test_custom_signal_received():
	var test_name = "custom_signal_test"
	tester.set_states({})
	await tester.start_test(test_dialogue, test_name)
	tester.assert_custom_signal_not_received()
	
	await tester.resume_with_choice(0)
	# one signal test
	tester.assert_custom_signal("test_signal_1,param1")
	tester.assert_response("triggering", [])
	
	# two signal test
	await tester.resume_with_choice(0)
	tester.assert_custom_signal("signal_1,1")
	tester.assert_custom_signal("signal_2,2")
	tester.assert_response("and then another signal triggers\nthe end", [], true)

func _test_issue11_endofdialogue_detection():
	var test_name = "issue11_end_of_dialogue_detection"
	var state = {"some_var": true}
	tester.set_states(state)
	await tester.start_test(test_dialogue, test_name)
	
	tester.assert_response("some text\nlong way trigger", ["one prompt"])
	await tester.resume_with_choice(0)
	tester.assert_response("reached the end.", [], true)
	state["some_var"] = false
	
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("some text\nreached the end.", [], true)

func _test_variable_injection_in_text():
	var test_name = "test_variable_injection_in_text"
	var state = {
		"test_variable": "success."
		}
	tester.set_states(state)
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("This is a variable display text.\nInject the following %s.\nyipee!"%state.test_variable, [], true)

func _test_nested_variable_injection_in_text():
	var test_name = "test_nested_variable_injection_in_text"
	var state = {
		"test_nested_variable": {
			"property1": "nested_deep"
		}
		}
	tester.set_states(state)
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("Inject the following nested_deep.", [], true)

func _test_null_variable_injection():
	var test_name = "test_variable_injection_in_text"
	var state = {}
	tester.set_states(state)
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("This is a variable display text.\nInject the following .\nyipee!", [], true)

func _test_nested_variable_conditional():
	var test_name = "test_nested_variable_conditional"
	var state = {
		"some_variable": {
			"nested_component": true
		}
		}
	tester.set_states(state)
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("about to test nested variable in conditional.\ntrue target reached.", [], true)
	
	state["some_variable"]["nested_component"] = false
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("about to test nested variable in conditional.\nelse target reached.", [], true)

func _test_missing_nested_variable_conditional():
	var test_name = "test_nested_variable_conditional"
	var state = {
		"some_variable": {}
		}
	tester.set_states(state)
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("about to test nested variable in conditional.\nelse target reached.", [], true)

func _test_complex_nested_variable_conditional():
	print("\tFirst Scenario...")
	var test_name = "test_complex_nested_variable_conditional"
	var state = {
		"some_variable": {
			"nested_component": true,
			"nested_component_2": {
				"even_deeper_component": false
			}
		},
		"second_variable": true,
		}
	tester.set_states(state)
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("about to test nested variable in conditional.\ntrue target reached.", [], true)
	
	print("\tSecond Scenario...")
	
	state["second_variable"] = false
	state["some_variable"]["nested_component_2"]["even_deeper_component"] = true
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("about to test nested variable in conditional.\ntrue target reached.", [], true)
	
	print("\tThird Scenario...")
	state["some_variable"]["nested_component_2"]["even_deeper_component"] = false
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("about to test nested variable in conditional.\nelse target reached.", [], true)

func _issue18_second_pass_expression_replacement_test():
	var test_name = "issue18_second_pass_expression_replacement_test"
	var state = {
		"variable": {
			"key1": 414,
			"key2": true,
			"key3": 3.14159265358979,
			"key4": "hello"
		},
		"variable_string": "anotherone"
	}
	tester.set_states(state)
	await tester.start_test(test_dialogue, test_name)
	tester.assert_response("starting test...\ntrue target reached.", [], true)
	
