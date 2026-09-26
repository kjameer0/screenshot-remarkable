# /drawing-session end

Close the session.

## Steps

1. Remove the marker directory (`${CLAUDE_JOB_DIR:-/tmp}/drawing-session.on`).
2. Reply `Drawing session off.` — plus, if the session produced substantive
   feedback, two or three lines on what came up. A session spent finding the same
   class of error three times is worth naming; otherwise skip the summary.
3. If a learning-plan session log is open, the `## Drawing artifacts` lines are
   already there from each look. Don't add a closing entry, and don't touch the
   marginal-gains table.

## Frames

Frames in `~/remarkable-frames/` are the user's files — **do not delete them
unprompted.** If there are a lot, offer:

```sh
ls -1 ~/remarkable-frames/frame-*.png | wc -l
```

> That session left 34 frames in ~/remarkable-frames. Want me to keep the last few
> and clear the rest, or leave them?

Only prune on an explicit yes. `latest.png` is a copy, not a link, so it survives
pruning of the timestamped frames.
