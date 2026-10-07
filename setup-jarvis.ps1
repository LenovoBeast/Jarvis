<#
.SYNOPSIS
  Guided setup for a local, voice-enabled personal AI assistant. Windows version.

.DESCRIPTION
  What it does:
    1. Checks which tools you already have (git, python, node, npm, claude)
    2. Lets you pick which agent repo to install
    3. Clones it and sets up a Python virtual environment
    4. Scaffolds .env and jarvis.config.json for you to fill in

  What it will NOT do:
    - Ask for or store your passwords
    - Fill in your API keys (it writes placeholders and tells you where to get them)
    - Install anything system-wide without telling you first

.PARAMETER CheckOnly
  Report what is installed, then stop. Changes nothing.

.PARAMETER Repo
  Skip the picker and use this repo URL.

.PARAMETER Dir
  Install location. Default: .\jarvis

.PARAMETER Yes
  Assume yes for all confirmations.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\setup-jarvis.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\setup-jarvis.ps1 -CheckOnly
#>
[CmdletBinding()]
param(
  [switch]$CheckOnly,
  [switch]$Yes,
  [string]$Repo = "",
  [string]$Dir = ".\jarvis"
)

$ErrorActionPreference = "Stop"
$Version = "1.0.0"

# ---------------------------------------------------------------- output

function Say      { param([string]$m) Write-Host $m }
function Dim      { param([string]$m) Write-Host $m -ForegroundColor DarkGray }
function Step     { param([string]$m) Write-Host ""; Write-Host "==> $m" -ForegroundColor Cyan }
function Ok       { param([string]$m) Write-Host "  [ok]   $m" -ForegroundColor Green }
function Missing  { param([string]$m) Write-Host "  [miss] $m" -ForegroundColor Yellow }
function Bad      { param([string]$m) Write-Host "  [fail] $m" -ForegroundColor Red }
function Die      { param([string]$m) Write-Host ""; Write-Host "error: $m" -ForegroundColor Red; exit 1 }

function Confirm-Action {
  param([string]$question)
  if ($Yes) { return $true }
  $reply = Read-Host "  $question [y/N]"
  return ($reply -match '^(y|yes)$')
}

function Write-Utf8NoBom {
  param([string]$Path, [string]$Content)
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

# ---------------------------------------------------------------- banner

Write-Host ""
Write-Host "  Jarvis setup assistant  v$Version" -ForegroundColor White
Dim "  Turns your laptop into a local, voice-enabled AI assistant."

# ---------------------------------------------------------------- 1. detect

Step "1/5  Checking your machine"

$isWin = $true
Ok "platform: windows (powershell $($PSVersionTable.PSVersion))"

# ---------------------------------------------------------------- 2. prerequisites

function Test-Tool {
  param([string[]]$Cmd, [string]$Label, [string]$Hint)

  # Accept several candidate names (e.g. python / python3 / py) and use the
  # first one that actually resolves.
  $resolved = $null
  foreach ($candidate in $Cmd) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) { $resolved = $candidate; break }
  }
  if (-not $resolved) {
    Missing "$Label -- not found"
    Dim "         install: $Hint"
    return $false
  }
  $Cmd = $resolved

  # Being on PATH is not proof it works. Windows ships "app execution aliases"
  # that resolve but fail when run -- `python` is the usual culprit, printing
  # "Python was not found; ... Microsoft Store". Actually run it and check.
  # Redirecting a native command's stderr also throws when ErrorActionPreference
  # is "Stop", so relax it for the duration of the probe.
  $v = ""
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    # Capture ALL output before slicing. Piping straight into
    # Select-Object -First 1 can terminate the native process early, which
    # makes $LASTEXITCODE unreliable -- so do not test the exit code at all.
    $out = @(& $Cmd --version 2>&1)
    if ($out.Count -eq 0 -or [string]::IsNullOrWhiteSpace("$($out[0])")) {
      $out = @(& $Cmd -V 2>&1)
    }
    if ($out.Count -gt 0) { $v = "$($out[0])".Trim() }
  } catch {
    $v = ""
  } finally {
    $ErrorActionPreference = $prev
  }

  # Detect the stub by what it printed, not by how it exited.
  $broken = ($v -match "Microsoft Store") -or
            ($v -match "not found") -or
            ($v -match "NativeCommandError") -or
            [string]::IsNullOrWhiteSpace($v)

  if ($broken) {
    Missing "$Label -- found but not working (stub alias?)"
    Dim "         install: $Hint"
    return $false
  }

  if ($v.Length -gt 58) { $v = $v.Substring(0, 58) + "..." }
  Ok ("{0}  {1}" -f $Label, $v)
  return $true
}

$missingCount = 0

if (-not (Test-Tool @("git")                  "git"                  "winget install --id Git.Git"))            { $missingCount++ }
if (-not (Test-Tool @("python","python3","py") "python"              "winget install --id Python.Python.3.12")) { $missingCount++ }
if (-not (Test-Tool @("node")                 "node"                 "winget install --id OpenJS.NodeJS.LTS")) { $missingCount++ }
if (-not (Test-Tool @("npm")                  "npm"                  "(comes with node)"))                     { $missingCount++ }
if (-not (Test-Tool @("claude")               "claude (Claude Code)" "see https://claude.com/claude-code"))    { $missingCount++ }

Write-Host ""
if ($missingCount -gt 0) {
  Write-Host "  $missingCount tool(s) missing." -ForegroundColor Yellow
  Dim "  Claude Code can install these for you -- just ask it:"
  Dim '     "Install the missing tools this script reported."'
  Dim "  Or use the install commands above, then re-run this script."
} else {
  Write-Host "  Everything you need is installed." -ForegroundColor Green
}

if ($CheckOnly) {
  Write-Host ""
  Dim "  -CheckOnly: stopping here, nothing was changed."
  exit 0
}

# ---------------------------------------------------------------- 3. pick a repo

Step "3/5  Pick your agent"

if ($Repo -ne "") {
  Ok "using: $Repo"
} else {
  Write-Host ""
  Write-Host "   What do you want it to do?" -ForegroundColor White
  Write-Host ""
  Write-Host "     1)  Control my computer         OpenInterpreter"
  Write-Host "     2)  Orchestrate several models  Microsoft JARVIS / HuggingGPT"
  Write-Host "     3)  Stay 100% local and private LocalGPT"
  Write-Host "     4)  Be voice-first from day one Leon"
  Write-Host "     5)  Something else              paste your own repo URL"
  Write-Host ""

  $choice = Read-Host "  Choose [1-5]"
  switch ($choice) {
    "1" { $Repo = "https://github.com/OpenInterpreter/open-interpreter" }
    "2" { $Repo = "https://github.com/microsoft/JARVIS" }
    "3" { $Repo = "https://github.com/PromtEngineer/localGPT" }
    "4" { $Repo = "https://github.com/leon-ai/leon" }
    "5" { $Repo = Read-Host "  Repo URL" }
    default { Die "not a valid choice: $choice" }
  }
  if ([string]::IsNullOrWhiteSpace($Repo)) { Die "no repo URL given" }
}

$repoName = ($Repo -split '/')[-1] -replace '\.git$', ''
Ok "repo: $repoName"

# ---------------------------------------------------------------- 4. clone + env

Step "4/5  Installing into $Dir"

$doUpdate = $false
if (Test-Path $Dir) {
  if (Test-Path (Join-Path $Dir ".git")) {
    Ok "already a git repo -- will update instead of cloning"
    $doUpdate = $true
  } else {
    Die "$Dir exists and is not a git repo. Move it or pass -Dir."
  }
}

if ($doUpdate) {
  if (Confirm-Action "Pull the latest changes into $Dir?") {
    git -C $Dir pull --ff-only
    if ($LASTEXITCODE -eq 0) { Ok "updated" } else { Bad "git pull failed" }
  } else {
    Dim "  skipped update"
  }
} else {
  Write-Host ""
  Dim "  Cloning $Repo"
  Dim "  into    $Dir"
  if (Confirm-Action "Proceed?") {
    git clone $Repo $Dir
    if ($LASTEXITCODE -ne 0) { Die "clone failed -- check the URL and your network" }
    Ok "cloned"
  } else {
    Die "aborted"
  }
}

$reqFile = Join-Path $Dir "requirements.txt"
$pkgFile = Join-Path $Dir "pyproject.toml"
$npmFile = Join-Path $Dir "package.json"
$venvPy  = Join-Path $Dir ".venv\Scripts\python.exe"
$venvPip = Join-Path $Dir ".venv\Scripts\pip.exe"

if ((Test-Path $reqFile) -or (Test-Path $pkgFile)) {
  Write-Host ""
  if (Confirm-Action "Create a Python virtual environment and install dependencies?") {
    Push-Location $Dir
    try {
      python -m venv .venv
      & $venvPip install --quiet --upgrade pip
      if (Test-Path "requirements.txt") {
        & $venvPip install -r requirements.txt
      } else {
        & $venvPip install -e .
      }
      if ($LASTEXITCODE -eq 0) { Ok "python environment ready (.venv)" }
      else { Bad "dependency install failed -- ask Claude Code to fix it" }
    } catch {
      Bad "python setup failed: $($_.Exception.Message)"
    } finally {
      Pop-Location
    }
  } else {
    Dim "  skipped"
  }
} else {
  Dim "  no Python manifest found -- skipping venv"
}

if (Test-Path $npmFile) {
  Write-Host ""
  if (Confirm-Action "Install Node dependencies (npm install)?") {
    Push-Location $Dir
    try {
      npm install --silent
      if ($LASTEXITCODE -eq 0) { Ok "node_modules ready" } else { Bad "npm install failed" }
    } finally {
      Pop-Location
    }
  } else {
    Dim "  skipped"
  }
}

# ---------------------------------------------------------------- 5. config

Step "5/5  Creating your config"

$envPath = Join-Path $Dir ".env"
if (Test-Path $envPath) {
  Dim "  .env already exists -- leaving it alone"
} else {
  $envBody = @'
# ---------------------------------------------------------------
# Jarvis environment.  DO NOT COMMIT THIS FILE.
#
# ElevenLabs (free tier is enough to start):
#   1. Log in at https://elevenlabs.io
#   2. Profile icon (top right) -> Profile + API key -> copy
#   3. Paste it below, replacing the placeholder
# ---------------------------------------------------------------

ELEVENLABS_API_KEY=PASTE_YOUR_KEY_HERE

# The voice to speak with.
#   VoiceLab / Voices -> pick one -> copy its Voice ID
ELEVENLABS_VOICE_ID=PASTE_YOUR_VOICE_ID_HERE
'@
  Write-Utf8NoBom -Path $envPath -Content $envBody
  Ok "wrote $envPath  (placeholders -- fill these in yourself)"
}

$cfgPath = Join-Path $Dir "jarvis.config.json"
if (Test-Path $cfgPath) {
  Dim "  jarvis.config.json already exists -- leaving it alone"
} else {
  $cfgBody = @'
{
  "name": "Jarvis",
  "personality": "Dry, precise, and slightly sarcastic. Never use exclamation marks.",
  "startupPhrase": "Good morning. I've been waiting.",
  "speakResponses": true,
  "boundaries": [
    "Never send an email without asking me first.",
    "Always confirm before deleting a file."
  ]
}
'@
  Write-Utf8NoBom -Path $cfgPath -Content $cfgBody
  Ok "wrote $cfgPath"
}

$gitignorePath = Join-Path $Dir ".gitignore"
if (Test-Path $gitignorePath) {
  $gi = Get-Content $gitignorePath -Raw
  if ($gi -notmatch '(?m)^\.env$') {
    Add-Content -Path $gitignorePath -Value "`r`n.env`r`n.venv/"
    Ok "added .env to $gitignorePath"
  }
} else {
  Write-Utf8NoBom -Path $gitignorePath -Content ".env`r`n.venv/`r`n"
  Ok "created $gitignorePath"
}

# ---------------------------------------------------------------- next steps

Write-Host ""
Write-Host "  Setup complete." -ForegroundColor Green
Write-Host ""
Write-Host "  Two things left, and only you can do them:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Add your voice key" -ForegroundColor White
Write-Host "     Open $Dir\.env and replace the two placeholders."
Write-Host "     Get them from https://elevenlabs.io  (free tier is fine)"
Write-Host ""
Write-Host "  2. Let it see your tools" -ForegroundColor White
Write-Host "     Open Claude Code in $Dir and ask, in plain English:"
Write-Host ""
Write-Host '        "Connect the agent to my Google Calendar. When I say'
Write-Host "         'what's my day look like', read my events out loud.\""
Write-Host ""
Write-Host "     Claude handles the OAuth flow and stores the credentials locally."
Write-Host ""
Write-Host "  Then test it:" -ForegroundColor White
Write-Host ""
Write-Host "        cd $Dir"
Write-Host "        .\.venv\Scripts\Activate.ps1    # if it uses Python"
Write-Host "        # then start the agent however its README says"
Write-Host ""
Dim "  Full guide: the index.html that came with this script."
Dim "  Stuck? Open Claude Code in $Dir and describe the error."
Write-Host ""
