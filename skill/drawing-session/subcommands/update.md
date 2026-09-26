# /drawing-session update

Pull the latest toolkit from GitHub and report what changed.

## Signature

`/drawing-session update [--check]`

`--check` fetches and reports whether an update exists, without changing anything.

## Find the repo

Resolve it from the installed skill rather than assuming a path, since the skill
may be symlinked from anywhere:

```sh
SKILL_REAL="$(cd -P ~/.claude/skills/drawing-session && pwd)"
REPO="$(git -C "$SKILL_REAL" rev-parse --show-toplevel 2>/dev/null)"
```

If `REPO` is empty the skill was installed with `--copy`, so the installed copy
isn't a git checkout. Fall back to the clone:

```sh
REPO="$(ls -d ~/screenshot-remarkable 2>/dev/null || find ~ -maxdepth 3 -name remarkable-capture.sh -not -path '*/.claude/*' 2>/dev/null | head -1 | xargs -I{} dirname {})"
```

If there's still no clone, say so: a `--copy` install with no clone anywhere has
nothing to pull, and the fix is `git clone` + `./install.sh`, not a pull.

## Update

1. **Refuse to clobber local work.** Check first:

   ```sh
   git -C "$REPO" status --porcelain
   ```

   If non-empty, stop and show what's dirty. Offer to stash, commit, or skip —
   don't pull over the user's uncommitted edits, which may be their own tweaks to
   the capture script.

2. **Record the old commit, then pull:**

   ```sh
   BEFORE="$(git -C "$REPO" rev-parse HEAD)"
   git -C "$REPO" pull --ff-only
   ```

   `--ff-only` on purpose: if their branch has diverged (local commits of their
   own), a merge is a decision for them to make, not a side effect of an update.
   On failure, report the divergence and stop.

3. **Report concretely** — what changed, not "updated successfully":

   ```sh
   git -C "$REPO" log --oneline "$BEFORE"..HEAD
   ```

   If `$BEFORE` equals HEAD, say it was already current. Otherwise summarize the
   new commits in a line or two, and call out anything that changes behavior the
   user relies on.

## After pulling

Check what needs a follow-up action, and do only what's needed:

| Changed | Consequence |
|---|---|
| `winid.swift` | Rebuilds automatically on next capture (the script compares mtimes). Nothing to do. |
| `remarkable-capture.sh` | Live immediately. |
| `skill/**` | Live immediately **if** the skill is symlinked. If it was installed with `--copy`, re-run `./install.sh --copy` or the pull has no effect on the installed skill — say this explicitly. |
| `install.sh` | Suggest `./install.sh --check` to re-verify the capture path. |
| Skill frontmatter (`name`/`description`, new subcommands) | Observed to hot-reload in Claude Code — a new subcommand became invocable without a restart. If a newly pulled subcommand isn't recognized, restart then. |

A session in progress survives an update: the marker directory is untouched and
the capture command is unchanged. Don't end the session to update.
