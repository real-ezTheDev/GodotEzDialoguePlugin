#!/usr/bin/env -S godot -s
## Consolidated property-based tests for localization translation runtime.
##
## Covers: translation substitution, fallback to source text, variable injection,
## locale selection, and translation table round-trip.
##
## Run from the project root:
##   godot --headless --path . -s res://test/RunTranslationPBT.gd

extends "res://addons/ez_dialogue/dialogue_test/test_runner.gd"

const _DialogueCommand   = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_command.gd")
const _DialogueParser    = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_parser.gd")
const _DialogueNode      = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_node.gd")
const _DialogueResource  = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_resource.gd")
const _DialogueResponse  = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_response.gd")
const _EzDialogueReader  = preload("res://addons/ez_dialogue/dialogue_reader.gd")
const _DialogueTokenizer = preload("res://addons/ez_dialogue/dialogue_tokenizer.gd")

const ITERATIONS := 50
const TEMP_FILE_PATH := "res://test/_temp_translation_pbt.ezd"

var _rng := RandomNumberGenerator.new()


func _get_suite_name() -> String:
	return "Localization Translation Tests"


# ── Generators ────────────────────────────────────────────────────────────────

const NAME_WORDS := [
	"Start", "Quest", "Battle", "Shop", "Inn", "Forest", "Castle",
	"Dragon", "Village", "End", "Intro", "Outro", "Boss", "NPC"
]

const SOURCE_TEXTS := [
	"Hello adventurer!",
	"Welcome to the shop.",
	"The dragon approaches...",
	"You found a treasure chest!",
	"The path splits ahead.",
	"A mysterious stranger appears.",
	"The door is locked.",
	"You hear a strange noise.",
	"The sun sets over the horizon.",
	"A battle begins!",
	"You feel a cold breeze.",
	"The merchant smiles warmly.",
]

const SOURCE_CHOICES := [
	"Accept the quest",
	"Decline",
	"Ask for more info",
	"Fight",
	"Run away",
	"Buy the item",
	"Sell equipment",
	"Talk to NPC",
	"Open the door",
	"Ignore it",
]

const TRANSLATION_PREFIXES := [
	"[FR]", "[JA]", "[DE]", "[ES]", "[IT]", "[PT]", "[ZH]", "[KO]"
]

const LOCALES := ["en", "fr", "ja", "de", "es", "it", "pt", "zh", "ko", "ru"]

const VAR_NAMES: Array[String] = [
	"player_name", "npc_name", "item", "location", "count",
	"title", "quest", "gold", "level", "weapon"
]

const VAR_VALUES_STR: Array[String] = [
	"Ezra", "Gandalf", "Sword of Light", "Dark Forest", "Rivertown",
	"Captain", "Dragon Slayer", "Mystic Orb", "Ancient Temple", "Hero"
]

const TEXT_FRAGMENTS: Array[String] = [
	"Hello", "Welcome to", "You found", "Beware of", "The path leads to",
	"says", "greets you", "awaits", "is ready", "has arrived",
	"Good morning", "Farewell", "Listen carefully", "Look over there", "Come here"
]

const TRANSLATED_FRAGMENTS: Array[String] = [
	"Bonjour", "Bienvenue a", "Vous avez trouve", "Attention a", "Le chemin mene a",
	"dit", "vous salue", "attend", "est pret", "est arrive",
	"Guten Morgen", "Auf Wiedersehen", "Hoer gut zu", "Schau dort", "Komm her"
]


## Generate a random node name.
func _gen_node_name() -> String:
	var word_count := _rng.randi_range(1, 2)
	var parts: Array[String] = []
	for i in range(word_count):
		parts.append(NAME_WORDS[_rng.randi_range(0, NAME_WORDS.size() - 1)])
	var name := " ".join(parts)
	if _rng.randf() > 0.7:
		name = name.to_upper()
	return name


## Generate a random source display text.
func _gen_source_text() -> String:
	return SOURCE_TEXTS[_rng.randi_range(0, SOURCE_TEXTS.size() - 1)]


## Generate a random source choice text.
func _gen_choice_text() -> String:
	return SOURCE_CHOICES[_rng.randi_range(0, SOURCE_CHOICES.size() - 1)]


## Generate a translated version of a source text (clearly different from source).
func _gen_translated_text(source: String) -> String:
	var prefix: String = TRANSLATION_PREFIXES[_rng.randi_range(0, TRANSLATION_PREFIXES.size() - 1)]
	return "%s %s #%d" % [prefix, source.to_upper(), _rng.randi_range(100, 999)]


## Generate a random locale string.
func _gen_locale() -> String:
	return LOCALES[_rng.randi_range(0, LOCALES.size() - 1)]


## Generate a random variable name.
func _gen_var_name() -> String:
	return VAR_NAMES[_rng.randi_range(0, VAR_NAMES.size() - 1)]


## Generate a random variable value.
func _gen_var_value() -> String:
	if _rng.randf() < 0.3:
		return str(_rng.randi_range(1, 9999))
	return VAR_VALUES_STR[_rng.randi_range(0, VAR_VALUES_STR.size() - 1)]


## Generate a random text fragment.
func _gen_text_fragment() -> String:
	return TEXT_FRAGMENTS[_rng.randi_range(0, TEXT_FRAGMENTS.size() - 1)]


## Generate a random translated text fragment.
func _gen_translated_fragment() -> String:
	return TRANSLATED_FRAGMENTS[_rng.randi_range(0, TRANSLATED_FRAGMENTS.size() - 1)]


## Generate a random token string (for locale/table tests).
func _gen_token() -> String:
	var prefixes: Array[String] = ["start", "quest_node", "intro", "battle", "shop", "ending", "npc_talk"]
	var prefix: String = prefixes[_rng.randi_range(0, prefixes.size() - 1)]
	var index: int = _rng.randi_range(1, 20)
	if _rng.randf() > 0.7:
		return "%s_choice_%d" % [prefix, index]
	return "%s_%d" % [prefix, index]


## Generate a random translated text for table tests.
func _gen_table_translated_text(locale: String, token: String) -> String:
	return "[%s] Translated: %s #%d" % [locale, token, _rng.randi_range(1, 9999)]


## Generate a random translation table (for round-trip tests).
func _gen_translation_table() -> Dictionary:
	var table := {}
	var num_entries := _rng.randi_range(0, 20)
	for i in range(num_entries):
		var length := _rng.randi_range(3, 25)
		var chars := "abcdefghijklmnopqrstuvwxyz0123456789_"
		var token := ""
		token += char(_rng.randi_range(97, 122))
		for _j in range(length - 1):
			token += chars[_rng.randi_range(0, chars.length() - 1)]
		var text := ""
		var text_len := _rng.randi_range(1, 50)
		for _j in range(text_len):
			text += char(_rng.randi_range(32, 126))
		if _rng.randf() < 0.3:
			text += " ${" + token + "}"
		table[token] = text
	return table


## Generate a set of unique locale strings.
func _gen_unique_locales(count: int) -> Array[String]:
	var base_locales: Array[String] = ["en", "fr", "ja", "de", "es", "it", "pt", "zh", "ko", "ru", "ar", "hi"]
	var suffixes: Array[String] = ["", "_US", "_GB", "_AT", "_CN", "_BR", "_MX", "_JP"]
	var locales: Array[String] = []
	var seen := {}
	var attempts := 0
	while locales.size() < count and attempts < count * 10:
		var locale: String = base_locales[_rng.randi_range(0, base_locales.size() - 1)]
		if _rng.randf() > 0.5:
			locale += suffixes[_rng.randi_range(0, suffixes.size() - 1)]
		if not seen.has(locale):
			seen[locale] = true
			locales.append(locale)
		attempts += 1
	return locales


## Generate a shared set of tokens for locale tests.
func _gen_shared_tokens() -> Array[String]:
	var count := _rng.randi_range(1, 10)
	var tokens: Array[String] = []
	var seen := {}
	for i in range(count):
		var token := _gen_token()
		if not seen.has(token):
			seen[token] = true
			tokens.append(token)
	return tokens


## Build a commands_raw string with the given display texts and choices.
func _build_commands_raw(display_texts: Array[String], choices: Array[String]) -> String:
	var lines: Array[String] = []
	for text in display_texts:
		lines.append(text)
	for choice in choices:
		lines.append("?> %s" % choice)
	return "\n".join(lines)


## Create a JSON resource for EzDialogueReader.start_dialogue().
func _create_dialogue_json(node_name: String, display_texts: Array[String], choices: Array[String]) -> JSON:
	var commands_raw := _build_commands_raw(display_texts, choices)
	var json_data := [
		{
			"id": 0,
			"name": node_name,
			"gnode_name": node_name,
			"commands_raw": commands_raw,
			"position": [0.0, 0.0]
		}
	]
	var json := JSON.new()
	json.data = json_data
	return json


## Create a DialogueResource for tokenization.
func _create_resource_for_tokenization(node_name: String, display_texts: Array[String], choices: Array[String]) -> DialogueResource:
	var resource := DialogueResource.new()
	var node := DialogueNode.new()
	node.id = 0
	node.name = node_name
	node.gnode_name = node_name
	node.commands_raw = _build_commands_raw(display_texts, choices)
	resource.dialogue_nodes = [node]
	return resource


## Compute expected output after variable injection on translated text.
func _compute_expected_output(translated_text: String, state: Dictionary) -> String:
	var result := translated_text
	for var_name in state.keys():
		var placeholder := "${%s}" % var_name
		result = result.replace(placeholder, str(state[var_name]))
	return result


# ── Property Tests ────────────────────────────────────────────────────────────

## Property 5: For DISPLAY_TEXT and PROMPT commands with translations, the reader
## emits translated text instead of source text.
func test_translated_text_emitted_for_display_and_choices() -> void:
	_rng.seed = 42

	for i in range(ITERATIONS):
		var node_name := _gen_node_name()
		var num_texts := _rng.randi_range(1, 4)
		var num_choices := _rng.randi_range(1, 3)

		var display_texts: Array[String] = []
		for _j in range(num_texts):
			display_texts.append(_gen_source_text())

		var choices: Array[String] = []
		for _j in range(num_choices):
			choices.append(_gen_choice_text())

		var resource := _create_resource_for_tokenization(node_name, display_texts, choices)
		var dialogue_json := _create_dialogue_json(node_name, display_texts, choices)

		# Tokenize and build translation table
		var tokenizer := DialogueTokenizer.new()
		var entries := tokenizer.tokenize(resource)
		var table := {}
		var expected_display_translations: Array[String] = []
		var expected_choice_translations: Array[String] = []

		for entry in entries:
			var translated := _gen_translated_text(entry["source_text"])
			table[entry["token"]] = translated
			if entry["token"].contains("_choice_"):
				expected_choice_translations.append(translated)
			else:
				expected_display_translations.append(translated)

		# Set up reader
		var reader := EzDialogueReader.new()
		get_root().add_child(reader)
		reader.set_translation_table("test_locale", table)
		reader.set_locale("test_locale")

		reader.start_dialogue(dialogue_json, {}, node_name)
		var response: DialogueResponse = await reader.dialogue_generated

		# Verify display text
		var expected_text := "\n".join(expected_display_translations)
		assert_eq(response.text, expected_text,
			"iter %d: display text should be translated (node='%s')" % [i, node_name])

		# Verify choices
		assert_eq(response.choices.size(), expected_choice_translations.size(),
			"iter %d: should have %d choices" % [i, expected_choice_translations.size()])
		for j in range(min(response.choices.size(), expected_choice_translations.size())):
			assert_eq(response.choices[j], expected_choice_translations[j],
				"iter %d: choice %d should be translated" % [i, j])

		get_root().remove_child(reader)
		reader.queue_free()


## Property 6a: When a token is NOT present in the translation table,
## the reader emits the original source text.
func test_fallback_to_source_when_token_missing() -> void:
	_rng.seed = 100

	for i in range(ITERATIONS):
		var node_name := _gen_node_name()
		var num_texts := _rng.randi_range(1, 4)
		var display_texts: Array[String] = []
		for _j in range(num_texts):
			display_texts.append(_gen_source_text())

		var empty_choices: Array[String] = []
		var dialogue_json := _create_dialogue_json(node_name, display_texts, empty_choices)

		# Set up reader with a locale and a table that has UNRELATED tokens
		var reader := EzDialogueReader.new()
		get_root().add_child(reader)

		var locale := _gen_locale()
		var unrelated_table := {"unrelated_token_1": "Some translation", "other_key": "Other text"}
		reader.set_translation_table(locale, unrelated_table)
		reader.set_locale(locale)

		reader.start_dialogue(dialogue_json, {}, node_name)
		var response: DialogueResponse = await reader.dialogue_generated

		var expected_text := "\n".join(display_texts)
		assert_eq(response.text, expected_text,
			"iter %d: missing tokens should fall back to source text (node='%s')" % [i, node_name])

		get_root().remove_child(reader)
		reader.queue_free()


## Property 6f: Mixed scenario — partial translation table where some tokens
## have translations and others are missing or empty. Only the missing/empty
## ones should fall back to source text.
func test_partial_table_selective_fallback() -> void:
	_rng.seed = 600

	for i in range(ITERATIONS):
		var node_name := _gen_node_name()
		var num_texts := _rng.randi_range(2, 4)
		var display_texts: Array[String] = []
		for _j in range(num_texts):
			display_texts.append(_gen_source_text())

		var empty_choices: Array[String] = []
		var resource := _create_resource_for_tokenization(node_name, display_texts, empty_choices)
		var dialogue_json := _create_dialogue_json(node_name, display_texts, empty_choices)

		# Tokenize to get the actual tokens
		var tokenizer := DialogueTokenizer.new()
		var entries := tokenizer.tokenize(resource)

		# Build a partial translation table
		var table := {}
		var expected_texts: Array[String] = []

		for idx in range(entries.size()):
			var entry: Dictionary = entries[idx]
			var token: String = entry["token"]
			var source: String = entry["source_text"]
			var roll := _rng.randf()

			if roll < 0.33:
				# Real translation — should be used
				var translated := "[TRANSLATED] " + source
				table[token] = translated
				expected_texts.append(translated)
			elif roll < 0.66:
				# Empty string → fallback to source
				table[token] = ""
				expected_texts.append(source)
			else:
				# Missing key → fallback to source
				expected_texts.append(source)

		# Set up reader
		var reader := EzDialogueReader.new()
		get_root().add_child(reader)

		var locale := _gen_locale()
		reader.set_translation_table(locale, table)
		reader.set_locale(locale)

		reader.start_dialogue(dialogue_json, {}, node_name)
		var response: DialogueResponse = await reader.dialogue_generated

		var expected_text := "\n".join(expected_texts)
		assert_eq(response.text, expected_text,
			"iter %d: partial table should selectively fall back (node='%s')" % [i, node_name])

		get_root().remove_child(reader)
		reader.queue_free()


## Property 7: Variable injection operates on translated text.
## Translation substitution occurs BEFORE variable injection, so placeholders
## in the translated text (even if not in source) are resolved.
func test_variable_injection_on_translated_text() -> void:
	_rng.seed = 77

	for iteration in range(ITERATIONS):
		# Source text has NO variables
		var source_text := _gen_text_fragment() + " " + _gen_text_fragment()

		# But the translated text DOES have a variable placeholder
		var var_name := _gen_var_name()
		var var_value := _gen_var_value()
		var translated_text := _gen_translated_fragment() + " ${%s} " % var_name + _gen_translated_fragment()

		var state := { var_name: var_value }

		# Build node
		var node_name := _gen_node_name()
		var normalized_name := node_name.to_lower().replace(" ", "_")
		var token := "%s_1" % normalized_name

		# Create .ezd content
		var ezd_content := "[node: %s]\n%s" % [node_name, source_text]

		# Write temp file
		var file := FileAccess.open(TEMP_FILE_PATH, FileAccess.WRITE)
		if file == null:
			assert_true(false, "iter %d: could not write temp file" % iteration)
			continue
		file.store_string(ezd_content)
		file.close()

		# Create reader with translation
		var reader := EzDialogueReader.new()
		get_root().add_child(reader)

		var locale := "test_locale"
		var table := { token: translated_text }
		reader.set_translation_table(locale, table)
		reader.set_locale(locale)

		reader.start_dialogue(TEMP_FILE_PATH, state, node_name)
		var response: DialogueResponse = await reader.dialogue_generated

		# Expected: the translated text with the variable resolved
		var expected := translated_text.replace("${%s}" % var_name, str(var_value))

		assert_true(not response.text.contains("${"),
			"iter %d: output should not contain unresolved placeholders, got: '%s'" % [iteration, response.text])

		assert_eq(response.text, expected,
			"iter %d: variable in translated text should be resolved\n  source: '%s'\n  translated: '%s'\n  expected: '%s'\n  got: '%s'" % [
				iteration, source_text, translated_text, expected, response.text])

		get_root().remove_child(reader)
		reader.queue_free()

	# Remove temp file
	DirAccess.remove_absolute(TEMP_FILE_PATH)


## Property 8: Switching locale causes lookups to use the correct table.
## Multiple tables loaded, switching between locales verifies isolation.
func test_locale_switch_uses_correct_table() -> void:
	_rng.seed = 42

	for i in range(ITERATIONS):
		var reader := EzDialogueReader.new()
		get_root().add_child(reader)

		# Generate 2-6 unique locales
		var num_locales := _rng.randi_range(2, 6)
		var locales := _gen_unique_locales(num_locales)
		var tokens := _gen_shared_tokens()

		# Generate and load a translation table for each locale
		var tables := {}
		for locale in locales:
			var table := {}
			for token in tokens:
				table[token] = _gen_table_translated_text(locale, token)
			tables[locale] = table
			reader.set_translation_table(locale, table)

		# Switch to each locale and verify the correct table is active
		for locale in locales:
			reader.set_locale(locale)
			assert_eq(reader.get_locale(), locale,
				"iter %d: active locale should be '%s'" % [i, locale])

			var active_table := reader.get_translation_table(reader.get_locale())
			assert_eq(active_table, tables[locale],
				"iter %d: table for locale '%s' should match loaded table" % [i, locale])

		# Switch in random order and verify
		for _j in range(num_locales * 2):
			var random_locale := locales[_rng.randi_range(0, locales.size() - 1)]
			reader.set_locale(random_locale)
			var active_table := reader.get_translation_table(reader.get_locale())
			assert_eq(active_table, tables[random_locale],
				"iter %d: random switch to '%s' should use correct table" % [i, random_locale])

		reader.queue_free()


## Property 9: Translation table set/get round-trip.
## For any Dictionary, set_translation_table then get_translation_table returns
## a Dictionary equal to the original input.
func test_translation_table_set_get_round_trip() -> void:
	_rng.seed = 42

	for iteration in range(ITERATIONS):
		var reader := EzDialogueReader.new()
		get_root().add_child(reader)

		var locale := _gen_locale()
		var table := _gen_translation_table()

		reader.set_translation_table(locale, table)
		var retrieved := reader.get_translation_table(locale)

		assert_eq(retrieved.size(), table.size(),
			"iteration %d: table size mismatch (locale=%s, expected=%d, got=%d)" % [
				iteration, locale, table.size(), retrieved.size()])

		for token in table.keys():
			assert_true(retrieved.has(token),
				"iteration %d: missing token '%s' in retrieved table" % [iteration, token])
			if retrieved.has(token):
				assert_eq(retrieved[token], table[token],
					"iteration %d: value mismatch for token '%s'" % [iteration, token])

		for token in retrieved.keys():
			assert_true(table.has(token),
				"iteration %d: unexpected extra token '%s' in retrieved table" % [iteration, token])

		get_root().remove_child(reader)
		reader.queue_free()
