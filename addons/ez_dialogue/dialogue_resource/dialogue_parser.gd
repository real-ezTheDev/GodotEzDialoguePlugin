@tool
class_name DialogueParser extends RefCounted

# Precompiled regex patterns — avoids recompiling on every parse call.
var _newline_regex := _compile("\\n")
var _branch_terminator_regex := _compile("->|{")
var _var_inject_regex := _compile("\\${\\S+?}")
var _close_paren_regex := _compile("\\)")
var _var_in_prompt_regex := _compile("\\${\\S+?}")

static func _compile(pattern: String) -> RegEx:
	var r := RegEx.new()
	r.compile(pattern)
	return r


## Parse the given dialogue script String into a list of [DialogueCommand]s.
func parse(dialogue_script: String) -> Array[DialogueCommand]:
	var root: Array[DialogueCommand] = []
	root.push_back(DialogueCommand.new(0, 0, DialogueCommand.CommandType.ROOT))
	var n := 0
	while n < dialogue_script.length():
		n = _parse_statement(n, dialogue_script, root)
	return root


# ── Main statement dispatcher ─────────────────────────────────────────────────

func _parse_statement(i: int, raw: String, stack: Array[DialogueCommand]) -> int:
	if i >= raw.length():
		return i

	var line := raw.count("\n", 0, max(i, 1)) + 1
	var col  := i - raw.substr(0, i).rfind("\n") - 1

	# Escape: \X → literal X
	if _peek("\\", i, raw):
		if i + 1 >= raw.length():
			return i + 1
		_append_text(raw[i + 1], stack[0].children, line, col)
		return i + 2

	# Prompt: ?>
	if _peek("?>", i, raw):
		return _parse_prompt(i, raw, stack, line, col)

	# Goto: ->
	if _peek("->", i, raw):
		var name := _collect_until(i + 2, raw, _newline_regex)
		stack[0].children.push_back(
			DialogueCommand.new(line, col, DialogueCommand.CommandType.GOTO, [name]))
		return i + 2 + name.length()

	# Signal: signal(...)
	if _peek("signal(", i, raw):
		var params := _collect_until(i + 7, raw, _close_paren_regex)
		stack[0].children.push_back(
			DialogueCommand.new(line, col, DialogueCommand.CommandType.SIGNAL, [params]))
		var end := i + 7 + params.length()
		if _peek(")", end, raw):
			end += 1
		else:
			_error(end, raw, "Expected ')' at end of 'signal('")
		return end

	# $elif (checked before $if to avoid prefix match)
	if _peek("$elif", i, raw):
		return _parse_branch(i, raw, stack, line, col, "$elif", DialogueCommand.CommandType.ELIF)

	# $if
	if _peek("$if", i, raw):
		return _parse_branch(i, raw, stack, line, col, "$if", DialogueCommand.CommandType.CONDITIONAL)

	# $else
	if _peek("$else", i, raw):
		return _parse_else(i, raw, stack, line, col)

	# Nested bracket open (only inside an existing bracket context)
	if _peek("{", i, raw) and not _peek("$", i - 1, raw) \
			and stack[0].type == DialogueCommand.CommandType.BRACKET:
		var bracket := DialogueCommand.new(line, col, DialogueCommand.CommandType.BRACKET)
		stack[0].children.push_back(bracket)
		stack.push_front(bracket)
		return i + 1

	# Bracket close (only inside a bracket context)
	if _peek("}", i, raw) and stack[0].type == DialogueCommand.CommandType.BRACKET:
		stack.pop_front()
		return i + 1

	# Page break: ---
	if _peek("---", i, raw):
		stack[0].children.push_back(
			DialogueCommand.new(line, col, DialogueCommand.CommandType.PAGE_BREAK))
		return i + 3

	# Plain text (bulk collection)
	return _collect_plain_text(i, raw, stack, line, col)


# ── Branch parsing ($if / $elif — unified) ────────────────────────────────────

func _parse_branch(
		i: int, raw: String, stack: Array[DialogueCommand],
		line: int, col: int, keyword: String, type: DialogueCommand.CommandType) -> int:

	# Validate $elif placement
	if type == DialogueCommand.CommandType.ELIF:
		var prev := _last_child_type(stack[0].children)
		if prev != DialogueCommand.CommandType.CONDITIONAL \
				and prev != DialogueCommand.CommandType.ELIF:
			_error(i, raw, "'%s' can only follow a '$if' or '$elif' block" % keyword)
			return i + keyword.length()

	var expr := _collect_until(i + keyword.length(), raw, _branch_terminator_regex)
	var children: Array[DialogueCommand] = []
	var cmd := DialogueCommand.new(line, col, type, [expr], children)
	stack[0].children.push_back(cmd)

	var next := i + keyword.length() + expr.length()
	return _parse_branch_body(next, raw, stack, children)


# Shared logic: after the expression, expect '{' or '->'
func _parse_branch_body(
		i: int, raw: String, stack: Array[DialogueCommand],
		children: Array[DialogueCommand]) -> int:

	var ep := _pos(i, raw)
	if _peek("{", i, raw) and not _peek("$", i - 1, raw):
		var bracket := DialogueCommand.new(ep["line"], ep["pos"], DialogueCommand.CommandType.BRACKET)
		children.push_back(bracket)
		stack.push_front(bracket)
		return i + 1
	elif _peek("->", i, raw):
		var name := _collect_until(i + 2, raw, _newline_regex)
		children.push_back(
			DialogueCommand.new(ep["line"], ep["pos"], DialogueCommand.CommandType.GOTO, [name]))
		return i + 2 + name.length()
	else:
		_error(i, raw, "Expected '{' or '->' after conditional keyword")
		return i


# ── $else parsing ─────────────────────────────────────────────────────────────

func _parse_else(i: int, raw: String, stack: Array[DialogueCommand], line: int, col: int) -> int:
	var prev := _last_child_type(stack[0].children)
	if prev != DialogueCommand.CommandType.CONDITIONAL \
			and prev != DialogueCommand.CommandType.ELIF:
		_error(i, raw, "'$else' can only follow a '$if' or '$elif' block")
		return i + 1

	var children: Array[DialogueCommand] = []
	var cmd := DialogueCommand.new(line, col, DialogueCommand.CommandType.ELSE, [], children)

	# Scan past whitespace to find '{' or '->'
	var pos := i + 5  # skip "$else"
	while pos < raw.length():
		var c := raw[pos]
		if c == " " or c == "\t" or c == "\r" or c == "\n":
			pos += 1
			continue
		if c == "{":
			var ep := _pos(pos, raw)
			var bracket := DialogueCommand.new(ep["line"], ep["pos"], DialogueCommand.CommandType.BRACKET)
			children.push_back(bracket)
			stack[0].children.push_back(cmd)
			stack.push_front(bracket)
			return pos + 1
		if _peek("->", pos, raw):
			var name := _collect_until(pos + 2, raw, _newline_regex)
			var ep := _pos(pos, raw)
			children.push_back(
				DialogueCommand.new(ep["line"], ep["pos"], DialogueCommand.CommandType.GOTO, [name]))
			stack[0].children.push_back(cmd)
			return pos + 2 + name.length()
		break

	_error(i, raw, "Expected '{' or '->' after '$else'")
	return i + 1


# ── Prompt parsing ────────────────────────────────────────────────────────────

func _parse_prompt(i: int, raw: String, stack: Array[DialogueCommand], line: int, col: int) -> int:
	var prompt := DialogueCommand.new(line, col, DialogueCommand.CommandType.PROMPT, [""], [])
	var next := _parse_prompt_content(i + 2, raw, prompt)
	stack[0].children.push_back(prompt)
	if prompt.children.size() > 0 \
			and prompt.children[0].type == DialogueCommand.CommandType.BRACKET:
		stack.push_front(prompt.children[0])
	return next

func _parse_prompt_content(i: int, raw: String, prompt: DialogueCommand) -> int:
	if i >= raw.length():
		return i

	var cp := _pos(i, raw)

	if _peek("\\", i, raw):
		if i + 1 >= raw.length():
			return i + 1
		prompt.values[0] += raw[i + 1]
		return _parse_prompt_content(i + 2, raw, prompt)

	if _peek("${", i, raw):
		var m := _var_in_prompt_regex.search(raw, i)
		if m and m.get_start() == i:
			prompt.values[0] += m.get_string()
			return _parse_prompt_content(i + m.get_string().length(), raw, prompt)

	if _peek("{", i, raw):
		var bracket := DialogueCommand.new(cp["line"], cp["pos"], DialogueCommand.CommandType.BRACKET)
		prompt.children.push_back(bracket)
		return i + 1

	if _peek("->", i, raw):
		var name := _collect_until(i + 2, raw, _newline_regex)
		prompt.children.push_back(
			DialogueCommand.new(cp["line"], cp["pos"], DialogueCommand.CommandType.GOTO, [name]))
		return i + 2 + name.length()

	prompt.values[0] += raw[i]
	return _parse_prompt_content(i + 1, raw, prompt)


# ── Plain text bulk collection ────────────────────────────────────────────────

func _collect_plain_text(
		i: int, raw: String, stack: Array[DialogueCommand],
		line: int, col: int) -> int:

	# Variable injection at current position?
	var vm := _var_inject_regex.search(raw, i)
	if vm and vm.get_start() == i:
		_append_text(vm.get_string(), stack[0].children, line, col)
		return i + vm.get_string().length()

	# Scan forward until a special token
	var inside_bracket := stack[0].type == DialogueCommand.CommandType.BRACKET
	var j := i
	while j < raw.length():
		match raw[j]:
			"\\":
				break
			"?":
				if _peek("?>", j, raw): break
			"-":
				if _peek("->", j, raw) or _peek("---", j, raw): break
			"$":
				break
			"{":
				if inside_bracket: break
			"}":
				if inside_bracket: break
			"s":
				if _peek("signal(", j, raw): break
		j += 1

	if j > i:
		_append_text(raw.substr(i, j - i), stack[0].children, line, col)
		return j

	# Single character fallback
	_append_text(raw[i], stack[0].children, line, col)
	return i + 1


# ── Utility functions ─────────────────────────────────────────────────────────

## Append text to the parse tree, merging with previous DISPLAY_TEXT if possible.
## Discards whitespace-only chunks.
func _append_text(text: String, children: Array, line: int, col: int) -> void:
	if text.strip_edges(true, true).is_empty():
		return
	if not children.is_empty() \
			and children[-1].type == DialogueCommand.CommandType.DISPLAY_TEXT:
		children[-1].values[0] += text
	else:
		children.push_back(
			DialogueCommand.new(line, col, DialogueCommand.CommandType.DISPLAY_TEXT, [text]))

## Collect characters from [start] until [terminator] regex matches.
func _collect_until(start: int, raw: String, terminator: RegEx) -> String:
	var m := terminator.search(raw, start)
	if m:
		return raw.substr(start, m.get_start() - start)
	return raw.substr(start)

## Check if [find] matches at position [start] in [raw].
func _peek(find: String, start: int, raw: String) -> bool:
	if start < 0 or start > raw.length():
		return false
	return raw.substr(start, find.length()) == find

## Get line/col position from a character index.
func _pos(i: int, raw: String) -> Dictionary:
	return {
		"line": raw.count("\n", 0, max(i, 1)) + 1,
		"pos": i - raw.substr(0, i).rfind("\n") - 1
	}

## Get the CommandType of the last child, or UNKNOWN if empty.
func _last_child_type(children: Array[DialogueCommand]) -> DialogueCommand.CommandType:
	if children.is_empty():
		return DialogueCommand.CommandType.UNKNOWN
	return children[-1].type

## Print a parse error with line/col context.
func _error(i: int, raw: String, message: String) -> void:
	var p := _pos(i, raw)
	printerr("Error at (line: %d, pos: %d): %s" % [p["line"], p["pos"], message])
