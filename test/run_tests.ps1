$godot   = "C:\Program Files (x86)\Godot\dotnet\Godot_v4.6.1-stable_mono_win64.exe"
$project = $PSScriptRoot | Split-Path -Parent
$out     = [System.IO.Path]::GetTempFileName()
$err     = [System.IO.Path]::GetTempFileName()

Start-Process `
    -FilePath $godot `
    -ArgumentList @("--headless", "--path", $project, "-s", "res://test/RunTests.gd") `
    -Wait -NoNewWindow `
    -RedirectStandardOutput $out `
    -RedirectStandardError  $err

# ── Colorized stdout ──────────────────────────────────────────────────────────
foreach ($line in Get-Content $out) {
    if     ($line -match "^\[ PASS \]")  { Write-Host $line -ForegroundColor Green  }
    elseif ($line -match "^\[ FAIL \]")  { Write-Host $line -ForegroundColor Red    }
    elseif ($line -match "^\[ RUN  \]")  { Write-Host $line -ForegroundColor Cyan   }
    elseif ($line -match "^={3,}")       { Write-Host $line -ForegroundColor DarkGray }
    elseif ($line -match "Results:")     {
        if ($line -match "0 failed") {
            Write-Host $line -ForegroundColor Green
        } else {
            Write-Host $line -ForegroundColor Red
        }
    }
    elseif ($line -match "Godot Engine") { Write-Host $line -ForegroundColor DarkGray }
    else                                 { Write-Host $line -ForegroundColor Gray     }
}

# ── Colorized stderr (errors and warnings only) ───────────────────────────────
foreach ($line in Get-Content $err) {
    if     ($line -match "^SCRIPT ERROR|^ERROR") { Write-Host $line -ForegroundColor Red    }
    elseif ($line -match "^Error in ")           { Write-Host $line -ForegroundColor Yellow }
    elseif ($line -match "^\s+at:|backtrace")    { Write-Host $line -ForegroundColor DarkGray }
    elseif ($line.Trim() -ne "")                 { Write-Host $line -ForegroundColor Yellow }
}

# ── Exit code ─────────────────────────────────────────────────────────────────
$passed = (Get-Content $out) -match "0 failed"
$code   = if ($passed) { 0 } else { 1 }

Remove-Item $out, $err -ErrorAction SilentlyContinue
exit $code
