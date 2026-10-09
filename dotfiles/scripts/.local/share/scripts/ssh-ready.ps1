# ssh-ready.ps1 — get git working with your GitHub key at the start of every lesson.
#
# HOW TO USE (read the three steps once):
#
#   1. FIRST LESSON ONLY: right-click this file -> Edit, and set your details
#      in the "Your details" section below.
#
#   2. Make sure your private key is at the KEY_PATH you set (for example
#      U:\Documents\ssh\id_ed25519). You already pasted the matching PUBLIC
#      key into GitHub — that only needs to happen once.
#
#   3. EVERY LESSON, in PowerShell (or the VSCode terminal), type:
#
#          . .\ssh-ready.ps1
#
#      The dot-space matters! It keeps the SSH agent alive for the whole
#      lesson, so git never asks for a password again.
#
#   If you get "running scripts is disabled" errors, run this ONCE per machine:
#       Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#   (No admin rights needed. If you can't set it, the teacher must allow it.)
#
# If your key has a passphrase, you'll be asked for it once per lesson.

# ── Your details ───────────────────────────────────────────────
$KEY_PATH    = 'U:\Documents\ssh\id_ed25519'   # your private key on U:
$GIT_NAME    = ''                              # e.g. "Ada Lovelace" (optional)
$GIT_EMAIL   = ''                              # e.g. "ada@school.org" (optional)
$KNOWN_HOSTS = 'U:\Documents\ssh\known_hosts'
# ───────────────────────────────────────────────────────────────

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host 'Please SOURCE this script instead of running it:' -ForegroundColor Yellow
    Write-Host "    . $($MyInvocation.MyCommand.Path)"
    return
}

# Find Git's own bash: git and ssh must agree on which ssh-agent they talk to.
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    Write-Host 'Error: git not found. Install Git for Windows.' -ForegroundColor Red
    return
}
$gitRoot  = Split-Path (Split-Path $gitCmd.Source -Parent) -Parent
$bashPath = Join-Path $gitRoot 'bin\bash.exe'
if (-not (Test-Path $bashPath)) {
    $bashPath = Join-Path $gitRoot 'usr\bin\bash.exe'
}
if (-not (Test-Path $bashPath)) {
    Write-Host "Error: could not find Git's bash.exe under $gitRoot" -ForegroundColor Red
    return
}

if (-not (Test-Path $KEY_PATH)) {
    Write-Host "Error: no key found at $KEY_PATH" -ForegroundColor Red
    Write-Host "Fix the KEY_PATH line in the 'Your details' section of ssh-ready.ps1."
    return
}

if ($GIT_NAME)  { $env:GIT_AUTHOR_NAME = $GIT_NAME;  $env:GIT_COMMITTER_NAME = $GIT_NAME }
if ($GIT_EMAIL) { $env:GIT_AUTHOR_EMAIL = $GIT_EMAIL; $env:GIT_COMMITTER_EMAIL = $GIT_EMAIL }

# Start the agent (only if one isn't running) and load the key. This runs
# inside Git's bash, so the agent and git share the same ssh. The two
# SSH_* lines printed are captured back into this PowerShell session.
$agentOut = & $bashPath -lc '
    if ! ssh-add -l >/dev/null 2>&1; then eval "$(ssh-agent -s 2>/dev/null)"; fi
    ssh-add "$1" >/dev/null && printf "SSH_AUTH_SOCK=%s\nSSH_AGENT_PID=%s\n" "$SSH_AUTH_SOCK" "$SSH_AGENT_PID"
' bash $KEY_PATH 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host 'ssh-add failed:' -ForegroundColor Red
    $agentOut | ForEach-Object { Write-Host "  $_" }
    return
}

foreach ($line in $agentOut) {
    if ($line -match '^SSH_AUTH_SOCK=(.+)$') { $env:SSH_AUTH_SOCK = $Matches[1] }
    if ($line -match '^SSH_AGENT_PID=(.+)$') { $env:SSH_AGENT_PID = $Matches[1] }
}

# Remember GitHub's fingerprint, so git doesn't ask about it every lesson.
$env:GIT_SSH_COMMAND = "ssh -o UserKnownHostsFile=$KNOWN_HOSTS -o StrictHostKeyChecking=accept-new"

# Check GitHub recognises this key (uses Git's ssh so it reaches our agent).
$check = & $bashPath -lc 'ssh -o UserKnownHostsFile="$1" -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1' bash $KNOWN_HOSTS
if (($check -join ' ') -match 'successfully authenticated') {
    Write-Host ''
    Write-Host 'SSH ready — you can clone, pull and push.'
} else {
    Write-Host ''
    Write-Host 'Warning: could not confirm GitHub access.' -ForegroundColor Yellow
    Write-Host 'Check your public key is added under GitHub -> Settings -> SSH and GPG keys.'
    return
}
