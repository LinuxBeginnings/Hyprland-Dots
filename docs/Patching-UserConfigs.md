# Patching UserConfigs / UserScripts

KoolDots preserves `~/.config/hypr/UserConfigs` and `~/.config/hypr/UserScripts`
on install, upgrade, and express upgrade - your edits are never overwritten.
That also means a fix shipped in the repo copy of a UserConfigs file will not
reach an existing install on its own.

To close that gap, the repo ships a small, non-destructive patch mechanism in
the top-level `patches/` directory. Patches run automatically:

- during `copy.sh` (install, upgrade, and express), after the UserConfigs and
  UserScripts restores; and
- during the menu's "update" action (`run_repo_update`).

Each patch only adds or adjusts a specific setting and is safe to run every
time.

## Patch contract

A patch is a small bash script named `patches/NN-name.sh` (sorted order, so use
the `NN-` prefix to control sequencing). It must:

- be **content-idempotent**: check whether its fix is already present and leave
  the file unchanged if so;
- target files under `$KOOLDOTS_CONFIG_HOME/hypr` (default
  `${XDG_CONFIG_HOME:-$HOME/.config}/hypr`), i.e. `UserConfigs/` and
  `UserScripts/`;
- skip cleanly (exit `0`) when a target file does not exist;
- never rewrite a whole file - only add/adjust the specific setting, so a user's
  own edits are preserved; and
- exit `0` for both "applied" and "already present/skipped".

The runner (`scripts/lib_patches.sh`) exports `KOOLDOTS_CONFIG_HOME` and
`KOOLDOTS_LOG` and executes each patch with `bash`. A non-zero exit is logged
and does not abort the overall upgrade.

## Shared helpers

Source `patches/lib.sh` for the common primitives:

```bash
# shellcheck source=./lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
```

- `patch_hypr_dir` - absolute path to the installed `hypr` config directory.
- `patch_log <msg>` - log a line (also appended to `$KOOLDOTS_LOG`).
- `patch_ensure_line <file> <present-regex> <line>` - append `<line>` when no
  line matches `<present-regex>`.
- `patch_ensure_line_after <file> <anchor-regex> <present-regex> <line>` -
  insert `<line>` after the first line matching `<anchor-regex>` (falls back to
  appending), when no line matches `<present-regex>`.

## Example

`patches/10-kitty-remember-window-size.sh` ensures `UserConfigs/kitty.conf`
sets `remember_window_size no` (required for kitty 0.49+ window-split
behavior), inserting it beneath the existing comment and doing nothing if the
key is already present.

## Adding a patch

1. Create `patches/NN-short-description.sh` with the contract above.
2. Make it executable (`chmod +x`).
3. Prefer the `patches/lib.sh` helpers over ad-hoc `sed`/`awk`.
4. Test against a temp config home: once with the fix absent, once with it
   already present (confirm no duplicate lines are added).
