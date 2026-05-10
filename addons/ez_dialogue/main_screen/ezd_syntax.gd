@tool
extends SyntaxHighlighter

@export var textColor: Color
@export var specialColor: Color
@export var constantColor: Color
@export var operatorColor: Color
@export var expressionColor: Color  ## Color for conditional expressions (e.g. the condition after $if)
@export var variableColor: Color    ## Color for ${variable} injections inside text

var node: DialogueNode
var lineToCommand = {}

# Pre-compiled regex — avoids recompiling on every line render.
var _bracket_regex: RegEx
var _signal_full_regex: RegEx   # matches full signal(...) to color keyword + parens
var _signal_param_regex: RegEx  # matches only the params inside signal(...)
var _variable_inject_regex: RegEx  # matches ${...} variable injections

func _init():
	_bracket_regex = RegEx.new()
	_bracket_regex.compile("[{}]")

	_signal_full_regex = RegEx.new()
	_signal_full_regex.compile("signal\\(([\\s\\S]*?)\\)")

	_signal_param_regex = RegEx.new()
	_signal_param_regex.compile("(?<=signal\\()([\\s\\S]*?)(?=\\))")

	_variable_inject_regex = RegEx.new()
	_variable_inject_regex.compile("\\$\\{\\S+?\\}")

func clear():
	node = null

func set_parsed_node(_node: DialogueNode):
	node = _node
	var queue = []
	queue.append_array(node.get_parse())
	lineToCommand = {}
	clear_highlighting_cache()
	while !queue.is_empty():
		var command: DialogueCommand = queue.pop_front()
		if !command.children.is_empty():
			queue.append_array(command.children)
		var line_key = command.start_line - 1
		if !lineToCommand.has(line_key):
			lineToCommand[line_key] = []
		lineToCommand[line_key].push_back(command)

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var result = {}
	var lineText: String = get_text_edit().get_line(line)

	if node == null:
		return result

	if !lineToCommand.has(line):
		# Blank line or a line with no parsed commands — default to textColor.
		result[0] = { "color": textColor }
	else:
		for command in lineToCommand.get(line):
			match command.type:
				DialogueCommand.CommandType.PROMPT:
					# "?>" operator in specialColor, then prompt text in textColor.
					result[command.start_pos] = { "color": specialColor }
					result[command.start_pos + 2] = { "color": textColor }

				DialogueCommand.CommandType.GOTO:
					# "->" operator in specialColor, then node name in constantColor.
					result[command.start_pos] = { "color": specialColor }
					result[command.start_pos + 2] = { "color": constantColor }

				DialogueCommand.CommandType.CONDITIONAL:
					# "$if" keyword in specialColor, expression in expressionColor.
					result[command.start_pos] = { "color": specialColor }
					# expression starts after "$if" (3 chars)
					result[command.start_pos + 3] = { "color": expressionColor }

				DialogueCommand.CommandType.ELSE:
					# "$else" keyword in specialColor.
					result[command.start_pos] = { "color": specialColor }

				DialogueCommand.CommandType.ELIF:
					# "$elif" keyword in specialColor, expression in expressionColor.
					result[command.start_pos] = { "color": specialColor }
					result[command.start_pos + 5] = { "color": expressionColor }

				DialogueCommand.CommandType.PAGE_BREAK:
					# "---" entirely in specialColor.
					result[command.start_pos] = { "color": specialColor }

				DialogueCommand.CommandType.SIGNAL:
					# "signal" keyword colored as specialColor.
					# Params and brackets are handled below by the signal regex pass.
					result[command.start_pos] = { "color": specialColor }

				DialogueCommand.CommandType.DISPLAY_TEXT:
					result[command.start_pos] = { "color": textColor }

				DialogueCommand.CommandType.BRACKET:
					# Brackets themselves are handled by the bracket regex pass below.
					pass

				DialogueCommand.CommandType.ROOT:
					pass

				_:
					result[command.start_pos] = { "color": textColor }

	# --- Bracket / paren coloring pass ---
	# Only color brackets as operators on lines that contain structural commands
	# ($if, $elif, $else, prompt, signal) or are bracket-only lines (just "}").
	# Plain text brackets in dialogue should stay textColor.
	var has_structural_command := false
	if lineToCommand.has(line):
		for cmd in lineToCommand.get(line):
			if cmd.type == DialogueCommand.CommandType.CONDITIONAL \
					or cmd.type == DialogueCommand.CommandType.ELIF \
					or cmd.type == DialogueCommand.CommandType.ELSE \
					or cmd.type == DialogueCommand.CommandType.PROMPT \
					or cmd.type == DialogueCommand.CommandType.SIGNAL \
					or cmd.type == DialogueCommand.CommandType.BRACKET:
				has_structural_command = true
				break

	# A line with only "}" (possibly indented) is a structural bracket close.
	if not has_structural_command and lineText.strip_edges() == "}":
		has_structural_command = true

	if has_structural_command:
		var bracketResults = _bracket_regex.search_all(lineText)
		for match in bracketResults:
			result[match.get_start()] = { "color": operatorColor }

	# --- signal(...) coloring pass ---
	# Color "signal" keyword as specialColor, parens as operatorColor,
	# and the params inside as textColor.
	var signalResults = _signal_full_regex.search_all(lineText)
	for match in signalResults:
		# "signal" keyword
		result[match.get_start()] = { "color": specialColor }
		# opening "("
		var open_paren_pos = match.get_start() + 6  # len("signal") == 6
		result[open_paren_pos] = { "color": operatorColor }
		# params
		if match.get_string(1).length() > 0:
			result[open_paren_pos + 1] = { "color": textColor }
		# closing ")"
		var close_paren_pos = match.get_end() - 1
		result[close_paren_pos] = { "color": operatorColor }

	# --- ${variable} injection coloring pass ---
	# Highlight variable placeholders distinctly from surrounding text.
	var varResults = _variable_inject_regex.search_all(lineText)
	for match in varResults:
		result[match.get_start()] = { "color": variableColor }
		# Resume textColor after the closing '}'
		var end_pos = match.get_end()
		if end_pos < lineText.length():
			result[end_pos] = { "color": textColor }

	# Godot requires color entries to be applied left-to-right.
	var sortedResult = {}
	var keys = result.keys()
	keys.sort()
	for position in keys:
		sortedResult[position] = result[position]

	return sortedResult

func _get_color_for_type(type: DialogueCommand.CommandType) -> Color:
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
		DialogueCommand.CommandType.ELSE:
			return specialColor
		DialogueCommand.CommandType.ELIF:
			return specialColor
		DialogueCommand.CommandType.SIGNAL:
			return specialColor
		_:
			return textColor
