using Godot;
using System.Collections.Generic;
using EzDialogue;

/// <summary>
/// Headless C# integration test for EzDialogueSharp localization methods.
/// Verifies that the C# wrapper correctly delegates to GDScript internals.
/// Attached to test/CSharpLocalizationTest.tscn and run via:
///   godot --headless --path . res://test/CSharpLocalizationTest.tscn
/// </summary>
public partial class CSharpLocalizationTest : Node
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

    /// <summary>
    /// Creates a DialogueResource from a JSON resource by calling GDScript methods.
    /// This mirrors how the GDScript tests create DialogueResource objects.
    /// </summary>
    private Resource CreateDialogueResource(Json jsonResource)
    {
        var script = GD.Load<Script>("res://addons/ez_dialogue/dialogue_resource/dialogue_resource.gd");
        var resource = (Resource)ClassDB.Instantiate("Resource");
        resource.SetScript(script);
        resource.Call("loadFromJson", jsonResource.Data);
        return resource;
    }

    private async void RunAllTests()
    {
        // Wait for EzDialogueSharp._Ready to complete.
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);

        // ── Test: SetTranslationTable / GetTranslationTable round-trip ────────
        Run("test_set_get_translation_table_roundtrip");
        TestSetGetTranslationTableRoundTrip();
        Pass();

        // ── Test: SetTranslationTable with empty table ───────────────────────
        Run("test_set_get_translation_table_empty");
        TestSetGetTranslationTableEmpty();
        Pass();

        // ── Test: SetLocale / GetLocale ──────────────────────────────────────
        Run("test_set_get_locale");
        TestSetGetLocale();
        Pass();

        // ── Test: SetLocale empty string disables translation ────────────────
        Run("test_set_locale_empty_disables");
        TestSetLocaleEmptyDisables();
        Pass();

        // ── Test: Tokenize returns structured entries ────────────────────────
        Run("test_tokenize_returns_entries");
        TestTokenizeReturnsEntries();
        Pass();

        // ── Test: ExportCsv produces valid file ──────────────────────────────
        Run("test_export_csv");
        TestExportCsv();
        Pass();

        // ── Test: ImportCsv loads translations ───────────────────────────────
        Run("test_import_csv");
        TestImportCsv();
        Pass();

        // ── Test: ImportCsv with non-existent file returns error ─────────────
        Run("test_import_csv_nonexistent_file");
        TestImportCsvNonexistentFile();
        Pass();

        // ── Test: ClearTranslationTable removes table ────────────────────────
        Run("test_clear_translation_table");
        TestClearTranslationTable();
        Pass();

        // ── Test: Multiple locales stored independently ──────────────────────
        Run("test_multiple_locales_independent");
        TestMultipleLocalesIndependent();
        Pass();

        // ── Test: Translation applied during dialogue playback ───────────────
        Run("test_translation_applied_during_playback");
        await TestTranslationAppliedDuringPlayback();
        Pass();

        // ── Summary ──────────────────────────────────────────────────────────
        GD.Print("");
        GD.Print(new string('=', 50));
        GD.Print($"C# Localization Tests: {_passed} passed, {_failed} failed");
        GD.Print(new string('=', 50));

        GetTree().Quit(_failed > 0 ? 1 : 0);
    }

    // ── Test Implementations ─────────────────────────────────────────────────

    private void TestSetGetTranslationTableRoundTrip()
    {
        var table = new Godot.Collections.Dictionary
        {
            { "start_1", "Bonjour le monde" },
            { "start_2", "Comment allez-vous?" },
            { "quest_node_choice_1", "Accepter la quête" }
        };

        _dialogue.SetTranslationTable("fr", table);
        var retrieved = _dialogue.GetTranslationTable("fr");

        AssertTrue(retrieved != null, "retrieved table should not be null");
        AssertTrue(retrieved.Count == 3, $"expected 3 entries, got {retrieved.Count}");
        AssertTrue((string)retrieved["start_1"] == "Bonjour le monde",
            $"start_1 mismatch: got '{retrieved["start_1"]}'");
        AssertTrue((string)retrieved["start_2"] == "Comment allez-vous?",
            $"start_2 mismatch: got '{retrieved["start_2"]}'");
        AssertTrue((string)retrieved["quest_node_choice_1"] == "Accepter la quête",
            $"quest_node_choice_1 mismatch: got '{retrieved["quest_node_choice_1"]}'");

        // Clean up
        _dialogue.ClearTranslationTable("fr");
    }

    private void TestSetGetTranslationTableEmpty()
    {
        var table = new Godot.Collections.Dictionary();
        _dialogue.SetTranslationTable("empty_locale", table);
        var retrieved = _dialogue.GetTranslationTable("empty_locale");

        AssertTrue(retrieved != null, "retrieved table should not be null");
        AssertTrue(retrieved.Count == 0, $"expected 0 entries, got {retrieved.Count}");

        // Clean up
        _dialogue.ClearTranslationTable("empty_locale");
    }

    private void TestSetGetLocale()
    {
        _dialogue.SetLocale("fr");
        var locale = _dialogue.GetLocale();
        AssertTrue(locale == "fr", $"expected 'fr', got '{locale}'");

        _dialogue.SetLocale("ja");
        locale = _dialogue.GetLocale();
        AssertTrue(locale == "ja", $"expected 'ja', got '{locale}'");

        // Reset
        _dialogue.SetLocale("");
    }

    private void TestSetLocaleEmptyDisables()
    {
        _dialogue.SetLocale("en");
        AssertTrue(_dialogue.GetLocale() == "en", "locale should be 'en'");

        _dialogue.SetLocale("");
        AssertTrue(_dialogue.GetLocale() == "", "locale should be empty after disabling");
    }

    private void TestTokenizeReturnsEntries()
    {
        var dialogueJson = GD.Load<Json>("res://test/mixed_commands_test_dialogue.json");
        var dialogueResource = CreateDialogueResource(dialogueJson);
        var entries = _dialogue.Tokenize(dialogueResource);

        AssertTrue(entries != null, "tokenize should return non-null");
        AssertTrue(entries.Count > 0, "tokenize should return entries for dialogue with text");

        // Verify first entry has required fields
        var firstEntry = entries[0];
        AssertTrue(firstEntry.ContainsKey("token"), "entry should have 'token' field");
        AssertTrue(firstEntry.ContainsKey("source_text"), "entry should have 'source_text' field");
        AssertTrue(firstEntry.ContainsKey("node_name"), "entry should have 'node_name' field");
        AssertTrue(firstEntry.ContainsKey("index"), "entry should have 'index' field");

        // Verify token format: should be "{node_name}_{index}"
        var token = (string)firstEntry["token"];
        AssertTrue(!string.IsNullOrEmpty(token), "token should not be empty");
        AssertTrue(token.Contains("_"), "token should contain underscore separator");
    }

    private void TestExportCsv()
    {
        var dialogueJson = GD.Load<Json>("res://test/mixed_commands_test_dialogue.json");
        var dialogueResource = CreateDialogueResource(dialogueJson);
        var csvPath = "user://test_csharp_export_localization.csv";

        var err = _dialogue.ExportCsv(dialogueResource, csvPath);
        AssertTrue(err == Error.Ok, $"export_csv should return OK, got {err}");

        // Verify the file was created by importing it back
        var importErr = _dialogue.ImportCsv("test_export_locale", csvPath);
        AssertTrue(importErr == Error.Ok, $"import_csv of exported file should return OK, got {importErr}");

        var table = _dialogue.GetTranslationTable("test_export_locale");
        AssertTrue(table != null, "imported table should not be null");
        AssertTrue(table.Count > 0, "imported table should have entries from exported CSV");

        // Clean up
        _dialogue.ClearTranslationTable("test_export_locale");
    }

    private void TestImportCsv()
    {
        // First export a CSV so we have a known file to import
        var dialogueJson = GD.Load<Json>("res://test/mixed_commands_test_dialogue.json");
        var dialogueResource = CreateDialogueResource(dialogueJson);
        var csvPath = "user://test_csharp_import_localization.csv";
        _dialogue.ExportCsv(dialogueResource, csvPath);

        // Import it for a locale
        var err = _dialogue.ImportCsv("import_test", csvPath);
        AssertTrue(err == Error.Ok, $"import_csv should return OK, got {err}");

        var table = _dialogue.GetTranslationTable("import_test");
        AssertTrue(table != null, "imported table should not be null");
        AssertTrue(table.Count > 0, "imported table should have entries");

        // Verify the keys match tokenization output
        var entries = _dialogue.Tokenize(dialogueResource);
        foreach (var entry in entries)
        {
            var token = (string)entry["token"];
            AssertTrue(table.ContainsKey(token),
                $"imported table should contain token '{token}' from tokenization");
        }

        // Clean up
        _dialogue.ClearTranslationTable("import_test");
    }

    private void TestImportCsvNonexistentFile()
    {
        var err = _dialogue.ImportCsv("nonexist_locale", "user://this_file_does_not_exist.csv");
        // Should return an error (not crash) and gracefully handle missing file
        AssertTrue(err != Error.Ok, "import_csv with non-existent file should return error");
    }

    private void TestClearTranslationTable()
    {
        var table = new Godot.Collections.Dictionary
        {
            { "token_1", "Translation 1" },
            { "token_2", "Translation 2" }
        };

        _dialogue.SetTranslationTable("clear_test", table);
        var retrieved = _dialogue.GetTranslationTable("clear_test");
        AssertTrue(retrieved.Count == 2, "table should have 2 entries before clear");

        _dialogue.ClearTranslationTable("clear_test");
        retrieved = _dialogue.GetTranslationTable("clear_test");
        AssertTrue(retrieved.Count == 0, $"table should be empty after clear, got {retrieved.Count}");
    }

    private void TestMultipleLocalesIndependent()
    {
        var frTable = new Godot.Collections.Dictionary
        {
            { "greeting", "Bonjour" }
        };
        var jaTable = new Godot.Collections.Dictionary
        {
            { "greeting", "こんにちは" }
        };
        var esTable = new Godot.Collections.Dictionary
        {
            { "greeting", "Hola" }
        };

        _dialogue.SetTranslationTable("fr", frTable);
        _dialogue.SetTranslationTable("ja", jaTable);
        _dialogue.SetTranslationTable("es", esTable);

        var frRetrieved = _dialogue.GetTranslationTable("fr");
        var jaRetrieved = _dialogue.GetTranslationTable("ja");
        var esRetrieved = _dialogue.GetTranslationTable("es");

        AssertTrue((string)frRetrieved["greeting"] == "Bonjour",
            $"fr greeting mismatch: got '{frRetrieved["greeting"]}'");
        AssertTrue((string)jaRetrieved["greeting"] == "こんにちは",
            $"ja greeting mismatch: got '{jaRetrieved["greeting"]}'");
        AssertTrue((string)esRetrieved["greeting"] == "Hola",
            $"es greeting mismatch: got '{esRetrieved["greeting"]}'");

        // Clean up
        _dialogue.ClearTranslationTable("fr");
        _dialogue.ClearTranslationTable("ja");
        _dialogue.ClearTranslationTable("es");
    }

    private async System.Threading.Tasks.Task TestTranslationAppliedDuringPlayback()
    {
        var dialogueJson = GD.Load<Json>("res://test/mixed_commands_test_dialogue.json");
        var dialogueResource = CreateDialogueResource(dialogueJson);

        // Tokenize to find the token for "plain_text_test_single_line" node
        var entries = _dialogue.Tokenize(dialogueResource);
        string targetToken = null;
        foreach (var entry in entries)
        {
            if ((string)entry["node_name"] == "plain_text_test_single_line")
            {
                targetToken = (string)entry["token"];
                break;
            }
        }

        AssertTrue(targetToken != null, "should find token for plain_text_test_single_line");

        // Set up translation table with a translated value
        var table = new Godot.Collections.Dictionary
        {
            { targetToken, "ceci est un test sur une seule ligne." }
        };
        _dialogue.SetTranslationTable("fr", table);
        _dialogue.SetLocale("fr");

        // Play dialogue and verify translated output
        _tester.SetStates(new Godot.Collections.Dictionary());
        await _tester.StartTest(dialogueJson, "plain_text_test_single_line");
        _tester.AssertResponse("ceci est un test sur une seule ligne.", new List<string>(), true);

        // Reset locale
        _dialogue.SetLocale("");
        _dialogue.ClearTranslationTable("fr");
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
