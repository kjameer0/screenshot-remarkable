#!/usr/bin/env bash
# Installer for the screenshot-remarkable toolkit.
# Builds the window-ID helper, checks the capture path works, and wires the
# drawing-session skill into a Claude Code skills directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE=link
CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --copy)  MODE=copy ;;
    --link)  MODE=link ;;
    --check) CHECK_ONLY=1 ;;
    -h|--help)
      cat <<USAGE
Usage: ./install.sh [--link|--copy] [--check]

  --link    Symlink the skill from this repo (default). Edits and git pulls
            take effect immediately; the repo stays the source of truth.
  --copy    Copy the skill instead. Use when the skills directory must be
            self-contained, or the repo lives somewhere transient.
  --check   Verify the capture path only; install nothing.

Environment:
  CLAUDE_SKILLS_DIR   override ~/.claude/skills
  REMARKABLE_APP      window owner to look for (default reMarkable)
  REMARKABLE_WINDOW   window title to look for (default "Screen Share")
USAGE
      exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

SKILLS="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
APP="${REMARKABLE_APP:-reMarkable}"
WINDOW="${REMARKABLE_WINDOW:-Screen Share}"

fail=0
note() { printf '  %-34s %s\n' "$1" "$2"; }

echo "screenshot-remarkable — checking the capture path"

# --- platform -------------------------------------------------------------
if [ "$(uname -s)" != Darwin ]; then
  note "platform" "FAIL — macOS only (needs screencapture + CoreGraphics)"
  exit 1
fi
note "platform" "ok — $(sw_vers -productVersion)"

# --- swiftc, needed to build the window-ID helper -------------------------
if ! command -v swiftc >/dev/null 2>&1; then
  note "swiftc" "FAIL — install Xcode Command Line Tools: xcode-select --install"
  fail=1
else
  note "swiftc" "ok"
  if [ ! -x "$SCRIPT_DIR/winid" ] || [ "$SCRIPT_DIR/winid.swift" -nt "$SCRIPT_DIR/winid" ]; then
    swiftc -O -o "$SCRIPT_DIR/winid" "$SCRIPT_DIR/winid.swift"
    note "winid" "built"
  else
    note "winid" "ok — already built"
  fi
fi

# --- screen recording permission + the target window ----------------------
# A terminal without Screen Recording permission still "succeeds" at capture,
# it just gets a desktop-wallpaper image, so check the window list instead:
# window *titles* are only visible to a process that holds the permission.
if [ "$fail" -eq 0 ]; then
  if ! windows="$("$SCRIPT_DIR/winid" 2>/dev/null)" || [ -z "$windows" ]; then
    note "screen recording" "FAIL — grant it to your terminal in"
    note "" "System Settings > Privacy & Security > Screen Recording"
    fail=1
  elif [ -z "$(printf '%s' "$windows" | awk -F'\t' '$4 != ""')" ]; then
    note "screen recording" "FAIL — window titles are hidden, which means the"
    note "" "permission is missing. Grant it to your terminal, then restart it."
    fail=1
  else
    note "screen recording" "ok"
    if id="$("$SCRIPT_DIR/winid" "$APP" "$WINDOW" 2>/dev/null)" && [ -n "$id" ]; then
      note "$APP / $WINDOW" "found — window $id"
    else
      note "$APP / $WINDOW" "not open (fine for now)"
      echo "      Open the reMarkable desktop app and start the screen share"
      echo "      before a session. Run ./remarkable-capture.sh --list to see"
      echo "      what is currently capturable."
    fi
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "capture path incomplete — fix the FAIL lines above, then re-run"
  exit 1
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "capture path ok (--check: nothing installed)"
  exit 0
fi

# --- install the skill ----------------------------------------------------
src="$SCRIPT_DIR/skill/drawing-session"
dest="$SKILLS/drawing-session"
mkdir -p "$SKILLS"

if [ -e "$dest" ] || [ -L "$dest" ]; then
  current="$dest"
  [ -L "$dest" ] && current="$dest -> $(readlink "$dest")"
  echo
  echo "  '$current' already exists."
  read -r -p "  Replace it? [y/N] " ans
  case "$ans" in
    y|Y|yes|YES) rm -rf "$dest" ;;
    *) echo "  left alone — skill not installed"; exit 0 ;;
  esac
fi

if [ "$MODE" = link ]; then
  ln -sfn "$src" "$dest"
  note "skill" "linked -> $dest"
else
  cp -R "$src" "$dest"
  note "skill" "copied -> $dest"
fi

cat <<DONE

Done. In Claude Code:

  /drawing-session start     preflight and begin a feedback session
  /drawing-session look      grab one frame and react to it

Or straight from the shell, no harness involved:

  ./remarkable-capture.sh -1     one screenshot, prints its path
  ./remarkable-capture.sh        continuous, ~/remarkable-frames/latest.png

For harnesses that don't read Claude Code skills, point the agent at AGENTS.md.
DONE
