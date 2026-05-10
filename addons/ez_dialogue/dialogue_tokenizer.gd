class_name DialogueTokenizer extends RefCounted

## Tokenize an entire DialogueResource.
## Returns an Array of token entry Dictionaries ordered by node appearance,
## then by sequential number within each node.
func tokenize(resource: DialogueResource) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for node in resource.dialogue_nodes:
		results.append_array(tokenize_node(node))
	return results


## Tokenize a single DialogueNode.
## Returns an Array of token entry Dictionaries for that node only.
## Each entry contains: token, source_text, node_name, index
func tokenize_node(node: DialogueNode) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var normalized_name := _normalize_name(node.name)
	var display_counter := 0
	var choice_counter := 0

	# Use the same traversal approach as EzDialogueReader._process_command:
	# Pop from front, expand ROOT/BRACKET children by prepending them in order.
	var stack: Array[DialogueCommand] = node.get_parse()

	while not stack.is_empty():
		var command: DialogueCommand = stack.pop_front()

		match command.type:
			DialogueCommand.CommandType.ROOT, DialogueCommand.CommandType.BRACKET:
				# Expand children in-place at the front (same as Reader._prepend_children)
				var copy: Array[DialogueCommand] = command.children.duplicate()
				copy.append_array(stack)
				stack = copy

			DialogueCommand.CommandType.DISPLAY_TEXT:
				display_counter += 1
				var source_text: String = command.values[0] if not command.values.is_empty() else ""
				results.append({
					"token": "%s_%d" % [normalized_name, display_counter],
					"source_text": source_text,
					"node_name": node.name,
					"index": display_counter
				})

			DialogueCommand.CommandType.PROMPT:
				choice_counter += 1
				var source_text: String = command.values[0] if not command.values.is_empty() else ""
				results.append({
					"token": "%s_choice_%d" % [normalized_name, choice_counter],
					"source_text": source_text,
					"node_name": node.name,
					"index": choice_counter
				})
				# Traverse into PROMPT children to find nested DISPLAY_TEXT/PROMPT
				if not command.children.is_empty():
					var copy: Array[DialogueCommand] = command.children.duplicate()
					copy.append_array(stack)
					stack = copy

			DialogueCommand.CommandType.CONDITIONAL, DialogueCommand.CommandType.ELIF, \
			DialogueCommand.CommandType.ELSE:
				# Traverse into conditional branches to find nested DISPLAY_TEXT/PROMPT
				var copy: Array[DialogueCommand] = command.children.duplicate()
				copy.append_array(stack)
				stack = copy

			DialogueCommand.CommandType.GOTO, DialogueCommand.CommandType.PAGE_BREAK, \
			DialogueCommand.CommandType.SIGNAL, DialogueCommand.CommandType.NEW_LINE, \
			DialogueCommand.CommandType.SPECIAL, DialogueCommand.CommandType.EXPRESSION:
				# These commands don't contain translatable text; skip them
				pass

	return results


## Export token entries to a CSV file at the given path.
## Columns: token, source_text, translated_text
## translated_text column is empty on fresh export.
## Returns OK on success, appropriate error code on failure.
func export_csv(resource: DialogueResource, file_path: String) -> Error:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		printerr("DialogueTokenizer: Failed to open file for writing: %s (error: %d)" % [file_path, err])
		return err

	# Write header
	file.store_line("token,source_text,translated_text")

	# Tokenize and write one row per entry
	var entries := tokenize(resource)
	for entry in entries:
		var token_str: String = entry["token"]
		var source_text: String = entry["source_text"]
		var line := "%s,%s," % [_escape_csv_field(token_str), _escape_csv_field(source_text)]
		file.store_line(line)

	file.close()
	return OK


## Parse a CSV file into a Translation Table (Dictionary mapping token → translated text).
## If translated_text is empty for a row, falls back to source_text value.
## Returns an empty Dictionary and logs an error if the file cannot be opened.
## Malformed rows (wrong column count) are skipped with a warning.
## Duplicate tokens: last occurrence wins.
func import_csv(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var err := FileAccess.get_open_error()
		printerr("DialogueTokenizer: Failed to open file for reading: %s (error: %d)" % [file_path, err])
		return {}

	var result: Dictionary = {}
	var line_number := 0
	var logical_row := ""
	var logical_row_start_line := 0

	while not file.eof_reached():
		var raw_line := file.get_line()
		line_number += 1

		# Skip the header row
		if line_number == 1:
			continue

		# Handle multi-line quoted fields per RFC 4180:
		# If we have an open logical row, append this line to it.
		if not logical_row.is_empty():
			logical_row += "\n" + raw_line
		else:
			# Skip empty lines (only when not accumulating a multi-line field)
			if raw_line.strip_edges().is_empty():
				continue
			logical_row = raw_line
			logical_row_start_line = line_number

		# Check if the logical row is complete (balanced quotes)
		if not _is_csv_row_complete(logical_row):
			continue

		var fields := _parse_csv_line(logical_row)
		logical_row = ""

		if fields.size() != 3:
			push_warning("DialogueTokenizer: Malformed CSV row at line %d (expected 3 columns, got %d). Skipping." % [logical_row_start_line, fields.size()])
			continue

		var token: String = fields[0]
		var source_text: String = fields[1]
		var translated_text: String = fields[2]

		# If translated_text is empty, fall back to source_text
		if translated_text.strip_edges().is_empty():
			result[token] = source_text
		else:
			result[token] = translated_text

	file.close()
	return result


## Check if a CSV row is complete (all quoted fields are closed).
## A row is complete when the number of unescaped double quotes is even.
func _is_csv_row_complete(line: String) -> bool:
	var quote_count := 0
	var i := 0
	while i < line.length():
		if line[i] == "\"":
			quote_count += 1
		i += 1
	# If quote count is even, all quoted fields are properly closed
	return quote_count % 2 == 0


## Parse a single CSV line into an array of fields per RFC 4180.
## Handles quoted fields with escaped double quotes (doubled quotes).
func _parse_csv_line(line: String) -> Array[String]:
	var fields: Array[String] = []
	var current_field := ""
	var in_quotes := false
	var i := 0

	while i < line.length():
		var c := line[i]

		if in_quotes:
			if c == "\"":
				# Check if next char is also a quote (escaped quote)
				if i + 1 < line.length() and line[i + 1] == "\"":
					current_field += "\""
					i += 2
					continue
				else:
					# End of quoted field
					in_quotes = false
					i += 1
					continue
			else:
				current_field += c
				i += 1
				continue
		else:
			if c == "\"":
				# Start of quoted field
				in_quotes = true
				i += 1
				continue
			elif c == ",":
				# Field separator
				fields.append(current_field)
				current_field = ""
				i += 1
				continue
			else:
				current_field += c
				i += 1
				continue

	# Don't forget the last field
	fields.append(current_field)
	return fields


## Escape a CSV field per RFC 4180.
## If the field contains commas, double quotes, or newlines, wrap it in double quotes
## and escape internal double quotes by doubling them.
func _escape_csv_field(field: String) -> String:
	if field.find(",") != -1 or field.find("\"") != -1 or field.find("\n") != -1 or field.find("\r") != -1:
		return "\"" + field.replace("\"", "\"\"") + "\""
	return field


## Normalize a node name: lowercase, replace spaces with underscores.
func _normalize_name(node_name: String) -> String:
	return node_name.to_lower().replace(" ", "_")
