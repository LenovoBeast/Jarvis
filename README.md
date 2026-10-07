# Jarvis

Everything you need to build a local, voice-enabled personal AI assistant — a setup guide, an
interactive setup script, and a UI design for the assistant itself.

**Read the guide online:** https://lenovobeast.github.io/Jarvis/

**Try the interface prototype:** https://lenovobeast.github.io/Jarvis/jarvis-ui-prototype.html

All the HTML is self-contained. No build step, no dependencies, no local server. Open a file in a
browser and it works.

---

## What's in here

| File | What it is |
|---|---|
| [`index.html`](index.html) | The setup guide, as a website — [live](https://lenovobeast.github.io/Jarvis/) |
| [`setup-jarvis.sh`](setup-jarvis.sh) | Guided setup — macOS, Linux, Git Bash |
| [`setup-jarvis.ps1`](setup-jarvis.ps1) | Guided setup — Windows PowerShell |
| [`jarvis-ui-prototype.html`](jarvis-ui-prototype.html) | Interactive prototype of the Jarvis interface — [live](https://lenovobeast.github.io/Jarvis/jarvis-ui-prototype.html) |

---

## Quick start

**Read the guide first** if you want to understand what's happening — either
[online](https://lenovobeast.github.io/Jarvis/) or by opening `index.html` in a browser. It has a
progress checklist that remembers where you got to.

**Or let the script do it.** It checks what you have installed, clones the agent repo you pick,
sets up a Python virtual environment, and scaffolds your config files.

No need to clone first — fetch the script directly:

```bash
# macOS / Linux / Git Bash
curl -fsSL https://raw.githubusercontent.com/LenovoBeast/Jarvis/main/setup-jarvis.sh -o setup-jarvis.sh
chmod +x setup-jarvis.sh
./setup-jarvis.sh
```

```powershell
# Windows
irm https://raw.githubusercontent.com/LenovoBeast/Jarvis/main/setup-jarvis.ps1 -OutFile setup-jarvis.ps1
powershell -ExecutionPolicy Bypass -File .\setup-jarvis.ps1
```

Already have the repo? Skip the download and run `./setup-jarvis.sh` (or `.\setup-jarvis.ps1`) from
the folder.

Both accept the same flags:

| Flag | What it does |
|---|---|
| `--check-only` / `-CheckOnly` | Report what's installed and stop. Changes nothing. |
| `--repo <url>` / `-Repo <url>` | Skip the picker and use this repo. |
| `--dir <path>` / `-Dir <path>` | Install location. Default `./jarvis`. |
| `--yes` / `-Yes` | Assume yes for confirmations. |
| `--help` | Show usage. |

### What the script does not do

It deliberately stops short of the two things only you can do:

- **It never asks for or stores your API keys.** It writes `.env` with clearly-labelled
  placeholders and tells you where to get the real values.
- **It never installs anything system-wide without asking.** Every step is a confirmation.

It also writes `.env` into the cloned repo's `.gitignore` so your keys can't be committed by
accident.

---

## The interface prototype

`jarvis-ui-prototype.html` is a working prototype of the assistant's UI, built around one idea:
**a single surface that grows with the task, anchored so it never moves.**

Instead of a full chat window, Jarvis has one panel fixed at the top edge that expands *only
downward*, as far as the task demands:

```
Resting (tray glyph) -> Ask (640x72) -> Answer (card) -> Act (rail + approval)
```

**Try it:** [open the prototype](https://lenovobeast.github.io/Jarvis/jarvis-ui-prototype.html)

| Input | What happens |
|---|---|
| `Ctrl`/`Cmd` + `K` | Summon the surface |
| `what's my day look like` | Answer flow — spoken strip, sources, actions |
| `clear my morning` | Act flow — live step rail, then an approval sheet |
| `Up` / `Down` | Walk command history |
| `Tab` | Accept the highlighted suggestion |
| `Esc` | Retreat exactly one level |

---

## Running locally

No tooling required:

```bash
start index.html      # Windows
open index.html       # macOS
xdg-open index.html   # Linux
```

Or serve the folder:

```bash
python -m http.server 8000
```

---

## Design notes

Both HTML files share one visual language — near-black surfaces, a cyan accent reserved
*exclusively* for state and interactive elements, and a monospace face for prompts and metadata.
The accent is never decorative: if something glows, it either has state or has a handler.

The interface is keyboard-first. Every voice action has a typed equivalent, status is carried by
icon shape and text rather than colour alone, and `prefers-reduced-motion` swaps every expansion
for a cross-fade.
