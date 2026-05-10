@tool
class_name DialogueParser extends RefCounted

# Parse the given dialogue script String into
# a list of (possibly nested) [DialogueCommand]s.
func parse(dialogue_script: String) -> Array[DialogueCommand]:
	var rootParse: Array[DialogueCommand] = []
	rootParse.push_back(
		DialogueCommand.new(0, 0, DialogueCommand.CommandType.ROOT))
	var n = 0
	while n < dialogue_script.length():
		n = _parse_statement(n, dialogue_script, rootParse)
	return rootParse


# Statement parser. Returns the next index to continue parsing from.
func _parse_statement(i: int, raw: String, parseProgress: Array[DialogueCommand]) -> int:
	const CONDITIONAL_OP := "$if"
	const ELIF_OP        := "$elif"
	const ELSE_OP        := "$else"

	if i >= raw.length():
		return i

	var currentLine := raw.count("\n", 0, max(i, 1)) + 1
	var inLinePos   := i - raw.substr(0, i).rfind("\n") - 1

	# --- Escape character ---
	if _peek_and_match("\\", i, raw):
		if i + 1 >= raw.length():
			return i + 1
		_add_letters_progress(
			raw[i + 1],
			parseProgress[0].children,
			currentLine, inLinePos,
			DialogueCommand.CommandType.DISPLAY_TEXT)
		return i + 2

	# --- Prompt / choice: ?> ---
	elif _peek_and_match("?>", i, raw):
		var prompt_command := DialogueCommand.new(
			currentLine, inLinePos,
			DialogueCommand.CommandType.PROMPT, [""], [])
		var next_index := _parse_prompt_command(i + 2, raw, prompt_command)
		parseProgress[0].children.push_back(prompt_command)
		if prompt_command.children.size() > 0 \
				&& prompt_command.children[0].type == DialogueCommand.CommandType.BRACKET:
			parseProgress.push_front(prompt_command.children[0])
		return next_index

	# --- Go To: -> ---
	elif _peek_and_match("->", i, raw):
		var terminating := RegEx.new()
		terminating.compile("\\n")
		var gotoNodeName := _collect_characters(i + 2, raw, terminating)
		parseProgress[0].children.push_back(
			DialogueCommand.new(
				currentLine, inLinePos,
				DialogueCommand.CommandType.GOTO, [gotoNodeName]))
		return i + 2 + gotoNodeName.length()

	# --- Custom signal: signal(...) ---
	elif _peek_and_match("signal(", i, raw):
		var terminating := RegEx.new()
		terminating.compile("\\)")
		var signalParams := _collect_characters(i + 7, raw, terminating)
		parseProgress[0].children.push_back(
			DialogueCommand.new(
				currentLine, inLinePos,
				DialogueCommand.CommandType.SIGNAL, [signalParams]))
		var nextIndex := i + 7 + signalParams.length()
		if _peek_and_match(")", nextIndex, raw):
			nextIndex += 1
		else:
			var ep := _get_position_from_index(nextIndex, raw)
			printerr("Error at (line: %d, pos: %d): Expected ')' at end of 'signal('" \
				% [ep["line"], ep["pos"]])
		return nextIndex

	# --- $elif (must be checked before $else and $if) ---
	elif _peek_and_match(ELIF_OP, i, raw):
		return _parse_elif(i, raw, parseProgress, currentLine, inLinePos, ELIF_OP)

	# --- $if ---
	elif _peek_and_match(CONDITIONAL_OP, i, raw):
		return _parse_conditional(i, raw, parseProgress, currentLine, inLinePos, CONDITIONAL_OP)

	# --- $else ---
	elif _peek_and_match(ELSE_OP, i, raw):
		return _parse_else(i, raw, parseProgress, currentLine, inLinePos)

	# --- Opening bracket: { ---
	# Only treat { as a bracket when inside an existing bracket context (nested).
	# Top-level { in plain text is treated as a literal character.
	# Bracket creation for $if/$elif/$else/prompt is handled by their respective parsers.
	elif _is_bracket_start(i, raw) and parseProgress[0].type == DialogueCommand.CommandType.BRACKET:
		var bracket := DialogueCommand.new(
			currentLine, inLinePos, DialogueCommand.CommandType.BRACKET)
		parseProgress[0].children.push_back(bracket)
		parseProgress.push_front(bracket)
		return i + 1

	# --- Closing bracket: } ---
	elif _peek_and_match("}", i, raw) and parseProgress[0].type == DialogueCommand.CommandType.BRACKET:
		parseProgress.pop_front()
		return i + 1

	# --- Page break: --- ---
	elif _peek_and_match("---", i, raw):
		parseProgress[0].children.push_back(
			DialogueCommand.new(
				currentLine, inLinePos, DialogueCommand.CommandType.PAGE_BREAK))
		return i + 3

	# --- Plain text (bulk collection for performance) ---
	# Collect as many plain-text characters as possible in one pass instead of
	# advancing one character at a time, which was O(n) function calls for text.
	return _collect_plain_text(i, raw, parseProgress, currentLine, inLinePos)


# Collect a run of plain text up to the next special token or ${...} injection.
# Only breaks on characters that can actually START a special command:
#   \  escape
#   ?> prompt
#   -> goto  (two chars, so we check for '-' followed by '>')
#   --- page break (three chars, check '-' followed by '--')
#   $  variable injection or $if/$elif/$else
#   {  bracket open
#   }  bracket close
#   signal(  custom signal (starts with 's')
func _collect_plain_text(
		i: int, raw: String,
		parseProgress: Array[DialogueCommand],
		currentLine: int, inLinePos: int) -> int:

	# Check for a ${...} variable injection starting right here.
	var varInjectRegex := RegEx.new()
	varInjectRegex.compile("\\${\\S+?}")
	var varMatch := varInjectRegex.search(raw, i)
	if varMatch && varMatch.get_start() == i:
		_add_letters_progress(
			varMatch.get_string(),
			parseProgress[0].children,
			currentLine, inLinePos,
			DialogueCommand.CommandType.DISPLAY_TEXT)
		return i + varMatch.get_string().length()

	# Collect plain characters until we hit a special token.
	var inside_bracket := parseProgress[0].type == DialogueCommand.CommandType.BRACKET
	var j := i
	while j < raw.length():
		var c := raw[j]
		match c:
			"\\":
				break
			"?":
				if _peek_and_match("?>", j, raw):
					break
			"-":
				# Only break for "->" (goto) or "---" (page break).
				if _peek_and_match("->", j, raw) or _peek_and_match("---", j, raw):
					break
			"$":
				break
			"{":
				if inside_bracket:
					break
			"}":
				if inside_bracket:
					break
			"s":
				if _peek_and_match("signal(", j, raw):
					break
		j += 1

	if j > i:
		var chunk := raw.substr(i, j - i)
		_add_letters_progress(
			chunk,
			parseProgress[0].children,
			currentLine, inLinePos,
			DialogueCommand.CommandType.DISPLAY_TEXT)
		return j

	# Single unrecognised character — advance by one to avoid an infinite loop.
	_add_letters_progress(
		raw[i],
		parseProgress[0].children,
		currentLine, inLinePos,
		DialogueCommand.CommandType.DISPLAY_TEXT)
	return i + 1


# Parse a $if block.
func _parse_conditional(
		i: int, raw: String, parseProgress: Array[DialogueCommand],
		currentLine: int, inLinePos: int, op: String) -> int:

	var terminating := RegEx.new()
	terminating.compile("->|{")
	var expression_string := _collect_characters(i + op.length(), raw, terminating)
	var conditional_children: Array[DialogueCommand] = []
	var result := DialogueCommand.new(
		currentLine, inLinePos,
		DialogueCommand.CommandType.CONDITIONAL,
		[expression_string],
		conditional_children)
	parseProgress[0].children.push_back(result)

	var nextIndex := i + op.length() + expression_string.length()
	var ep := _get_position_from_index(nextIndex, raw)

	if _is_bracket_start(nextIndex, raw):
		var bracket := DialogueCommand.new(
			ep["line"], ep["pos"], DialogueCommand.CommandType.BRACKET)
		conditional_children.push_back(bracket)
		parseProgress.push_front(bracket)
		nextIndex += 1
	elif _peek_and_match("->", nextIndex, raw):
		var gotoTerm := RegEx.new()
		gotoTerm.compile("\\n")
		var gotoNodeName := _collect_characters(nextIndex + 2, raw, gotoTerm)
		conditional_children.push_back(
			DialogueCommand.new(
				ep["line"], ep["pos"],
				DialogueCommand.CommandType.GOTO, [gotoNodeName]))
		nextIndex += 2 + gotoNodeName.length()
	else:
		printerr("Error at (line: %d, pos: %d): Expected '{' or '->' after '%s'" \
			% [ep["line"], ep["pos"], op])
	return nextIndex


# Parse a $elif block.
func _parse_elif(
		i: int, raw: String, parseProgress: Array[DialogueCommand],
		currentLine: int, inLinePos: int, op: String) -> int:

	var last_child_type := _last_child_type(parseProgress[0].children)
	if last_child_type != DialogueCommand.CommandType.CONDITIONAL \
			&& last_child_type != DialogueCommand.CommandType.ELIF:
		printerr("Error at (line: %d, pos: %d): '$elif' can only follow a '$if' or '$elif' block" \
			% [currentLine, inLinePos])
		return i + op.length()

	var terminating := RegEx.new()
	terminating.compile("->|{")
	var expression_string := _collect_characters(i + op.length(), raw, terminating)
	var elif_children: Array[DialogueCommand] = []
	var result := DialogueCommand.new(
		currentLine, inLinePos,
		DialogueCommand.CommandType.ELIF,
		[expression_string],
		elif_children)
	parseProgress[0].children.push_back(result)

	var nextIndex := i + op.length() + expression_string.length()
	var ep := _get_position_from_index(nextIndex, raw)

	if _is_bracket_start(nextIndex, raw):
		var bracket := DialogueCommand.new(
			ep["line"], ep["pos"], DialogueCommand.CommandType.BRACKET)
		elif_children.push_back(bracket)
		parseProgress.push_front(bracket)
		nextIndex += 1
	elif _peek_and_match("->", nextIndex, raw):
		var gotoTerm := RegEx.new()
		gotoTerm.compile("\\n")
		var gotoNodeName := _collect_characters(nextIndex + 2, raw, gotoTerm)
		elif_children.push_back(
			DialogueCommand.new(
				ep["line"], ep["pos"],
				DialogueCommand.CommandType.GOTO, [gotoNodeName]))
		nextIndex += 2 + gotoNodeName.length()
	else:
		printerr("Error at (line: %d, pos: %d): Expected '{' or '->' after '$elif'" \
			% [ep["line"], ep["pos"]])
	return nextIndex


# Parse a $else block.
func _parse_else(
		i: int, raw: String, parseProgress: Array[DialogueCommand],
		currentLine: int, inLinePos: int) -> int:

	var last_child_type := _last_child_type(parseProgress[0].children)
	if last_child_type != DialogueCommand.CommandType.CONDITIONAL \
			&& last_child_type != DialogueCommand.CommandType.ELIF:
		printerr("Error at (line: %d, pos: %d): '$else' can only follow a '$if' or '$elif' block" \
			% [currentLine, inLinePos])
		return i + 1

	var elseChildren: Array[DialogueCommand] = []
	var result := DialogueCommand.new(
		currentLine, inLinePos,
		DialogueCommand.CommandType.ELSE, [], elseChildren)

	# Scan forward from after "$else" to find the opening '{' or '->' on the
	# same or next non-empty line. We scan character by character to avoid the
	# greedy/non-greedy regex pitfall of matching tokens far away in the file.
	var pos := i + 5  # skip past "$else" (5 chars)
	while pos < raw.length():
		var c := raw[pos]
		if c == " " or c == "\t" or c == "\r" or c == "\n":
			pos += 1
			continue
		if c == "{":
			# Found the opening bracket.
			var ep := _get_position_from_index(pos, raw)
			var bracket := DialogueCommand.new(
				ep["line"], ep["pos"], DialogueCommand.CommandType.BRACKET)
			elseChildren.push_back(bracket)
			parseProgress[0].children.push_back(result)
			parseProgress.push_front(bracket)
			return pos + 1
		if _peek_and_match("->", pos, raw):
			# Found a direct goto.
			var gotoTerm := RegEx.new()
			gotoTerm.compile("\\n")
			var gotoNodeName := _collect_characters(pos + 2, raw, gotoTerm)
			var ep := _get_position_from_index(pos, raw)
			elseChildren.push_back(
				DialogueCommand.new(
					ep["line"], ep["pos"],
					DialogueCommand.CommandType.GOTO, [gotoNodeName]))
			parseProgress[0].children.push_back(result)
			return pos + 2 + gotoNodeName.length()
		# Hit a non-whitespace character that isn't '{' or '->' — malformed.
		break

	printerr("Error at (line: %d, pos: %d): Expected '{' or '->' after '$else'" \
		% [currentLine, inLinePos])
	return i + 1


# Parse the label and child commands of a PROMPT (?>) command.
func _parse_prompt_command(i: int, raw: String, promptCommand: DialogueCommand) -> int:
	if i >= raw.length():
		return i

	var character_pos := _get_position_from_index(i, raw)

	if _peek_and_match("\\", i, raw):
		if i + 1 >= raw.length():
			return i + 1
		promptCommand.values[0] += raw[i + 1]
		return _parse_prompt_command(i + 2, raw, promptCommand)
	elif _peek_and_match("${", i, raw):
		# Variable injection inside prompt label — collect and append.
		var varRegex := RegEx.new()
		varRegex.compile("\\${\\S+?}")
		var varMatch := varRegex.search(raw, i)
		if varMatch && varMatch.get_start() == i:
			promptCommand.values[0] += varMatch.get_string()
			return _parse_prompt_command(i + varMatch.get_string().length(), raw, promptCommand)
		# Malformed ${, fall through to plain char.
	elif _peek_and_match("{", i, raw):
		var bracket := DialogueCommand.new(
			character_pos["line"], character_pos["pos"],
			DialogueCommand.CommandType.BRACKET)
		promptCommand.children.push_back(bracket)
		return i + 1
	elif _peek_and_match("->", i, raw):
		var gotoTerm := RegEx.new()
		gotoTerm.compile("\\n")
		var gotoNodeName := _collect_characters(i + 2, raw, gotoTerm)
		promptCommand.children.push_back(
			DialogueCommand.new(
				character_pos["line"], character_pos["pos"],
				DialogueCommand.CommandType.GOTO, [gotoNodeName]))
		return i + 2 + gotoNodeName.length()

	promptCommand.values[0] += raw[i]
	return _parse_prompt_command(i + 1, raw, promptCommand)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _collect_characters(starting: int, raw: String, terminating: RegEx) -> String:
	var m := terminating.search(raw, starting)
	if m:
		return raw.substr(starting, m.get_start() - starting)
	return raw.substr(starting)

func _is_previous_parse_type(
		type: DialogueCommand.CommandType,
		parseProgress: Array[DialogueCommand]) -> bool:
	if parseProgress.is_empty():
		return false
	return parseProgress[-1].type == type

func _last_child_type(children: Array[DialogueCommand]) -> DialogueCommand.CommandType:
	if children.is_empty():
		return DialogueCommand.CommandType.UNKNOWN
	return children[-1].type

func _add_letters_progress(
		letter: String, parseProgress: Array,
		currentLine: int, currentPos: int,
		type: DialogueCommand.CommandType) -> void:
	# Discard chunks that are entirely whitespace (blank lines, indentation gaps
	# between commands). These should not appear in output text.
	if letter.strip_edges(true, true).is_empty():
		return
	if _is_previous_parse_type(type, parseProgress):
		parseProgress[-1].values[0] += letter
	else:
		parseProgress.push_back(
			DialogueCommand.new(currentLine, currentPos, type, [letter]))

func _peek_and_match(find: String, start: int, raw: String) -> bool:
	if start < 0 || start > raw.length():
		return false
	return raw.substr(start, find.length()) == find

func _is_bracket_start(i: int, raw: String) -> bool:
	return _peek_and_match("{", i, raw) && !_peek_and_match("$", i - 1, raw)

func _get_position_from_index(i: int, raw: String) -> Dictionary:
	var lineNumber := raw.count("\n", 0, max(i, 1)) + 1
	var characterNumber := i - raw.substr(0, i).rfind("\n") - 1
	return { "line": lineNumber, "pos": characterNumber }
