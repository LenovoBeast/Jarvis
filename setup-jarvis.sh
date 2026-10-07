#!/usr/bin/env bash
#
# setup-jarvis.sh -- guided setup for a local, voice-enabled personal AI assistant.
#
# What it does:
#   1. Checks which tools you already have (git, python3, node, npm, claude)
#   2. Lets you pick which agent repo to install
#   3. Clones it and sets up a Python virtual environment
#   4. Scaffolds .env and jarvis.config.json for you to fill in
#
# What it will NOT do:
#   - Ask for or store your passwords
#   - Fill in your API keys (it writes placeholders and tells you where to get them)
#   - Install anything system-wide without telling you first
#
# Usage:
#   ./setup-jarvis.sh                  interactive setup
#   ./setup-jarvis.sh --check-only     report what is installed, change nothing
#   ./setup-jarvis.sh --repo <url>     skip the picker
#   ./setup-jarvis.sh --dir <path>     install location (default: ./jarvis)
#   ./setup-jarvis.sh --yes            assume yes for confirmations
#   ./setup-jarvis.sh --help
#
set -euo pipefail

VERSION="1.0.0"

# ---------------------------------------------------------------- output

if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
  C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'
else
  C_RESET=""; C_DIM=""; C_BOLD=""; C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi

say()  { printf '%s\n' "$*"; }
dim()  { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
step() { printf '\n%s==>%s %s%s%s\n' "$C_CYAN" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
ok()   { printf '  %s[ok]%s   %s\n' "$C_GREEN" "$C_RESET" "$*"; }
miss() { printf '  %s[miss]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
bad()  { printf '  %s[fail]%s %s\n' "$C_RED" "$C_RESET" "$*"; }
die()  { printf '\n%serror:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

# ---------------------------------------------------------------- args

CHECK_ONLY=0
ASSUME_YES=0
REPO_URL=""
INSTALL_DIR="./jarvis"

while [ $# -gt 0 ]; do
  case "$1" in
    --check-only) CHECK_ONLY=1 ;;
    --yes|-y)     ASSUME_YES=1 ;;
    --repo)       REPO_URL="${2:-}"; shift ;;
    --dir)        INSTALL_DIR="${2:-}"; shift ;;
    --help|-h)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

confirm() {
  [ "$ASSUME_YES" = "1" ] && return 0
  printf '  %s [y/N] ' "$1"
  read -r reply </dev/tty || return 1
  case "$reply" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# ---------------------------------------------------------------- banner

printf '\n%s  Jarvis setup assistant  v%s%s\n' "$C_BOLD" "$VERSION" "$C_RESET"
dim  "  Turns your laptop into a local, voice-enabled AI assistant."

# ---------------------------------------------------------------- 1. detect OS

step "1/5  Checking your machine"

OS="unknown"; PKG=""
case "$(uname -s)" in
  Darwin) OS="macos"; PKG="brew install" ;;
  Linux)
    OS="linux"
    if   command -v apt-get >/dev/null 2>&1; then PKG="sudo apt install"
    elif command -v dnf     >/dev/null 2>&1; then PKG="sudo dnf install"
    elif command -v pacman  >/dev/null 2>&1; then PKG="sudo pacman -S"
    fi ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows-gitbash"; PKG="winget install" ;;
esac
ok "platform: $OS"

# ---------------------------------------------------------------- 2. prerequisites

have() { command -v "$1" >/dev/null 2>&1; }

MISSING=0

check() {
  local cmd="$1" label="$2" hint="$3"
  if have "$cmd"; then
    local v; v="$("$cmd" --version 2>&1 | head -1 | tr -d '\r')"
    ok "$label  ${C_DIM}$v${C_RESET}"
  else
    miss "$label -- not found"
    dim  "         install: $hint"
    MISSING=$((MISSING + 1))
  fi
}

check git    "git"    "${PKG:-install} git"
check python3 "python3" "${PKG:-install} python3"
check node   "node"   "${PKG:-install} nodejs"
check npm    "npm"    "(comes with node)"
check claude "claude (Claude Code)" "see https://claude.com/claude-code"

printf '\n'
if [ "$MISSING" -gt 0 ]; then
  printf '  %s%d tool(s) missing.%s\n' "$C_YELLOW" "$MISSING" "$C_RESET"
  dim  "  Claude Code can install these for you -- just ask it:"
  dim  '     "Install the missing tools this script reported."'
  dim  "  Or use the install commands above, then re-run this script."
else
  printf '  %sEverything you need is installed.%s\n' "$C_GREEN" "$C_RESET"
fi

if [ "$CHECK_ONLY" = "1" ]; then
  say ""
  dim "  --check-only: stopping here, nothing was changed."
  exit 0
fi

# ---------------------------------------------------------------- 3. pick a repo

step "3/5  Pick your agent"

if [ -n "$REPO_URL" ]; then
  ok "using: $REPO_URL"
else
  cat <<'MENU'

   What do you want it to do?

     1)  Control my computer        OpenInterpreter
     2)  Orchestrate several models  Microsoft JARVIS / HuggingGPT
     3)  Stay 100% local and private LocalGPT
     4)  Be voice-first from day one Leon
     5)  Something else              paste your own repo URL

MENU
  printf '  Choose [1-5]: '
  read -r choice </dev/tty || die "could not read your choice"

  case "$choice" in
    1) REPO_URL="https://github.com/OpenInterpreter/open-interpreter" ;;
    2) REPO_URL="https://github.com/microsoft/JARVIS" ;;
    3) REPO_URL="https://github.com/PromtEngineer/localGPT" ;;
    4) REPO_URL="https://github.com/leon-ai/leon" ;;
    5) printf '  Repo URL: '; read -r REPO_URL </dev/tty ;;
    *) die "not a valid choice: $choice" ;;
  esac
  [ -n "$REPO_URL" ] || die "no repo URL given"
fi

REPO_NAME="$(basename "$REPO_URL" .git)"
ok "repo: $REPO_NAME"

# ---------------------------------------------------------------- 4. clone + env

step "4/5  Installing into $INSTALL_DIR"

if [ -e "$INSTALL_DIR" ]; then
  if [ -d "$INSTALL_DIR/.git" ]; then
    ok "already a git repo -- will update instead of cloning"
    DO_UPDATE=1
  else
    die "$INSTALL_DIR exists and is not a git repo. Move it or pick --dir."
  fi
else
  DO_UPDATE=0
fi

if [ "$DO_UPDATE" = "1" ]; then
  if confirm "Pull the latest changes into $INSTALL_DIR?"; then
    git -C "$INSTALL_DIR" pull --ff-only && ok "updated"
  else
    dim "  skipped update"
  fi
else
  say ""
  dim "  Cloning $REPO_URL"
  dim "  into    $INSTALL_DIR"
  if confirm "Proceed?"; then
    git clone "$REPO_URL" "$INSTALL_DIR" || die "clone failed -- check the URL and your network"
    ok "cloned"
  else
    die "aborted"
  fi
fi

# Python venv, only if this looks like a Python project
if [ -f "$INSTALL_DIR/requirements.txt" ] || [ -f "$INSTALL_DIR/pyproject.toml" ]; then
  say ""
  if confirm "Create a Python virtual environment and install dependencies?"; then
    ( cd "$INSTALL_DIR" \
      && python3 -m venv .venv \
      && ./.venv/bin/pip install --quiet --upgrade pip \
      && { [ -f requirements.txt ] && ./.venv/bin/pip install -r requirements.txt || ./.venv/bin/pip install -e . ; } ) \
      && ok "python environment ready (.venv)" \
      || bad "dependency install failed -- ask Claude Code to fix it"
  else
    dim "  skipped"
  fi
else
  dim "  no Python manifest found -- skipping venv"
fi

# Node deps
if [ -f "$INSTALL_DIR/package.json" ]; then
  say ""
  if confirm "Install Node dependencies (npm install)?"; then
    ( cd "$INSTALL_DIR" && npm install --silent ) && ok "node_modules ready" || bad "npm install failed"
  else
    dim "  skipped"
  fi
fi

# ---------------------------------------------------------------- 5. config

step "5/5  Creating your config"

if [ -f "$INSTALL_DIR/.env" ]; then
  dim "  .env already exists -- leaving it alone"
else
  cat > "$INSTALL_DIR/.env" <<'ENVEOF'
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
ENVEOF
  ok "wrote $INSTALL_DIR/.env  (placeholders -- fill these in yourself)"
fi

if [ -f "$INSTALL_DIR/jarvis.config.json" ]; then
  dim "  jarvis.config.json already exists -- leaving it alone"
else
  cat > "$INSTALL_DIR/jarvis.config.json" <<'CFGEOF'
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
CFGEOF
  ok "wrote $INSTALL_DIR/jarvis.config.json"
fi

# Make sure secrets never get committed
if [ -f "$INSTALL_DIR/.gitignore" ]; then
  if ! grep -q '^\.env$' "$INSTALL_DIR/.gitignore" 2>/dev/null; then
    printf '\n.env\n.venv/\n' >> "$INSTALL_DIR/.gitignore"
    ok "added .env to $INSTALL_DIR/.gitignore"
  fi
else
  printf '.env\n.venv/\n' > "$INSTALL_DIR/.gitignore"
  ok "created $INSTALL_DIR/.gitignore"
fi

# ---------------------------------------------------------------- next steps

cat <<EOF

${C_BOLD}${C_GREEN}  Setup complete.${C_RESET}

  ${C_BOLD}Two things left, and only you can do them:${C_RESET}

  ${C_BOLD}1. Add your voice key${C_RESET}
     Open ${C_CYAN}$INSTALL_DIR/.env${C_RESET} and replace the two placeholders.
     Get them from https://elevenlabs.io  (free tier is fine)

  ${C_BOLD}2. Let it see your tools${C_RESET}
     Open Claude Code in ${C_CYAN}$INSTALL_DIR${C_RESET} and ask, in plain English:

        "Connect the agent to my Google Calendar. When I say
         'what's my day look like', read my events out loud."

     Claude handles the OAuth flow and stores the credentials locally.

  ${C_BOLD}Then test it:${C_RESET}

        cd $INSTALL_DIR
        source .venv/bin/activate     # if it uses Python
        # then start the agent however its README says

  ${C_DIM}Full guide: the index.html that came with this script.${C_RESET}
  ${C_DIM}Stuck? Open Claude Code in $INSTALL_DIR and describe the error.${C_RESET}

EOF
