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
}
