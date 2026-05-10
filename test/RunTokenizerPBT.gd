#!/usr/bin/env -S godot -s
## Consolidated property-based tests for the localization tokenizer.
##
## Covers: token format/structure, determinism, stability on edit,
## renumbering on structural change, CSV export, and CSV round-trip.
##
## Run from the project root:
##   godot --headless --path . -s res://test/RunTokenizerPBT.gd

extends "res://addons/ez_dialogue/dialogue_test/test_runner.gd"

const _DialogueCommand   = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_command.gd")
const _DialogueParser    = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_parser.gd")
const _DialogueNode      = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_node.gd")
const _DialogueResource  = preload("res://addons/ez_dialogue/dialogue_resource/dialogue_resource.gd")
const _DialogueTokenizer = preload("res://addons/ez_dialogue/dialogue_tokenizer.gd")

const ITERATIONS := 50
const CSV_PATH := "user://test_tokenizer_pbt_csv.csv"

var _rng := RandomNumberGenerator.new()


func _get_suite_name() -> String:
	return "Localization Tokenizer Tests"


# ── Generators ────────────────────────────────────────────────────────────────

const NAME_WORDS := [
	"Start", "Quest", "Battle", "Shop", "Inn", "Forest", "Castle",
	"Dragon", "Village", "End", "Intro", "Outro", "Boss", "NPC",
	"Tavern", "Bridge", "Cave", "Tower", "Gate", "Market"
]

const SPECIAL_CHARS := ["!", "@", "#", "&", "-", "'", ".", ","]

const SAMPLE_TEXTS := [
	"Hello world",
	"How are you today?",
	"The dragon approaches!",
	"You found a treasure chest.",
	"Welcome to the ${shop_name}.",
	"Your score is ${score} points.",
	"Greetings, ${player_name}!",
	"The weather is nice.",
	"Something happened.",
	"End of the road.",
	"He said, \"hello\" to me.",
	"Items: sword, shield, potion",
	"${npc_name} says: ${greeting}",
	"Level ${level}, HP ${hp}/${max_hp}",
]

const CHOICE_TEXTS := [
	"Accept",
	"Decline",
	"Fight",
	"Run away",
	"Ask for more info",
	"Buy ${item_name}",
	"Go to ${destination}",
	"Say hello",
	"Ignore",
	"Investigate",
	"Trade ${item_a} for ${item_b}",
]


## Generate a random node name with varied formatting (spaces, uppercase, special chars).
func _gen_node_name() -> String:
	var word_count := _rng.randi_range(1, 3)
	var parts: Array[String] = []
	for i in range(word_count):
		var word: String = NAME_WORDS[_rng.randi_range(0, NAME_WORDS.size() - 1)]
		var case_roll := _rng.randi_range(0, 3)
		match case_roll:
			0: word = word.to_upper()
			1: word = word.to_lower()
			2: pass  # keep as-is (Title Case)
			3: word = word.to_upper() if word.length() < 4 else word
		parts.append(word)

	var name := " ".join(parts)
	if _rng.randi_range(0, 4) == 0 and not SPECIAL_CHARS.is_empty():
		var char_idx := _rng.randi_range(0, SPECIAL_CHARS.size() - 1)
		name += SPECIAL_CHARS[char_idx]
	return name


## Generate a random dialogue script string.
## Returns [script_string, expected_display_count, expected_choice_count].
func _gen_dialogue_script() -> Array:
	var display_count := _rng.randi_range(1, 5)
	var choice_count := _rng.randi_range(0, 3)
	var lines: Array[String] = []

	for i in range(display_count):
		var text: String = SAMPLE_TEXTS[_rng.randi_range(0, SAMPLE_TEXTS.size() - 1)]
		if i > 0:
			lines.append("---")
		lines.append(text)

	if choice_count > 0:
		for i in range(choice_count):
			var choice_text: String = CHOICE_TEXTS[_rng.randi_range(0, CHOICE_TEXTS.size() - 1)]
			lines.append("?> %s {}" % choice_text)

	return ["\n".join(lines), display_count, choice_count]


## Generate a random DialogueNode.
## Returns [node, expected_display_count, expected_choice_count].
func _gen_node() -> Array:
	var node := DialogueNode.new()
	node.name = _gen_node_name()
	var gen_result := _gen_dialogue_script()
	node.commands_raw = gen_result[0]
	return [node, gen_result[1], gen_result[2]]


## Generate a random DialogueResource with 1-5 nodes.
## Returns [resource, Array of [node_name, display_count, choice_count]].
func _gen_resource() -> Array:
	var resource := DialogueResource.new()
	var node_count := _rng.randi_range(1, 5)
	var node_info: Array = []

	for i in range(node_count):
		var gen_result := _gen_node()
		var node: DialogueNode = gen_result[0]
		node.id = i
		resource.dialogue_nodes.append(node)
		node_info.append([node.name, gen_result[1], gen_result[2]])

	return [resource, node_info]


## Generate a resource with unique normalized node names (for CSV round-trip).
func _gen_resource_unique_names() -> DialogueResource:
	var resource := DialogueResource.new()
	var node_count := _rng.randi_range(1, 5)
	var used_normalized_names: Dictionary = {}

	for i in range(node_count):
		var node := DialogueNode.new()
		var name := _gen_node_name()
		var normalized := name.to_lower().replace(" ", "_")
		var attempts := 0
		while used_normalized_names.has(normalized) and attempts < 20:
			name = _gen_node_name()
			normalized = name.to_lower().replace(" ", "_")
			attempts += 1
		used_normalized_names[normalized] = true
		node.name = name
		node.id = i
		node.commands_raw = _gen_dialogue_script()[0]
		resource.dialogue_nodes.append(node)

	return resource


## Generate a random display text (for Property 3).
func _gen_display_text() -> String:
	return SAMPLE_TEXTS[_rng.randi_range(0, SAMPLE_TEXTS.size() - 1)]


## Generate a different display text (guaranteed different from original).
func _gen_different_text(original: String) -> String:
	var new_text := _gen_display_text()
	var attempts := 0
	while new_text == original and attempts < 20:
		new_text = _gen_display_text()
		attempts += 1
	if new_text == original:
		new_text = original + " (edited)"
	return new_text


## Build a dialogue script with N display texts separated by page breaks.
func _build_script_with_n_texts(n: int) -> String:
	var lines: Array[String] = []
	for i in range(n):
		lines.append(_gen_display_text())
	return "\n---\n".join(lines)


## Insert a new display text at position K (0-indexed) into an existing script.
func _insert_display_text_at(original_script: String, insert_pos: int) -> String:
	var parts := original_script.split("\n---\n")
	var new_text := "INSERTED: " + _gen_display_text()
	var new_parts: Array[String] = []
	for i in range(parts.size()):
		if i == insert_pos:
			new_parts.append(new_text)
		new_parts.append(parts[i])
	if insert_pos >= parts.size():
		new_parts.append(new_text)
	return "\n---\n".join(new_parts)


## Generate a different node name (for rename testing).
func _gen_different_name(original: String) -> String:
	var new_name := _gen_node_name()
	while new_name.to_lower().replace(" ", "_") == original.to_lower().replace(" ", "_"):
		new_name = _gen_node_name()
	return new_name


# ── Helpers ───────────────────────────────────────────────────────────────────

func _normalize_name(node_name: String) -> String:
	return node_name.to_lower().replace(" ", "_")


func _make_node(node_name: String, script: String) -> DialogueNode:
	var node := DialogueNode.new()
	node.name = node_name
	node.commands_raw = script
	return node


## Read the CSV file and parse into an array of records (RFC 4180 compliant).
func _read_csv_records(file_path: String) -> Array:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return []
	var content := file.get_as_text()
	file.close()
	return _parse_csv_content(content)


func _parse_csv_content(content: String) -> Array:
	var records: Array = []
	var current_field := ""
	var current_record: Array[String] = []
	var in_quotes := false
	var i := 0

	while i < content.length():
		var c := content[i]
		if in_quotes:
			if c == "\"":
				if i + 1 < content.length() and content[i + 1] == "\"":
					current_field += "\""
					i += 2
					continue
				else:
					in_quotes = false
					i += 1
					continue
			else:
				current_field += c
				i += 1
				continue
		else:
			if c == "\"":
				in_quotes = true
				i += 1
				continue
			elif c == ",":
				current_record.append(current_field)
				current_field = ""
				i += 1
				continue
			elif c == "\n":
				current_record.append(current_field)
				current_field = ""
				records.append(current_record)
				current_record = []
				i += 1
				continue
			elif c == "\r":
				i += 1
				continue
			else:
				current_field += c
				i += 1
				continue

	if not current_field.is_empty() or not current_record.is_empty():
		current_record.append(current_field)
		records.append(current_record)

	return records


func _cleanup_csv() -> void:
	if FileAccess.file_exists(CSV_PATH):
		DirAccess.remove_absolute(CSV_PATH)


func _get_node_names(resource: DialogueResource) -> Array:
	var names := []
	for node in resource.dialogue_nodes:
		names.append(node.name)
	return names


# ── Property Tests ────────────────────────────────────────────────────────────

## Property 1: Tokenization produces correct format and structure.
## Each token matches the expected naming pattern with sequential numbering.
func test_token_format_and_sequential_numbering() -> void:
	_rng.seed = 42

	for iteration in range(ITERATIONS):
		var gen_result := _gen_resource()
		var resource: DialogueResource = gen_result[0]
		var node_info: Array = gen_result[1]

		var tokenizer = _DialogueTokenizer.new()
		var tokens := tokenizer.tokenize(resource)

		var token_idx := 0

		for node_idx in range(node_info.size()):
			var node_name: String = node_info[node_idx][0]
			var expected_display: int = node_info[node_idx][1]
			var expected_choice: int = node_info[node_idx][2]
			var normalized := _normalize_name(node_name)

			var node_tokens: Array[Dictionary] = []
			while token_idx < tokens.size() and tokens[token_idx]["node_name"] == node_name:
				node_tokens.append(tokens[token_idx])
				token_idx += 1

			# Verify each entry contains all required fields
			for entry in node_tokens:
				assert_true(entry.has("token"),
					"iter %d, node '%s': entry missing 'token' field" % [iteration, node_name])
				assert_true(entry.has("source_text"),
					"iter %d, node '%s': entry missing 'source_text' field" % [iteration, node_name])
				assert_true(entry.has("node_name"),
					"iter %d, node '%s': entry missing 'node_name' field" % [iteration, node_name])
				assert_true(entry.has("index"),
					"iter %d, node '%s': entry missing 'index' field" % [iteration, node_name])

			# Separate display tokens and choice tokens
			var display_tokens: Array[Dictionary] = []
			var choice_tokens: Array[Dictionary] = []
			for entry in node_tokens:
				if "_choice_" in (entry["token"] as String):
					choice_tokens.append(entry)
				else:
					display_tokens.append(entry)

			# Verify display token format: "{normalized_name}_{n}" starting at 1
			assert_eq(display_tokens.size(), expected_display,
				"iter %d, node '%s': expected %d display tokens, got %d" % [
					iteration, node_name, expected_display, display_tokens.size()])

			for i in range(display_tokens.size()):
				var expected_token := "%s_%d" % [normalized, i + 1]
				assert_eq(display_tokens[i]["token"], expected_token,
					"iter %d, node '%s': display token %d format" % [iteration, node_name, i + 1])
				assert_eq(display_tokens[i]["index"], i + 1,
					"iter %d, node '%s': display index %d" % [iteration, node_name, i + 1])
				assert_eq(display_tokens[i]["node_name"], node_name,
					"iter %d, node '%s': node_name preserved" % [iteration, node_name])

			# Verify choice token format: "{normalized_name}_choice_{n}" starting at 1
			assert_eq(choice_tokens.size(), expected_choice,
				"iter %d, node '%s': expected %d choice tokens, got %d" % [
					iteration, node_name, expected_choice, choice_tokens.size()])

			for i in range(choice_tokens.size()):
				var expected_token := "%s_choice_%d" % [normalized, i + 1]
				assert_eq(choice_tokens[i]["token"], expected_token,
					"iter %d, node '%s': choice token %d format" % [iteration, node_name, i + 1])
				assert_eq(choice_tokens[i]["index"], i + 1,
					"iter %d, node '%s': choice index %d" % [iteration, node_name, i + 1])

		# Verify all tokens were consumed (ordering matches node appearance)
		assert_eq(token_idx, tokens.size(),
			"iter %d: all tokens accounted for (expected %d, consumed %d)" % [
				iteration, tokens.size(), token_idx])


## Property 2: Tokenization is deterministic — same tokenizer instance.
## Calling tokenize() multiple times on the same resource produces identical output.
func test_tokenization_is_deterministic() -> void:
	_rng.seed = 42
	var tokenizer = _DialogueTokenizer.new()

	for iteration in range(ITERATIONS):
		var gen_result := _gen_resource()
		var resource: DialogueResource = gen_result[0]

		var result1 := tokenizer.tokenize(resource)
		var result2 := tokenizer.tokenize(resource)

		if result1.size() != result2.size():
			_failed += 1
			printerr("  FAIL: iteration %d — array sizes differ: %d vs %d" % [
				iteration, result1.size(), result2.size()])
			printerr("  Counterexample: resource with %d nodes, names=%s" % [
				resource.dialogue_nodes.size(), _get_node_names(resource)])
			return

		for i in range(result1.size()):
			var entry1 = result1[i]
			var entry2 = result2[i]

			if entry1["token"] != entry2["token"]:
				_failed += 1
				printerr("  FAIL: iteration %d, entry %d — tokens differ: '%s' vs '%s'" % [
					iteration, i, entry1["token"], entry2["token"]])
				printerr("  Counterexample: resource with %d nodes, names=%s" % [
					resource.dialogue_nodes.size(), _get_node_names(resource)])
				return

			if entry1["source_text"] != entry2["source_text"]:
				_failed += 1
				printerr("  FAIL: iteration %d, entry %d — source_text differs" % [iteration, i])
				return

			if entry1["node_name"] != entry2["node_name"]:
				_failed += 1
				printerr("  FAIL: iteration %d, entry %d — node_name differs" % [iteration, i])
				return

			if entry1["index"] != entry2["index"]:
				_failed += 1
				printerr("  FAIL: iteration %d, entry %d — index differs" % [iteration, i])
				return

	assert_true(true, "all %d iterations produced deterministic output" % ITERATIONS)


## Property 3: Token stability on content edit.
## Modifying text content without adding/removing entries produces the same tokens.
func test_tokens_stable_when_text_edited() -> void:
	_rng.seed = 42
	var failures := 0
	var first_failure_detail := ""

	for iteration in range(ITERATIONS):
		var node_name := _gen_node_name()
		var num_displays: int = _rng.randi_range(2, 5)

		# Build script with page breaks between texts
		var texts: Array[String] = []
		for i in range(num_displays):
			texts.append(_gen_display_text())
		var script := "\n---\n".join(texts)

		# Create node and tokenize
		var node := DialogueNode.new()
		node.name = node_name
		node.commands_raw = script

		var tokenizer = _DialogueTokenizer.new()
		var tokens_before = tokenizer.tokenize_node(node)

		if tokens_before.is_empty():
			continue

		# Pick a random entry to modify
		var modify_idx: int = _rng.randi() % texts.size()
		texts[modify_idx] = _gen_different_text(texts[modify_idx])

		# Rebuild script with modified text
		var modified_script := "\n---\n".join(texts)
		node.commands_raw = modified_script
		node.clear_parse()

		var tokens_after = tokenizer.tokenize_node(node)

		# Assert same tokens
		if tokens_before.size() != tokens_after.size():
			failures += 1
			if first_failure_detail.is_empty():
				first_failure_detail = "Iteration %d: Token count changed from %d to %d after modifying entry %d. Node: '%s'" % [
					iteration, tokens_before.size(), tokens_after.size(), modify_idx, node_name]
			continue

		for i in range(tokens_before.size()):
			if tokens_before[i]["token"] != tokens_after[i]["token"]:
				failures += 1
				if first_failure_detail.is_empty():
					first_failure_detail = "Iteration %d: Token at index %d changed from '%s' to '%s'. Node: '%s'" % [
						iteration, i, tokens_before[i]["token"], tokens_after[i]["token"], node_name]
				break

	if failures > 0:
		_failed += 1
		printerr("  FAIL: Token stability violated in %d/%d iterations" % [failures, ITERATIONS])
		printerr("  First failure: %s" % first_failure_detail)
	else:
		print("  Token stability held across all %d iterations" % ITERATIONS)


## Property 4a: Inserting a new DISPLAY_TEXT causes subsequent entries to renumber.
func test_tokens_renumber_on_structural_change() -> void:
	_rng.seed = hash("property4a")

	for iteration in range(ITERATIONS):
		var node_name := _gen_node_name()
		var num_texts := _rng.randi_range(2, 5)
		var original_script := _build_script_with_n_texts(num_texts)

		var node := _make_node(node_name, original_script)
		var tokenizer = _DialogueTokenizer.new()
		var original_tokens = tokenizer.tokenize_node(node)

		var original_display_count := original_tokens.size()
		if original_display_count == 0:
			continue

		# Choose a random insertion position
		var insert_pos := _rng.randi_range(0, original_display_count - 1)

		# Insert a new DISPLAY_TEXT at that position
		var modified_script := _insert_display_text_at(original_script, insert_pos)
		var modified_node := _make_node(node_name, modified_script)
		modified_node.clear_parse()
		var new_tokens = tokenizer.tokenize_node(modified_node)

		# Should have one more entry
		assert_eq(new_tokens.size(), original_display_count + 1,
			"iter %d: insertion should add one entry (had %d, now %d)" % [iteration, original_display_count, new_tokens.size()])

		# Verify sequential numbering is correct after insertion
		var normalized := _normalize_name(node_name)
		var display_idx := 0
		for entry in new_tokens:
			if not "_choice_" in entry["token"]:
				display_idx += 1
				var expected_token := "%s_%d" % [normalized, display_idx]
				assert_eq(entry["token"], expected_token,
					"iter %d: token at position %d should be %s, got %s" % [iteration, display_idx, expected_token, entry["token"]])
				assert_eq(entry["index"], display_idx,
					"iter %d: index at position %d should be %d" % [iteration, display_idx, display_idx])


## Property 4b: Renaming a node causes all tokens to reflect the new normalized name.
func test_tokens_update_on_node_rename() -> void:
	_rng.seed = hash("property4b")

	for iteration in range(ITERATIONS):
		var original_name := _gen_node_name()
		var num_texts := _rng.randi_range(1, 5)
		var script := _build_script_with_n_texts(num_texts)

		var node := _make_node(original_name, script)
		var tokenizer = _DialogueTokenizer.new()
		var original_tokens = tokenizer.tokenize_node(node)

		if original_tokens.is_empty():
			continue

		# Rename the node
		var new_name := _gen_different_name(original_name)
		var renamed_node := _make_node(new_name, script)
		var new_tokens = tokenizer.tokenize_node(renamed_node)

		# Same number of tokens
		assert_eq(new_tokens.size(), original_tokens.size(),
			"iter %d: rename should not change token count" % iteration)

		# All tokens should use the new normalized name
		var new_normalized := _normalize_name(new_name)

		for i in range(new_tokens.size()):
			var new_entry = new_tokens[i]
			var old_entry = original_tokens[i]

			var expected_suffix: String
			if "_choice_" in old_entry["token"]:
				expected_suffix = "%s_choice_%d" % [new_normalized, old_entry["index"]]
			else:
				expected_suffix = "%s_%d" % [new_normalized, old_entry["index"]]
			assert_eq(new_entry["token"], expected_suffix,
				"iter %d: token should be '%s', got '%s'" % [iteration, expected_suffix, new_entry["token"]])

			assert_eq(new_entry["node_name"], new_name,
				"iter %d: node_name should be '%s'" % [iteration, new_name])

			assert_eq(new_entry["source_text"], old_entry["source_text"],
				"iter %d: source_text should be unchanged after rename" % iteration)

			assert_eq(new_entry["index"], old_entry["index"],
				"iter %d: index should be unchanged after rename" % iteration)


## Property 10: CSV export correctness — header, row count, ordering, placeholder preservation.
func test_csv_export_format_and_ordering() -> void:
	_rng.seed = 42

	for iteration in range(ITERATIONS):
		var gen_result := _gen_resource()
		var resource: DialogueResource = gen_result[0]

		var tokenizer = _DialogueTokenizer.new()
		var expected_tokens := tokenizer.tokenize(resource)

		var err := tokenizer.export_csv(resource, CSV_PATH)
		assert_eq(err, OK, "iter %d: export_csv should return OK" % iteration)

		var records := _read_csv_records(CSV_PATH)
		# Filter out trailing empty records
		while not records.is_empty() and records[-1].size() == 1 and (records[-1][0] as String).strip_edges().is_empty():
			records.pop_back()

		# Verify header row
		assert_true(records.size() >= 1,
			"iter %d: CSV should have at least a header row" % iteration)
		if records.size() >= 1:
			var header: Array = records[0]
			assert_eq(header.size(), 3,
				"iter %d: CSV header should have 3 fields" % iteration)
			if header.size() == 3:
				assert_eq(header[0], "token", "iter %d: header field 0" % iteration)
				assert_eq(header[1], "source_text", "iter %d: header field 1" % iteration)
				assert_eq(header[2], "translated_text", "iter %d: header field 2" % iteration)

		# Verify row count
		var data_records := records.size() - 1
		assert_eq(data_records, expected_tokens.size(),
			"iter %d: expected %d data rows, got %d" % [iteration, expected_tokens.size(), data_records])

		# Verify ordering and placeholder preservation
		for row_idx in range(min(data_records, expected_tokens.size())):
			var fields: Array = records[row_idx + 1]
			assert_eq(fields.size(), 3,
				"iter %d, row %d: expected 3 CSV fields" % [iteration, row_idx])

			if fields.size() >= 2:
				var csv_token: String = fields[0]
				var csv_source_text: String = fields[1]
				var expected_token: String = expected_tokens[row_idx]["token"]
				var expected_source: String = expected_tokens[row_idx]["source_text"]

				assert_eq(csv_token, expected_token,
					"iter %d, row %d: token ordering mismatch" % [iteration, row_idx])
				assert_eq(csv_source_text, expected_source,
					"iter %d, row %d: source_text mismatch" % [iteration, row_idx])

				# Verify ${...} placeholders are preserved
				var placeholder_regex := RegEx.new()
				placeholder_regex.compile("\\$\\{[^}]+\\}")
				var expected_matches := placeholder_regex.search_all(expected_source)
				var csv_matches := placeholder_regex.search_all(csv_source_text)
				assert_eq(csv_matches.size(), expected_matches.size(),
					"iter %d, row %d: placeholder count mismatch" % [iteration, row_idx])

			if fields.size() >= 3:
				assert_eq(fields[2] as String, "",
					"iter %d, row %d: translated_text should be empty on fresh export" % [iteration, row_idx])

		_cleanup_csv()


## Property 11: CSV import round-trip — keys match tokenize() output.
## Exporting to CSV and importing produces a table whose keys match tokenize().
func test_csv_export_import_round_trip() -> void:
	_rng.seed = 42

	for iteration in range(ITERATIONS):
		var resource := _gen_resource_unique_names()
		var tokenizer = _DialogueTokenizer.new()

		var token_entries := tokenizer.tokenize(resource)
		if token_entries.is_empty():
			continue

		var export_err := tokenizer.export_csv(resource, CSV_PATH)
		assert_eq(export_err, OK, "iter %d: export_csv should succeed" % iteration)
		if export_err != OK:
			continue

		var imported := tokenizer.import_csv(CSV_PATH)

		# Verify key count matches
		var expected_keys: Array[String] = []
		for entry in token_entries:
			expected_keys.append(entry["token"])

		assert_eq(imported.size(), expected_keys.size(),
			"iter %d: imported dict size (%d) should match token count (%d)" % [
				iteration, imported.size(), expected_keys.size()])

		# Verify each expected token key exists
		for token_key in expected_keys:
			assert_true(imported.has(token_key),
				"iter %d: imported dict should contain token '%s'" % [iteration, token_key])

		# Verify no extra keys
		for key in imported.keys():
			assert_true(key in expected_keys,
				"iter %d: imported dict has unexpected key '%s'" % [iteration, key])

	_cleanup_csv()
