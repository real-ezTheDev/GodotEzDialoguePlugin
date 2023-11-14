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
		
func _test_single_line_plain_text():
	var test_name = "plain_text_test_single_line"
	dialogue_handler.start_dialogue(test_dialogue, {}, test_name)
	await _assert_response("this is a single line test.", [])
	
func _test_multi_line_plain_text():
	var test_name = "plain_text_test_multi_line"
	dialogue_handler.start_dialogue(test_dialogue, {}, test_name)
	await _assert_response("this is a multi line text.\nWhere the consequent lines are put parsed together.", [])

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
