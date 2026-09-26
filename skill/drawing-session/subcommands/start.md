# /drawing-session start

Confirm the whole capture path works *before* the user starts drawing, then hold the
session contract for the rest of the conversation.

The point of the preflight is that a drawing session fails at an annoying moment —
the user writes something, asks for feedback, and only then discovers the share
window was never open. Check first, once.

## Preflight

Run these together; they're independent:

```sh
ls ~/screenshot-remarkable/remarkable-capture.sh
~/screenshot-remarkable/remarkable-capture.sh --list
```

Check the window through `--list`, not by calling the `winid` binary directly:
the binary is gitignored and may not exist yet on a fresh clone, whereas the
script compiles it on demand. `--list` prints every capturable window, so a
missing Screen Share row is itself the diagnosis.

| Check | Pass | Fail → say this |
|---|---|---|
| Script exists | path prints | "Can't find the capture script" + the locate command from SKILL.md |
| Window findable | a `reMarkable  Screen Share` row appears | "The reMarkable Screen Share window isn't open — open the desktop app and start the screen share." Then stop; don't guess at a region capture. |
| Test frame | next step | — |

Then take one real frame and read it:

```sh
~/screenshot-remarkable/remarkable-capture.sh -1
```

Reading the test frame matters — it is the only way to catch a window that is
findable but showing the wrong thing (app's file browser instead of the canvas,
tablet asleep, share paused on a stale image).

If `winid` isn't built yet the script compiles it on first run and prints
`building window-id helper...`; that's normal, not an error. It needs `swiftc`
from the Xcode Command Line Tools.

## Confirm readiness

Create the marker directory, record the test frame's hash so the first real look
isn't reported as "unchanged", and report in one or two lines:

```sh
D="${CLAUDE_JOB_DIR:-/tmp}/drawing-session.on"; mkdir -p "$D"
md5 -q <test frame> > "$D/last-hash"
```

Report, concretely, not as a checklist:

> Drawing session ready — I can see your reMarkable page (currently: *one line on
> what's actually on it*). Draw, then say "look" or just ask me about it.

Naming what is already on the page proves the pipe works end to end. If the page
is blank, say it's blank — that's a pass, not a failure.

Then ask what they want out of the session **only if** it isn't already clear from
how they invoked it. "Check my algebra as I go" and "just tell me if my diagram
reads clearly" call for different responses, and knowing which avoids grading
someone who wanted a reaction.

---

## Session contract (parent behavior while the marker exists)

**Trigger — grab a fresh frame when the user's turn:**
- asks to look: "look", "check this", "how's this", "now?", "done";
- asks a question whose answer depends on the page: "is step 3 right", "what did I
  do wrong", "does this diagram make sense";
- refers to the drawing deictically: "this", "here", "that part" with no other
  referent in the conversation.

**Do not grab a frame when** the turn is plainly conversational ("thanks", "makes
sense", "what's the quadratic formula again") or is about the tooling itself
("change the interval", "stop the session"). A reflexive screenshot on every turn
is the main way this skill gets expensive.

**Each triggered turn:**
1. `remarkable-capture.sh -1` → path.
2. `md5 -q <path>`; if it equals `last-hash`, don't read the image — tell them the
   page is unchanged (see SKILL.md).
3. Otherwise Read the path, update `last-hash`, append the path to `frames`.
4. Respond per the feedback conventions in SKILL.md. Verify math via
   `wolfram-runner` before calling anything wrong.

**If capture fails mid-session** (non-zero exit: window closed, share stopped,
tablet disconnected): say which, and that the session is still on and will pick
back up when the window returns — the script re-resolves the window ID, so a
reopened share needs no restart. Don't tear the session down on one failure.

**Durability:** the contract holds for every subsequent turn until
`/drawing-session end`, even across unrelated topics in between.
