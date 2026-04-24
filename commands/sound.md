---
description: Toggle agenthoff sound notifications (task-done and waiting-for-input) on/off
argument-hint: "[on|off|status]"
allowed-tools: Bash
---

Manage the agenthoff sound notification toggle. The sentinel file `~/.agenthoff/sound-disabled` controls state: present = muted, absent = on (default).

Interpret `$ARGUMENTS`:
- `on` → ensure sentinel is absent (remove if present)
- `off` → ensure sentinel is present (create it)
- `status` or empty → just report current state

Use this PowerShell one-liner via Bash (`powershell -NoProfile -Command "..."`) to perform the action, then report the resulting state clearly:

```powershell
$flag = Join-Path $env:USERPROFILE '.agenthoff\sound-disabled'
$dir  = Split-Path $flag
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

switch ('$ARGUMENTS') {
  'on'     { if (Test-Path $flag) { Remove-Item $flag }; 'ON' }
  'off'    { New-Item -ItemType File -Path $flag -Force | Out-Null; 'OFF' }
  default  { if (Test-Path $flag) { 'OFF' } else { 'ON' } }
}
```

Report the new state to the user in one short line, e.g. `agenthoff sounds: ON`.
