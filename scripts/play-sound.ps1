param([string]$Event = "done")

$disableFlag = Join-Path $env:USERPROFILE ".agenthoff\sound-disabled"
if (Test-Path $disableFlag) { exit 0 }

try {
    switch ($Event) {
        "done"    { [System.Media.SystemSounds]::Asterisk.Play() }
        "waiting" { [System.Media.SystemSounds]::Question.Play() }
        default   { [System.Media.SystemSounds]::Beep.Play() }
    }
    Start-Sleep -Milliseconds 600
} catch {
    exit 0
}
