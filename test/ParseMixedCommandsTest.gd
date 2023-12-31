extends Node2D

@export var test_dialogue: JSON

@onready var dialogue_handler: EzDialogue = $"../EzDialogue"

func _ready():
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
	dialogue_handler.start_dialogue(test_dialogue, {}, test_name)
	await _assert_response("this is a single line test.", [])
	
func _test_multi_line_plain_text():
	var test_name = "plain_text_test_multi_line"
	dialogue_handler.start_dialogue(test_dialogue, {}, test_name)
	await _assert_response("this is a multi line text.\nWhere the consequent lines are put parsed together.", [])

func _test_conditional_base_case():
	var test_name = "base_conditional_display"
	
	# conditional truthy
	dialogue_handler.start_dialogue(test_dialogue, {"test_variable": true}, test_name)
	await _assert_response("starting test.\nvariable is true.\npost conditional text pick up.", [])
	
	# conditional falsy
	dialogue_handler.start_dialogue(test_dialogue, {"test_variable": false}, test_name)
	await _assert_response("starting test.\nvariable is not true.\npost conditional text pick up.", [])

func _test_conditional_missing_variable():
	var test_name = "base_conditional_display"
	dialogue_handler.start_dialogue(test_dialogue, {}, test_name)
	
	await _assert_response("starting test.\nvariable is not true.\npost conditional text pick up.", [])

func _test_plain_transition():
	var test_name = "plain_transition_test"
	dialogue_handler.start_dialogue(test_dialogue, {}, test_name)
	await _assert_response("this is base transition test.\ntransition successful.", [])
	
func _test_conditional_transition():
	var test_name = "conditional_transition_test"

	dialogue_handler.start_dialogue(test_dialogue, {"test_variable":true}, test_name)
	await _assert_response("conditional transition test.\ntrue target reached.", [])
	
	dialogue_handler.start_dialogue(test_dialogue, {"test_variable":false}, test_name)
	await _assert_response("conditional transition test.\nelse target reached.", [])
	
func _test_choice_based_transition():
	var test_name = "choice_based_transition"
	dialogue_handler.start_dialogue(test_dialogue, {}, test_name)
	await _assert_response("choice is selected.", ["choice a", "choice b"])
	dialogue_handler.next(0)
	await _assert_response("choice A transition target.", [])
	
	dialogue_handler.start_dialogue(test_dialogue, {}, test_name)
	await _assert_response("choice is selected.", ["choice a", "choice b"])
	dialogue_handler.next(1)
	await _assert_response("choice B transition target.", [])

func _assert_custom_signal(param: String):
	var signal_param = await dialogue_handler.custom_signal_received
	assert(param == signal_param,
		'Expected custom singal:"%s",\nactual custom signal:%s' % [param , signal_param])
	
func _assert_response(response_text: String, choices: Array[String]):
	var response: DialogueResponse = await dialogue_handler.dialogue_generated
	assert(response.text == response_text,
		'Expected repsonse text:"%s",\nactual response:"%s"' % [response_text, response.text])
		
	for choice in choices:
		assert(response.choices.has(choice),
			'Expected choice text:"%s",\nnot in:%s' % [choice, response.choices])
