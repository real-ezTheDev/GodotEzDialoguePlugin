using Godot;
using System;

namespace EzDialogue;

/// <summary>
/// C# wrapper for the EzDialogue plugin.
/// Provides a typed C# API over the GDScript EzDialogue node.
/// 
/// Usage:
///   var dialogue = GetNode&lt;EzDialogueSharp&gt;("EzDialogueSharp");
///   dialogue.DialogueGenerated += OnDialogueGenerated;
///   dialogue.CustomSignalReceived += OnCustomSignal;
///   dialogue.StartDialogue(dialogueJson, state);
/// </summary>
[GlobalClass]
public partial class EzDialogueSharp : Node
{
    /// <summary>
    /// Emitted when a page of dialogue is ready to display.
    /// </summary>
    [Signal]
    public delegate void DialogueGeneratedEventHandler(DialogueResponseSharp response);

    /// <summary>
    /// Emitted when a signal(...) command is encountered in the dialogue script.
    /// </summary>
    [Signal]
    public delegate void CustomSignalReceivedEventHandler(string value);

    /// <summary>
    /// (Deprecated) Emitted when end of dialogue is reached.
    /// Use DialogueResponseSharp.EodReached instead.
    /// </summary>
    [Signal]
    public delegate void EndOfDialogueReachedEventHandler();

    private Node _gdReader;

    public override void _Ready()
    {
        // Create the GDScript EzDialogue node and add it as a child.
        var ezDialogueScript = GD.Load<Script>("res://addons/ez_dialogue/ez_dialogue_node.gd");
        _gdReader = new Node();
        _gdReader.SetScript(ezDialogueScript);
        _gdReader.Name = "_EzDialogueInternal";
        AddChild(_gdReader);

        // Connect GDScript signals to C# signals.
        _gdReader.Connect("dialogue_generated", Callable.From<GodotObject>(_OnDialogueGenerated));
        _gdReader.Connect("custom_signal_received", Callable.From<string>(_OnCustomSignalReceived));
        _gdReader.Connect("end_of_dialogue_reached", Callable.From(_OnEndOfDialogueReached));
    }

    /// <summary>
    /// Start processing dialogue from the specified node.
    /// </summary>
    /// <param name="dialogue">A loaded JSON resource (legacy) or a string path to an .ezd file.</param>
    /// <param name="state">Game state dictionary accessible to the dialogue.</param>
    /// <param name="startingNodeName">Name of the dialogue node to begin from.</param>
    public void StartDialogue(Resource dialogue, Godot.Collections.Dictionary state, string startingNodeName = "start")
    {
        _gdReader.Call("start_dialogue", dialogue, state, startingNodeName);
    }

    /// <summary>
    /// Start processing dialogue from an .ezd file path.
    /// </summary>
    /// <param name="ezdFilePath">Resource path to the .ezd file (e.g. "res://dialogue/my_dialogue.ezd").</param>
    /// <param name="state">Game state dictionary accessible to the dialogue.</param>
    /// <param name="startingNodeName">Name of the dialogue node to begin from.</param>
    public void StartDialogueFromEzd(string ezdFilePath, Godot.Collections.Dictionary state, string startingNodeName = "start")
    {
        _gdReader.Call("start_dialogue", ezdFilePath, state, startingNodeName);
    }

    /// <summary>
    /// Advance to the next page or select a choice.
    /// </summary>
    /// <param name="choiceIndex">Index of the selected choice (0-based). Ignored if no choices are pending.</param>
    public void Next(int choiceIndex = 0)
    {
        _gdReader.Call("next", choiceIndex);
    }

    /// <summary>
    /// Whether the dialogue reader is currently processing commands.
    /// </summary>
    public bool IsRunning => (bool)_gdReader.Get("is_running");

    private void _OnDialogueGenerated(GodotObject responseObj)
    {
        var response = new DialogueResponseSharp
        {
            Text = (string)responseObj.Get("text"),
            EodReached = (bool)responseObj.Get("eod_reached")
        };

        var choicesVariant = responseObj.Get("choices");
        if (choicesVariant.VariantType == Variant.Type.Array)
        {
            var gdChoices = choicesVariant.AsGodotArray<string>();
            foreach (var choice in gdChoices)
            {
                response.Choices.Add(choice);
            }
        }

        EmitSignal(SignalName.DialogueGenerated, response);
    }

    private void _OnCustomSignalReceived(string value)
    {
        EmitSignal(SignalName.CustomSignalReceived, value);
    }

    private void _OnEndOfDialogueReached()
    {
        EmitSignal(SignalName.EndOfDialogueReached);
    }

    // --- Localization API ---

    /// <summary>
    /// Tokenize a DialogueResource and return structured token entries.
    /// Each entry contains: token, source_text, node_name, index.
    /// </summary>
    /// <param name="resource">The DialogueResource to tokenize.</param>
    /// <returns>An array of dictionaries representing token entries.</returns>
    public Godot.Collections.Array<Godot.Collections.Dictionary> Tokenize(Resource resource)
    {
        return (Godot.Collections.Array<Godot.Collections.Dictionary>)_gdReader.Call("tokenize", resource);
    }

    /// <summary>
    /// Tokenize a single DialogueNode and return its token entries.
    /// </summary>
    /// <param name="node">The DialogueNode resource to tokenize.</param>
    /// <returns>An array of dictionaries representing token entries for that node.</returns>
    public Godot.Collections.Array<Godot.Collections.Dictionary> TokenizeNode(Resource node)
    {
        return (Godot.Collections.Array<Godot.Collections.Dictionary>)_gdReader.Call("tokenize_node", node);
    }

    /// <summary>
    /// Export tokens to a CSV file at the given path.
    /// </summary>
    /// <param name="resource">The DialogueResource to export tokens from.</param>
    /// <param name="filePath">The file path to write the CSV to.</param>
    /// <returns>OK on success, appropriate error code on failure.</returns>
    public Error ExportCsv(Resource resource, string filePath)
    {
        return (Error)(long)_gdReader.Call("export_csv", resource, filePath);
    }

    /// <summary>
    /// Import translations from a CSV file for a given locale.
    /// </summary>
    /// <param name="locale">The locale identifier (e.g. "fr", "ja").</param>
    /// <param name="filePath">The file path to the CSV translation file.</param>
    /// <returns>OK on success, appropriate error code on failure.</returns>
    public Error ImportCsv(string locale, string filePath)
    {
        return (Error)(long)_gdReader.Call("import_csv", locale, filePath);
    }

    /// <summary>
    /// Set the Translation Table for a given locale.
    /// </summary>
    /// <param name="locale">The locale identifier (e.g. "fr", "ja").</param>
    /// <param name="table">A dictionary mapping token strings to translated text strings.</param>
    public void SetTranslationTable(string locale, Godot.Collections.Dictionary table)
    {
        _gdReader.Call("set_translation_table", locale, table);
    }

    /// <summary>
    /// Get the Translation Table for a given locale.
    /// </summary>
    /// <param name="locale">The locale identifier to retrieve the table for.</param>
    /// <returns>A dictionary mapping token strings to translated text strings, or empty if none loaded.</returns>
    public Godot.Collections.Dictionary GetTranslationTable(string locale)
    {
        return (Godot.Collections.Dictionary)_gdReader.Call("get_translation_table", locale);
    }

    /// <summary>
    /// Clear the Translation Table for a given locale.
    /// </summary>
    /// <param name="locale">The locale identifier to clear.</param>
    public void ClearTranslationTable(string locale)
    {
        _gdReader.Call("clear_translation_table", locale);
    }

    /// <summary>
    /// Set the active locale for translation lookups.
    /// </summary>
    /// <param name="locale">The locale identifier to activate. Empty string disables translation.</param>
    public void SetLocale(string locale)
    {
        _gdReader.Call("set_locale", locale);
    }

    /// <summary>
    /// Get the current active locale.
    /// </summary>
    /// <returns>The currently active locale string, or empty if translation is disabled.</returns>
    public string GetLocale()
    {
        return (string)_gdReader.Call("get_locale");
    }
}
