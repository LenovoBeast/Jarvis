# Jarvis

Two self-contained deliverables from the **Build Your Own Jarvis** reel — a setup guide, and a
UI design for the assistant it teaches you to build.

Everything here is plain HTML. No build step, no dependencies, no local server. Open either file
in a browser and it works.

---

## What's in here

| File | What it is |
|---|---|
| [`index.html`](index.html) | The setup guide, as a website |
| [`jarvis-ui-prototype.html`](jarvis-ui-prototype.html) | An interactive prototype of the Jarvis interface |

### `index.html` — the setup guide

A full walkthrough for turning a laptop into a local, voice-enabled personal AI assistant using
open-source repos and Claude Code. Covers prerequisites, picking a repo, adding an ElevenLabs
voice, connecting your own tools, building custom commands, and troubleshooting.

Features a sticky table of contents with scroll-spy, a reading-progress bar, copy-to-clipboard on
every prompt block, and an expandable troubleshooting section.

### `jarvis-ui-prototype.html` — the interface

A working prototype of the assistant's UI, built around one idea: **a single surface that grows
with the task, anchored so it never moves.**

Instead of a full chat window, Jarvis has one panel fixed at the top edge that expands *only
downward*, as far as the task demands:

```
Resting (tray glyph) → Ask (640×72) → Answer (card) → Act (rail + approval)
```

**Try it:**

| Input | What happens |
|---|---|
| `Ctrl`/`Cmd` + `K` | Summon the surface |
| `what's my day look like` | Answer flow — spoken strip, sources, actions |
| `clear my morning` | Act flow — live step rail, then an approval sheet |
| `↑` `↓` | Walk command history |
| `Tab` | Accept the highlighted suggestion |
| `Esc` | Retreat exactly one level |

The design reasoning — target user, layout zones, navigation model, feedback states, and the
options deliberately rejected — is documented in the project memory notes.

---

## Running it

No tooling required:

```bash
# just open the file
start index.html            # Windows
open index.html             # macOS
xdg-open index.html         # Linux
```

Or serve the folder if you prefer:

```bash
python -m http.server 8000
```

---

## Design notes

Both files share one visual language — near-black surfaces, a cyan accent reserved *exclusively*
for state and interactive elements, and a monospace face for prompts and metadata. The accent is
never decorative: if something glows, it either has state or has a handler.

The UI is keyboard-first. Every voice action has a typed equivalent, status is carried by icon
shape and text rather than color alone, and `prefers-reduced-motion` swaps every expansion for a
cross-fade.
