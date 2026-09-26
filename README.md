# screenshot-remarkable

A small macOS toolkit for getting AI feedback on what you're drawing **as you draw
it**. Screenshot a reMarkable tablet's shared screen — once, on an interval, or on
demand from an agent mid-conversation.

Built for the reMarkable desktop app's **Screen Share** window, but it will track
any window you point it at.

Two pieces:

- **`remarkable-capture.sh`** — the capture script. Useful on its own.
- **`skill/drawing-session/`** — a Claude Code skill that drives it, so an agent
  can preflight the setup and then grab a fresh frame whenever the conversation
  refers to your page. Other harnesses: see [AGENTS.md](AGENTS.md).

## Quick start

```sh
git clone https://github.com/kjameer0/screenshot-remarkable.git
cd screenshot-remarkable
./install.sh
```

The installer builds the window-ID helper, checks that screen capture actually
works (permissions included), reports whether the share window is open, and wires
the skill into `~/.claude/skills`. `./install.sh --check` verifies the capture path
without installing anything.

Then, in Claude Code:

```
/drawing-session start
```

It reads your page, tells you what it sees, and from then on grabs a fresh frame
whenever you ask about the drawing. Or skip the harness entirely and use the
script directly:

## Usage

```sh
./remarkable-capture.sh              # track the reMarkable Screen Share window, every 3s
./remarkable-capture.sh -1           # take a single screenshot and exit
./remarkable-capture.sh -1 -c        # single screenshot, straight to the clipboard
./remarkable-capture.sh -i 1.5 -c    # every 1.5s, each new frame ready to paste with Cmd-V
./remarkable-capture.sh -k 20        # keep only the 20 newest frames
./remarkable-capture.sh --list       # list capturable windows
./remarkable-capture.sh -a Chrome -t Figma   # track some other app/window
./remarkable-capture.sh -r 100,80,1200,1600  # fixed screen region instead
./remarkable-capture.sh -f           # whole screen
```

With `-1` the script prints the path of the frame it wrote and exits, so it
composes with other commands (`open "$(./remarkable-capture.sh -1)"`). It exits
non-zero if the window can't be captured.

Frames land in `~/remarkable-frames/` (override with `-o`), timestamped. The
newest is always at `~/remarkable-frames/latest.png`, so you can drag that one
file into a chat and re-drag it as the drawing evolves. `Ctrl-C` to stop.

| flag | meaning |
|---|---|
| `-i, --interval` | seconds between captures (default 3) |
| `-o, --outdir` | where frames go (default `~/remarkable-frames`) |
| `-a, --app` | window owner to match (default `reMarkable`) |
| `-t, --title` | window title substring (default `Screen Share`) |
| `-1, --once` | take one screenshot, print its path, exit |
| `-c, --clipboard` | copy each new frame to the clipboard |
| `-k, --keep` | keep only the N newest frames |
| `-r, --region` | capture a fixed `x,y,width,height` region |
| `-f, --full` | capture the whole screen |
| `-l, --list` | list capturable windows and exit |

## How it works

Capture is by CoreGraphics **window ID** (`screencapture -l<id>`), not by screen
coordinates. That means it:

- crops exactly to the window, at full retina resolution;
- works while the window is **behind** other windows, so you can keep a chat in
  front of the drawing;
- needs only **Screen Recording** permission — a coordinate-based region capture
  would also need Accessibility in order to look up the window's position.

`winid.swift` (compiled automatically on first run) resolves the window ID from
the window list. It prefers owner-name matches over title-only matches, so an
unrelated browser tab that merely mentions "reMarkable" in its title can't win.

Identical frames are discarded via an md5 comparison, so an idle drawing doesn't
pile up duplicate files. If the share window closes, the script waits and picks
back up when it reopens, re-resolving the ID (which changes on reopen).

## The drawing-session skill

`./install.sh` symlinks `skill/drawing-session/` into `~/.claude/skills` (use
`--copy` for a self-contained install), so the repo stays the source of truth and
`git pull` updates the skill. It's usually picked up immediately; restart Claude
Code only if `/drawing-session` doesn't appear.

| | |
|---|---|
| `/drawing-session start` | preflight, read a test frame, confirm ready, then hold the session |
| `/drawing-session look` | grab one frame now and react to it |
| `/drawing-session end` | close the session; offers to prune frames, never deletes unprompted |
| `/drawing-session status` | marker state, whether the window is findable, frame count |

Two things it does deliberately:

- **Your clipboard stays yours.** Frames are read from disk; the skill never passes
  `-c`.
- **Unchanged pages aren't re-read.** Each look md5-compares against the last frame
  read, so a long session doesn't spend an image per turn on a static drawing.

For harnesses that don't read Claude Code skills, [AGENTS.md](AGENTS.md) states the
same contract in a portable form — many agent tools pick that file up automatically.

## Requirements

- macOS, with Swift available (`swiftc`, from the Xcode Command Line Tools)
- Screen Recording permission for whichever terminal you run it from
  (System Settings › Privacy & Security › Screen Recording)
- The reMarkable desktop app, with the tablet's screen share running — or any
  other window you'd rather point it at

`./install.sh --check` verifies all of the above and tells you which is missing.

## Notes

- `screencapture` silently refuses dot-prefixed output filenames, which is why
  the in-progress frame is written as `pending-frame.png`.
- The compiled `winid` binary is gitignored; it is rebuilt on first run, or
  whenever `winid.swift` is newer.
