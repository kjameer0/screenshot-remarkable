# Agent instructions: reMarkable drawing feedback

This repo lets an agent **see what the user is drawing right now** on a reMarkable
tablet whose screen is shared to their Mac, and give feedback on work in progress.

Claude Code users get this as a skill (`skill/drawing-session/`, installed by
`./install.sh`). Any other harness should read this file instead — the contract is
the same, only the invocation differs.

**Requirements:** you need shell access and the ability to read image files. A
text-only model cannot do the feedback part; it can still run the script to save
frames for someone else to look at.

## The one operation

```sh
./remarkable-capture.sh -1
```

Prints the absolute path of a PNG it just wrote. Exits non-zero if the window
can't be captured. Read that path with your file-reading tool.

Everything else is policy about *when* to call it.

## Contract

**Preflight before the user starts drawing.** `./install.sh --check` verifies the
capture path; `./remarkable-capture.sh --list` shows whether the reMarkable
"Screen Share" window is actually open. Then take one frame and read it, and say
what is on the page. The failure this avoids is the user writing something, asking
for feedback, and only then discovering the share window was never open. Naming
what's already on the page proves the pipe works; a blank page is a pass.

**Grab a fresh frame when** the user asks you to look ("look", "check this",
"how's this", "now?"), asks something whose answer depends on the page ("is step 3
right", "what did I do wrong"), or points deictically ("this", "here") with no
other referent.

**Don't grab one when** the turn is conversational ("thanks", "makes sense") or
about the tooling ("change the interval", "stop"). A reflexive screenshot every
turn is the main way this gets expensive.

**Skip unchanged pages.** Before reading, `md5 -q <frame>` and compare to the last
frame you read. If identical, don't read the image — say the page hasn't changed,
or just answer from what you already know of it. Otherwise a twenty-turn session
spends twenty images on one static drawing.

**Read the newest frame only.** The page is cumulative, so the latest frame already
contains the earlier content. Don't re-read old frames to "compare" unless asked
about an earlier state.

**Never pass `-c`.** That flag copies the frame to the system clipboard. The
clipboard belongs to the user; read frames from disk. (It exists only for pasting
into a browser chat by hand.)

**Read the frame directly rather than transcribing it first,** if your harness lets
you choose. Feedback on partial handwriting depends on spatial information —
crossed-out work, arrows, which step went wrong — that a transcribe-then-reason hop
discards. Delegate to a cheaper vision model only for transcription-only requests
or when cost is flagged.

**On mid-session failure** (window closed, share stopped, tablet asleep): say which,
and that it will pick back up when the window returns. The script re-resolves the
window ID each call, so a reopened share needs no restart. Don't tear down on one
failure.

## Feedback conventions

- Lead with the single most useful sentence: the error, or the confirmation.
- Anchor feedback to a place on the page ("the third line", "the substitution in
  the denominator") so the user doesn't have to hunt.
- State your reading of genuinely ambiguous symbols (`z`/`2`, `x`/`×`, smudged
  exponents) before answering, so a misread gets caught instead of silently
  answered.
- Work in progress is not work that is wrong. If the page stops mid-derivation,
  react to where it's heading; a blank next step is not an error.
- Verify math with a computer algebra tool before calling anything wrong. A
  confident wrong correction on the user's own page is the worst outcome here.
- Don't grade unprompted. "Look at this" invites a reaction, not a score.

## Where things are

| | |
|---|---|
| `remarkable-capture.sh` | capture script; `--help` for all flags |
| `winid.swift` | resolves the CoreGraphics window ID (built on demand) |
| `skill/drawing-session/` | Claude Code skill: `SKILL.md` + `subcommands/` |
| `~/remarkable-frames/` | frames; newest always `latest.png` |
