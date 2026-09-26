# /drawing-session look

Grab one fresh frame right now and respond to it. Works with or without an active
session — this is the whole skill in one command if the user doesn't want a
persistent mode.

## Signature

`/drawing-session look [question]`

With a question, answer that question about the page. Without one, react to what
changed since the last look, or to the page as a whole on a first look.

## Steps

1. `~/screenshot-remarkable/remarkable-capture.sh -1` → prints the frame path.
   Non-zero exit → report why (window closed / share stopped) and stop.
2. `md5 -q <path>`. If a session marker exists and the hash matches `last-hash`:
   - If the user asked a question, answer from what you already know of the page —
     the previous frame is still current, so a re-read buys nothing.
   - If they just said "look", tell them nothing has changed yet.
3. Read the path with the Read tool. One image, the newest frame only.
4. Update `last-hash` and append to `frames` if a marker exists.
5. Reply per the feedback conventions in SKILL.md.

## Responding well

Anchor feedback to a location on the page — "the third line", "the substitution
into the denominator" — so the user knows where to look without hunting. Page
position is exactly what a transcription would have thrown away, so use it.

If a symbol is genuinely ambiguous (`z`/`2`, `x`/`×`, a smudged exponent), say
which reading you assumed before answering, rather than silently picking one.

On a page that is mid-derivation, react to the trajectory: whether the next step
they're set up for will work. That is more useful during a session than a verdict
on a half-finished line.

For anything you will call wrong in math, verify with `wolfram-runner` first.
