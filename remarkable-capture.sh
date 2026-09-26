#!/bin/bash
# Continuously screenshot the shared reMarkable window so frames can be
# pasted/uploaded into a Claude chat for feedback.
#
#   ./remarkable-capture.sh                # track the reMarkable Screen Share window, 3s
#   ./remarkable-capture.sh -1             # take exactly one screenshot and exit
#   ./remarkable-capture.sh -1 -c          # one screenshot, straight to the clipboard
#   ./remarkable-capture.sh -i 1.5 -c      # 1.5s, copy each new frame to the clipboard
#   ./remarkable-capture.sh -k 20          # keep only the 20 newest frames
#   ./remarkable-capture.sh -a Chrome -t Figma   # any other app/window
#   ./remarkable-capture.sh --list         # show capturable windows and exit
#   ./remarkable-capture.sh -r 100,80,1200,1600  # fixed screen region instead
#   ./remarkable-capture.sh -f             # whole screen
#
# Captures the window by its CoreGraphics window ID, so it works even when the
# window is behind others and needs only Screen Recording permission (no
# Accessibility). Unchanged frames are discarded; newest is always latest.png.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WINID="$HERE/winid"

APP="reMarkable"
TITLE="Screen Share"
INTERVAL=3
OUTDIR="$HOME/remarkable-frames"
MODE="window"     # window | region | full
REGION=""
CLIPBOARD=0
ONCE=0
KEEP=0            # 0 = keep every frame

usage() { awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    -i|--interval)  INTERVAL="$2"; shift 2 ;;
    -o|--outdir)    OUTDIR="$2"; shift 2 ;;
    -a|--app)       APP="$2"; TITLE=""; MODE="window"; shift 2 ;;
    -t|--title)     TITLE="$2"; MODE="window"; shift 2 ;;
    -r|--region)    REGION="$2"; MODE="region"; shift 2 ;;
    -f|--full)      MODE="full"; shift ;;
    -c|--clipboard) CLIPBOARD=1; shift ;;
    -1|--once)      ONCE=1; shift ;;
    -k|--keep)      KEEP="$2"; shift 2 ;;
    -l|--list)      MODE="list"; shift ;;
    -h|--help)      usage 0 ;;
    *) echo "unknown option: $1" >&2; usage 1 ;;
  esac
done

# Build the window-ID helper on first run (or if its source is newer).
if [ ! -x "$WINID" ] || [ "$HERE/winid.swift" -nt "$WINID" ]; then
  echo "building window-id helper..."
  swiftc -O -o "$WINID" "$HERE/winid.swift" || { echo "!! swiftc failed" >&2; exit 1; }
fi

if [ "$MODE" = list ]; then
  printf 'ID\tSIZE\tAPP\tTITLE\n'; exec "$WINID"
fi

resolve_id() { "$WINID" "$APP" ${TITLE:+"$TITLE"} 2>/dev/null; }

if [ "$MODE" = window ]; then
  win=$(resolve_id)
  if [ -z "$win" ]; then
    echo "!! no window matching app='$APP'${TITLE:+ title~'$TITLE'}." >&2
    echo "   Is the screen share open? Run --list to see what's capturable." >&2
    exit 1
  fi
  echo "tracking window $win  (app='$APP'${TITLE:+ title~'$TITLE'})"
fi

mkdir -p "$OUTDIR"

shot() {
  case "$MODE" in
    window)
      # Re-resolve each tick: the ID changes if the share window is reopened.
      local id; id=$(resolve_id)
      [ -z "$id" ] && return 1
      screencapture -x -o -l"$id" "$1" 2>/dev/null ;;
    region) screencapture -x -o -R"$REGION" "$1" 2>/dev/null ;;
    full)   screencapture -x -o "$1" 2>/dev/null ;;
  esac
}

cleanup() { echo; echo "stopped — $count frame(s) in $OUTDIR"; exit 0; }
trap cleanup INT TERM

last_hash=""
count=0
missing=0
# NB: screencapture refuses dot-prefixed output filenames, so no leading dot.
tmp="$OUTDIR/pending-frame.png"

if [ "$ONCE" = 0 ]; then
  echo "capturing every ${INTERVAL}s -> $OUTDIR   (latest: $OUTDIR/latest.png)"
  [ "$CLIPBOARD" = 1 ] && echo "clipboard mode: each new frame is ready to paste with Cmd-V"
  echo "Ctrl-C to stop"
fi

while true; do
  if shot "$tmp" && [ -s "$tmp" ]; then
    missing=0
    hash=$(md5 -q "$tmp" 2>/dev/null)
    # One-shot always saves; the loop saves only when the frame actually changed.
    if [ "$ONCE" = 1 ] || { [ -n "$hash" ] && [ "$hash" != "$last_hash" ]; }; then
      last_hash="$hash"
      count=$((count + 1))
      frame="$OUTDIR/frame-$(date +%Y%m%d-%H%M%S).png"
      # Timestamps are second-granularity; don't clobber a frame from this
      # same second (easy to hit with back-to-back one-shots).
      if [ -e "$frame" ]; then
        n=2
        while [ -e "${frame%.png}-$n.png" ]; do n=$((n + 1)); done
        frame="${frame%.png}-$n.png"
      fi
      mv "$tmp" "$frame"
      cp "$frame" "$OUTDIR/latest.png"
      [ "$CLIPBOARD" = 1 ] && osascript -e \
        "set the clipboard to (read (POSIX file \"$frame\") as «class PNGf»)" 2>/dev/null
      if [ "$ONCE" = 1 ]; then
        echo "$frame"
        [ "$CLIPBOARD" = 1 ] && echo "copied to clipboard — paste with Cmd-V"
      else
        printf '\r[%d] %s  ' "$count" "$(basename "$frame")"
      fi
      if [ "$KEEP" -gt 0 ]; then
        ls -1t "$OUTDIR"/frame-*.png 2>/dev/null | tail -n +"$((KEEP + 1))" \
          | while read -r old; do rm -f "$old"; done
      fi
    else
      rm -f "$tmp"
    fi
    [ "$ONCE" = 1 ] && exit 0
  else
    rm -f "$tmp"
    missing=$((missing + 1))
    if [ "$ONCE" = 1 ]; then
      # Don't hang on a one-shot: a few quick retries, then give up loudly.
      if [ "$missing" -ge 3 ]; then
        echo "!! couldn't capture the window after $missing tries" >&2
        exit 1
      fi
      sleep 0.5
      continue
    fi
    [ "$missing" = 1 ] && printf '\rwindow gone — waiting for it to come back...  '
  fi
  sleep "$INTERVAL"
done
