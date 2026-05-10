using Godot;
using System.Collections.Generic;

namespace EzDialogue;

/// <summary>
/// C# representation of a dialogue response.
/// Contains the display text, available choices, and end-of-dialogue flag.
/// </summary>
[GlobalClass]
public partial class DialogueResponseSharp : GodotObject
{
    /// <summary>
    /// The dialogue text to display to the player.
    /// Multi-line text is joined with newlines.
    /// </summary>
    public string Text { get; set; } = "";

    /// <summary>
    /// Available player choices. Empty if no choices are presented.
    /// </summary>
    public List<string> Choices { get; set; } = new();

    /// <summary>
    /// True if this is the final response — no more dialogue follows.
    /// </summary>
    public bool EodReached { get; set; } = false;

    /// <summary>
    /// Whether this response has any content (text or choices).
    /// </summary>
    public bool IsEmpty => string.IsNullOrEmpty(Text) && Choices.Count == 0;
}
