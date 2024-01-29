class_name DialogueTest extends RefCounted

var dialogue_reader: EzDialogueReader
var state: Dictionary = {}

func _init(_dialogue_reader: EzDialogue):
	dialogue_reader = _dialogue_reader

# start the dialogue test from specified dialogue node.
func start_test(dialogue_json: JSON, start_node: String):
	dialogue_reader.start_dialogue(dialogue_json, state, start_node)

# Resume the dialogue run without specifying a choice selection.
func resume_without_choice():
	dialogue_reader.next()

# Resume test dialogue run where choice_index is selected.
# In another words, continue the test "GIVEN" that the player selected a specified choice_index.
func resume_with_choice(choice_index: int):
	dialogue_reader.next(choice_index)

# Set state variables to be used for current dialogue test run.
# If any state variable name already exists in the test run's state,
# the value is overriden with the provided value.
func set_states(_state: Dictionary):
	state = _state
	
# Check and assert that the given dialogue node has been visited since the last interaction.
# For example, if at the start of the test run 'node_1' is visited and is awaiting player response.
# Only the assertion of "node_1" would pass.
# If you continue the test by calling resume_with_choice(1) and 'node_2' is visited,
# only the assertion of "node_2" would pass. "node_1" is no longer a valid assertion since "node_1" was
# visited before the last interaction (of making a choice/resuming).
#
# In another word, on every "resume" and "start" dialogue node visit history is wiped.
# This function is for a non-dialogue-text sensitive test of the flow and logic after each interactions.
func assert_dialogue_node_visited(expected_dialogue_node:String):
	# await response to make sure the dialogue processinng for this round is finished.
	var response: DialogueResponse = await dialogue_reader.dialogue_generated
	var history_stack: Array[String] = dialogue_reader.dialogue_visit_history
	assert(history_stack.has(expected_dialogue_node),
		'Node "%s" was not visited: \n%s' % [expected_dialogue_node, history_stack])
	return true
	
func assert_dialogue_node_not_visited(dialogue_node_name: String):
	# await response to make sure the dialogue processinng for this round is finished.
	var response: DialogueResponse = await dialogue_reader.dialogue_generated
	var history_stack: Array[String] = dialogue_reader.dialogue_visit_history
	assert(!history_stack.has(dialogue_node_name),
		'Node "%s" was visited: \n%s' % [dialogue_node_name, history_stack])
	return true
	
# Check and assert generated response texts and choices.
func assert_response(expected_display_text: String, expected_choices: Array[String]):
	var response: DialogueResponse = await dialogue_reader.dialogue_generated
	assert(response.text == expected_display_text,
		'Expected repsonse text:"%s",\nactual response:"%s"' % [expected_display_text, response.text])
		
	for choice in expected_choices:
		assert(response.choices.has(	choice),
			'Expected choice text:"%s",\nnot in:%s' % [choice, response.choices])
	return true

# Check and assert custom signal with expected signal parameter is received.
func assert_custom_signal(expected_signal_parameter: String):
	return true
