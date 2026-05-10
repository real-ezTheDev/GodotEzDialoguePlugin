# EzDialogue Syntax Highlighting for VS Code / Kiro

Provides syntax highlighting for `.ezd` dialogue files in VS Code, Kiro, or any VS Code-based editor.

## What You Get

- Node headers (`[node: name]`) highlighted as keywords
- `$if` / `$elif` / `$else` colored as control flow
- `->` goto and `?>` prompt operators
- `signal(...)` keyword and parameter highlighting
- `${variable}` injection highlighting
- `---` page break markers
- Escape characters (`\`)
- Bracket matching and auto-close for `{}`
- Folding by node headers

## Installation

The extension is a folder — no marketplace publish or `.vsix` build needed. You just need to place (or link) the `vscode-ezd` folder into your editor's extensions directory.

### Where is the extensions directory?

| Editor | Platform | Path |
|--------|----------|------|
| VS Code | Windows | `%USERPROFILE%\.vscode\extensions\` |
| VS Code | macOS | `~/.vscode/extensions/` |
| VS Code | Linux | `~/.vscode/extensions/` |
| Kiro | Windows | `%USERPROFILE%\.kiro\extensions\` |
| Kiro | macOS | `~/.kiro/extensions/` |
| Kiro | Linux | `~/.kiro/extensions/` |
| VS Code Insiders | Windows | `%USERPROFILE%\.vscode-insiders\extensions\` |
| Cursor | Windows | `%USERPROFILE%\.cursor\extensions\` |

### Option 1: Symlink (recommended for development)

Creates a link so changes to the grammar take effect on reload without re-copying.

**Windows (PowerShell as Admin):**
```powershell
New-Item -ItemType Junction -Path "$env:USERPROFILE\.vscode\extensions\ezdialogue-syntax" -Target "<path-to-project>\vscode-ezd"
```

**macOS / Linux:**
```bash
ln -s <path-to-project>/vscode-ezd ~/.vscode/extensions/ezdialogue-syntax
```

Replace `<path-to-project>` with the actual path to your EzDialoguePlugin folder. For Kiro, replace `.vscode` with `.kiro`.

### Option 2: Copy the folder

Copy the entire `vscode-ezd` folder into your extensions directory and rename it:

**Windows:**
```powershell
Copy-Item -Recurse "<path-to-project>\vscode-ezd" "$env:USERPROFILE\.vscode\extensions\ezdialogue-syntax"
```

**macOS / Linux:**
```bash
cp -r <path-to-project>/vscode-ezd ~/.vscode/extensions/ezdialogue-syntax
```

### Option 3: Workspace-only (no global install)

If you only want highlighting in this specific project, add this to your `.vscode/settings.json`:

```json
{
    "files.associations": {
        "*.ezd": "ezdialogue"
    }
}
```

Then create `.vscode/extensions.json` pointing to the local extension:
```json
{
    "recommendations": []
}
```

Note: workspace-only grammar injection requires the extension to be installed globally. Use Option 1 or 2 for the grammar to actually load.

## After Installation

1. Reload your editor (Ctrl+Shift+P → "Developer: Reload Window")
2. Open any `.ezd` file
3. The language mode in the bottom-right status bar should show **EzDialogue**

If it doesn't auto-detect, click the language mode and search for "EzDialogue".

## Uninstall

Delete the symlink or copied folder:

**Windows:**
```powershell
Remove-Item "$env:USERPROFILE\.vscode\extensions\ezdialogue-syntax"
```

**macOS / Linux:**
```bash
rm ~/.vscode/extensions/ezdialogue-syntax
```

## File Structure

```
vscode-ezd/
├── package.json                  ← Extension manifest
├── language-configuration.json   ← Bracket matching, folding rules
├── syntaxes/
│   └── ezd.tmLanguage.json      ← TextMate grammar (the highlighting rules)
└── README.md                     ← This file
```

## Customizing Colors

The grammar uses standard TextMate scopes. You can customize colors in your editor's `settings.json`:

```json
{
    "editor.tokenColorCustomizations": {
        "textMateRules": [
            { "scope": "keyword.control.node.ezd", "settings": { "foreground": "#569CD6" } },
            { "scope": "entity.name.function.node-name.ezd", "settings": { "foreground": "#DCDCAA" } },
            { "scope": "keyword.operator.goto.ezd", "settings": { "foreground": "#C586C0" } },
            { "scope": "constant.other.node-reference.ezd", "settings": { "foreground": "#CE9178" } },
            { "scope": "variable.other.injection.ezd", "settings": { "foreground": "#9CDCFE" } },
            { "scope": "keyword.other.signal.ezd", "settings": { "foreground": "#C586C0" } }
        ]
    }
}
```
