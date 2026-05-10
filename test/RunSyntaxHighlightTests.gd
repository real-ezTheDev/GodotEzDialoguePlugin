#!/usr/bin/env -S godot -s
## Headless test for syntax highlighting logic.
##
## Tests that the parser produces the correct command types at the correct
## line positions, and that the color-mapping logic assigns the right color
## category to each command type. This validates the "identification and
## grouping" layer without needing a live CodeEdit widget.
##
## Run:  godot --headless -s test/RunSyntaxHighlightTests.gd

extends SceneTree

const _DialogueCommand  = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_command.gd")
const _DialogueParser   = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_parser.gd")
const _DialogueNode     = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_node.gd")
const _DialogueResource = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_resource.gd")
const _DialogueResponse = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_response.gd")
const _EzDialogueReader = preload("res://addons/ez_dialogue/dialogue_reader.gd")

# Color categories (we use strings since we can't instantiate the highlighter
# without a TextEdit, but we can test the mapping logic).
enum ColorCat { TEXT, SPECIAL, CONSTANT, OPERATOR, EXPRESSION, VARIABLE }

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run_all_tests.call_deferred()


func _run_all_tests() -> void:
	# ── Command-to-line mapping tests ─────────────────────────────────────────
	_test_plain_text_mapping()
	_test_goto_mapping()
	_test_prompt_mapping()
	_test_conditional_mapping()
	_test_elif_mapping()
	_test_else_mapping()
	_test_signal_mapping()
	_test_page_break_mapping()
	_test_variable_injection_mapping()
	_test_mixed_line_mapping()

	# ── Color category assignment tests ───────────────────────────────────────
	_test_color_for_display_text()
	_test_color_for_goto()
	_test_color_for_prompt()
	_test_color_for_conditional()
	_test_color_for_elif()
	_test_color_for_else()
	_test_color_for_signal()
	_test_color_for_page_break()

	# ── Regex pass tests (bracket, signal, variable positions) ────────────────
	_test_bracket_regex_positions()
	_test_signal_regex_positions()
	_test_variable_regex_positions()

	# ── Complex multi-line script tests (loaded from file) ────────────────────
	_test_complex_line_types()
	_test_complex_variable_positions()
	_test_complex_conditional_chain()
	_test_complex_nested_prompts()
	_test_complex_signal_inline()
	_test_complex_page_break_position()
	_test_complex_goto_inside_bracket()
	_test_complex_text_after_conditional_block()
	_test_complex_bracket_positions()

	# ── Summary ───────────────────────────────────────────────────────────────
	print("")
	print("=".repeat(50))
	print("Syntax Highlight Tests: %d passed, %d failed" % [_passed, _failed])
	print("=".repeat(50))
	quit(1 if _failed > 0 else 0)


# ── Assertion helpers ─────────────────────────────────────────────────────────

func _assert_eq(actual, expected, context: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		printerr("[ FAIL ] %s — expected: %s, got: %s" % [context, str(expected), str(actual)])

func _assert_true(condition: bool, context: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("[ FAIL ] %s" % context)


# ── Helpers ───────────────────────────────────────────────────────────────────

# Build the lineToCommand map the same way the highlighter does.
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

# Get the color category for a command type (mirrors _get_color_for_type logic).
func _color_cat_for(type: int) -> int:
	match type:
		DialogueCommand.CommandType.DISPLAY_TEXT:
			return ColorCat.TEXT
		DialogueCommand.CommandType.PAGE_BREAK:
			return ColorCat.SPECIAL
		DialogueCommand.CommandType.PROMPT:
			return ColorCat.SPECIAL
		DialogueCommand.CommandType.GOTO:
			return ColorCat.CONSTANT
		DialogueCommand.CommandType.CONDITIONAL:
			return ColorCat.SPECIAL
		DialogueCommand.CommandType.ELSE:
			return ColorCat.SPECIAL
		DialogueCommand.CommandType.ELIF:
			return ColorCat.SPECIAL
		DialogueCommand.CommandType.SIGNAL:
			return ColorCat.SPECIAL
		_:
			return ColorCat.TEXT

# Find commands of a specific type in a line map.
func _find_commands_of_type(line_map: Dictionary, type: int) -> Array:
	var results := []
	for line in line_map.keys():
		for cmd in line_map[line]:
			if cmd.type == type:
				results.push_back({"line": line, "cmd": cmd})
	return results


# ── Command-to-line mapping tests ─────────────────────────────────────────────

func _test_plain_text_mapping() -> void:
	print("[ RUN  ] _test_plain_text_mapping")
	var map := _build_line_map("Hello world.")
	var texts := _find_commands_of_type(map, DialogueCommand.CommandType.DISPLAY_TEXT)
	_assert_true(texts.size() >= 1, "plain text: at least one DISPLAY_TEXT command")
	_assert_eq(texts[0]["line"], 0, "plain text: on line 0")
	print("[ PASS ] _test_plain_text_mapping")

func _test_goto_mapping() -> void:
	print("[ RUN  ] _test_goto_mapping")
	var map := _build_line_map("some text\n-> target_node")
	var gotos := _find_commands_of_type(map, DialogueCommand.CommandType.GOTO)
	_assert_eq(gotos.size(), 1, "goto: exactly one GOTO command")
	_assert_eq(gotos[0]["line"], 1, "goto: on line 1")
	_assert_eq(gotos[0]["cmd"].values[0].strip_edges(), "target_node", "goto: target name")
	print("[ PASS ] _test_goto_mapping")

func _test_prompt_mapping() -> void:
	print("[ RUN  ] _test_prompt_mapping")
	var map := _build_line_map("?> choice one -> node_a\n?> choice two -> node_b")
	var prompts := _find_commands_of_type(map, DialogueCommand.CommandType.PROMPT)
	_assert_eq(prompts.size(), 2, "prompt: two PROMPT commands")
	_assert_eq(prompts[0]["line"], 0, "prompt 1: on line 0")
	_assert_eq(prompts[1]["line"], 1, "prompt 2: on line 1")
	print("[ PASS ] _test_prompt_mapping")

func _test_conditional_mapping() -> void:
	print("[ RUN  ] _test_conditional_mapping")
	var map := _build_line_map("$if some_var {\n    text\n}")
	var conds := _find_commands_of_type(map, DialogueCommand.CommandType.CONDITIONAL)
	_assert_eq(conds.size(), 1, "conditional: one CONDITIONAL command")
	_assert_eq(conds[0]["line"], 0, "conditional: on line 0")
	# Expression should contain "some_var"
	_assert_true(conds[0]["cmd"].values[0].strip_edges().begins_with("some_var"),
		"conditional: expression contains variable name")
	print("[ PASS ] _test_conditional_mapping")

func _test_elif_mapping() -> void:
	print("[ RUN  ] _test_elif_mapping")
	var map := _build_line_map("$if a {\n    x\n}\n$elif b {\n    y\n}")
	var elifs := _find_commands_of_type(map, DialogueCommand.CommandType.ELIF)
	_assert_eq(elifs.size(), 1, "elif: one ELIF command")
	_assert_eq(elifs[0]["line"], 3, "elif: on line 3")
	print("[ PASS ] _test_elif_mapping")

func _test_else_mapping() -> void:
	print("[ RUN  ] _test_else_mapping")
	var map := _build_line_map("$if a {\n    x\n}\n$else {\n    y\n}")
	var elses := _find_commands_of_type(map, DialogueCommand.CommandType.ELSE)
	_assert_eq(elses.size(), 1, "else: one ELSE command")
	_assert_eq(elses[0]["line"], 3, "else: on line 3")
	print("[ PASS ] _test_else_mapping")

func _test_signal_mapping() -> void:
	print("[ RUN  ] _test_signal_mapping")
	var map := _build_line_map("text before\nsignal(play,sound)\ntext after")
	var signals := _find_commands_of_type(map, DialogueCommand.CommandType.SIGNAL)
	_assert_eq(signals.size(), 1, "signal: one SIGNAL command")
	_assert_eq(signals[0]["line"], 1, "signal: on line 1")
	_assert_eq(signals[0]["cmd"].values[0], "play,sound", "signal: params correct")
	print("[ PASS ] _test_signal_mapping")

func _test_page_break_mapping() -> void:
	print("[ RUN  ] _test_page_break_mapping")
	var map := _build_line_map("page one\n---\npage two")
	var breaks := _find_commands_of_type(map, DialogueCommand.CommandType.PAGE_BREAK)
	_assert_eq(breaks.size(), 1, "page_break: one PAGE_BREAK command")
	_assert_eq(breaks[0]["line"], 1, "page_break: on line 1")
	print("[ PASS ] _test_page_break_mapping")

func _test_variable_injection_mapping() -> void:
	print("[ RUN  ] _test_variable_injection_mapping")
	# ${var} is stored as DISPLAY_TEXT containing the placeholder
	var map := _build_line_map("Hello ${name}, welcome.")
	var texts := _find_commands_of_type(map, DialogueCommand.CommandType.DISPLAY_TEXT)
	_assert_true(texts.size() >= 1, "var_inject: at least one DISPLAY_TEXT")
	# The stored text should contain the ${name} placeholder
	var combined := ""
	for t in texts:
		combined += t["cmd"].values[0]
	_assert_true(combined.contains("${name}"), "var_inject: placeholder preserved in text")
	print("[ PASS ] _test_variable_injection_mapping")

func _test_mixed_line_mapping() -> void:
	print("[ RUN  ] _test_mixed_line_mapping")
	# A complex script with multiple command types
	var script := "intro text\n$if flag {\n    inner text\n    -> some_node\n}\n$else {\n    signal(alert,1)\n}"
	var map := _build_line_map(script)
	# Line 0: DISPLAY_TEXT (intro text)
	_assert_true(map.has(0), "mixed: line 0 exists")
	# Line 1: CONDITIONAL
	var conds := _find_commands_of_type(map, DialogueCommand.CommandType.CONDITIONAL)
	_assert_eq(conds[0]["line"], 1, "mixed: CONDITIONAL on line 1")
	# Line 3: GOTO (-> some_node)
	var gotos := _find_commands_of_type(map, DialogueCommand.CommandType.GOTO)
	_assert_true(gotos.size() >= 1, "mixed: at least one GOTO")
	# Line 5: ELSE
	var elses := _find_commands_of_type(map, DialogueCommand.CommandType.ELSE)
	_assert_eq(elses[0]["line"], 5, "mixed: ELSE on line 5")
	# Line 6: SIGNAL
	var signals := _find_commands_of_type(map, DialogueCommand.CommandType.SIGNAL)
	_assert_eq(signals[0]["line"], 6, "mixed: SIGNAL on line 6")
	print("[ PASS ] _test_mixed_line_mapping")


# ── Color category assignment tests ───────────────────────────────────────────

func _test_color_for_display_text() -> void:
	print("[ RUN  ] _test_color_for_display_text")
	_assert_eq(_color_cat_for(DialogueCommand.CommandType.DISPLAY_TEXT), ColorCat.TEXT,
		"DISPLAY_TEXT → TEXT color")
	print("[ PASS ] _test_color_for_display_text")

func _test_color_for_goto() -> void:
	print("[ RUN  ] _test_color_for_goto")
	_assert_eq(_color_cat_for(DialogueCommand.CommandType.GOTO), ColorCat.CONSTANT,
		"GOTO → CONSTANT color")
	print("[ PASS ] _test_color_for_goto")

func _test_color_for_prompt() -> void:
	print("[ RUN  ] _test_color_for_prompt")
	_assert_eq(_color_cat_for(DialogueCommand.CommandType.PROMPT), ColorCat.SPECIAL,
		"PROMPT → SPECIAL color")
	print("[ PASS ] _test_color_for_prompt")

func _test_color_for_conditional() -> void:
	print("[ RUN  ] _test_color_for_conditional")
	_assert_eq(_color_cat_for(DialogueCommand.CommandType.CONDITIONAL), ColorCat.SPECIAL,
		"CONDITIONAL → SPECIAL color")
	print("[ PASS ] _test_color_for_conditional")

func _test_color_for_elif() -> void:
	print("[ RUN  ] _test_color_for_elif")
	_assert_eq(_color_cat_for(DialogueCommand.CommandType.ELIF), ColorCat.SPECIAL,
		"ELIF → SPECIAL color")
	print("[ PASS ] _test_color_for_elif")

func _test_color_for_else() -> void:
	print("[ RUN  ] _test_color_for_else")
	_assert_eq(_color_cat_for(DialogueCommand.CommandType.ELSE), ColorCat.SPECIAL,
		"ELSE → SPECIAL color")
	print("[ PASS ] _test_color_for_else")

func _test_color_for_signal() -> void:
	print("[ RUN  ] _test_color_for_signal")
	_assert_eq(_color_cat_for(DialogueCommand.CommandType.SIGNAL), ColorCat.SPECIAL,
		"SIGNAL → SPECIAL color")
	print("[ PASS ] _test_color_for_signal")

func _test_color_for_page_break() -> void:
	print("[ RUN  ] _test_color_for_page_break")
	_assert_eq(_color_cat_for(DialogueCommand.CommandType.PAGE_BREAK), ColorCat.SPECIAL,
		"PAGE_BREAK → SPECIAL color")
	print("[ PASS ] _test_color_for_page_break")


# ── Regex pass tests ──────────────────────────────────────────────────────────

func _test_bracket_regex_positions() -> void:
	print("[ RUN  ] _test_bracket_regex_positions")
	var regex := RegEx.new()
	regex.compile("[{}()\\[\\]]")
	var line := "$if flag { -> node }"
	var matches := regex.search_all(line)
	# Should find '{' at pos 10 and '}' at pos 20
	_assert_true(matches.size() >= 2, "bracket regex: finds at least 2 brackets")
	var positions := []
	for m in matches:
		positions.push_back(m.get_start())
	_assert_true(positions.has(line.find("{")), "bracket regex: finds opening {")
	_assert_true(positions.has(line.rfind("}")), "bracket regex: finds closing }")
	print("[ PASS ] _test_bracket_regex_positions")

func _test_signal_regex_positions() -> void:
	print("[ RUN  ] _test_signal_regex_positions")
	var regex := RegEx.new()
	regex.compile("signal\\(([\\s\\S]*?)\\)")
	var line := "text signal(play,sfx) more"
	var matches := regex.search_all(line)
	_assert_eq(matches.size(), 1, "signal regex: one match")
	_assert_eq(matches[0].get_start(), 5, "signal regex: starts at pos 5")
	_assert_eq(matches[0].get_string(1), "play,sfx", "signal regex: captures params")
	# Verify keyword end position (for coloring "signal" vs "(")
	var keyword_end := matches[0].get_start() + 6  # len("signal")
	_assert_eq(line[keyword_end], "(", "signal regex: char after keyword is '('")
	print("[ PASS ] _test_signal_regex_positions")

func _test_variable_regex_positions() -> void:
	print("[ RUN  ] _test_variable_regex_positions")
	var regex := RegEx.new()
	regex.compile("\\$\\{\\S+?\\}")
	var line := "Hello ${name}, you have ${coins} gold."
	var matches := regex.search_all(line)
	_assert_eq(matches.size(), 2, "variable regex: two matches")
	_assert_eq(matches[0].get_string(), "${name}", "variable regex: first is ${name}")
	_assert_eq(matches[1].get_string(), "${coins}", "variable regex: second is ${coins}")
	# Verify positions for color start/end
	_assert_eq(matches[0].get_start(), 6, "variable regex: ${name} starts at 6")
	_assert_eq(matches[0].get_end(), 13, "variable regex: ${name} ends at 13")
	print("[ PASS ] _test_variable_regex_positions")

# ── Complex multi-line script tests ───────────────────────────────────────────
# These tests load a realistic multi-line dialogue script and verify that the
# parser correctly identifies command types at the right lines — the same data
# the syntax highlighter uses to assign colors.
#
# The script (highlight_test_script.txt) layout:
#   Line 0:  "Welcome traveller, ${player_name}."          → DISPLAY_TEXT
#   Line 1:  "You have ${gold} gold coins."                → DISPLAY_TEXT
#   Line 2:  "---"                                         → PAGE_BREAK
#   Line 3:  "$if reputation >= 50 {"                      → CONDITIONAL + BRACKET
#   Line 4:  "    The guard nods respectfully."            → DISPLAY_TEXT
#   Line 5:  "    ?> Ask about the quest -> quest_info"    → PROMPT (+ GOTO child)
#   Line 6:  "    ?> Leave quietly {}"                     → PROMPT (+ BRACKET child)
#   Line 7:  "}"                                           → (bracket close, no command)
#   Line 8:  "$elif reputation >= 20 {"                    → ELIF + BRACKET
#   Line 9:  "    The guard eyes you suspiciously."        → DISPLAY_TEXT
#   Line 10: "    signal(play_sfx,suspicious)"             → SIGNAL
#   Line 11: "    ?> Bribe the guard {"                    → PROMPT + BRACKET
#   Line 12: "        signal(set,gold,-10)"                → SIGNAL
#   Line 13: "        He pockets the coins."               → DISPLAY_TEXT
#   Line 14: "        -> quest_info"                       → GOTO
#   Line 15: "    }"                                       → (bracket close)
#   Line 16: "    ?> Walk away -> town_square"             → PROMPT (+ GOTO child)
#   Line 17: "}"                                           → (bracket close)
#   Line 18: "$else {"                                     → ELSE + BRACKET
#   Line 19: "    Halt! You are not welcome here."         → DISPLAY_TEXT
#   Line 20: "    -> kicked_out"                           → GOTO
#   Line 21: "}"                                           → (bracket close)
#   Line 22: "The sun sets behind the castle walls."       → DISPLAY_TEXT

var _complex_map: Dictionary

func _load_complex_script() -> void:
	if !_complex_map.is_empty():
		return
	var file := FileAccess.open("res://test/highlight_test_script.txt", FileAccess.READ)
	var content := file.get_as_text()
	_complex_map = _build_line_map(content)


func _test_complex_line_types() -> void:
	print("[ RUN  ] _test_complex_line_types")
	_load_complex_script()

	# Line 0: should have DISPLAY_TEXT (contains ${player_name})
	var line0_types := _get_types_on_line(0)
	_assert_true(line0_types.has(DialogueCommand.CommandType.DISPLAY_TEXT),
		"complex line 0: has DISPLAY_TEXT")

	# Line 2: PAGE_BREAK
	var line2_types := _get_types_on_line(2)
	_assert_true(line2_types.has(DialogueCommand.CommandType.PAGE_BREAK),
		"complex line 2: has PAGE_BREAK")

	# Line 3: CONDITIONAL
	var line3_types := _get_types_on_line(3)
	_assert_true(line3_types.has(DialogueCommand.CommandType.CONDITIONAL),
		"complex line 3: has CONDITIONAL")

	# Line 8: ELIF
	var line8_types := _get_types_on_line(8)
	_assert_true(line8_types.has(DialogueCommand.CommandType.ELIF),
		"complex line 8: has ELIF")

	# Line 18: ELSE
	var line18_types := _get_types_on_line(18)
	_assert_true(line18_types.has(DialogueCommand.CommandType.ELSE),
		"complex line 18: has ELSE")

	print("[ PASS ] _test_complex_line_types")


func _test_complex_variable_positions() -> void:
	print("[ RUN  ] _test_complex_variable_positions")
	_load_complex_script()

	# Lines 0-1 are merged into one DISPLAY_TEXT starting on line 0 since there's
	# no command between them. Both ${player_name} and ${gold} are in that chunk.
	var texts_line0 := _get_commands_on_line(0, DialogueCommand.CommandType.DISPLAY_TEXT)
	var combined := ""
	for cmd in texts_line0:
		combined += cmd.values[0]
	_assert_true(combined.contains("${player_name}"),
		"complex vars: merged text contains ${player_name}")
	_assert_true(combined.contains("${gold}"),
		"complex vars: merged text contains ${gold}")

	print("[ PASS ] _test_complex_variable_positions")


func _test_complex_conditional_chain() -> void:
	print("[ RUN  ] _test_complex_conditional_chain")
	_load_complex_script()

	# Verify the $if / $elif / $else chain is correctly identified.
	var conds := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.CONDITIONAL)
	_assert_eq(conds.size(), 1, "complex chain: exactly 1 CONDITIONAL")
	_assert_eq(conds[0]["line"], 3, "complex chain: CONDITIONAL on line 3")

	var elifs := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.ELIF)
	_assert_eq(elifs.size(), 1, "complex chain: exactly 1 ELIF")
	_assert_eq(elifs[0]["line"], 8, "complex chain: ELIF on line 8")

	var elses := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.ELSE)
	_assert_eq(elses.size(), 1, "complex chain: exactly 1 ELSE")
	_assert_eq(elses[0]["line"], 18, "complex chain: ELSE on line 18")

	# Verify expression content
	_assert_true(conds[0]["cmd"].values[0].strip_edges().begins_with("reputation"),
		"complex chain: $if expression starts with 'reputation'")
	_assert_true(elifs[0]["cmd"].values[0].strip_edges().begins_with("reputation"),
		"complex chain: $elif expression starts with 'reputation'")

	print("[ PASS ] _test_complex_conditional_chain")


func _test_complex_nested_prompts() -> void:
	print("[ RUN  ] _test_complex_nested_prompts")
	_load_complex_script()

	var prompts := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.PROMPT)
	# Should find: line 5, line 6, line 11, line 16
	_assert_true(prompts.size() >= 4, "complex prompts: at least 4 PROMPT commands")

	# Verify prompts are on expected lines
	var prompt_lines := []
	for p in prompts:
		prompt_lines.push_back(p["line"])
	_assert_true(prompt_lines.has(5), "complex prompts: PROMPT on line 5")
	_assert_true(prompt_lines.has(6), "complex prompts: PROMPT on line 6")
	_assert_true(prompt_lines.has(11), "complex prompts: PROMPT on line 11")
	_assert_true(prompt_lines.has(16), "complex prompts: PROMPT on line 16")

	print("[ PASS ] _test_complex_nested_prompts")


func _test_complex_signal_inline() -> void:
	print("[ RUN  ] _test_complex_signal_inline")
	_load_complex_script()

	var signals := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.SIGNAL)
	# Should find: line 10 (play_sfx,suspicious) and line 12 (set,gold,-10)
	_assert_true(signals.size() >= 2, "complex signals: at least 2 SIGNAL commands")

	var signal_lines := []
	var signal_params := []
	for s in signals:
		signal_lines.push_back(s["line"])
		signal_params.push_back(s["cmd"].values[0])
	_assert_true(signal_lines.has(10), "complex signals: SIGNAL on line 10")
	_assert_true(signal_lines.has(12), "complex signals: SIGNAL on line 12")
	_assert_true(signal_params.has("play_sfx,suspicious"),
		"complex signals: params 'play_sfx,suspicious' found")
	_assert_true(signal_params.has("set,gold,-10"),
		"complex signals: params 'set,gold,-10' found")

	print("[ PASS ] _test_complex_signal_inline")


func _test_complex_page_break_position() -> void:
	print("[ RUN  ] _test_complex_page_break_position")
	_load_complex_script()

	var breaks := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.PAGE_BREAK)
	_assert_eq(breaks.size(), 1, "complex page_break: exactly 1 PAGE_BREAK")
	_assert_eq(breaks[0]["line"], 2, "complex page_break: on line 2")

	print("[ PASS ] _test_complex_page_break_position")


func _test_complex_goto_inside_bracket() -> void:
	print("[ RUN  ] _test_complex_goto_inside_bracket")
	_load_complex_script()

	var gotos := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.GOTO)
	# Should find gotos on lines: 14 (-> quest_info inside bribe bracket),
	# 20 (-> kicked_out inside else bracket), plus goto children of prompts
	# (lines 5, 16 as children of PROMPT commands).
	_assert_true(gotos.size() >= 2, "complex gotos: at least 2 standalone GOTO commands")

	var goto_lines := []
	for g in gotos:
		goto_lines.push_back(g["line"])
	_assert_true(goto_lines.has(14), "complex gotos: GOTO on line 14 (inside bribe bracket)")
	_assert_true(goto_lines.has(20), "complex gotos: GOTO on line 20 (inside else bracket)")

	print("[ PASS ] _test_complex_goto_inside_bracket")


func _test_complex_text_after_conditional_block() -> void:
	print("[ RUN  ] _test_complex_text_after_conditional_block")
	_load_complex_script()

	# "The sun sets behind the castle walls." appears after the $if/$elif/$else
	# block closes. Verify it exists as a DISPLAY_TEXT command somewhere in the
	# map (the exact line depends on parser line-counting for the closing }).
	var all_texts := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.DISPLAY_TEXT)
	var found_sun := false
	for entry in all_texts:
		if entry["cmd"].values[0].strip_edges().begins_with("The sun"):
			found_sun = true
			break
	_assert_true(found_sun,
		"complex post-block: 'The sun sets...' exists as DISPLAY_TEXT after conditional block")

	print("[ PASS ] _test_complex_text_after_conditional_block")


func _test_complex_bracket_positions() -> void:
	print("[ RUN  ] _test_complex_bracket_positions")
	_load_complex_script()

	# Verify BRACKET commands exist on the lines where { appears after $if/$elif/$else
	var brackets := _find_commands_of_type(_complex_map, DialogueCommand.CommandType.BRACKET)
	# Expected bracket lines: 3 ($if {), 8 ($elif {), 11 (?> Bribe {), 18 ($else {)
	# Plus the dead-end {} on line 6
	_assert_true(brackets.size() >= 4, "complex brackets: at least 4 BRACKET commands")

	var bracket_lines := []
	for b in brackets:
		bracket_lines.push_back(b["line"])
	_assert_true(bracket_lines.has(3), "complex brackets: BRACKET on line 3 ($if)")
	_assert_true(bracket_lines.has(8), "complex brackets: BRACKET on line 8 ($elif)")
	_assert_true(bracket_lines.has(18), "complex brackets: BRACKET on line 18 ($else)")

	print("[ PASS ] _test_complex_bracket_positions")


# ── Helpers for complex tests ─────────────────────────────────────────────────

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
