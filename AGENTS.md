# AGENTS.md

Project rules for AI agents working in this repository.

## Shell environment

The user's interactive shell is **zsh** (currently 5.9.2) on ~98% of their systems, including the test hosts. This governs every command an agent hands over to be run by hand.

- It applies to commands the user runs: their terminal, `ssh host '...'` triage, test systems.
- It does **not** apply to this repo's own scripts, which are bash (`#!/usr/bin/env bash`). Do not rewrite them for zsh.
- `ssh host 'cmd'` runs the remote **login shell**, so it is zsh on the test systems.
- The dangerous failure mode is not a loud error. Several bash-isms run happily in zsh and return **wrong data**, which then corrupts the analysis or the script built on top of it.
- Prefer the portable subset of both shells. When a snippet is genuinely bash-specific, force bash and say so.
- When a result matters, confirm the shell first: `echo $ZSH_VERSION` or `ps -p $$ -o comm=`.
- Get it right the first time. Generating a bash-ism, watching it fail, then re-issuing it for zsh wastes a round trip and risks a wrong conclusion in between.

### Never hand these over for a zsh shell

- `for x in $var` — zsh does not word-split, so it loops once over the whole string.
  - Use `while IFS= read -r x; do ... done <<<"$var"`.
- `${arr[0]}` — empty in zsh, arrays are 1-indexed. Use `${arr[1]}` or `"${arr[@]}"`.
- `**/` globs — recursive in zsh, but only with `shopt -s globstar` in bash. Same command, different file set.
- An unmatched glob — fatal in zsh (`no matches found`). Use `find`, or `setopt null_glob`.
- `shopt`, `mapfile`, `readarray` — bash-only. `read -p` and `BASH_REMATCH` mean something else, or nothing at all.
- `echo` with escapes — zsh's `echo` interprets them. Use `printf`.
- `status` — read-only in zsh, it is `$?`. `$path` — tied to `PATH` in zsh.
- `cmd | while read x` — the loop runs in the current shell in zsh, so variables it sets survive; in bash they do not. The same script reports different results.
- `set -e` / `pipefail` — close enough to be tempting, not close enough to rely on for exact error paths.

### Reliable escapes

- Force bash for a one-liner: `bash -c '...'`.
- Force bash over ssh without quoting games: `ssh host 'bash -s' <<'EOF' ... EOF`.
- Prefer tools that parse their own input (`find`, `grep -r`, `awk`, `jq`) over shell loops and globs.
- If output is empty, a single blob, or a suspiciously short list, suspect a shell mismatch before concluding the system is in that state.

## Script shebangs

Every script in this repository starts with `#!/usr/bin/env bash`.

- Never `#!/bin/bash` and never `#!/bin/sh`.
  - NixOS has no `/bin/bash`, only `/nix/store/.../bin/bash`.
  - `/usr/bin/env` is the one path it does provide, so `env bash` is the portable form.
  - The installer does not cover NixOS, but the scripts are run there.
- The rule covers an interpreter named inside a script, not just the shebang.
  - `systemd-run` and `setsid` resolve their command against a different `PATH`, so name the interpreter absolutely there.
  - `"$BASH"` is the bash already running the script, and the right thing to pass. Not `bash`, not `/bin/bash`.
- Python scripts use `#!/usr/bin/env python3` for the same reason.
- `config/hypr/scripts/tests/test-shebangs.sh` enforces all of this.

## Branch hygiene

- `git fetch --prune` and pull the current branch before editing. Never start work on a stale branch.
- Stash or commit local edits first, so the pull cannot fail or conflict.
- Work on `development` and push there directly.
- Do not open a pull request for work on `development`, and do not offer to.
  - `development` reaches `main` only when a release is cut.
  - A change is finished once it is on `development`.
  - Pull requests from outside contributors still target `development`.
- Say which branch and commit the work started from.

## Remote

- `git push` prints `remote: This repository moved. Please use the new location:` when the URL GitHub holds for the repo differs from `origin`'s.
- That URL is canonical. Correct `origin` to it and say so: `git remote set-url origin git@github.com:LinuxBeginnings/Hyprland-Dots.git`.
- Keep the transport already in use. This repo is SSH, so a corrected URL stays `git@github.com:...`, never `https://`.
- Do not defer it: GitHub redirects the old path, so nothing fails loudly and every later push repeats the warning.
- The difference is usually only the case of the org name (`Linuxbeginnings` against `LinuxBeginnings`), but treat whatever URL GitHub names as the one to use.

## Supported distros

The installer and the dotfiles upgrade flow cover these:

- Debian, Arch, Fedora and openSUSE: installer on `main`.
- Ubuntu: the installer is branched per release, matched on `VERSION_ID`.
  - Linux Mint and Zorin OS are supported as Ubuntu 24.04 based.
  - Ubuntu 26.10 is not officially supported and uses the 26.04 branch.
    - It must warn: `Ubuntu 26.10 not officially supported. Use at own risk`
- NixOS and Gentoo are not covered.
  - NixOS is declarative and ships no `update-deps.sh`.
  - There is no Gentoo installer repository.
  - The scripts still have to run on NixOS. See Script shebangs.

## Hyprland 0.57

The dots target Hyprland 0.57, which configures through a Lua manager. The hyprlang parser and its `hyprctl keyword` write path are gone.

- Config is Lua: `hl.config()`, `hl.get_config()`, `hl.dsp.*`, `hl.curve`, `hl.animation`, loaded from `hyprland.lua` through `dofile`.
- Write config at runtime with `hyprctl eval`, never `hyprctl keyword`.
  - `eval` runs the string in Hyprland's embedded Lua state and answers exactly `ok`.
  - `keyword` is no longer a registered command, yet `hyprctl keyword <opt> <value>` still exits 0 while answering `unknown request`.
  - Exit status alone therefore reads a rejected write as a success, which is how Rainbow Borders silently stopped applying the border.
  - Only the exact reply `ok` counts as a successful write.
  - Keep a `keyword` fallback only for builds older than 0.57.
  - `RainbowBorders-low-cpu.sh` and `RainbowBorders.bak.sh` are the reference: build the `hl.config()` string, `eval` it, require `ok`.
- `hyprctl getoption` prints a gradient as `gradient data: <c1> <c2> ... <N>deg`, with bare hex and no `0x` prefix.
  - Re-add `0x` before handing such a value back to a colour parser.
- `hyprctl dispatch` is a shorthand for `hl.dispatch(...)`; a dispatcher name plus arguments is parsed as Lua.
  - Use the `hl.dsp.*` helpers instead of legacy dispatcher strings.
- New in 0.57: `decoration:wobble`, off by default, and `quirks:skip_non_kms_dmabuf_formats`.

## Changelog

`CHANGELOG.md` is the source of truth for user-facing changes. The same text is pasted into Discord and GitHub tagged-release notes, so line breaks must be intentional.

- Markdown only. No prose paragraphs, no tables.
- Section headings keep the colon: `## Fixed:`, `## Added:`, `## Updated:`, `## Removed:`. `Fixed:` comes first.
- One top-level bullet per change: one short line, no trailing period.
- Details are nested bullets (`  - `). One short sentence per line. One idea per line.
- Never wrap a sentence across two lines. Every bullet is a single line.
- Keep every line under ~80 characters so it does not wrap when pasted.
- Backtick code, paths, settings and keys.
- An entry that came from an issue or a PR ends with a link to it.
  - Last nested bullet: `  - Issue: [#158](<url>)` or `  - PR: [#159](<url>)`.
- Keep `development` current: add the entry as the change lands, under the next version heading at the top of the file.
- Create that heading if it is missing. Never edit a section for a version that is already released.

Shape:

```markdown
## Fixed:

- `<thing>` no longer `<symptom>`
  - `<cause>`
  - `<what changed>`
  - `<effect>`
  - Issue: [#158](https://github.com/LinuxBeginnings/Hyprland-Dots/issues/158)
- `<second fix>` `<one line summary>`
  - `<detail>`
  - PR: [#159](https://github.com/LinuxBeginnings/Hyprland-Dots/pull/159)
```

## Commit messages

- Short subject line, then an optional short body. Do not narrate the root cause.
- Reference files by basename, not full paths: `settings.lua`, `lib_detect.sh`.
- One line per change, no paragraphs re-explaining the changelog entry.
- Example: `v2.3.27.7: no_hardware_cursors defaults to 2, NVIDIA/hybrid/VM set 1`

## Version bump

- Never bump the version for a normal change. The version stays at the last released one until a release is actually cut.
- A release does all of this together:
  - Finalise the `## vX.Y.Z` heading at the top of `CHANGELOG.md`.
  - Set `DOTS_VERSION` in `config/hypr/lua/env.lua`.
  - Rename the `config/hypr/vX.Y.Z` marker file. `copy.sh` and `KooLsDotsUpdate.sh` read it to detect the installed version.
  - Merge `development` into `main` and tag `Hyprland-Dots-vX.Y.Z`.
- The updater compares against `main`, so an unreleased version on `development` must not be advertised there.

## Wiki sync

- The wiki documents released versions only.
- Update `Changelogs.md` (English) and `Changelogs.es.md` (Spanish) after the release lands on `main`. Never sync a change that only exists on `development`.
- Keep the header of each file (title, language links, updated date) and refresh the date line.
- Spanish section headings: `## Corregido:`, `## Añadido:`, `## Actualizado:`, `## Eliminado:`.
- `../Hyprland-Dots.wiki` is a separate git repository. Commit and push it separately.
