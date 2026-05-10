$godot   = "C:\Program Files (x86)\Godot\dotnet\Godot_v4.6.1-stable_mono_win64.exe"
$project = $PSScriptRoot | Split-Path -Parent

$suites = @(
    @{ Name = "Dialogue Tests";           Script = "res://test/RunTests.gd" },
    @{ Name = "Syntax Highlight Tests";   Script = "res://test/RunSyntaxHighlightTests.gd" }
)

$totalFailed = 0

foreach ($suite in $suites) {
    $out = [System.IO.Path]::GetTempFileName()
    $err = [System.IO.Path]::GetTempFileName()

    Write-Host ""
    Write-Host ("-" * 50) -ForegroundColor DarkGray
    Write-Host " $($suite.Name)" -ForegroundColor White
    Write-Host ("-" * 50) -ForegroundColor DarkGray

    Start-Process `
        -FilePath $godot `
        -ArgumentList @("--headless", "--path", $project, "-s", $suite.Script) `
        -Wait -NoNewWindow `
        -RedirectStandardOutput $out `
        -RedirectStandardError  $err

    # Colorized stdout
    foreach ($line in Get-Content $out) {
        if     ($line -match "^\[ PASS \]")  { Write-Host $line -ForegroundColor Green  }
        elseif ($line -match "^\[ FAIL \]")  { Write-Host $line -ForegroundColor Red    }
        elseif ($line -match "^\[ RUN  \]")  { Write-Host $line -ForegroundColor Cyan   }
        elseif ($line -match "^={3,}")       { Write-Host $line -ForegroundColor DarkGray }
        elseif ($line -match "Results:|Tests:") {
            if ($line -match "0 failed") {
                Write-Host $line -ForegroundColor Green
            } else {
                Write-Host $line -ForegroundColor Red
            }
        }
        elseif ($line -match "Godot Engine") { Write-Host $line -ForegroundColor DarkGray }
        else                                 { Write-Host $line -ForegroundColor Gray     }
    }

    # Colorized stderr
    foreach ($line in Get-Content $err) {
        if     ($line -match "^\[ FAIL \]")              { Write-Host $line -ForegroundColor Red    }
        elseif ($line -match "^SCRIPT ERROR|^ERROR")     { Write-Host $line -ForegroundColor Red    }
        elseif ($line -match "^Error in ")               { Write-Host $line -ForegroundColor Yellow }
        elseif ($line -match "^\s+at:|backtrace")        { Write-Host $line -ForegroundColor DarkGray }
        elseif ($line.Trim() -ne "")                     { Write-Host $line -ForegroundColor Yellow }
    }

    # Track failures
    if (-not ((Get-Content $out) -match "0 failed")) {
        $totalFailed++
    }

    Remove-Item $out, $err -ErrorAction SilentlyContinue
}

# Final summary
Write-Host ""
Write-Host ("=" * 50) -ForegroundColor DarkGray
if ($totalFailed -eq 0) {
    Write-Host " All $($suites.Count) test suites passed." -ForegroundColor Green
} else {
    Write-Host " $totalFailed of $($suites.Count) test suites had failures." -ForegroundColor Red
}
Write-Host ("=" * 50) -ForegroundColor DarkGray

exit $(if ($totalFailed -gt 0) { 1 } else { 0 })
