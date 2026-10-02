# AGENTS.md

Project rules for AI agents working in this repository.

## Branch hygiene

- `git fetch --prune` and pull the current branch before editing. Never start work on a stale branch.
- Stash or commit local edits first, so the pull cannot fail or conflict.
- Work on `development`. Pull requests target `development`, not `main`.
- Say which branch and commit the work started from.

## Changelog

`CHANGELOG.md` is the source of truth for user-facing changes. The same text is pasted into Discord and GitHub tagged-release notes, so line breaks must be intentional.

- Markdown only. No prose paragraphs, no tables.
- Section headings keep the colon: `## Fixed:`, `## Added:`, `## Updated:`, `## Removed:`. `Fixed:` comes first.
- One top-level bullet per change: one short line, no trailing period.
- Details are nested bullets (`  - `). One short sentence per line. One idea per line.
- Never wrap a sentence across two lines. Every bullet is a single line.
- Keep every line under ~80 characters so it does not wrap when pasted.
- Backtick code, paths, settings and keys.
- Keep `development` current: add the entry as the change lands, under the next version heading at the top of the file.
- Create that heading if it is missing. Never edit a section for a version that is already released.

Shape:

```markdown
## Fixed:

- `<thing>` no longer `<symptom>`
  - `<cause>`
  - `<what changed>`
  - `<effect>`
- `<second fix>` `<one line summary>`
  - `<detail>`
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
