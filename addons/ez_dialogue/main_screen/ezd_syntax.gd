@tool
extends SyntaxHighlighter

@export var textColor: Color
@export var specialColor: Color
@export var constantColor: Color
@export var operatorColor: Color

var node: DialogueNode
var lineToCommand = {}

func clear():
	node = null
	
func set_parsed_node(_node: DialogueNode):
	node = _node
	var queue = []
	queue.append_array(node.get_parse())
	lineToCommand = {}
	clear_highlighting_cache()
	while !queue.is_empty():
		var command:DialogueCommand = queue.pop_front()
		if !command.children.is_empty():
			queue.append_array(command.children)
		if !lineToCommand.has(command.start_line-1):
			lineToCommand[command.start_line-1] = []
		lineToCommand[command.start_line-1].push_back(command)

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var result = {}
	if node && !lineToCommand.has(line):
		var crawlLine = line
		while crawlLine >= 0:
			# getting previous line's last coloring information
			if lineToCommand.has(crawlLine):
				result[0] = {
					"color": _get_clolor_for_type(lineToCommand.get(crawlLine)[-1].type)
				}
				break
			crawlLine -= 1
	elif node && lineToCommand.has(line):
		for command in lineToCommand.get(line):
			if command.type == DialogueCommand.CommandType.GOTO:
				pass

			match command.type:
				DialogueCommand.CommandType.PROMPT:
					result[command.start_pos] = {
						"color": specialColor
					}
					result[command.start_pos+2] = {
						"color": textColor
					}
				DialogueCommand.CommandType.GOTO:
					result[command.start_pos] = {
						"color": specialColor
					}
					result[command.start_pos+2] = {
						"color": constantColor
					}
				_:
					result[command.start_pos] = {
						"color": _get_clolor_for_type(command.type)
					}
	
	var bracketRegex = RegEx.new()
	bracketRegex.compile("{|}|\\(|\\)")
	var lineText = get_text_edit().get_line(line)
	var searchResults = bracketRegex.search_all(lineText)
	if !searchResults.is_empty():
		for search in searchResults:
			result[search.get_start()] = {
				"color": operatorColor
			}
	
	var signalRegex = RegEx.new()
	signalRegex.compile("signal\\(([\\s\\S]*?)\\)")
	var signalParamResult = signalRegex.search_all(lineText)
	if !signalParamResult.is_empty():
		for signalSearch in signalParamResult:
			result[signalSearch.get_start(1)] = {
				"color": textColor
			}
			
	# Godot bug = color application is order sensitive.. so we must have them left to right
	var sortedResult = {}
	var keys = result.keys()
	keys.sort()
	for position in keys:
		sortedResult[position] = result[position]

	return sortedResult
	
func _get_clolor_for_type(type: DialogueCommand.CommandType) -> Color:
	match type:
		DialogueCommand.CommandType.DISPLAY_TEXT:
			return textColor
		DialogueCommand.CommandType.PAGE_BREAK:
			return specialColor
		DialogueCommand.CommandType.PROMPT:
			return specialColor
		DialogueCommand.CommandType.GOTO:
			return constantColor
		DialogueCommand.CommandType.CONDITIONAL:
			return specialColor
		DialogueCommand.CommandType.SIGNAL:
			return specialColor
		_:
			return Color(255,0,0)
