@tool
class_name EzDialogueReader extends Node

## (This signal no longer triggers. Check for boolean value DialogueResponse.eod_reached from dialogue_generated signal instead.)
## Emitted when the end of the dialogue is reached and
## no more dialogue needs to be processed.
## @deprecated 
signal end_of_dialogue_reached()

## Emitted when the current "page" of dialogue is processed.
## [param response] includes simple [param text] response,
## and dialogue choices if applicable.
signal dialogue_generated(response: DialogueResponse)

## Emitted when the dialogue reads a command for custom signal.
## [param value] is a String value used within [param signal] dialogue command.
##
## ie. if you wrote [param signal(value1,value2,value3)], [param value] = [param "value1,value2,value3"]
signal custom_signal_received(value)

@onready var is_running = false
@onready var _resource_cache: Dictionary = {}
@onready var history_stack_size = 100

var _processing_dialogue: DialogueResource
var _executing_command_stack: Array[DialogueCommand]
var dialogue_visit_history: Array[String]

# Actions for each choice index is stored here while
# waiting for caller response on choice selection.
var _pending_choice_actions: Array
var _stateReference: Dictionary

func _process(delta):
	if is_running:
		var response = DialogueResponse.new()
		while is_running:
			if _executing_command_stack.is_empty():
				is_running = false
				if _pending_choice_actions.is_empty():
					response.eod_reached = true
					end_of_dialogue_reached.emit()
				break
				
			_process_command(_executing_command_stack.pop_front(), response)

		dialogue_generated.emit(response)

## Load and start processing the dialogue.
##
## [param dialogue] dialogue JSON file generated by EzDialogue plugin.
## 
## [param state] Dictionary of game state data that is accessible
## and manipulatable by the dialogue process.
##
## [param start_node] name of the dialogue node the process should begin with.
## The default starting node is [param "start"].
func start_dialogue(
	dialogue: JSON, state: Dictionary, starting_node_name = "start"):
	
	_load_dialogue(dialogue)
	var starting_node = _processing_dialogue.get_node_by_name(starting_node_name)
	_executing_command_stack = starting_node.get_parse()
	_pending_choice_actions = []
	dialogue_visit_history = [starting_node.name]
	_stateReference = state
	is_running = true

func _load_dialogue(dialogue: JSON):
	if !_resource_cache.has(dialogue.resource_path):
		var dialogueResource = DialogueResource.new()
		dialogueResource.loadFromJson(dialogue.data)
		_resource_cache[dialogue.resource_path] = dialogueResource
	_processing_dialogue = _resource_cache[dialogue.resource_path]

## Begin processing next step/page of the dialogue.
## the call is ignored if the previous start/run of dialogue is not finished.
## Dialogue process is considered "finished" and ready to move on to next
## if [signal EzDialogue.dialogue_generated] is emited.	
## 
## [param choice_index] index number of the dialogue choice to select from
## the previous response. If the previous Dialogue resoponse doesn't require
## a choice, this parameter is ignored and the next dialogue is processed.
# Provide choice index from the response if relevant.
func next(choice_index: int = 0):
	if is_running:
		return
	
	dialogue_visit_history = []
	if choice_index >= 0 && choice_index < _pending_choice_actions.size():
		# select a choice
		var commands = _pending_choice_actions[choice_index] as Array[DialogueCommand]
		commands.append_array(_executing_command_stack)
		_executing_command_stack = commands
		
		# clear pending choices for new execution
		_pending_choice_actions = []
		is_running = true
	else:
		# resume executing existing commmand stack
		is_running = true

func _process_command(command: DialogueCommand, response: DialogueResponse):
	if command.type == DialogueCommand.CommandType.ROOT:
		var front = command.children.duplicate(true)
		front.append_array(_executing_command_stack)
		_executing_command_stack = front
	elif command.type == DialogueCommand.CommandType.SIGNAL:
		var signalValue = command.values[0]
		custom_signal_received.emit(signalValue)
	elif command.type == DialogueCommand.CommandType.BRACKET:
		# push contents of bracket into execution stack
		var front = command.children.duplicate(true)
		front.append_array(_executing_command_stack)
		_executing_command_stack = front
	elif command.type == DialogueCommand.CommandType.DISPLAY_TEXT:
		var displayText: String = _inject_variable_to_text(command.values[0].strip_edges(true,true))
		# normal text display
		response.append_text(displayText)
	elif command.type == DialogueCommand.CommandType.PAGE_BREAK:
		# page break. stop processing until further user input
		is_running = false
	elif command.type == DialogueCommand.CommandType.PROMPT:
		# choice item
		var actions: Array[DialogueCommand] = []
		var prompt: String = _inject_variable_to_text(command.values[0])
		actions.append_array(command.children)
		response.append_choice(prompt.strip_edges())
		_pending_choice_actions.push_back(actions)
	elif command.type == DialogueCommand.CommandType.GOTO:
		# jump to and run specified node
		# NOTE: GOTO is a terminating command, meaning any remaining commands
		# in the execution stack is cleared and replaced by commands in
		# the destination node.
		var destination_node = _processing_dialogue.get_node_by_name(
			command.values[0])
		_executing_command_stack = destination_node.get_parse()
		dialogue_visit_history.push_front(destination_node.name)
		if dialogue_visit_history.size() > history_stack_size:
			dialogue_visit_history.remove_at(-1)
	elif command.type == DialogueCommand.CommandType.CONDITIONAL:
		var expression = command.values[0]
		var result = _evaluate_conditional_expression(expression)
		if result:
			#drop other elif and else's
			while !_executing_command_stack.is_empty() && \
				(_executing_command_stack[0].type == DialogueCommand.CommandType.ELSE || \
				_executing_command_stack[0].type == DialogueCommand.CommandType.ELIF):
				_executing_command_stack.pop_front()
			_queue_executing_commands(command.children)
	elif command.type == DialogueCommand.CommandType.ELSE:
		_queue_executing_commands(command.children)
		
func _inject_variable_to_text(text: String):
		# replacing variable placeholders
		var requiredVariables: Array = []
		var variablePlaceholderRegex = RegEx.new()
		variablePlaceholderRegex.compile("\\${(\\S+?)}")
		var nestedVariableRegex = RegEx.new()
		nestedVariableRegex.compile("(\"\\S+?\")")
		var final_text = text
		var matchResults = variablePlaceholderRegex.search_all(final_text)
		for result in matchResults:
			var nestedResults = nestedVariableRegex.search_all(result.get_string(1))
			if nestedResults.size()>0:
				requiredVariables.push_back(_nested_state_reference(result.get_string(1),nestedResults))
			else:
				requiredVariables.push_back(result.get_string(1))
		
		for variable in requiredVariables:
			var value = "" 
			var variable_name_string = ""
			if variable is Array:
				value = _recursion_search_inject(_stateReference,variable,1)
				if not value is String:
					value = str(value)
				variable_name_string = variable[0]
			else:
				value = _stateReference.get(variable)
				variable_name_string = variable
				
			if value:
				if not value is String:
					value = str(value)
				final_text = final_text.replace(
					"${%s}"%variable_name_string, value)
			else:
				final_text = final_text.replace(
					"${%s}"%variable_name_string, "")
		return final_text

func _queue_executing_commands(commands: Array[DialogueCommand]):
	var copy = commands.duplicate(true)
	copy.append_array(_executing_command_stack)
	_executing_command_stack = copy

func _evaluate_conditional_expression(expression: String):
	# initial version of conditional expression...
	# only handle order of operation and && and ||
	var properties = _stateReference.keys()
	var evaluation = Expression.new()
	var availableVariables: Array[String] = []
	var workingExpression = expression
	var variableValues = []
	
	var requiredVariables = []
	var variable_pattern = RegEx.new()
	variable_pattern.compile("[\"a-zA-Z_\\d]+(\\[\"[a-zA-Z_\\d]+?\"\\])*")
	var match_results = variable_pattern.search_all(expression)
	var nestedVariableRegex = RegEx.new()
	nestedVariableRegex.compile("(\"\\S+?\")")
	
	for variable_match in match_results:
		var extracted_pattern = variable_match.get_string(0)
		if ["true", "false"].has(extracted_pattern)\
			|| extracted_pattern.is_valid_float()\
			|| extracted_pattern.is_valid_int() \
			|| extracted_pattern.begins_with("\""):
			continue

		var nestedResults = nestedVariableRegex.search_all(extracted_pattern)
		if nestedResults.size() > 0:
			requiredVariables.push_back(
				_nested_state_reference(variable_match.get_string(0), nestedResults))
		else:
			requiredVariables.push_back(variable_match.get_string(0))

	for variable in requiredVariables:
		var value = "" 
		if variable is Array:
			value = _recursion_search_inject(_stateReference,variable,1)
			
			if not value is String :
				value = str(value)
			else:
				value = "\"" + value + "\""

			workingExpression = workingExpression.replace(
				variable[0], value)
		else:
			value = _stateReference.get(variable)
			if not value is String:
				value = str(value)
			else:
				value = "\"" + value + "\""
			workingExpression = workingExpression.replace(
				variable, value)
		
	for property in properties:
		availableVariables.push_back(property)
		variableValues.push_back(_stateReference.get(property))
	
	var parse_error = evaluation.parse(workingExpression, PackedStringArray(availableVariables))
	var result = evaluation.execute(variableValues)
	if evaluation.has_execute_failed():
		printerr("Conditional expression '%s' did not parse/execute correctly with state: %s"%[expression, variableValues])
		# failed expression statement is assumed falsy.
		return false
	return result

#region Added Functions
func _recursion_search_inject(startingPoint,searchKey,count):
	#keep recursing into a entry till hitting anything that's count is the same size as the searchKey array or not a dictionary or array
	var returnVal = startingPoint
	if count < searchKey.size():
		if startingPoint.has(searchKey[count]):
			returnVal = startingPoint[searchKey[count]]
			if returnVal is Dictionary or returnVal is Array:
				returnVal = _recursion_search_inject(returnVal,searchKey,count+1)
		else:
			printerr("Missing key %s"%searchKey[count])
			return null
	return returnVal

func _nested_state_reference(key: String, nestedKey: Array[RegExMatch], inject = true):
	#finds all the keys of a expression or ${variable}
	var temp = [key]
	if inject:
		temp.append(key.left(key.find("[")))

	for i in nestedKey:
		temp.append(i.get_string(1).replace("\"",""))
	return temp
