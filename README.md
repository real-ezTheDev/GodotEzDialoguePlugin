# EzDialogue Plugin for Godot

EzDialogue is a Dialogue extension for Godot Game Engine.

The Plugin provides ways to create and organize in-game dialogues by providing customized dialogue management tab in Godot Engine. Use EzDialogue's own scripting language to write dialogues, control narrative branches, and trigger custom in-game functions.

**Documentation**
- [Getting Started Guide](#writing-dialogue) — how to use the editor and wire up dialogue in your game (this page)
- [Syntax Reference](SYNTAX_REFERENCE.md) — quick-lookup for every command, operator, and language rule
- [EZD File Format](EZD_FORMAT.md) — the plain-text `.ezd` format for authoring dialogue outside the Godot editor
- [Testing Guide](TESTING.md) — how to write automated tests for your dialogue flows
- [VS Code Extension](vscode-ezd/README.md) — syntax highlighting for `.ezd` files in VS Code / Kiro (includes install instructions)

## Requirement

EzDialogue plugin has only been tested with Godot v4.0+

## Video Tutorial

Click [here](https://youtu.be/WVflfiKjXgk) for video tutorial/demo.

## Installation

1. Download or clone this repository.
2. Copy the `addons/ez_dialogue/` folder into your Godot project so the path is:
   ```
   your_project/
   └── addons/
       └── ez_dialogue/
           ├── plugin.cfg
           ├── ez_dialogue.gd
           └── ...
   ```
   > **Common mistake:** If you downloaded the ZIP from GitHub, don't copy the entire extracted folder. The ZIP extracts to `GodotEzDialoguePlugin-main/` — you need the `addons/ez_dialogue/` folder from *inside* it, not the wrapper folder.
3. Open `Project > Project Settings...`, then go to the `Plugins` tab.
4. Find `DeveloperEzra's Dialogue Manager` and set its status to `Enable`.
5. The `EzDialogue` tab should now appear in your editor.

## Writing Dialogue

To begin writing your dialogue, go to `EzDialogue` tab.

### Dialogue Node
Create a dialogue node by clicking the `+` on the top left corner of the dialogue editor window.
!["+" button in editor](https://github.com/real-ezTheDev/GodotEzDialoguePlugin/blob/dev/readme_src/add_diag_node_button.png?raw=true)

Once you select the node (the created Dialogue Node should be alrady selected), the right-side panel enables. This is where you edit the Dialogue Node's name and its content.
![click on node to edit its content](https://github.com/real-ezTheDev/GodotEzDialoguePlugin/blob/dev/readme_src/selecting_diag_node.png?raw=true)

### Writing Content
#### Dialogue Name
The name of a dialogue should be unique within the file (case-INsensitive). Dialogue Node's name is how you instruct the flow between different nodes.

By `default`, You should name the starting node `Start`.

#### Plain Text
You can simply start writing your plain text dialogue in the content section of the Dialogue Node. Whatever you write would show up as dialogue message in your game.
![click on node to edit its content](https://github.com/real-ezTheDev/GodotEzDialoguePlugin/blob/dev/readme_src/plain_text_example.png?raw=true)

#### Variable Injection in Text
You can inject the value of variable defined in the state `Dictionary` within the text by surrounding the varaible name with `${variable_name}`

![click on node to edit its content](https://github.com/real-ezTheDev/GodotEzDialoguePlugin/blob/dev/readme_src/variable_dialogue_example.png?raw=true)

### Flow Control and Branching
Naturally, you want to navigate to different dialogue based on conditions and player choices.
This section focuses on this.

#### Go To Node
You can transition and begin processing the desired node with a simple go to command with a syntax `-> node name`.
Remember I mentioned you should make sure the node name is unique? It's because of this, the system will try to search for a case-insensitive node name matching the target of the `->` command.
![click on node to edit its content](https://github.com/real-ezTheDev/GodotEzDialoguePlugin/blob/dev/readme_src/simple_goto_example.png?raw=true)

#### Player Choices
You can present choices with a `choice`(`?>`) command with a syntax:
```
?> choice text to show to player -> target node
```
the text "Choice ttext to show to player" will be displayed as an option for your player,
and the result of selecting the choice is `-> target node`, where the system would transition and begin processing the dialogue node named "target node" in this example.

While I believe most of the post-choice selection logic should be handled in the new node, you still have the option to execute commands before transitioning (or not transition at all) by using brackets `{}`:

```
?> some choice txt {
    nice choice
    signal(set,variable,2)
    -> next node
}
```

In the above example, when the choice "some choice txt" is selected, the system would execute the commands surrounded by the brackets:
1. display text "nice choice"
2. emit custom signal with signal parameter "set,variable,2"
3. transition to a node named "next node"

> <i><b>NOTE</i></b> Sometimes you might want to have an "empty" choice to immediately end the dialogue after the player made a choice. You can make your prompt "do nothing" with the format `?> choice text {}`.

#### Conditional
To display or transition based on a state condition, you can use the conditional statement with a command `$if [condition] {...} $else {...}`

Here's an example of displaying 2 different message based on the value of the state variable named "roll":
![click on node to edit its content](https://github.com/real-ezTheDev/GodotEzDialoguePlugin/blob/dev/readme_src/conditional_example.png?raw=true)

As with #player-choices , you can nest and include as many commands as you want within the brackets.. However, as of right now, I cannot guarantee that it would function 100% until further development :)

### Custom Commands
The EzDialogue manager uses the signal pattern that Godot is familiar with. Anytime the dialogue sees a pattern of `signal(some value)`, a signal is emitted from the dialogue handler with values in between the parenthesis as the signal value.

Fortunately (unfortunately), the way Godot handles signal is still synchronous, so the headache of having to race between the next part of the dialogue being processed vs your custom signal processing should not have to be a problem.

Some examples, I personally use for custom signal are :
setting values of the variable, 
triggering animation/effect/sound,
and etc.

### Escape Commands
You can escape any of the above "special" reserved commands and words with a single backslash to display them as plain text.

For example the following dialogue script:
```
\$if you wish to see me {
    call me.
}
```

would be displayed as:

"$if you wish to see me {
    call me.
}"

instead of being interpretted as `$if` command.

### How to Load Dialogue in Game

This section explains how to load and use dialogue resources at runtime. Both GDScript and C# are supported.

#### Setup

1. Add an **EzDialogue** node to your scene (GDScript), or an **EzDialogueSharp** node (C#).
2. Load your dialogue file (`.json` or `.ezd`).
3. Connect to the response signal and call `start_dialogue` / `StartDialogue`.

#### GDScript Example

```gdscript
extends Control

@export var dialogue: JSON  # Assign in inspector

@onready var dialogue_handler: EzDialogue = $EzDialogue

func _ready():
    dialogue_handler.dialogue_generated.connect(_on_dialogue_generated)
    dialogue_handler.custom_signal_received.connect(_on_custom_signal)
    
    var state = {"player_name": "Hero", "gold": 50}
    dialogue_handler.start_dialogue(dialogue, state, "start")

func _on_dialogue_generated(response: DialogueResponse):
    # Display the text
    $Label.text = response.text
    
    # Show choices if any
    for i in response.choices.size():
        _add_choice_button(response.choices[i], i)
    
    # Check if dialogue is finished
    if response.eod_reached:
        print("Dialogue complete!")

func _on_custom_signal(value: String):
    var params = value.split(",")
    match params[0]:
        "play_sound":
            AudioManager.play(params[1])
        "set":
            state[params[1]] = params[2]

func _on_choice_selected(choice_index: int):
    dialogue_handler.next(choice_index)
```

#### C# Example

```csharp
using Godot;
using EzDialogue;

public partial class MyDialogueUI : Control
{
    [Export] public Resource DialogueFile;

    private EzDialogueSharp _dialogue;

    public override void _Ready()
    {
        _dialogue = GetNode<EzDialogueSharp>("EzDialogueSharp");
        _dialogue.DialogueGenerated += OnDialogueGenerated;
        _dialogue.CustomSignalReceived += OnCustomSignal;

        var state = new Godot.Collections.Dictionary
        {
            ["player_name"] = "Hero",
            ["gold"] = 50
        };
        _dialogue.StartDialogue(DialogueFile, state, "start");
    }

    private void OnDialogueGenerated(DialogueResponseSharp response)
    {
        // Display the text
        GetNode<Label>("Label").Text = response.Text;

        // Show choices if any
        for (int i = 0; i < response.Choices.Count; i++)
            AddChoiceButton(response.Choices[i], i);

        // Check if dialogue is finished
        if (response.EodReached)
            GD.Print("Dialogue complete!");
    }

    private void OnCustomSignal(string value)
    {
        var parts = value.Split(",");
        switch (parts[0])
        {
            case "play_sound":
                AudioManager.Play(parts[1]);
                break;
            case "set":
                // Update state as needed
                break;
        }
    }

    private void OnChoiceSelected(int choiceIndex)
    {
        _dialogue.Next(choiceIndex);
    }
}
```

#### Loading .ezd Files

You can also load `.ezd` files directly at runtime:

**GDScript:**
```gdscript
dialogue_handler.start_dialogue("res://dialogue/my_dialogue.ezd", state, "start")
```

**C#:**
```csharp
_dialogue.StartDialogueFromEzd("res://dialogue/my_dialogue.ezd", state, "start");
```

#### API Quick Reference

| Action | GDScript | C# |
|--------|----------|-----|
| Start dialogue (JSON) | `start_dialogue(json, state, "start")` | `StartDialogue(resource, state, "start")` |
| Start dialogue (.ezd) | `start_dialogue("res://path.ezd", state, "start")` | `StartDialogueFromEzd("res://path.ezd", state, "start")` |
| Advance / select choice | `next(choice_index)` | `Next(choiceIndex)` |
| Response signal | `dialogue_generated(response: DialogueResponse)` | `DialogueGenerated += handler` |
| Custom signal | `custom_signal_received(value: String)` | `CustomSignalReceived += handler` |
| Check if running | `is_running` | `IsRunning` |
| Response text | `response.text` | `response.Text` |
| Response choices | `response.choices` | `response.Choices` |
| End of dialogue | `response.eod_reached` | `response.EodReached` |

For a basic and complete GDScript implementation see the demo in [./crpg_dialogue_demo](https://github.com/real-ezTheDev/GodotEzDialoguePlugin/blob/dev/crpg_dialogue_demo)

---

## Syntax Reference

For a full command reference — every operator, truthy/falsy rule, nested variable syntax, and a complete worked example — see the **[Syntax Reference](SYNTAX_REFERENCE.md)**.

---

### Design Goals and Future Plans

I believe between custom signal and other basic dialogue commands, there's a "round about" way to do pretty much anything one would desire. However, some of the "round about" solution might end up being very inconvenient, and I would like to resolve them as they come up. So, please feel free to share any thoughts and suggestions.

I personally believe writing as much as you can without taking short cuts in narrative is the best player experience. So, I want to develop the tool towards helping with that goal in mind.

I do not wish for this tool to start over-reaching into another programming/scripting language, but focused on the goal of "writing dialogues and branch in full depth where nothing but my own creativity blocks the process."

#### Recently Completed
- ✅ **Syntax highlighting hardening** — full overhaul with dedicated color categories, regex-based token detection, and 80+ automated tests
- ✅ **C# support** — typed wrapper (`EzDialogueSharp`), test harness (`DialogueTestSharp`), full documentation
- ✅ **`.ezd` plain-text format** — author dialogue outside the Godot editor with VS Code syntax highlighting
- ✅ **`$elif` support** — multi-branch conditionals without nesting
- ✅ **Cross-node search** — live search with graph highlighting and Ctrl+F shortcut
- ✅ **Headless test runner** — automated testing from terminal with CI-friendly exit codes
- ✅ **Bug fixes** — parser performance, conditional evaluation, bracket handling, GraphEdit compatibility

#### Roadmap
1. **Node tagging** — label nodes with tags to quickly filter and search by category (e.g. "unfinished", "needs-review", "side-quest")
2. **Flow reference** — when editing a node, see which other nodes can reach it (incoming connections displayed in the UI)
3. **Jump to earliest unhandled branch** — pre-plan a split, write depth-first on one branch, then jump back to the next unwritten branch
4. **Undo/redo** — integrate with Godot's UndoRedo system for graph and editor actions

