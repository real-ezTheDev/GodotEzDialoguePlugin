# EzDialogue — Syntax Reference

A complete reference for the EzDialogue scripting language. Every command you can write inside a Dialogue Node's content editor is listed here.

> **New to EzDialogue?** Start with the [README](README.md) for a guided walkthrough of the editor and how to wire everything up in your game. Come back here when you need to look something up quickly.

---

## Quick-Reference Table

| Syntax | Name | Description |
|--------|------|-------------|
| `plain text` | Plain Text | Displayed as dialogue message |
| `${variable}` | Variable Injection | Inserts a state variable's value into text |
| `${variable["key"]}` | Nested Variable Injection | Inserts a nested dictionary value into text |
| `-> node name` | Go To | Jumps to and begins processing another node |
| `?> choice text -> node name` | Choice (goto) | Presents a player choice that transitions to a node |
| `?> choice text { ... }` | Choice (inline) | Presents a player choice with inline commands |
| `?> choice text {}` | Choice (dead-end) | Presents a choice that ends the dialogue |
| `$if expr { ... }` | Conditional | Executes block if expression is truthy |
| `$elif expr { ... }` | Else-if | Executes block if preceding `$if`/`$elif` was falsy and this expression is truthy |
| `$else { ... }` | Else | Executes block when all preceding `$if`/`$elif` branches were falsy |
| `signal(params)` | Custom Signal | Emits a custom signal with the given parameter string |
| `---` | Page Break | Pauses dialogue until `next()` is called |
| `\` | Escape | Treats the next character as plain text |

---

## Plain Text

Any line that doesn't start with a special command is treated as dialogue text. Multiple consecutive lines are joined into a single response with newlines between them.

```
Hello there, traveller.
What brings you to these parts?
```

The above produces a single response:

```
Hello there, traveller.
What brings you to these parts?
```

---

## Variable Injection — `${variable}`

Inject the current value of a state variable directly into displayed text by wrapping the variable name in `${ }`.

```
You rolled a ${roll}.
Your name is ${player_name}, correct?
```

If the variable doesn't exist in the state dictionary, the placeholder is replaced with an empty string — no error is thrown.

### Nested Variable Injection — `${variable["key"]}`

Access a value nested inside a dictionary variable using bracket notation:

```
Your strength is ${stats["strength"]}.
The item is called ${inventory["equipped"]["name"]}.
```

This works for any depth of nesting as long as each level is a `Dictionary`.

---

## Go To — `-> node name`

Transitions immediately to another Dialogue Node and begins processing it. This is a **terminating command** — any remaining commands in the current node are discarded.

```
Thanks for visiting.
-> farewell_node
```

Node name matching is **case-insensitive** and strips leading/trailing whitespace, so `-> My Node` and `-> my node` both resolve to the same node.

---

## Page Break — `---`

Pauses dialogue processing at this point. The current response (all text collected so far) is emitted via `dialogue_generated`, and the dialogue waits until your game code calls `next()`.

Use this to split a long monologue into multiple pages the player clicks through.

```
This is the first page of a long speech.
---
And this is the second page, shown after the player clicks next.
---
And a third.
```

> **Note:** A page break is not needed at the end of a node — the dialogue naturally pauses when it runs out of commands and waits for `next()`.

---

## Player Choices — `?>`

Present one or more choices to the player. All `?>` lines in a node are collected into the `choices` array of the `DialogueResponse`. Your game code reads that array and calls `next(choice_index)` with the index of the selected choice.

### Choice with Go To

```
?> "I come in peace." -> peaceful_path
?> "Stand aside!" -> aggressive_path
```

### Choice with Inline Commands

Use `{ }` to run commands when a choice is selected, before (or instead of) transitioning:

```
?> Accept the offer {
    signal(set,quest_accepted,true)
    Very well. We have a deal.
    -> deal_accepted_node
}
?> Refuse {
    I don't think so.
    -> refused_node
}
```

Commands inside `{ }` can include plain text, `signal()`, `->`, and even nested `$if`/`$elif`/`$else` blocks.

### Dead-End Choice

Use empty brackets `{}` to make a choice that simply ends the dialogue with no further action:

```
?> Goodbye. {}
?> See you around. {}
```

---

## Conditional — `$if` / `$elif` / `$else`

Execute different blocks of commands depending on a state variable or expression.

```
$if relationship >= 50 {
    I'm glad you're here, ${player_name}.
}
$elif relationship >= 20 {
    Oh, it's you.
}
$else {
    What do you want.
}
```

You can chain as many `$elif` branches as you need between `$if` and `$else`. The first branch whose condition is truthy is executed; all remaining branches are skipped.

### Supported Operators

| Operator | Meaning |
|----------|---------|
| `==` | Equal |
| `!=` | Not equal |
| `>` | Greater than |
| `<` | Less than |
| `>=` | Greater than or equal |
| `<=` | Less than or equal |
| `&&` | Logical AND |
| `\|\|` | Logical OR |
| `!` | Logical NOT |

### Truthy / Falsy Rules

- `true`, a non-zero number, or a non-empty string → **truthy**
- `false`, `0`, an empty string, or a variable **missing from the state dictionary** → **falsy**

```
$if has_key {
    The door opens.
}
$else {
    It's locked.
}
```

### Nested Dictionary in Conditionals

Test nested dictionary values the same way as variable injection:

```
$if stats["strength"] >= 10 {
    You force the door open.
}
$else {
    You can't budge it.
}
```

### Complex Expressions

Expressions follow standard boolean precedence. Use parentheses to group sub-expressions:

```
$if (reputation >= 50 && is_guild_member) || has_override_pass {
    Welcome, friend.
}
$else {
    You're not allowed in here.
}
```

### Conditional with Direct Go To

Use `->` directly after `$if`, `$elif`, or `$else` without brackets when there's no text to display:

```
$if quest_complete {
    -> reward_node
}
$else {
    -> quest_reminder_node
}
```

---

## Custom Signal — `signal(params)`

Emit a custom signal from the dialogue to your game code. Everything inside the parentheses is passed as a single string to the `custom_signal_received(value)` signal.

```
signal(play_sound,door_creak)
signal(set,gold,gold+10)
signal(trigger_animation,npc_bow)
```

Your game connects to `custom_signal_received` and parses the string however it needs:

```gdscript
func _on_custom_signal_received(value: String):
    var parts = value.split(",")
    match parts[0]:
        "play_sound":
            AudioManager.play(parts[1])
        "set":
            state[parts[1]] = int(parts[2])
        "trigger_animation":
            npc.play_animation(parts[1])
```

> **Tip:** Signals are processed synchronously — the dialogue does not advance until your signal handler returns. This means you can safely update state variables in a signal handler and the updated values will be available to any `$if` or `${ }` that follows on the same page.

---

## Escape Character — `\`

Prefix any special character or keyword with `\` to treat it as plain text instead of a command.

```
\$if you want to see me, just ask.
The price is \${100} gold.
Use \-> to point the way.
```

Renders as:

```
$if you want to see me, just ask.
The price is ${100} gold.
Use -> to point the way.
```

---

## Complete Example

A self-contained example showing most features together, based on the included `crpg_dialogue_demo`.

**Node: `start`**
```
Tschk' — your lack of resolve only proves you to be weak.

?> "Would it hurt you to be a bit nicer?" -> nicer_please
?> [Intimidation] "TSCHK' I find your judgement weak!" -> intimidation_check
```

**Node: `nicer_please`**
```
If I was any "nicer", we wouldn't survive another minute.

?> Okay... nevermind. -> end
```

**Node: `intimidation_check`**
```
signal(roll,intimidation,10)
---
[You rolled a ${roll}]
$if roll >= 15 {
    Well, you surprise me ga'hik... I might even want to have you.
}
$else {
    Don't even try it ga'hik!
}
```

**Node: `end`**
```
the end
```

**What happens at runtime:**
1. `start` displays the NPC line and two choices.
2. If the player picks the intimidation option, `intimidation_check` fires a `signal` so the game can roll dice and write the result into `state["roll"]`.
3. The `---` page break pauses until the game calls `next()`, giving the roll animation time to play.
4. The `${roll}` injection shows the rolled value, then `$if roll >= 15` branches to the success or failure line.
