#!/usr/bin/env -S godot -s
## Unit tests for end-to-end localization workflow.
##
## Validates: Requirements 5.3, 7.6, 8.3, 2.4
##
## Tests:
## - Full workflow: tokenize → export CSV → simulate translation → import CSV → start dialogue → verify translated output
## - Locale hot-switch mid-dialogue
## - CSV error handling: import non-existent file
## - Tokenizer independence: instantiate without a Reader
## - Multiple locales loaded simultaneously
## - clear_translation_table followed by lookup returns source text
##
## Run from the project root:
##   godot --headless -s test/RunLocalizationIntegrationTests.gd

extends "res://addons/ez_dialogue/dialogue_test/test_runner.gd"

const _DialogueCommand   = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_command.gd")
const _DialogueParser    = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_parser.gd")
const _DialogueNode      = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_node.gd")
const _DialogueResource  = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_resource.gd")
const _DialogueResponse  = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_response.gd")
const _EzDialogueReader  = preload("res://addons/ez_dialogue/dialogue_reader.gd")
const _EzDialogue        = preload("res://addons/ez_dialogue/ez_dialogue_node.gd")
const _DialogueTokenizer = preload("res://addons/ez_dialogue/dialogue_tokenizer.gd")
const _EzdFileParser     = preload("res://addons/ez_dialogue/dialogue_resource/ezd_file_parser.gd")
const _DialogueTest      = preload("res://addons/ez_dialogue/dialogue_test/dialogue_test.gd")

const CSV_TEMP_PATH := "user://test_localization_integration.csv"
const CSV_TRANSLATED_PATH := "user://test_localization_translated.csv"


func _get_suite_name() -> String:
	return "Localization Integration Tests"


# ── Helpers ───────────────────────────────────────────────────────────────────

## Create a DialogueResource with a single node from raw commands.
func _make_resource(node_name: String, commands_raw: String) -> DialogueResource:
	var resource := DialogueResource.new()
	var node := DialogueNode.new()
	node.id = 0
	node.name = node_name
	node.gnode_name = node_name.to_lower()
	node.commands_raw = commands_raw
	resource.dialogue_nodes = [node]
	return resource


## Create a DialogueResource with multiple nodes.
func _make_multi_node_resource(nodes: Array[Dictionary]) -> DialogueResource:
	var resource := DialogueResource.new()
	for i in range(nodes.size()):
		var node := DialogueNode.new()
		node.id = i
		node.name = nodes[i]["name"]
		node.gnode_name = nodes[i]["name"].to_lower()
		node.commands_raw = nodes[i]["commands_raw"]
		resource.dialogue_nodes.push_back(node)
	return resource


## Create a JSON dialogue resource for the reader (single node).
func _make_json(node_name: String, commands_raw: String) -> JSON:
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


## Create a JSON dialogue resource with multiple nodes.
func _make_multi_node_json(nodes: Array[Dictionary]) -> JSON:
	var json_data := []
	for i in range(nodes.size()):
		json_data.append({
			"id": i,
			"name": nodes[i]["name"],
			"gnode_name": nodes[i]["name"],
			"commands_raw": nodes[i]["commands_raw"],
			"position": [0.0, float(i) * 100.0]
		})
	var json := JSON.new()
	json.data = json_data
	return json


## Write a translated CSV file manually for testing import.
func _write_translated_csv(path: String, rows: Array[Array]) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_line("token,source_text,translated_text")
	for row in rows:
		file.store_line("%s,%s,%s" % [row[0], row[1], row[2]])
	file.close()


## Clean up temp files.
func _cleanup_temp_files() -> void:
	if FileAccess.file_exists(CSV_TEMP_PATH):
		DirAccess.remove_absolute(CSV_TEMP_PATH)
	if FileAccess.file_exists(CSV_TRANSLATED_PATH):
		DirAccess.remove_absolute(CSV_TRANSLATED_PATH)


# ── Tests ─────────────────────────────────────────────────────────────────────

## Test full workflow: tokenize → export CSV → simulate translation → import CSV
## → start dialogue with locale → verify translated output.
func test_full_localization_workflow() -> void:
	_cleanup_temp_files()

	# 1. Create a dialogue resource
	var commands_raw := "Hello traveller.\n---\nWelcome to the village.\n?> Continue {}\n?> Leave {}"
	var resource := _make_resource("Greeting", commands_raw)
	var dialogue_json := _make_json("Greeting", commands_raw)

	# 2. Tokenize the resource
	var tokenizer := DialogueTokenizer.new()
	var entries := tokenizer.tokenize(resource)
	assert_true(entries.size() > 0, "tokenize should produce entries")

	# 3. Export to CSV
	var export_err := tokenizer.export_csv(resource, CSV_TEMP_PATH)
	assert_eq(export_err, OK, "export_csv should succeed")
	assert_true(FileAccess.file_exists(CSV_TEMP_PATH), "CSV file should exist after export")

	# 4. Simulate translation by writing a translated CSV
	var translated_rows: Array[Array] = []
	translated_rows.append(["greeting_1", "Hello traveller.", "Bonjour voyageur."])
	translated_rows.append(["greeting_2", "Welcome to the village.", "Bienvenue au village."])
	translated_rows.append(["greeting_choice_1", " Continue ", "Continuer"])
	translated_rows.append(["greeting_choice_2", " Leave ", "Quitter"])
	_write_translated_csv(CSV_TRANSLATED_PATH, translated_rows)

	# 5. Import the translated CSV
	var reader := EzDialogueReader.new()
	get_root().add_child(reader)

	var import_err := reader.load_translation_csv("fr", CSV_TRANSLATED_PATH)
	assert_eq(import_err, OK, "load_translation_csv should succeed")

	# 6. Set locale and start dialogue
	reader.set_locale("fr")
	reader.start_dialogue(dialogue_json, {}, "Greeting")
	var response: DialogueResponse = await reader.dialogue_generated

	# 7. Verify translated output
	assert_eq(response.text, "Bonjour voyageur.", "first page should be translated")

	# Continue to next page
	reader.next()
	var response2: DialogueResponse = await reader.dialogue_generated
	assert_eq(response2.text, "Bienvenue au village.", "second page display text translated")
	assert_eq(response2.choices.size(), 2, "should have 2 choices")
	assert_eq(response2.choices[0], "Continuer", "first choice translated")
	assert_eq(response2.choices[1], "Quitter", "second choice translated")

	# Cleanup
	get_root().remove_child(reader)
	reader.queue_free()
	_cleanup_temp_files()


## Test locale hot-switch mid-dialogue: start dialogue, get first response,
## switch locale, call next(), verify new locale text.
## Validates: Requirement 5.3
func test_locale_hot_switch_mid_dialogue() -> void:
	# Create a dialogue with a page break so we can switch locale between pages
	var commands_raw := "Hello world.\n---\nSecond page text."
	var dialogue_json := _make_json("Greet", commands_raw)
	var resource := _make_resource("Greet", commands_raw)

	# Build translation tables for two locales
	var tokenizer := DialogueTokenizer.new()
	var entries := tokenizer.tokenize(resource)

	var fr_table := {}
	var de_table := {}
	for entry in entries:
		if entry["token"] == "greet_1":
			fr_table["greet_1"] = "Bonjour le monde."
			de_table["greet_1"] = "Hallo Welt."
		elif entry["token"] == "greet_2":
			fr_table["greet_2"] = "Texte de la deuxieme page."
			de_table["greet_2"] = "Zweite Seite Text."

	# Set up reader with French locale
	var reader := EzDialogueReader.new()
	get_root().add_child(reader)
	reader.set_translation_table("fr", fr_table)
	reader.set_translation_table("de", de_table)
	reader.set_locale("fr")

	# Start dialogue — first page should be in French
	reader.start_dialogue(dialogue_json, {}, "Greet")
	var response1: DialogueResponse = await reader.dialogue_generated
	assert_eq(response1.text, "Bonjour le monde.", "first page should be French")

	# Switch locale to German mid-dialogue
	reader.set_locale("de")

	# Continue to next page — should now be in German
	reader.next()
	var response2: DialogueResponse = await reader.dialogue_generated
	assert_eq(response2.text, "Zweite Seite Text.", "second page should be German after locale switch")

	# Cleanup
	get_root().remove_child(reader)
	reader.queue_free()


## Test CSV error handling: import non-existent file, verify error logged
## and graceful fallback.
## Validates: Requirement 7.6
func test_csv_import_nonexistent_file() -> void:
	var reader := EzDialogueReader.new()
	get_root().add_child(reader)

	# Attempt to import a non-existent file
	var err := reader.load_translation_csv("fr", "user://this_file_does_not_exist_12345.csv")
	assert_eq(err, ERR_FILE_CANT_OPEN, "should return ERR_FILE_CANT_OPEN for non-existent file")

	# Verify the reader still works — no translation table loaded, so source text is used
	var commands_raw := "Hello world."
	var dialogue_json := _make_json("Test", commands_raw)
	reader.set_locale("fr")

	reader.start_dialogue(dialogue_json, {}, "Test")
	var response: DialogueResponse = await reader.dialogue_generated
	assert_eq(response.text, "Hello world.", "should fall back to source text after CSV error")

	# Cleanup
	get_root().remove_child(reader)
	reader.queue_free()


## Test tokenizer independence: instantiate DialogueTokenizer without a Reader,
## verify it works standalone.
## Validates: Requirement 8.3
func test_tokenizer_independence() -> void:
	# Create a tokenizer directly — no Reader involved
	var tokenizer := DialogueTokenizer.new()

	# Create a resource manually
	var resource := _make_resource("Standalone", "Line one.\n---\nLine two.\n?> Choice A {}")

	# Tokenize without any Reader
	var entries := tokenizer.tokenize(resource)

	# Verify results
	assert_eq(entries.size(), 3, "should produce 3 entries (2 display + 1 choice)")
	assert_eq(entries[0]["token"], "standalone_1", "first display token")
	assert_contains(entries[0]["source_text"], "Line one.", "first source text contains expected")
	assert_eq(entries[1]["token"], "standalone_2", "second display token")
	assert_contains(entries[1]["source_text"], "Line two.", "second source text contains expected")
	assert_eq(entries[2]["token"], "standalone_choice_1", "choice token")
	assert_contains(entries[2]["source_text"], "Choice A", "choice source text contains expected")

	# Verify tokenize_node also works standalone
	var node := DialogueNode.new()
	node.name = "Another Node"
	node.commands_raw = "Some text."
	var node_entries := tokenizer.tokenize_node(node)
	assert_eq(node_entries.size(), 1, "tokenize_node should work standalone")
	assert_eq(node_entries[0]["token"], "another_node_1", "node name normalized")


## Test multiple locales loaded simultaneously.
## Validates: Requirement 5.1
func test_multiple_locales_loaded() -> void:
	var reader := EzDialogueReader.new()
	get_root().add_child(reader)

	# Load translation tables for 3 locales
	var fr_table := {"greet_1": "Bonjour"}
	var de_table := {"greet_1": "Hallo"}
	var ja_table := {"greet_1": "こんにちは"}

	reader.set_translation_table("fr", fr_table)
	reader.set_translation_table("de", de_table)
	reader.set_translation_table("ja", ja_table)

	# Verify each locale's table is stored independently
	var retrieved_fr := reader.get_translation_table("fr")
	var retrieved_de := reader.get_translation_table("de")
	var retrieved_ja := reader.get_translation_table("ja")

	assert_eq(retrieved_fr["greet_1"], "Bonjour", "French table stored correctly")
	assert_eq(retrieved_de["greet_1"], "Hallo", "German table stored correctly")
	assert_eq(retrieved_ja["greet_1"], "こんにちは", "Japanese table stored correctly")

	# Verify switching locales uses the correct table at runtime
	var commands_raw := "Hello."
	var dialogue_json := _make_json("Greet", commands_raw)

	# Test French
	reader.set_locale("fr")
	reader.start_dialogue(dialogue_json, {}, "Greet")
	var resp_fr: DialogueResponse = await reader.dialogue_generated
	assert_eq(resp_fr.text, "Bonjour", "French locale produces French text")

	# Test German
	reader.set_locale("de")
	reader.start_dialogue(dialogue_json, {}, "Greet")
	var resp_de: DialogueResponse = await reader.dialogue_generated
	assert_eq(resp_de.text, "Hallo", "German locale produces German text")

	# Test Japanese
	reader.set_locale("ja")
	reader.start_dialogue(dialogue_json, {}, "Greet")
	var resp_ja: DialogueResponse = await reader.dialogue_generated
	assert_eq(resp_ja.text, "こんにちは", "Japanese locale produces Japanese text")

	# Cleanup
	get_root().remove_child(reader)
	reader.queue_free()


## Test clear_translation_table followed by lookup returns source text.
## Validates: Requirement 2.4
func test_clear_translation_table_fallback() -> void:
	var reader := EzDialogueReader.new()
	get_root().add_child(reader)

	# Load a translation table
	var table := {"test_1": "Translated text"}
	reader.set_translation_table("fr", table)
	reader.set_locale("fr")

	# Verify translation works before clearing
	var commands_raw := "Original text."
	var dialogue_json := _make_json("Test", commands_raw)

	reader.start_dialogue(dialogue_json, {}, "Test")
	var resp1: DialogueResponse = await reader.dialogue_generated
	assert_eq(resp1.text, "Translated text", "should use translated text before clear")

	# Clear the translation table
	reader.clear_translation_table("fr")

	# Verify the table is gone
	var retrieved := reader.get_translation_table("fr")
	assert_eq(retrieved.size(), 0, "cleared table should be empty")

	# Start dialogue again — should fall back to source text
	reader.start_dialogue(dialogue_json, {}, "Test")
	var resp2: DialogueResponse = await reader.dialogue_generated
	assert_eq(resp2.text, "Original text.", "should fall back to source text after clear")

	# Cleanup
	get_root().remove_child(reader)
	reader.queue_free()


## Test that disabling locale (setting to empty string) returns source text.
func test_disable_locale_returns_source() -> void:
	var reader := EzDialogueReader.new()
	get_root().add_child(reader)

	# Load a translation table and set locale
	var table := {"test_1": "Translated"}
	reader.set_translation_table("fr", table)
	reader.set_locale("fr")

	var commands_raw := "Source text."
	var dialogue_json := _make_json("Test", commands_raw)

	# Verify translation works
	reader.start_dialogue(dialogue_json, {}, "Test")
	var resp1: DialogueResponse = await reader.dialogue_generated
	assert_eq(resp1.text, "Translated", "should translate when locale is set")

	# Disable locale
	reader.set_locale("")
	assert_eq(reader.get_locale(), "", "locale should be empty after disable")

	# Start dialogue again — should use source text
	reader.start_dialogue(dialogue_json, {}, "Test")
	var resp2: DialogueResponse = await reader.dialogue_generated
	assert_eq(resp2.text, "Source text.", "should use source text when locale disabled")

	# Cleanup
	get_root().remove_child(reader)
	reader.queue_free()
