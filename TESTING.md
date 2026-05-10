# Testing Your Dialogue

EzDialogue includes a built-in testing framework so you can verify your dialogue flows, branching logic, and signal behavior without manually clicking through your game.

## Quick Start

1. Write your dialogue (`.ezd` or `.json`)
2. Create a test script
3. Run it headlessly from the terminal

### GDScript

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

### C#

For C# projects, use `DialogueTestSharp` which mirrors the GDScript `DialogueTest` API:

```csharp
// test/MyCSharpDialogueTest.cs
using Godot;
using System.Collections.Generic;
using EzDialogue;

public partial class MyCSharpDialogueTest : Node
{
    private EzDialogueSharp _dialogue;
    private DialogueTestSharp _tester;

    public override void _Ready()
    {
        _dialogue = new EzDialogueSharp();
        _dialogue.Name = "EzDialogueSharp";
        AddChild(_dialogue);

        _tester = new DialogueTestSharp(_dialogue);
        AddChild(_tester);

        CallDeferred(nameof(RunTests));
    }

    private async void RunTests()
    {
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        var dialogue = GD.Load<Json>("res://dialogue/my_dialogue.json");

        // Test the happy path
        _tester.SetStates(new() { ["has_key"] = true });
        await _tester.StartTest(dialogue, "start");
        _tester.AssertResponse("The door opens.", new(), true);

        // Test the sad path
        _tester.SetStates(new() { ["has_key"] = false });
        await _tester.StartTest(dialogue, "start");
        _tester.AssertResponse("It's locked.", new(), true);

        GD.Print("All tests passed!");
        GetTree().Quit();
    }
}
```

Create a scene (`test/MyCSharpTest.tscn`) with this script attached, then run:
```
godot --headless --path . res://test/MyCSharpTest.tscn
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

### GDScript — DialogueTest

#### Setup

| Method | Description |
|--------|-------------|
| `DialogueTest.new(reader: EzDialogueReader)` | Create a test harness wrapping a dialogue reader |
| `set_states(state: Dictionary)` | Set the state variables for the next test run |

#### Driving the Dialogue

| Method | Description |
|--------|-------------|
| `await start_test(dialogue, start_node: String)` | Start dialogue from a named node and wait for the first response |
| `await resume_without_choice()` | Continue after a page break (no choice needed) |
| `await resume_with_choice(choice_index: int)` | Select a choice by index and continue |

#### Assertions

| Method | Description |
|--------|-------------|
| `assert_response(text, choices, eod_reached)` | Assert the displayed text, available choices, and whether end-of-dialogue was reached |
| `assert_dialogue_node_visited(node_name)` | Assert a specific node was visited during the last interaction |
| `assert_dialogue_node_not_visited(node_name)` | Assert a node was NOT visited |
| `assert_custom_signal(param_string)` | Assert a `signal(...)` command fired with the given parameter |
| `assert_custom_signal_not_received()` | Assert no custom signals were emitted |

### C# — DialogueTestSharp

#### Setup

| Method | Description |
|--------|-------------|
| `new DialogueTestSharp(dialogue)` | Create a test harness wrapping an `EzDialogueSharp` node |
| `SetStates(Dictionary state)` | Set the state variables for the next test run |

#### Driving the Dialogue

| Method | Description |
|--------|-------------|
| `await StartTest(Resource dialogue, string startNode)` | Start dialogue from a named node and wait for the first response |
| `await StartTestFromEzd(string path, string startNode)` | Start from an .ezd file path |
| `await ResumeWithoutChoice()` | Continue after a page break |
| `await ResumeWithChoice(int choiceIndex)` | Select a choice by index and continue |

#### Assertions

| Method | Description |
|--------|-------------|
| `AssertResponse(string text, List<string> choices, bool eodReached)` | Assert text, choices, and end-of-dialogue |
| `AssertCustomSignal(string param)` | Assert a signal was received with the given parameter |
| `AssertCustomSignalNotReceived()` | Assert no custom signals were emitted |
| `LastResponse` | Property to access the raw `DialogueResponseSharp` for manual checks |

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

**GDScript:**
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

**C#:**
```csharp
// Start at a node with choices
_tester.SetStates(new());
await _tester.StartTest(dialogue, "crossroads");
_tester.AssertResponse("Which path?",
    new List<string> { "Go left", "Go right" }, false);

// Pick choice 0
await _tester.ResumeWithChoice(0);
_tester.AssertResponse("You went left.", new(), true);

// Re-run and pick the other choice
await _tester.StartTest(dialogue, "crossroads");
await _tester.ResumeWithChoice(1);
_tester.AssertResponse("You went right.", new(), true);
```

## Testing Conditionals

**GDScript:**
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

**C#:**
```csharp
// Truthy path
_tester.SetStates(new() { ["is_friend"] = true });
await _tester.StartTest(dialogue, "guard");
_tester.AssertResponse("Welcome, friend!", new(), true);

// Falsy path
_tester.SetStates(new() { ["is_friend"] = false });
await _tester.StartTest(dialogue, "guard");
_tester.AssertResponse("Halt! Who goes there?", new(), true);
```

## Testing Signals

**GDScript:**
```gdscript
await _tester.start_test(dialogue, "treasure_chest")
_tester.assert_custom_signal("give_item,gold_key")
_tester.assert_custom_signal("play_sfx,chest_open")
```

**C#:**
```csharp
_tester.SetStates(new());
await _tester.StartTest(dialogue, "treasure_chest");
_tester.AssertCustomSignal("give_item,gold_key");
_tester.AssertCustomSignal("play_sfx,chest_open");
```

## Testing Page Breaks

**GDScript:**
```gdscript
await _tester.start_test(dialogue, "long_speech")
_tester.assert_response("First page of the speech.", [], false)  # false = not end yet

await _tester.resume_without_choice()
_tester.assert_response("Second page.", [], true)  # true = end of dialogue
```

**C#:**
```csharp
_tester.SetStates(new());
await _tester.StartTest(dialogue, "long_speech");
_tester.AssertResponse("First page of the speech.", new(), false);

await _tester.ResumeWithoutChoice();
_tester.AssertResponse("Second page.", new(), true);
```

## Testing Node Visits (Flow Verification)

```gdscript
_tester.set_states({"quest_done": true})
await _tester.start_test(dialogue, "quest_giver")

# Verify the dialogue flowed through the reward node
_tester.assert_dialogue_node_visited("reward_node")
_tester.assert_dialogue_node_not_visited("rejection_node")
```

> **Note:** Node visit tracking is only available via the GDScript `DialogueTest` harness. For C# tests, verify flow by checking the response text content instead.

## Testing .ezd Files

**GDScript:**
```gdscript
func _run() -> void:
    _reader.start_dialogue("res://dialogue/my_dialogue.ezd", state, "start")
    var response = await _reader.dialogue_generated
    # ... assertions ...
```

**C#:**
```csharp
_tester.SetStates(new());
await _tester.StartTestFromEzd("res://dialogue/my_dialogue.ezd", "start");
_tester.AssertResponse("Expected text.", new(), true);
```

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
