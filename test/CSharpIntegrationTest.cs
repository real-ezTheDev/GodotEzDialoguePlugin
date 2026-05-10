using Godot;
using System.Collections.Generic;
using EzDialogue;

/// <summary>
/// Headless C# integration test for EzDialogueSharp and DialogueTestSharp.
/// Attached to test/CSharpTest.tscn and run via:
///   godot --headless --path . res://test/CSharpTest.tscn
/// </summary>
public partial class CSharpIntegrationTest : Node
{
    private EzDialogueSharp _dialogue;
    private DialogueTestSharp _tester;
    private int _passed = 0;
    private int _failed = 0;
    private string _currentTest = "";

    public override void _Ready()
    {
        _dialogue = new EzDialogueSharp();
        _dialogue.Name = "EzDialogueSharp";
        AddChild(_dialogue);

        _tester = new DialogueTestSharp(_dialogue);
        AddChild(_tester);

        CallDeferred(nameof(RunAllTests));
    }

    private async void RunAllTests()
    {
        // Wait for EzDialogueSharp._Ready to complete.
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);

        var dialogueJson = GD.Load<Json>("res://test/mixed_commands_test_dialogue.json");

        // ── Test: Plain text ─────────────────────────────────────────────────
        Run("test_plain_text");
        _tester.SetStates(new());
        await _tester.StartTest(dialogueJson, "plain_text_test_single_line");
        _tester.AssertResponse("this is a single line test.", new(), true);
        Pass();

        // ── Test: Multi-line text ────────────────────────────────────────────
        Run("test_multi_line_text");
        _tester.SetStates(new());
        await _tester.StartTest(dialogueJson, "plain_text_test_multi_line");
        _tester.AssertResponse(
            "this is a multi line text.\nWhere the consequent lines are put parsed together.",
            new(), true);
        Pass();

        // ── Test: Choices ────────────────────────────────────────────────────
        Run("test_choices");
        _tester.SetStates(new());
        await _tester.StartTest(dialogueJson, "choice_based_transition");
        _tester.AssertResponse("choice is selected.",
            new List<string> { "choice a", "choice b" }, false);
        Pass();

        // ── Test: Choice selection ───────────────────────────────────────────
        Run("test_choice_selection");
        await _tester.ResumeWithChoice(0);
        _tester.AssertResponse("choice A transition target.", new(), true);
        Pass();

        // ── Test: Conditional truthy ─────────────────────────────────────────
        Run("test_conditional_truthy");
        _tester.SetStates(new() { ["test_variable"] = true });
        await _tester.StartTest(dialogueJson, "base_conditional_display");
        _tester.AssertResponse(
            "starting test.\nvariable is true.\npost conditional text pick up.",
            new(), true);
        Pass();

        // ── Test: Conditional falsy ──────────────────────────────────────────
        Run("test_conditional_falsy");
        _tester.SetStates(new() { ["test_variable"] = false });
        await _tester.StartTest(dialogueJson, "base_conditional_display");
        _tester.AssertResponse(
            "starting test.\nvariable is not true.\npost conditional text pick up.",
            new(), true);
        Pass();

        // ── Test: Custom signal ──────────────────────────────────────────────
        Run("test_custom_signal");
        _tester.SetStates(new());
        await _tester.StartTest(dialogueJson, "custom_signal_test");
        _tester.AssertCustomSignalNotReceived();
        await _tester.ResumeWithChoice(0);
        _tester.AssertCustomSignal("test_signal_1,param1");
        Pass();

        // ── Test: Variable injection ─────────────────────────────────────────
        Run("test_variable_injection");
        _tester.SetStates(new() { ["test_variable"] = "success." });
        await _tester.StartTest(dialogueJson, "test_variable_injection_in_text");
        _tester.AssertResponse(
            "This is a variable display text.\nInject the following success..\nyipee!",
            new(), true);
        Pass();

        // ── Test: Page break ─────────────────────────────────────────────────
        Run("test_page_break");
        _tester.SetStates(new());
        await _tester.StartTest(dialogueJson, "test_page_break");
        _tester.AssertResponse("page one text.", new(), false);
        await _tester.ResumeWithoutChoice();
        _tester.AssertResponse("page two text.", new(), true);
        Pass();

        // ── Test: EZD file loading ───────────────────────────────────────────
        Run("test_ezd_loading");
        _tester.SetStates(new());
        await _tester.StartTestFromEzd("res://test/sample_dialogue.ezd", "start");
        var resp = _tester.LastResponse;
        AssertTrue(resp != null && resp.Text.Contains("Hello traveller"), "ezd text");
        AssertTrue(resp != null && resp.Choices.Count == 2, "ezd choices");
        Pass();

        // ── Test: Goto transition ────────────────────────────────────────────
        Run("test_goto_transition");
        _tester.SetStates(new());
        await _tester.StartTest(dialogueJson, "plain_transition_test");
        _tester.AssertResponse(
            "this is base transition test.\ntransition successful.", new(), true);
        Pass();

        // ── Summary ──────────────────────────────────────────────────────────
        GD.Print("");
        GD.Print(new string('=', 50));
        GD.Print($"C# Integration Tests: {_passed} passed, {_failed} failed");
        GD.Print(new string('=', 50));

        GetTree().Quit(_failed > 0 ? 1 : 0);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private void Run(string name)
    {
        _currentTest = name;
        GD.Print($"[ RUN  ] {name}");
    }

    private void Pass()
    {
        _passed++;
        GD.Print($"[ PASS ] {_currentTest}");
    }

    private void AssertTrue(bool condition, string context)
    {
        if (!condition)
        {
            _failed++;
            GD.PrintErr($"  FAIL: {_currentTest}: {context}");
        }
    }
}
