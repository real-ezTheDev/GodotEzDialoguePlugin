## Base class for headless test scripts.
##
## Subclass this, define functions prefixed with "test_", and they'll be
## auto-discovered and run. No need to manually list tests or print RUN/PASS.
##
## Usage:
##   extends "res://addons/ez_dialogue/dialogue_test/test_runner.gd"
##
##   func test_something() -> void:
##       assert_eq(1 + 1, 2, "basic math")
##       assert_true(true, "truth")
##
##   func test_async_thing() -> void:
##       await some_signal
##       assert_eq(result, expected, "async result")

class_name EzDialogueTestRunner extends SceneTree

var _passed := 0
var _failed := 0
var _current_test := ""
var _suite_name := "Tests"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_suite_name = _get_suite_name()
	var tests := _discover_tests()

	for test_name in tests:
		_current_test = test_name
		print("[ RUN  ] " + test_name)
		await call(test_name)
		print("[ PASS ] " + test_name)
		_passed += 1

	print("")
	print("=".repeat(50))
	print("%s: %d passed, %d failed" % [_suite_name, _passed, _failed])
	print("=".repeat(50))
	quit(1 if _failed > 0 else 0)


## Override in subclass to set the suite name shown in the summary.
func _get_suite_name() -> String:
	return "Tests"


## Auto-discover all methods starting with "test_" in the subclass.
func _discover_tests() -> Array[String]:
	var tests: Array[String] = []
	for method in get_method_list():
		var name: String = method["name"]
		if name.begins_with("test_"):
			tests.push_back(name)
	tests.sort()
	return tests


# ── Assertion methods ─────────────────────────────────────────────────────────
# These track pass/fail counts and print failures to stderr.
# The "context" parameter describes what's being checked.

func assert_eq(actual, expected, context: String = "") -> void:
	var label := _make_label(context)
	if actual == expected:
		pass  # silent pass — counted at test level
	else:
		_failed += 1
		printerr("  FAIL: %s — expected: %s, got: %s" % [label, str(expected), str(actual)])

func assert_true(condition: bool, context: String = "") -> void:
	var label := _make_label(context)
	if not condition:
		_failed += 1
		printerr("  FAIL: %s" % label)

func assert_false(condition: bool, context: String = "") -> void:
	assert_true(not condition, context)

func assert_contains(text: String, substring: String, context: String = "") -> void:
	var label := _make_label(context)
	if not text.contains(substring):
		_failed += 1
		printerr("  FAIL: %s — '%s' not found in '%s'" % [label, substring, text.left(80)])

func assert_not_null(value, context: String = "") -> void:
	var label := _make_label(context)
	if value == null:
		_failed += 1
		printerr("  FAIL: %s — value is null" % label)


func _make_label(context: String) -> String:
	if context.is_empty():
		return _current_test
	return "%s: %s" % [_current_test, context]
