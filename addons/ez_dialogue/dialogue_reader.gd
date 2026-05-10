@tool
class_name EzDialogueReader extends Node

## (DEPRECATED — use DialogueResponse.eod_reached from the dialogue_generated signal instead.)
## @deprecated
signal end_of_dialogue_reached()

## Emitted when the current "page" of dialogue is processed.
signal dialogue_generated(response: DialogueResponse)

## Emitted when the dialogue executes a signal(...) command.
signal custom_signal_received(value)

const MAX_COMMANDS_PER_FRAME := 500

var is_running := false
var history_stack_size := 100
var dialogue_visit_history: Array[String]

var _resource_cache: Dictionary = {}
var _processing_dialogue: DialogueResource
var _executing_command_stack: Array[DialogueCommand]
var _pending_choice_actions: Array
var _stateReference: Dictionary
var _current_response: DialogueResponse

# Localization state
var _translation_tables: Dictionary = {}   # { locale_string: { token: translated_text } }
var _active_locale: String = ""

# Per-dialogue token index built on start_dialogue()
# Maps: normalized_node_name → { "display": [token1, token2, ...], "choice": [token1, ...] }
var _current_token_index: Dictionary = {}

# Runtime counters (reset per node traversal)
var _display_counter: int = 0
var _choice_counter: int = 0
var _current_node_normalized: String = ""

# Precompiled regex — avoids recompiling on every text/expression evaluation.
var _placeholder_regex := _compile("\\${(\\S+?)}")
var _nested_key_regex := _compile("(\"\\S+?\")")
var _variable_pattern := _compile("[a-zA-Z_][a-zA-Z_\\d]*(\\[\"[a-zA-Z_\\d]+?\"\\])*")

static func _compile(pattern: String) -> RegEx:
	var r := RegEx.new()
	r.compile(pattern)
	return r


# ── Core loop ─────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not is_running:
		return

	if _current_response == null:
		_current_response = DialogueResponse.new()

	var count := 0
	while is_running:
		if _executing_command_stack.is_empty():
			is_running = false
			if _pending_choice_actions.is_empty():
				_current_response.eod_reached = true
				end_of_dialogue_reached.emit()
			break

		_process_command(_executing_command_stack.pop_front(), _current_response)
		count += 1
		if count >= MAX_COMMANDS_PER_FRAME:
			return  # carry over to next frame

	dialogue_generated.emit(_current_response)
	_current_response = null


# ── Public API ────────────────────────────────────────────────────────────────

## Start processing dialogue. Accepts JSON (legacy), String path to .ezd, or Resource.
func start_dialogue(dialogue, state: Dictionary, starting_node_name: String = "start") -> void:
	_load_dialogue(dialogue)
	# Build token index for translation lookup if a locale is active
	if not _active_locale.is_empty():
		_build_token_index()
	else:
		_current_token_index = {}
	var node := _processing_dialogue.get_node_by_name(starting_node_name)
	_executing_command_stack = node.get_parse()
	_pending_choice_actions = []
	_current_response = null
	dialogue_visit_history = [node.name]
	_stateReference = state
	# Initialize node counters for the starting node
	_reset_node_counters(node.name)
	is_running = true

## Advance to the next page or select a choice.
func next(choice_index: int = 0) -> void:
	if is_running:
		return
	if choice_index >= 0 and choice_index < _pending_choice_actions.size():
		var commands := _pending_choice_actions[choice_index] as Array[DialogueCommand]
		commands.append_array(_executing_command_stack)
		_executing_command_stack = commands
		_pending_choice_actions = []
	_current_response = null
	is_running = true


# ── Localization API ──────────────────────────────────────────────────────────

## Set the Translation Table for a given locale.
func set_translation_table(locale: String, table: Dictionary) -> void:
	_translation_tables[locale] = table

## Get the Translation Table for a given locale (returns empty Dict if none loaded).
func get_translation_table(locale: String) -> Dictionary:
	return _translation_tables.get(locale, {})

## Clear the Translation Table for a given locale.
func clear_translation_table(locale: String) -> void:
	_translation_tables.erase(locale)

## Set the active locale for translation lookups. Empty string disables translation.
func set_locale(locale: String) -> void:
	_active_locale = locale
	# Build token index if dialogue is already loaded and locale is being activated
	if not _active_locale.is_empty() and _processing_dialogue != null and _current_token_index.is_empty():
		_build_token_index()

## Get the current active locale.
func get_locale() -> String:
	return _active_locale

## Load a Translation Table from a CSV file for the given locale.
## Uses DialogueTokenizer.import_csv() internally.
## Returns OK on success, or ERR_FILE_CANT_OPEN if the file cannot be read.
func load_translation_csv(locale: String, file_path: String) -> Error:
	var result := DialogueTokenizer.new().import_csv(file_path)
	if result.is_empty():
		return ERR_FILE_CANT_OPEN
	set_translation_table(locale, result)
	return OK


# ── Translation helpers ────────────────────────────────────────────────────────

## Look up a token in the active translation table and return translated text,
## or the original text if no translation is available.
func _translate_text(token: String, original: String) -> String:
	if _active_locale.is_empty():
		return original
	var table = _translation_tables.get(_active_locale, {})
	var translated = table.get(token, "")
	if translated.is_empty():
		return original
	return translated

## Build the internal token index from the current DialogueResource.
## Maps normalized_node_name → { "display": [token1, ...], "choice": [token1, ...] }
func _build_token_index() -> void:
	_current_token_index = {}
	if _processing_dialogue == null:
		return
	var tokenizer := DialogueTokenizer.new()
	for node in _processing_dialogue.dialogue_nodes:
		var normalized_name := node.name.to_lower().replace(" ", "_")
		var display_tokens: Array[String] = []
		var choice_tokens: Array[String] = []
		var entries := tokenizer.tokenize_node(node)
		for entry in entries:
			var token_str: String = entry["token"]
			if token_str.find("_choice_") != -1:
				choice_tokens.append(token_str)
			else:
				display_tokens.append(token_str)
		_current_token_index[normalized_name] = {
			"display": display_tokens,
			"choice": choice_tokens
		}

## Reset per-node counters and set the current node for token tracking.
func _reset_node_counters(node_name: String) -> void:
	_current_node_normalized = node_name.to_lower().replace(" ", "_")
	_display_counter = 0
	_choice_counter = 0

## Get the current display token based on the counter, or return empty string.
func _get_current_display_token() -> String:
	var node_data = _current_token_index.get(_current_node_normalized, {})
	var tokens = node_data.get("display", [])
	if _display_counter > 0 and _display_counter <= tokens.size():
		return tokens[_display_counter - 1]
	return ""

## Get the current choice token based on the counter, or return empty string.
func _get_current_choice_token() -> String:
	var node_data = _current_token_index.get(_current_node_normalized, {})
	var tokens = node_data.get("choice", [])
	if _choice_counter > 0 and _choice_counter <= tokens.size():
		return tokens[_choice_counter - 1]
	return ""


# ── Command processing ────────────────────────────────────────────────────────

func _process_command(command: DialogueCommand, response: DialogueResponse) -> void:
	match command.type:
		DialogueCommand.CommandType.ROOT, DialogueCommand.CommandType.BRACKET:
			_prepend_children(command.children)

		DialogueCommand.CommandType.SIGNAL:
			custom_signal_received.emit(command.values[0])

		DialogueCommand.CommandType.DISPLAY_TEXT:
			var text: String = (command.values[0] as String).strip_edges(true, true)
			_display_counter += 1
			var token := _get_current_display_token()
			if not token.is_empty():
				text = _translate_text(token, text)
			response.append_text(_inject_variables(text))

		DialogueCommand.CommandType.PAGE_BREAK:
			is_running = false

		DialogueCommand.CommandType.PROMPT:
			var prompt: String = command.values[0].strip_edges()
			_choice_counter += 1
			var choice_token := _get_current_choice_token()
			if not choice_token.is_empty():
				prompt = _translate_text(choice_token, prompt)
			prompt = _inject_variables(prompt)
			var actions: Array[DialogueCommand] = []
			actions.append_array(command.children)
			response.append_choice(prompt)
			_pending_choice_actions.push_back(actions)

		DialogueCommand.CommandType.GOTO:
			var dest := _processing_dialogue.get_node_by_name(command.values[0])
			_executing_command_stack = dest.get_parse()
			_push_history(dest.name)
			_reset_node_counters(dest.name)

		DialogueCommand.CommandType.CONDITIONAL, DialogueCommand.CommandType.ELIF:
			if _evaluate_expression(command.values[0]):
				_drop_elif_else_chain()
				_prepend_children(command.children)

		DialogueCommand.CommandType.ELSE:
			_prepend_children(command.children)


# ── Stack helpers ─────────────────────────────────────────────────────────────

func _prepend_children(children: Array[DialogueCommand]) -> void:
	var copy := children.duplicate(true)
	copy.append_array(_executing_command_stack)
	_executing_command_stack = copy

func _drop_elif_else_chain() -> void:
	while not _executing_command_stack.is_empty():
		var t := _executing_command_stack[0].type
		if t == DialogueCommand.CommandType.ELIF or t == DialogueCommand.CommandType.ELSE:
			_executing_command_stack.pop_front()
		else:
			break

func _push_history(node_name: String) -> void:
	dialogue_visit_history.push_front(node_name)
	if dialogue_visit_history.size() > history_stack_size:
		dialogue_visit_history.resize(history_stack_size)


# ── Dialogue loading ──────────────────────────────────────────────────────────

func _load_dialogue(dialogue) -> void:
	var cache_key: String
	var loader: Callable

	if dialogue is JSON:
		cache_key = dialogue.resource_path
		loader = func():
			var res := DialogueResource.new()
			res.loadFromJson(dialogue.data)
			return res
	elif dialogue is String:
		cache_key = dialogue
		loader = func(): return EzdFileParser.new().parse_file(dialogue)
	elif dialogue is Resource and dialogue.resource_path.ends_with(".ezd"):
		cache_key = dialogue.resource_path
		loader = func(): return EzdFileParser.new().parse_file(dialogue.resource_path)
	else:
		printerr("EzDialogueReader: Unsupported dialogue type: " + str(typeof(dialogue)))
		return

	if not _resource_cache.has(cache_key):
		var res = loader.call()
		if res == null:
			printerr("EzDialogueReader: Failed to load: " + cache_key)
			return
		_resource_cache[cache_key] = res

	_processing_dialogue = _resource_cache[cache_key]


# ── Variable injection ────────────────────────────────────────────────────────

func _inject_variables(text: String) -> String:
	var result := text
	for m in _placeholder_regex.search_all(result):
		var inner := m.get_string(1)
		var nested := _nested_key_regex.search_all(inner)
		var value: String
		var placeholder: String

		if nested.size() > 0:
			var keys := _build_key_path(inner, nested)
			var raw_val = _resolve_nested(keys)
			value = str(raw_val) if raw_val != null else ""
			placeholder = "${%s}" % keys[0]
		else:
			var raw_val = _stateReference.get(inner)
			value = str(raw_val) if raw_val != null else ""
			placeholder = "${%s}" % inner

		result = result.replace(placeholder, value)
	return result


# ── Conditional expression evaluation ────────────────────────────────────────

func _evaluate_expression(expression: String) -> bool:
	var substituted := expression
	var simple_names: PackedStringArray = []
	var simple_values: Array = []
	var seen: Dictionary = {}

	# Sort matches longest-first to avoid partial replacement.
	var matches := _variable_pattern.search_all(expression)
	matches.sort_custom(func(a, b): return a.get_string(0).length() > b.get_string(0).length())

	for vm in matches:
		var token := vm.get_string(0)
		if _is_literal(token) or seen.has(token):
			continue
		seen[token] = true

		var nested := _nested_key_regex.search_all(token)
		if nested.size() > 0:
			# Nested dict access — substitute resolved value into expression string.
			var keys := _build_key_path(token, nested)
			var resolved = _resolve_nested(keys)
			substituted = substituted.replace(token, _to_expr_literal(resolved))
		else:
			# Simple variable — pass as named input to Expression.
			var resolved = _stateReference.get(token)
			simple_names.push_back(token)
			simple_values.push_back(resolved if resolved != null else false)

	var eval := Expression.new()
	if eval.parse(substituted, simple_names) != OK:
		printerr("Error in [%s]: Parse failed '%s': %s" \
			% [_current_node_name(), substituted, eval.get_error_text()])
		return false

	var result = eval.execute(simple_values)
	if eval.has_execute_failed():
		printerr("Error in [%s]: Execute failed '%s': %s" \
			% [_current_node_name(), substituted, eval.get_error_text()])
		return false

	return bool(result)


# ── State resolution helpers ──────────────────────────────────────────────────

func _resolve_nested(keys: Array):
	# keys = [full_token, base_name, key1, key2, ...]
	var current = _stateReference
	for idx in range(1, keys.size()):
		var key = keys[idx]
		if current is Dictionary:
			if current.has(key):
				current = current[key]
			else:
				printerr("Error in [%s]: Key '%s' not found (path: '%s')" \
					% [_current_node_name(), key, keys[0]])
				return null
		elif current is Resource:
			var prop = (current as Resource).get(key)
			if prop != null:
				current = prop
			else:
				printerr("Error in [%s]: Property '%s' not found (path: '%s')" \
					% [_current_node_name(), key, keys[0]])
				return null
		else:
			break
	return current

func _build_key_path(token: String, nested_matches: Array[RegExMatch]) -> Array:
	var result: Array = [token, token.left(token.find("["))]
	for m in nested_matches:
		result.append(m.get_string(1).replace("\"", ""))
	return result

func _is_literal(token: String) -> bool:
	return ["true", "false", "null"].has(token) \
		or token.is_valid_float() \
		or token.is_valid_int() \
		or token.begins_with("\"")

func _to_expr_literal(value) -> String:
	if value == null:
		return "false"
	if value is String:
		return "\"" + value + "\""
	return str(value)

func _current_node_name() -> String:
	if dialogue_visit_history.is_empty():
		return "<unknown>"
	return dialogue_visit_history[0]
