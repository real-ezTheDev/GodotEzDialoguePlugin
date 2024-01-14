class_name DialogueTest extends RefCounted

var dialogue_reader: EzDialogueReader
var state: Dictionary = {}

func _init(_dialogue_reader: EzDialogue):
	dialogue_reader = _dialogue_reader

# start the dialogue test from specified dialogue node.
func start_test(dialogue_json: JSON, start_node: String):
	dialogue_reader.start_dialogue(dialogue_json, state, start_node)

func resume_without_choice():
	dialogue_reader.next()
	
func resume_with_choice(choice_index: int):
	dialogue_reader.next(choice_index)

# Set state variables to be used for current dialogue test run.
# If any state variable name already exists in the test run's state,
# the value is overriden with the provided value.
func set_states(_state: Dictionary):
	state = _state
	
# Check and assert that the last "step" of the test run visited the listed dialogue nodes (as named in the EzDialogue UI).
func assert_dialogue_nodes_visited(expected_dialogue_nodes:Array[String]):
	pass
	
# Check and assert generated response texts and choices.
func assert_response(expected_display_text: String, expected_choices: Array[String]):
	var response: DialogueResponse = await dialogue_reader.dialogue_generated
	assert(response.text == expected_display_text,
		'Expected repsonse text:"%s",\nactual response:"%s"' % [expected_display_text, response.text])
		
	for choice in expected_choices:
		assert(response.choices.has(choice),
			'Expected choice text:"%s",\nnot in:%s' % [choice, response.choices])

# Check and assert custom signal with expected signal parameter is received.
func assert_custom_signal(expected_signal_parameter: String):
	pass
