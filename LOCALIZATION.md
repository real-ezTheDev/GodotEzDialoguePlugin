# EzDialogue — Localization Guide

This guide explains how to localize dialogue text in your game using EzDialogue's built-in localization system. The system assigns stable tokens to each piece of translatable text, lets you export/import translations via CSV, and substitutes translated text at runtime.

> **New to EzDialogue?** Start with the [README](README.md) for the basics of writing dialogue and wiring it up in your game.

---

## Overview

The localization workflow has three stages:

1. **Tokenize** — Extract all translatable strings from your dialogue and assign each a stable, human-readable token (e.g. `start_1`, `quest_node_choice_1`).
2. **Translate** — Export tokens to CSV, send to translators, and import the completed translations back.
3. **Play** — Set a locale at runtime and the reader automatically substitutes translated text during dialogue playback.

---

## How Tokens Work

Each translatable string gets a token based on its **node name** and **position**:

- Display text: `{normalized_node_name}_{n}` (e.g. `start_1`, `start_2`)
- Choice text: `{normalized_node_name}_choice_{n}` (e.g. `quest_node_choice_1`)

Node names are normalized to lowercase with spaces replaced by underscores. A node named "Quest Node" produces tokens like `quest_node_1`, `quest_node_choice_1`.

**Stability rules:**
- Editing the text content of a line does not change its token (tokens depend on position, not content).
- Inserting or removing lines causes subsequent tokens in that node to renumber.
- Renaming a node changes all tokens for that node.

---

## GDScript API

### Tokenizing

```gdscript
@onready var dialogue: EzDialogue = $EzDialogue

# Tokenize an entire dialogue resource
var entries: Array[Dictionary] = dialogue.tokenize(my_resource)

# Each entry looks like:
# { "token": "start_1", "source_text": "Hello world", "node_name": "Start", "index": 1 }

# Tokenize a single node
var node_entries = dialogue.tokenize_node(some_node)
```

### CSV Export / Import

```gdscript
# Export all tokens to a CSV file for translators
dialogue.export_csv(my_resource, "res://translations/dialogue_strings.csv")

# Import a completed translation CSV for a locale
var err = dialogue.import_csv("fr", "res://translations/dialogue_fr.csv")
```

The exported CSV has three columns:

```csv
token,source_text,translated_text
start_1,"Hello world",""
start_2,"How are you?",""
quest_node_choice_1,"Accept the quest",""
```

Translators fill in the `translated_text` column. If left empty, the source text is used as fallback.

### Loading Translations Directly

You can also supply translations as a plain Dictionary without using CSV:

```gdscript
var french_table = {
    "start_1": "Bonjour le monde",
    "start_2": "Comment allez-vous?",
    "quest_node_choice_1": "Accepter la quête"
}
dialogue.set_translation_table("fr", french_table)
```

### Setting the Active Locale

```gdscript
# Enable French translations
dialogue.set_locale("fr")

# Start dialogue — text is now automatically translated
dialogue.start_dialogue(my_dialogue, state, "start")

# Switch to German mid-dialogue (takes effect on next text)
dialogue.set_locale("de")

# Disable translation (use source text)
dialogue.set_locale("")
```

### Managing Translation Tables

```gdscript
# Get the current table for a locale
var table = dialogue.get_translation_table("fr")

# Clear a locale's translations
dialogue.clear_translation_table("fr")

# Check the active locale
var current = dialogue.get_locale()
```

---

## C# API

The `EzDialogueSharp` node exposes the same functionality with C#-idiomatic naming:

```csharp
using Godot;
using EzDialogue;

// Tokenize
var entries = _dialogue.Tokenize(myResource);
var nodeEntries = _dialogue.TokenizeNode(someNode);

// CSV export/import
_dialogue.ExportCsv(myResource, "res://translations/strings.csv");
_dialogue.ImportCsv("fr", "res://translations/strings_fr.csv");

// Direct table manipulation
var table = new Godot.Collections.Dictionary
{
    { "start_1", "Bonjour le monde" },
    { "start_2", "Comment allez-vous?" }
};
_dialogue.SetTranslationTable("fr", table);
_dialogue.SetLocale("fr");

// Other methods
var retrieved = _dialogue.GetTranslationTable("fr");
_dialogue.ClearTranslationTable("fr");
string locale = _dialogue.GetLocale();
```

---

## Complete Workflow Example

Here's a full example of localizing a dialogue file:

### 1. Export tokens

```gdscript
# In an editor script or tool
var resource = load("res://dialogue/main_quest.json")
var dialogue = EzDialogue.new()
dialogue.export_csv(resource, "res://translations/main_quest.csv")
```

### 2. Translate the CSV

Send `main_quest.csv` to your translators. They fill in the `translated_text` column:

```csv
token,source_text,translated_text
greeting_1,"Hello adventurer!","Bonjour aventurier!"
greeting_2,"Welcome to the village.","Bienvenue au village."
greeting_choice_1,"Accept quest","Accepter la quête"
greeting_choice_2,"Decline","Refuser"
```

### 3. Load translations at runtime

```gdscript
func _ready():
    var dialogue = $EzDialogue
    
    # Load the French translation
    dialogue.import_csv("fr", "res://translations/main_quest_fr.csv")
    
    # Set locale based on player preference
    dialogue.set_locale(Settings.language)
    
    # Start dialogue — automatically uses translated text
    dialogue.start_dialogue(quest_dialogue, state, "greeting")
```

---

## Variable Injection in Translations

Translators can reposition `${variable}` placeholders freely. Translation substitution happens **before** variable injection, so placeholders are resolved at their translated positions.

**Source text:**
```
Hello ${player_name}, welcome to ${town}!
```

**French translation:**
```
Bienvenue à ${town}, ${player_name}!
```

Both produce correct output — the variables resolve wherever the translator placed them.

---

## Fallback Behavior

The system gracefully handles missing translations:

| Scenario | Behavior |
|----------|----------|
| Token not in translation table | Source text is used |
| Token maps to empty string `""` | Source text is used |
| No table loaded for active locale | Source text is used |
| Locale set to empty string `""` | Translation disabled, source text used |
| CSV file doesn't exist | Error logged, source text used |

This means you can ship with partial translations — untranslated strings simply appear in the source language.

---

## Using the Tokenizer Standalone

The `DialogueTokenizer` class works independently of the reader. You can use it in editor tools, export scripts, or CI pipelines without starting dialogue playback:

```gdscript
var tokenizer = DialogueTokenizer.new()
var resource = load("res://dialogue/my_dialogue.json")

# Get structured token data
var entries = tokenizer.tokenize(resource)

# Export to CSV
tokenizer.export_csv(resource, "user://export.csv")

# Import a translated CSV
var table = tokenizer.import_csv("user://translated.csv")
```

---

## API Quick Reference

| Action | GDScript | C# |
|--------|----------|-----|
| Tokenize resource | `tokenize(resource)` | `Tokenize(resource)` |
| Tokenize single node | `tokenize_node(node)` | `TokenizeNode(node)` |
| Export to CSV | `export_csv(resource, path)` | `ExportCsv(resource, path)` |
| Import CSV for locale | `import_csv(locale, path)` | `ImportCsv(locale, path)` |
| Set translation table | `set_translation_table(locale, dict)` | `SetTranslationTable(locale, dict)` |
| Get translation table | `get_translation_table(locale)` | `GetTranslationTable(locale)` |
| Clear translation table | `clear_translation_table(locale)` | `ClearTranslationTable(locale)` |
| Set active locale | `set_locale(locale)` | `SetLocale(locale)` |
| Get active locale | `get_locale()` | `GetLocale()` |

---

## Tips

- **Keep node names unique after normalization.** Two nodes named "Quest Node" and "quest_node" would produce colliding tokens.
- **Re-export after structural changes.** If you add or remove lines in a node, re-export the CSV and merge with existing translations (tokens after the change point will have new numbers).
- **Multiple locales can be loaded simultaneously.** Switch between them instantly with `set_locale()`.
- **Hot-switching works mid-dialogue.** Changing the locale takes effect on the next piece of text processed — no need to restart the dialogue.
