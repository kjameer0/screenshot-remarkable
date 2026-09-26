---
name: drawing-session
description: Run a live feedback session on whatever the user is drawing or writing on their reMarkable tablet (shared to the Mac via the reMarkable app's "Screen Share" window). `start` preflights the capture script and confirms the session is ready; while a session is on, every user turn that refers to the drawing triggers a fresh screenshot that is read before replying. Use when the user wants feedback on handwritten math/notes/sketches in progress, says "look at my tablet", "check my work", "how's this", "start a drawing session", or asks for feedback on a shared screen. Subcommands - start, look, end, status.
---

# drawing-session

Conversational feedback on work-in-progress handwriting. The user draws on a
reMarkable 2; the tablet's screen is shared to the Mac; this skill grabs a fresh
frame of that window whenever the conversation needs one, so replies are always
about what is on the page *now*.

Complements `/image`: that skill handles images the user hands you. This one
**goes and gets** the image itself, on a schedule set by the conversation.

## Paths

| What | Where |
|---|---|
| Capture script | `~/screenshot-remarkable/remarkable-capture.sh` |
| Frames | `~/remarkable-frames/` (newest always `latest.png`) |
| Session marker | `$CLAUDE_JOB_DIR/drawing-session.on`, else `/tmp/drawing-session-<pid>.on` |

The marker is a directory holding `last-hash` (md5 of the last frame actually
read) and `frames` (paths read this session, one per line).

If the capture script is missing, locate it once with
`ls ~/screenshot-remarkable/remarkable-capture.sh 2>/dev/null || find ~ -maxdepth 3 -name remarkable-capture.sh 2>/dev/null | head -1`.
If it still isn't found, say so and stop — do not fall back to `screencapture`
by hand, since window-ID resolution is the whole point.

## Dispatch

`/drawing-session <subcommand>`

| Subcommand | File | Purpose |
|---|---|---|
| `start` | `subcommands/start.md` | Preflight the capture path, confirm the session is ready, then hold the contract |
| `look` | `subcommands/look.md` | Grab one fresh frame now and respond to it |
| `end` | `subcommands/end.md` | Drop the marker, optionally summarize and tidy frames |
| `status` | — | Report marker state, whether the Screen Share window is currently findable, and frame count |

Bare `/drawing-session` means `start`. If the user describes the intent in their
own words ("look at my tablet", "check what I just wrote"), run `look` — or
`start` first if no marker exists — without asking which subcommand they meant.

## Grabbing a frame (the one operation)

```sh
~/screenshot-remarkable/remarkable-capture.sh -1
```

One-shot: prints the absolute path of the frame it wrote, exits non-zero if the
window can't be captured. **Never pass `-c`.** The clipboard belongs to the user;
frames are read from disk. Read the printed path with the Read tool.

### Skip unchanged frames

Before reading a frame, compare it to the last one read:

```sh
md5 -q <new frame>
```

If it matches `last-hash` in the marker directory, **do not read the image.** Say
the page hasn't changed since the last look and ask what they'd like — or, if they
asked a question that the previous frame already answers, just answer it. This
keeps a session of twenty turns from spending twenty images on one static page.
On a genuine change, read the frame and overwrite `last-hash`.

### Read the newest frame only

Each turn reads exactly one image: the frame just captured. Never re-read earlier
frames to "compare" unless the user explicitly asks about an earlier state — the
page is cumulative, so the newest frame already contains the older content.

## Vision-token policy

Unlike `/image`, the parent **reads the frame directly** here rather than routing
through `image-reader`. Feedback on partial, ambiguous handwriting is the deliverable,
and a transcription-then-reason hop loses the spatial information (crossed-out work,
arrows, where a step went wrong) that the feedback depends on.

Two escape hatches, for when that trade is wrong:
- User asks only for a transcription, or for many pages at once → delegate to
  `image-reader` as `/image` does.
- Session is running long and the user flags cost → offer to switch to
  `image-reader` for routine looks, reserving direct reads for "why is this wrong".

## Feedback conventions

- Lead with the single most useful sentence — the error, or the confirmation.
- Quote what you read back **only** when the handwriting is ambiguous or you might
  have misread a symbol, so a misread gets caught rather than silently answered.
- Work in progress is not work that is wrong: if the page stops mid-derivation,
  respond to the direction it's heading, don't treat a blank next step as an error.
- For math, verify against Wolfram via `wolfram-runner` before calling anything
  wrong — a confident wrong correction on the user's own page is the worst outcome.
- Don't grade unprompted. "Look at this" invites a reaction, not a score.

## Learning-plan integration

Same rule as `/image`: if the cwd is inside a `claude-learning-plan` module (a
`plan.yaml` in cwd or any parent up to `claude-workspace/`) **and** a session log
under `<module>/schedule/sessions/` has an unfilled marginal-gains table, append
one line per look under a `## Drawing artifacts` heading:

```
- 2026-09-26 19:16 — look — `frame-20260926-191629.png` — flagged sign error in step 3
```

Never touch the marginal-gains table itself.

## See also

- `remarkable-capture.sh --help` — all capture flags (interval, region, other apps).
- `/image` — for images the user hands you, and for `image-reader` delegation.
- `/wolfram` — math verification via `wolfram-runner`.
