#!/usr/bin/env -S godot -s
## Tests for syntax highlighting logic — command identification, line mapping,
## color assignment, and regex-based token detection.

extends "res://addons/ez_dialogue/dialogue_test/test_runner.gd"

const _DialogueCommand  = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_command.gd")
const _DialogueParser   = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_parser.gd")
const _DialogueNode     = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_node.gd")
const _DialogueResource = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_resource.gd")
const _DialogueResponse = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_response.gd")
const _EzDialogueReader = preload("res://addons/ez_dialogue/dialogue_reader.gd")

enum ColorCat { TEXT, SPECIAL, CONSTANT, OPERATOR, EXPRESSION, VARIABLE }

var _complex_map: Dictionary


func _get_suite_name() -> String:
	return "Syntax Highlight Tests"


# ── Helpers ───────────────────────────────────────────────────────────────────

func _build_line_map(script_text: String) -> Dictionary:
	var parser := DialogueParser.new()
	var parse_result := parser.parse(script_text)
	var line_map := {}
	var queue := []
	queue.append_array(parse_result)
	while !queue.is_empty():
		var command: DialogueCommand = queue.pop_front()
		if !command.children.is_empty():
			queue.append_array(command.children)
		var line_key := command.start_line - 1
		if !line_map.has(line_key):
			line_map[line_key] = []
		line_map[line_key].push_back(command)
	return line_map

func _color_cat_for(type: int) -> int:
	match type:
		DialogueCommand.CommandType.DISPLAY_TEXT: return ColorCat.TEXT
		DialogueCommand.CommandType.PAGE_BREAK:   return ColorCat.SPECIAL
		DialogueCommand.CommandType.PROMPT:       return ColorCat.SPECIAL
		DialogueCommand.CommandType.GOTO:         return ColorCat.CONSTANT
		DialogueCommand.CommandType.CONDITIONAL:  return ColorCat.SPECIAL
		DialogueCommand.CommandType.ELSE:         return ColorCat.SPECIAL
		DialogueCommand.CommandType.ELIF:         return ColorCat.SPECIAL
		DialogueCommand.CommandType.SIGNAL:       return ColorCat.SPECIAL
		_: return ColorCat.TEXT

func _find_commands_of_type(line_map: Dictionary, type: int) -> Array:
	var results := []
	for line in line_map.keys():
		for cmd in line_map[line]:
			if cmd.type == type:
				results.push_back({"line": line, "cmd": cmd})
	return results

func _load_complex_script() -> void:
	if !_complex_map.is_empty():
		return
	var file := FileAccess.open("res://test/highlight_test_script.txt", FileAccess.READ)
	_complex_map = _build_line_map(file.get_as_text())

func _get_types_on_line(line: int) -> Array:
	var types := []
	if _complex_map.has(line):
		for cmd in _complex_map[line]:
			types.push_back(cmd.type)
	return types

func _get_commands_on_line(line: int, type: int) -> Array:
	var results := []
	if _complex_map.has(line):
		for cmd in _complex_map[line]:
			if cmd.type == type:
				results.push_back(cmd)
	return results


# ── Simple mapping tests ──────────────────────────────────────────────────────

func test_plain_text_mapping() -> void:
	var map := _build_line_map("Hello world.")
	var texts := _find_commands_of_type(map, DialogueCommand.CommandType.DISPLAY_TEXT)
	assert_true(texts.size() >= 1, "at least one DISPLAY_TEXT")
	assert_eq(texts[0]["line"], 0, "on line 0")

func test_goto_mapping() -> void:
	var map := _build_line_map("some text\n-> target_node")
	var gotos := _find_commands_of_type(map, DialogueCommand.CommandType.GOTO)
	assert_eq(gotos.size(), 1, "one GOTO")
	assert_eq(gotos[0]["line"], 1, "on line 1")
	assert_eq(gotos[0]["cmd"].values[0].strip_edges(), "target_node")

func test_prompt_mapping() -> void:
	var map := _build_line_map("?> choice one -> node_a\n?> choice two -> node_b")
	var prompts := _find_commands_of_type(map, DialogueCommand.CommandType.PROMPT)
	assert_eq(prompts.size(), 2, "two PROMPTs")
	assert_eq(prompts[0]["line"], 0)
	assert_eq(prompts[1]["line"], 1)

func test_conditional_mapping() -> void:
	var map := _build_line_map("$if some_var {\n    text\n}")
	var conds := _find_commands_of_type(map, DialogueCommand.CommandType.CONDITIONAL)
	assert_eq(conds.size(), 1, "one CONDITIONAL")
	assert_eq(conds[0]["line"], 0)
	assert_true(conds[0]["cmd"].values[0].strip_edges().begins_with("some_var"))

func test_elif_mapping() -> void:
	var map := _build_line_map("$if a {\n    x\n}\n$elif b {\n    y\n}")
	var elifs := _find_commands_of_type(map, DialogueCommand.CommandType.ELIF)
	assert_eq(elifs.size(), 1, "one ELIF")
	assert_eq(elifs[0]["line"], 3)

func test_else_mapping() -> void:
	var map := _build_line_map("$if a {\n    x\n}\n$else {\n    y\n}")
	var elses := _find_commands_of_type(map, DialogueCommand.CommandType.ELSE)
	assert_eq(elses.size(), 1, "one ELSE")
	assert_eq(elses[0]["line"], 3)

func test_signal_mapping() -> void:
	var map := _build_line_map("text before\nsignal(play,sound)\ntext after")
	var signals := _find_commands_of_type(map, DialogueCommand.CommandType.SIGNAL)
	assert_eq(signals.size(), 1, "one SIGNAL")
	assert_eq(signals[0]["line"], 1)
	assert_eq(signals[0]["cmd"].values[0], "play,sound")

func test_page_break_mapping() -> void:
	var map := _build_line_map("page one\n---\npage two")
	var breaks := _find_commands_of_type(map, DialogueCommand.CommandType.PAGE_BREAK)
	assert_eq(breaks.size(), 1, "one PAGE_BREAK")
	assert_eq(breaks[0]["line"], 1)

func test_variable_injection_mapping() -> void:
	var map := _build_line_map("Hello ${name}, welcome.")
	var texts := _find_commands_of_type(map, DialogueCommand.CommandType.DISPLAY_TEXT)
	assert_true(texts.size() >= 1)
	var combined := ""
	for t in texts:
		combined += t["cmd"].values[0]
	assert_contains(combined, "${name}")

func test_mixed_line_mapping() -> void:
	var script := "intro text\n$if flag {\n    inner text\n    -> some_node\n}\n$else {\n    signal(alert,1)\n}"
	var map := _build_line_map(script)
	assert_true(map.has(0), "line 0 exists")
	var conds := _find_commands_of_type(map, DialogueCommand.CommandType.CONDITIONAL)
	assert_eq(conds[0]["line"], 1)
	var gotos := _find_commands_of_type(map, DialogueCommand.CommandType.GOTO)
	assert_true(gotos.size() >= 1)
	var elses := _find_commands_of_type(map, DialogueCommand.CommandType.ELSE)
	assert_eq(elses[0]["line"], 5)
	var signals := _find_commands_of_type(map, DialogueCommand.CommandType.SIGNAL)
	assert_eq(signals[0]["line"], 6)


# ── Color category tests ─────────────────────────────────────────────────────

func test_color_display_text() -> void:
	assert_eq(_color_cat_for(DialogueCommand.CommandType.DISPLAY_TEXT), ColorCat.TEXT)

func test_color_goto() -> void:
	assert_eq(_color_cat_for(DialogueCommand.CommandType.GOTO), ColorCat.CONSTANT)

func test_color_prompt() -> void:
	assert_eq(_color_cat_for(DialogueCommand.CommandType.PROMPT), ColorCat.SPECIAL)

func test_color_conditional() -> void:
	assert_eq(_color_cat_for(DialogueCommand.CommandType.CONDITIONAL), ColorCat.SPECIAL)

func test_color_elif() -> void:
	assert_eq(_color_cat_for(DialogueCommand.CommandType.ELIF), ColorCat.SPECIAL)

func test_color_else() -> void:
	assert_eq(_color_cat_for(DialogueCommand.CommandType.ELSE), ColorCat.SPECIAL)

func test_color_signal() -> void:
	assert_eq(_color_cat_for(DialogueCommand.CommandType.SIGNAL), ColorCat.SPECIAL)

func test_color_page_break() -> void:
	assert_eq(_color_cat_for(DialogueCommand.CommandType.PAGE_BREAK), ColorCat.SPECIAL)


# ── Regex position tests ─────────────────────────────────────────────────────

func test_bracket_regex_positions() -> void:
	var regex := RegEx.new()
	regex.compile("[{}]")
	var line := "$if flag { -> node }"
	var matches := regex.search_all(line)
	assert_true(matches.size() >= 2, "finds at least 2 brackets")
	var positions := []
	for m in matches:
		positions.push_back(m.get_start())
	assert_true(positions.has(line.find("{")), "finds {")
	assert_true(positions.has(line.rfind("}")), "finds }")

func test_signal_regex_positions() -> void:
	var regex := RegEx.new()
	regex.compile("signal\\(([\\s\\S]*?)\\)")
	var line := "text signal(play,sfx) more"
	var matches := regex.search_all(line)
	assert_eq(matches.size(), 1)
	assert_eq(matches[0].get_start(), 5)
	assert_eq(matches[0].get_string(1), "play,sfx")
	assert_eq(line[matches[0].get_start() + 6], "(")

func test_variable_regex_positions() -> void:
	var regex := RegEx.new()
	regex.compile("\\$\\{\\S+?\\}")
	var line := "Hello ${name}, you have ${coins} gold."
	var matches := regex.search_all(line)
	assert_eq(matches.size(), 2)
	assert_eq(matches[0].get_string(), "${name}")
	assert_eq(matches[1].get_string(), "${coins}")
	assert_eq(matches[0].get_start(), 6)
	assert_eq(matches[0].get_end(), 13)


# ── Complex multi-line script tests ──────────────────────────────────────────

func test_complex_line_types() -> void:
	_load_complex_script()
	assert_true(_get_types_on_line(0).has(DialogueCommand.CommandType.DISPLAY_TEXT), "line 0: TEXT")
	assert_true(_get_types_on_line(2).has(DialogueCommand.CommandType.PAGE_BREAK), "line 2: PAGE_BREAK")
	assert_true(_get_types_on_line(3).has(DialogueCommand.CommandType.CONDITIONAL), "line 3: CONDITIONAL")
	assert_true(_get_types_on_line(8).has(DialogueCommand.CommandType.ELIF), "line 8: ELIF")
	assert_true(_get_types_on_line(18).has(DialogueCommand.CommandType.ELSE), "line 18: ELSE")

func test_complex_variable_positions() -> void:
	_load_complex_script()
	var texts := _get_commands_on_line(0, DialogueCommand.CommandType.DISPLAY_TEXT)
	var combined := ""
	for cmd in texts:
		combined += cmd.values[0]
	assert_contains(combined, "${player_name}")
	assert_contains(combined, "${gold}")

func test_complex_conditional_chain() -> void:
	_load_complex_script()
	var conds := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.CONDITIONAL)
	assert_eq(conds.size(), 1)
	assert_eq(conds[0]["line"], 3)
	var elifs := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.ELIF)
	assert_eq(elifs.size(), 1)
	assert_eq(elifs[0]["line"], 8)
	var elses := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.ELSE)
	assert_eq(elses.size(), 1)
	assert_eq(elses[0]["line"], 18)
	assert_true(conds[0]["cmd"].values[0].strip_edges().begins_with("reputation"))
	assert_true(elifs[0]["cmd"].values[0].strip_edges().begins_with("reputation"))

func test_complex_nested_prompts() -> void:
	_load_complex_script()
	var prompts := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.PROMPT)
	assert_true(prompts.size() >= 4, "at least 4 prompts")
	var lines := []
	for p in prompts:
		lines.push_back(p["line"])
	assert_true(lines.has(5))
	assert_true(lines.has(6))
	assert_true(lines.has(11))
	assert_true(lines.has(16))

func test_complex_signal_inline() -> void:
	_load_complex_script()
	var signals := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.SIGNAL)
	assert_true(signals.size() >= 2)
	var lines := []
	var params := []
	for s in signals:
		lines.push_back(s["line"])
		params.push_back(s["cmd"].values[0])
	assert_true(lines.has(10))
	assert_true(lines.has(12))
	assert_true(params.has("play_sfx,suspicious"))
	assert_true(params.has("set,gold,-10"))

func test_complex_page_break_position() -> void:
	_load_complex_script()
	var breaks := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.PAGE_BREAK)
	assert_eq(breaks.size(), 1)
	assert_eq(breaks[0]["line"], 2)

func test_complex_goto_inside_bracket() -> void:
	_load_complex_script()
	var gotos := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.GOTO)
	assert_true(gotos.size() >= 2)
	var lines := []
	for g in gotos:
		lines.push_back(g["line"])
	assert_true(lines.has(14), "goto on line 14")
	assert_true(lines.has(20), "goto on line 20")

func test_complex_text_after_block() -> void:
	_load_complex_script()
	var all_texts := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.DISPLAY_TEXT)
	var found := false
	for entry in all_texts:
		if entry["cmd"].values[0].strip_edges().begins_with("The sun"):
			found = true
			break
	assert_true(found, "'The sun sets...' exists after conditional block")

func test_complex_bracket_positions() -> void:
	_load_complex_script()
	var brackets := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.BRACKET)
	assert_true(brackets.size() >= 4)
	var lines := []
	for b in brackets:
		lines.push_back(b["line"])
	assert_true(lines.has(3), "bracket on line 3")
	assert_true(lines.has(8), "bracket on line 8")
	assert_true(lines.has(18), "bracket on line 18")
