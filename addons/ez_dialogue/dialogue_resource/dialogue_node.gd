@tool
class_name DialogueNode extends Resource

var id: int = -1
var name: String = ""
var commands_raw: String = ""
var position: Vector2 = Vector2(0, 0)
var _parsed: Array[DialogueCommand] = []

func serialize():
	var res = {
		"id": id,
		"name": name,
		"commands_raw": commands_raw,
		"position": [position.x, position.y]
	}
	return JSON.stringify(res)

func loadFromJson(jsonObj):
	id = jsonObj["id"]
	name = jsonObj["name"]
	commands_raw = jsonObj["commands_raw"]
	if jsonObj.has("position"):
		position = Vector2(jsonObj["position"][0], jsonObj["position"][1])
	_parsed = []

func clear_parse():
	_parsed = []

func get_parse() -> Array[DialogueCommand]:
	if _parsed.is_empty():
		_parsed = _parse_contents(commands_raw)

	return _parsed.duplicate(true)
	
func get_display_texts():
	var text = ""
	for parseItem in get_parse():
		if parseItem.type == DialogueCommand.CommandType.DISPLAY_TEXT:
			text += parseItem.values[0]
	return text.strip_edges(true, true)
	
func get_destination_nodes():
	var result = []
	var crawlStack = get_parse()
	while !crawlStack.is_empty():
		var parseItem = crawlStack.pop_front()
		for child in parseItem.children:
			crawlStack.push_front(child)
			
		if parseItem.type == DialogueCommand.CommandType.GOTO:
			var prompt = {}
		
			if !parseItem.values.is_empty():
				result.push_back(parseItem.values[0].strip_edges(true, true))

	return result
	
func _parse_contents(content: String):
	var rootParse: Array[DialogueCommand] = []
	rootParse.push_back(
		DialogueCommand.new(0, 0, DialogueCommand.CommandType.ROOT))
	var n = 0
	while n < content.length():
		n = _parse_statement(n, content, rootParse)
	
	#print ("content parseD:")
	#print (rootParse)
	return rootParse
	
# satement parser
func _parse_statement(i: int, raw: String, parseProgress: Array[DialogueCommand]):
	var conditional_operator = "$if"
	var else_operator = "$else"
	
	if i >= raw.length():
		return i

	var currentLine = raw.count("\n", 0, max(i, 1)) + 1
	var inLinePos = i - raw.substr(0, i).rfind("\n") - 1
	if _peek_and_match("\\", i, raw):
		# escape character "\" detected, store following letter as plain text.
		if i + 1 >= raw.length():
			# out of bound, next letter is not availalbe.
			return i + 1

		_add_letters_progress(
			raw[i] + raw[i+1],
			parseProgress[0].children,
			currentLine,
			inLinePos,
			DialogueCommand.CommandType.DISPLAY_TEXT)
		return i + 2
	elif _peek_and_match("?>", i, raw):
		# prompt can take either bracket { } as child or directly take goto (->)
		var promptParseProgress: Array[DialogueCommand] = []
		var terminating = RegEx.new()
		terminating.compile("->|{")
		var promptText = _collect_characters(i+2, raw, terminating)
		var nextIndex = i + 2 + promptText.length()
		var promptChildren: Array[DialogueCommand] = []
		var result = DialogueCommand.new(
			currentLine,
			inLinePos,
			DialogueCommand.CommandType.PROMPT,
			[promptText],
			promptChildren)
		parseProgress[0].children.push_back(result)
		
		var end_position = _get_position_from_index(nextIndex, raw)
		if _is_bracket_start(nextIndex, raw):
			var bracket = DialogueCommand.new(
				end_position["line"],
				end_position["pos"],
				DialogueCommand.CommandType.BRACKET
			)
			promptChildren.push_back(bracket)
			parseProgress.push_front(bracket)
			nextIndex += 1
		elif _peek_and_match("->", nextIndex, raw):
			var gotoTerm = RegEx.new()
			gotoTerm.compile("\\n")
			var gotoNodeName = _collect_characters(nextIndex+2, raw, gotoTerm)
			var gotoCommand = DialogueCommand.new(
				end_position["line"],
				end_position["pos"],
				DialogueCommand.CommandType.GOTO,
				[gotoNodeName])
			promptChildren.push_back(gotoCommand)
			nextIndex += 2 + gotoNodeName.length()
		else:
			printerr(
				"Error at (line: %d, pos: %d): Expected '{' or '->' at the end of '?> [prompt]'" % [end_position["line"], end_position["pos"]])
		return nextIndex
	elif _peek_and_match("->", i, raw):
		var terminating = RegEx.new()
		terminating.compile("\\n")
		var gotoNodeName = _collect_characters(i+2, raw, terminating)
		var gotoCommand = DialogueCommand.new(
			currentLine, inLinePos, DialogueCommand.CommandType.GOTO,[gotoNodeName])
		parseProgress[0].children.push_back(gotoCommand)
		return i + 2 + gotoNodeName.length()
	elif _peek_and_match("signal(", i, raw):
		var terminating = RegEx.new()
		terminating.compile("\\)")
		var signalName = _collect_characters(i + 7, raw, terminating)
		parseProgress[0].children.push_back(
			DialogueCommand.new(
				currentLine,
				inLinePos,
				DialogueCommand.CommandType.SIGNAL,
				[signalName]))
		var nextIndex = i + 7 + signalName.length()
		var end_position = _get_position_from_index(nextIndex, raw)
		if _peek_and_match(")", nextIndex, raw):
			nextIndex += 1
		else:
			printerr(
				"Error at (line: %d, pos: %d): Expected ')' at the end of 'signal(...'" % [end_position["line"], end_position["pos"]])
		return i + 7 + signalName.length() + 1
	elif _peek_and_match(conditional_operator, i, raw):
		var terminating = RegEx.new()
		terminating.compile("->|{")
		var expression_string = _collect_characters(
			i + conditional_operator.length(), raw, terminating)
		var conditional_children: Array[DialogueCommand] = []
		var result = DialogueCommand.new(
			currentLine,
			inLinePos,
			DialogueCommand.CommandType.CONDITIONAL,
			[expression_string],
			conditional_children)
		
		parseProgress[0].children.push_back(result)
		
		var nextIndex = i + conditional_operator.length() + expression_string.length()
		var end_position = _get_position_from_index(nextIndex, raw)
		if _is_bracket_start(nextIndex, raw):
			var bracket = DialogueCommand.new(
				end_position["line"],
				end_position["pos"],
				DialogueCommand.CommandType.BRACKET
			)
			conditional_children.push_back(bracket)
			parseProgress.push_front(bracket)
			nextIndex += 1
		elif _peek_and_match("->", nextIndex, raw):
			var gotoTerm = RegEx.new()
			gotoTerm.compile("\\n")
			var gotoNodeName = _collect_characters(nextIndex+2, raw, gotoTerm)
			var gotoCommand = DialogueCommand.new(
				end_position["line"],
				end_position["pos"],
				DialogueCommand.CommandType.GOTO
				[gotoNodeName])
			conditional_children.push_back(gotoCommand)
			nextIndex += 2 + gotoNodeName.length()
		else:
			printerr(
				"Error at (line: %d, pos: %d): Expected '{' at the end of '%s'" \
				% [ end_position["line"],
					end_position["pos"],
					conditional_operator])
		return nextIndex
	elif _peek_and_match(else_operator, i, raw):
		# checking for last item of the current command's children for CONDITIONAL
		if parseProgress[0].children[-1].type == DialogueCommand.CommandType.CONDITIONAL:
			# else only is accepted when there's an $if right before
			var elseChildren: Array[DialogueCommand] = []
			var result = DialogueCommand.new(
				currentLine,
				inLinePos,
				DialogueCommand.CommandType.ELSE,
				[],
				elseChildren)
			var nextPosition = i + 1
			
			# skip whitespace after '$else' to find '{' or '->'
			var bracketRegex = RegEx.new()
			bracketRegex.compile("\\s*?{")
			var bracketMatch = bracketRegex.search(raw, nextPosition)
			
			var gotoRegex = RegEx.new()
			gotoRegex.compile("\\s*?->")
			var gotoMatch = gotoRegex.search(raw, nextPosition)
			
			if bracketMatch:
				# '{' found
				nextPosition = bracketMatch.get_end()
				var end_position = _get_position_from_index(nextPosition, raw)

				var bracket = DialogueCommand.new(
					end_position["line"],
					end_position["pos"],
					DialogueCommand.CommandType.BRACKET
				)

				elseChildren.push_back(bracket)
				parseProgress[0].children.push_back(result)
				parseProgress.push_front(bracket)
				return nextPosition + 1
			elif gotoMatch:
				nextPosition = gotoMatch.get_end()
				var gotoTerm = RegEx.new()
				gotoTerm.compile("\\n")
				var gotoNodeName = _collect_characters(nextPosition, raw, gotoTerm)
				var end_position = _get_position_from_index(nextPosition, raw)
				var gotoCommand = DialogueCommand.new(
					end_position["line"],
					end_position["pos"],
					DialogueCommand.CommandType.GOTO
					[gotoNodeName])
				elseChildren.push_back(gotoCommand)
				return nextPosition + gotoNodeName.length()
			else:
				printerr(
					"Error at (line: %d, pos: %d): You need '{' after '$else'." \
					% [currentLine, inLinePos])
				pass
		else:
			printerr(
				"Error at (line: %d, pos: %d): '$else' can only be used after \
				an '$if' block" % [currentLine, inLinePos])
		pass
	elif _is_bracket_start(i, raw):
		var bracket = DialogueCommand.new(
			currentLine,
			inLinePos,
			DialogueCommand.CommandType.BRACKET
		)
		parseProgress[0].children.push_back(bracket)
		parseProgress.push_front(bracket)
		return i + 1
	elif _peek_and_match("}", i , raw):
		if parseProgress[0].type == DialogueCommand.CommandType.BRACKET:
			# end of bracket pop stck.
			parseProgress.pop_front()
			return i + 1
		#printerr(
		#	"Error at (line: %d, pos: %d): Found '}' with no matching '{' before" % [currentLine, inLinePos])
	elif _peek_and_match("---", i, raw):
		var result: DialogueCommand = DialogueCommand.new(
			currentLine, inLinePos, DialogueCommand.CommandType.PAGE_BREAK)
		parseProgress[0].children.push_back(result)
		return i + 3
	
	var variableInjectRegex = RegEx.new()
	variableInjectRegex.compile("\\${\\S+?}")
	var varInjectMatch = variableInjectRegex.search(raw, i)

	if varInjectMatch && varInjectMatch.get_start() == i:
		_add_letters_progress(
			varInjectMatch.get_string(),
			parseProgress[0].children,
			currentLine,
			inLinePos,
			DialogueCommand.CommandType.DISPLAY_TEXT)
		return i + varInjectMatch.get_string().length()
	else:
		# no special keyword ==> LETTERS
		_add_letters_progress(
			raw[i], parseProgress[0].children, currentLine, inLinePos, DialogueCommand.CommandType.DISPLAY_TEXT)
		return i + 1

# Collect values in raw String starting from 'starting' index until 'terminating' character is found.
func _collect_characters(starting: int, raw: String, terminating: RegEx):
	var result = ""
	var match = terminating.search(raw, starting)
	if match:
		return raw.substr(starting, match.get_start() - starting)
	return raw.substr(starting)

func _is_previous_parse_type(type: DialogueCommand.CommandType, parseProgress: Array[DialogueCommand]):
	if parseProgress.is_empty():
		return false
		
	return parseProgress[-1].type == type

func _add_letters_progress(letter: String, parseProgress: Array, currentLine: int, currentPos: int, type: DialogueCommand.CommandType):
	if _is_previous_parse_type(type, parseProgress):
		# merge to previous "letters" type parse
		parseProgress[-1].values[0] += letter
	elif letter == " " || letter == "\t" || letter == "\n":
		return
	else:
		# start new "letters" type parse
		var result = DialogueCommand.new(
			currentLine,
			currentPos,
			type,
			[letter])
		parseProgress.push_back(result)

func _peek_and_match(find: String, start: int, raw: String) -> bool:
	if start < 0 || start > raw.length():
		return false

	return raw.substr(start, find.length()) == find

func _is_bracket_start(i: int, raw: String):
	return _peek_and_match("{", i, raw) && !_peek_and_match("$", i-1, raw)

func _get_position_from_index(i: int, raw: String):
	var lineNumber = raw.count("\n", 0, max(i, 1)) + 1
	var characterNumber = i - raw.substr(0, i).rfind("\n") - 1
	return {
		"line": lineNumber,
		"pos": characterNumber
	}

