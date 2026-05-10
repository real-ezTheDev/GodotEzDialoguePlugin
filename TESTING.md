# Testing Your Dialogue

EzDialogue includes a built-in testing framework so you can verify your dialogue flows, branching logic, and signal behavior without manually clicking through your game.

## Quick Start

1. Write your dialogue (`.ezd` or `.json`)
2. Create a test script
3. Run it headlessly from the terminal

```gdscript
# test/MyDialogueTest.gd
extends SceneTree

var _reader: EzDialogue
var _tester: DialogueTest

func _initialize() -> void:
    _reader = EzDialogue.new()
    get_root().add_child(_reader)
    _tester = DialogueTest.new(_reader)
    get_root().add_child(_tester)
    _run.call_deferred()

func _run() -> void:
    var dialogue: JSON = load("res://dialogue/my_dialogue.json")

    # Test the happy path
    _tester.set_states({"has_key": true})
    await _tester.start_test(dialogue, "start")
    _tester.assert_response("The door opens.", [], true)

    # Test the sad path
    _tester.set_states({"has_key": false})
    await _tester.start_test(dialogue, "start")
    _tester.assert_response("It's locked.", [], true)

    print("All tests passed!")
    quit()
```

Run it:
```
godot --headless --path . -s test/MyDialogueTest.gd
```

## Core Concepts

### DialogueTest

`DialogueTest` is the test harness. It wraps an `EzDialogue` node and provides methods to drive the dialogue forward and assert on the results.

```gdscript
var tester = DialogueTest.new(your_ez_dialogue_node)
```

### Test Lifecycle

Each test interaction follows this pattern:

1. **Set state** — provide the game variables the dialogue will read
2. **Start or resume** — kick off the dialogue or continue after a choice
3. **Assert** — verify the response text, choices, signals, and visited nodes

```gdscript
# 1. Set state
_tester.set_states({"gold": 100, "reputation": 30})

# 2. Start dialogue from a specific node
await _tester.start_test(dialogue, "shop_keeper")

# 3. Assert what was generated
_tester.assert_response("Welcome! What can I get you?", ["Buy sword", "Leave"])
```

## API Reference

### Setup

| Method | Description |
|--------|-------------|
| `DialogueTest.new(reader: EzDialogueReader)` | Create a test harness wrapping a dialogue reader |
| `set_states(state: Dictionary)` | Set the state variables for the next test run |

### Driving the Dialogue

| Method | Description |
|--------|-------------|
| `await start_test(dialogue, start_node: String)` | Start dialogue from a named node and wait for the first response |
| `await resume_without_choice()` | Continue after a page break (no choice needed) |
| `await resume_with_choice(choice_index: int)` | Select a choice by index and continue |

### Assertions

| Method | Description |
|--------|-------------|
| `assert_response(text, choices, eod_reached)` | Assert the displayed text, available choices, and whether end-of-dialogue was reached |
| `assert_dialogue_node_visited(node_name)` | Assert a specific node was visited during the last interaction |
| `assert_dialogue_node_not_visited(node_name)` | Assert a node was NOT visited |
| `assert_custom_signal(param_string)` | Assert a `signal(...)` command fired with the given parameter |
| `assert_custom_signal_not_received()` | Assert no custom signals were emitted |

### assert_response Parameters

```gdscript
_tester.assert_response(
    "Expected display text",   # The exact text shown to the player
    ["Choice A", "Choice B"],  # Expected choice labels (order doesn't matter)
    false                      # true if this is the final response (end of dialogue)
)
```

- **text** — Multi-line text uses `\n`: `"Line one.\nLine two."`
- **choices** — Pass `[]` if no choices are expected
- **eod_reached** — `true` means the dialogue has ended, `false` means more content follows

## Testing Choices and Branching

```gdscript
# Start at a node with choices
await _tester.start_test(dialogue, "crossroads")
_tester.assert_response("Which path?", ["Go left", "Go right"])

# Pick choice index 0 ("Go left")
await _tester.resume_with_choice(0)
_tester.assert_response("You went left.", [], true)

# Re-run and pick the other choice
await _tester.start_test(dialogue, "crossroads")
await _tester.resume_with_choice(1)
_tester.assert_response("You went right.", [], true)
```

## Testing Conditionals

```gdscript
# Truthy path
_tester.set_states({"is_friend": true})
await _tester.start_test(dialogue, "guard")
_tester.assert_response("Welcome, friend!", [], true)

# Falsy path
_tester.set_states({"is_friend": false})
await _tester.start_test(dialogue, "guard")
_tester.assert_response("Halt! Who goes there?", [], true)

# Missing variable (treated as falsy)
_tester.set_states({})
await _tester.start_test(dialogue, "guard")
_tester.assert_response("Halt! Who goes there?", [], true)
```

## Testing Signals

```gdscript
await _tester.start_test(dialogue, "treasure_chest")
_tester.assert_custom_signal("give_item,gold_key")
_tester.assert_custom_signal("play_sfx,chest_open")
```

## Testing Page Breaks

```gdscript
await _tester.start_test(dialogue, "long_speech")
_tester.assert_response("First page of the speech.", [], false)  # false = not end yet

await _tester.resume_without_choice()
_tester.assert_response("Second page.", [], true)  # true = end of dialogue
```

## Testing Node Visits (Flow Verification)

```gdscript
_tester.set_states({"quest_done": true})
await _tester.start_test(dialogue, "quest_giver")

# Verify the dialogue flowed through the reward node
_tester.assert_dialogue_node_visited("reward_node")
_tester.assert_dialogue_node_not_visited("rejection_node")
```

## Testing .ezd Files

You can pass a file path string to `start_dialogue` for `.ezd` files:

```gdscript
func _run() -> void:
    _reader.start_dialogue("res://dialogue/my_dialogue.ezd", state, "start")
    var response = await _reader.dialogue_generated
    # ... assertions ...
```

Or use `DialogueTest.start_test` with a loaded JSON resource for `.json` files (the original approach).

## Running Tests from Terminal

```
godot --headless --path <project_root> -s <test_script_path>
```

Example:
```
godot --headless --path . -s test/MyDialogueTest.gd
```

Exit code `0` means all passed. Exit code `1` means failures occurred. Assertion failures print to stderr with details about expected vs actual values.

## Tips

- **Test each branch independently** — set different states and re-run `start_test` from the same node
- **Test edge cases** — missing variables, empty states, boundary values for numeric comparisons
- **Name your starting nodes descriptively** — makes test output easier to read
- **Keep test dialogues small** — test one flow per node rather than one giant dialogue
- **Use `assert_dialogue_node_visited`** for flow tests where you care about WHICH nodes were hit, not the exact text
