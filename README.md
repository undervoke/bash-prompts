# bash-prompts

A lightweight Bash prompts library. The initial capability is a grouped,
dependency-aware checkbox selector: the user checks items in labeled groups
while required dependencies auto-check and stay locked with their reasons
until no longer needed.

Status: 0.1.0, the initial capability release. The API below describes
this release. Exercised on macOS with the system Bash 3.2 and newer Bash
versions; other platforms are not claimed.

## Roadmap

- [x] Extract the generic selector from the current consumer implementations
      into a standalone, namespaced Bash source file (`lib/picker.sh`).
- [x] Define the small caller API: caller-supplied item labels, group labels,
      and dependency edges as input; direct/auto selection state and lock
      reasons as the result contract.
- [x] Keep groups caller-defined; the library encodes no consumer group
      policy.
- [x] Carry over transitive dependency closure, lock reasons, grouped
      scrolling display, confirmation-before-execution semantics, and
      terminal setup/restore.
- [x] Preserve Bash 3.2 compatibility and rely only on Bash plus system
      terminal utilities, so rendering the selector needs no extra language
      runtime.
- [x] Integrate into consumers by pinned vendoring: each consumer ships a
  version-pinned copy with MIT license and exact upstream provenance, so an
  ordinary clone runs without fetching a UI dependency.
- [x] Verify on exercised environments only; do not advertise unverified
  platform support.
- [x] Cut the first tagged release with usage documentation and MIT license
  packaging.

## API

The caller fills parallel input arrays and reads back the result arrays;
`pick_close` expands direct choices through dependencies, and `pick_run`
opens the interactive checkbox UI:

- In: `PICK_LABEL`, `PICK_GROUP`, `PICK_DEPS` (comma-separated labels),
  `PICK_VALID` (`1` include, `0` exclude; unset counts as included).
- Out: `PICK_DIRECT` (explicitly chosen), `PICK_STATE` (selected including
  required dependencies), `PICK_AUTO` (auto-added, retained until
  explicitly unchecked).
- `pick_find_label`, `pick_split_csv`, and `pick_locked_by` are small
  helpers for consumers; every other `pick_*` name is internal.

Groups are caller-defined labels shown on every row and header. Labels must
be unique; each dependency must reference an earlier row.

## Usage

Source `lib/picker.sh`, fill the input arrays, then call `pick_close` for
an explicit selection or `pick_run` for the interactive checkbox UI.
`pick_run` starts with nothing checked and returns 0 with the result arrays
set, or 1 when cancelled. Confirm the printed plan before acting on
`PICK_STATE`; deselecting never uninstalls anything. See the header of
`lib/picker.sh` for the full contract.

```sh
source lib/picker.sh
PICK_LABEL=(editor linter bundle)
PICK_GROUP=(tools tools tools)
PICK_DEPS=('' 'editor' 'linter')
PICK_VALID=(1 1 1)
PICK_DIRECT=(0 0 1)
PICK_STATE=(0 0 0)
PICK_AUTO=(0 0 0)
pick_close || exit 1
```

## Demo

`examples/checkbox.sh` opens the real interactive picker on harmless sample
items, then prints the checked results (or reports the cancel). It performs
no installation, downloads, or system changes. Without a terminal it reports
that interactive selection needs one instead of prompting.

## Runtime goal

Bash with system terminal utilities, and nothing else, is enough to display
the selector. Consumers include a pinned copy of the library source, so a
normal cloned checkout works without network downloads or extra runtimes.
