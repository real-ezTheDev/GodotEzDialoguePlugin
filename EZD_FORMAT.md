# EzDialogue File Format (`.ezd`)

A plain-text file format for authoring EzDialogue scripts. Each `.ezd` file represents one dialogue document containing one or more named nodes.

## Structure

```
[node: node_name]
dialogue script content...

[node: another_node]
more content...
```

## Node Header

```
[node: node_name]
[node: node_name, position: 100, 200]
```

- `node_name` — required, case-insensitive unique identifier for the node
- `position: x, y` — optional, graph editor position (float values). If omitted, the editor auto-layouts the node.

The header must be on its own line. Everything between one header and the next (or end of file) is the node's dialogue script body.

## Body

The body uses the existing EzDialogue scripting language. For a complete reference of every command, operator, and rule, see the **[Syntax Reference](SYNTAX_REFERENCE.md)**.

Summary of available commands:

- Plain text (displayed as dialogue)
- `${variable}` — variable injection
- `-> node_name` — goto
- `?> choice text -> node_name` — player choice with goto
- `?> choice text { ... }` — player choice with inline commands
- `$if expr { ... }` — conditional
- `$elif expr { ... }` — else-if
- `$else { ... }` — else
- `signal(params)` — custom signal
- `---` — page break
- `\` — escape next character

## Example

```
[node: start]
Tschk' — your lack of resolve only proves you to be weak.

?> "Would it hurt you to be a bit nicer?" -> nicer_please
?> [Intimidation] "TSCHK' I find your judgement weak!" -> intimidation_check

[node: nicer_please, position: 260, 100]
If I was any "nicer", we wouldn't survive another minute.

?> Okay... nevermind. -> end

[node: intimidation_check, position: 280, 360]
signal(roll,intimidation,10)
---
[You rolled a ${roll}]
$if roll >= 15 {
    Well, you surprise me ga'hik... I might even want to have you.
}
$else {
    Don't even try it ga'hik!
}

[node: end, position: 480, 200]
the end
```

## Compatibility

The EzDialogue plugin supports both formats:
- **`.ezd`** — the plain-text format described here (recommended for new projects)
- **`.json`** — the legacy JSON format (fully supported for backward compatibility)

Both can be loaded at runtime via `EzDialogueReader.start_dialogue()` and opened in the Godot editor plugin.
