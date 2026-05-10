using Godot;
using System.Collections.Generic;
using EzDialogue;

namespace EzDialogue;

/// <summary>
/// C# test harness for EzDialogue — mirrors the GDScript DialogueTest API.
/// 
/// Usage:
///   var tester = new DialogueTestSharp(ezDialogueSharpNode);
///   AddChild(tester);
///   
///   tester.SetStates(new() { ["has_key"] = true });
///   await tester.StartTest(dialogueResource, "start");
///   tester.AssertResponse("The door opens.", new(), true);
/// </summary>
public partial class DialogueTestSharp : Node
{
    private EzDialogueSharp _dialogue;
    private DialogueResponseSharp _response;
    private List<string> _customSignalResponses = new();
    private Godot.Collections.Dictionary _state = new();

    public DialogueTestSharp(EzDialogueSharp dialogue)
    {
        _dialogue = dialogue;
        _dialogue.CustomSignalReceived += OnCustomSignalReceived;
    }

    /// <summary>
    /// Set state variables for the next test run.
    /// </summary>
    public void SetStates(Godot.Collections.Dictionary state)
    {
        _state = state;
    }

    /// <summary>
    /// Start dialogue from a named node and wait for the first response.
    /// </summary>
    public async System.Threading.Tasks.Task StartTest(Resource dialogue, string startNode)
    {
        _customSignalResponses.Clear();
        _response = null;
        _dialogue.DialogueGenerated += OnDialogueGenerated;
        _dialogue.StartDialogue(dialogue, _state, startNode);
        await WaitForResponse();
        _dialogue.DialogueGenerated -= OnDialogueGenerated;
    }

    /// <summary>
    /// Start dialogue from an .ezd file path and wait for the first response.
    /// </summary>
    public async System.Threading.Tasks.Task StartTestFromEzd(string ezdPath, string startNode)
    {
        _customSignalResponses.Clear();
        _response = null;
        _dialogue.DialogueGenerated += OnDialogueGenerated;
        _dialogue.StartDialogueFromEzd(ezdPath, _state, startNode);
        await WaitForResponse();
        _dialogue.DialogueGenerated -= OnDialogueGenerated;
    }

    /// <summary>
    /// Resume dialogue without selecting a choice (after a page break).
    /// </summary>
    public async System.Threading.Tasks.Task ResumeWithoutChoice()
    {
        _customSignalResponses.Clear();
        _response = null;
        _dialogue.DialogueGenerated += OnDialogueGenerated;
        _dialogue.Next(0);
        await WaitForResponse();
        _dialogue.DialogueGenerated -= OnDialogueGenerated;
    }

    /// <summary>
    /// Resume dialogue by selecting a choice at the given index.
    /// </summary>
    public async System.Threading.Tasks.Task ResumeWithChoice(int choiceIndex)
    {
        _customSignalResponses.Clear();
        _response = null;
        _dialogue.DialogueGenerated += OnDialogueGenerated;
        _dialogue.Next(choiceIndex);
        await WaitForResponse();
        _dialogue.DialogueGenerated -= OnDialogueGenerated;
    }

    /// <summary>
    /// Assert the response text, choices, and end-of-dialogue flag.
    /// </summary>
    public void AssertResponse(string expectedText, List<string> expectedChoices = null, bool expectedEodReached = false)
    {
        expectedChoices ??= new();

        if (_response == null)
        {
            GD.PrintErr($"  FAIL: AssertResponse — no response received");
            return;
        }

        if (_response.Text != expectedText)
        {
            GD.PrintErr($"  FAIL: Expected text: \"{expectedText}\"\n        Actual text:   \"{_response.Text}\"");
        }

        foreach (var choice in expectedChoices)
        {
            if (!_response.Choices.Contains(choice))
            {
                GD.PrintErr($"  FAIL: Expected choice \"{choice}\" not found in: [{string.Join(", ", _response.Choices)}]");
            }
        }

        if (_response.EodReached != expectedEodReached)
        {
            GD.PrintErr($"  FAIL: Expected eod_reached={expectedEodReached}, got {_response.EodReached}");
        }
    }

    /// <summary>
    /// Assert that a custom signal with the given parameter was received.
    /// </summary>
    public void AssertCustomSignal(string expectedParam)
    {
        if (!_customSignalResponses.Contains(expectedParam))
        {
            GD.PrintErr($"  FAIL: Expected custom signal \"{expectedParam}\" not received. Got: [{string.Join(", ", _customSignalResponses)}]");
        }
    }

    /// <summary>
    /// Assert that no custom signals were received during the last interaction.
    /// </summary>
    public void AssertCustomSignalNotReceived()
    {
        if (_customSignalResponses.Count > 0)
        {
            GD.PrintErr($"  FAIL: Unexpected custom signals received: [{string.Join(", ", _customSignalResponses)}]");
        }
    }

    /// <summary>
    /// Get the last response for manual inspection.
    /// </summary>
    public DialogueResponseSharp LastResponse => _response;

    private void OnDialogueGenerated(DialogueResponseSharp response)
    {
        _response = response;
    }

    private void OnCustomSignalReceived(string value)
    {
        _customSignalResponses.Add(value);
    }

    private async System.Threading.Tasks.Task WaitForResponse()
    {
        // Wait frames until the response arrives (dialogue processes in _process).
        for (int i = 0; i < 10; i++)
        {
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            if (_response != null)
                return;
        }
        GD.PrintErr("  WARN: WaitForResponse timed out after 10 frames");
    }
}
