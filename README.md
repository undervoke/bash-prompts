# bash-prompts

Grouped interactive selection in Bash. `pick_select` provides ordinary
multi-selection; `pick_run` adds dependency-aware selection. Both use the
same terminal UI. Requires Bash 3.2+ and system `tput`/`stty`. Exercised on macOS;
other platforms are not yet verified.

## Multi-select

```bash
source ./lib/picker.sh
PICK_ID=(editor formatter notes)
PICK_LABEL=('Editor' 'Formatter' 'Notes, drafts')
PICK_GROUP=(Tools Tools Documents)
PICK_STATE=(1 0 0)

if pick_select; then
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        [[ ${PICK_STATE[i]} == 1 ]] || continue
        printf '%s\n' "${PICK_ID[i]}"
    done
else
    rc=$?
    printf 'Selection ended with status %s\n' "$rc" >&2
fi
```

Parallel, dense, zero-based arrays describe each row:

| Array | Contract |
|---|---|
| `PICK_ID` | Unique identity. An unset entry falls back to its label. |
| `PICK_LABEL` | Display text; labels may repeat when IDs differ. |
| `PICK_GROUP` | Group text. Unset means an unnamed group. |
| `PICK_VALID` | `0` excludes a row; `1` or unset includes it. |
| `PICK_STATE` | Selected flags (`0`/`1`), used as both input and output. |

`pick_select` keeps the incoming selected flags, excludes invalid rows,
and accepts an empty selection. Dependency arrays do not affect it.
Return codes: `0` submitted, `1` cancelled, `2` invalid input, no selectable
rows, or an unavailable interactive terminal. Read the result on `0`.
Rows retain their input indices; display groups follow first appearance,
with input order within each group. The UI writes to the terminal on stdout;
results are returned in arrays. One `PICK_*` state is active per Bash process.

## Dependency-aware selection

```bash
PICK_ID=(base addon bundle)
PICK_LABEL=('Base' 'Add-on' 'Bundle')
PICK_GROUP=(Components Components Presets)
PICK_DEPS=('' 'base' 'addon')
if pick_run; then
    printf 'Selected flags: %s\n' "${PICK_STATE[*]}"
fi
```

`pick_run` starts unchecked and returns `0` on nonempty submission, `1` on
cancellation or failure, preserving the 0.1 return contract. Checking a row
checks its transitive prerequisites.

`PICK_DEPENDENCY_MODE=cascade` (the default) lets a prerequisite be unchecked
and also unchecks every selected row that transitively depends on it. Those
removed rows lose their direct and retained automatic selection state.
Other prerequisites remain selected until explicitly unchecked.

`PICK_DEPENDENCY_MODE=lock` instead keeps a selected prerequisite locked
while a selected row requires it. Automatic choices remain checked after
becoming unlocked, until explicitly unchecked. Unknown mode names produce
an input error. This option does not affect `pick_select`.

`PICK_DIRECT` records explicit choices, `PICK_AUTO` retains automatic
choices, and `PICK_STATE` contains the combined selection. `pick_close`
computes this closure without opening the UI: set `PICK_DIRECT` and clear
`PICK_AUTO` for a fresh selection. It returns `0` on success or `1` on an
invalid graph, leaving the selection unchanged on failure.

`PICK_DEPS` contains comma-separated IDs of earlier rows. Tokens are trimmed;
referenced IDs are nonempty, comma-free, and have no leading/trailing spaces
or tabs. Display labels are independent of this grammar. Ordered edges make
this dependency contract acyclic. Selected dependencies must be available.

## Colors

```bash
PICK_FOCUS_COLOR=cyan
PICK_SELECTED_COLOR=green
PICK_GROUP_COLOR=blue
```

Colors are optional for both entry points and default to terminal colors.
Supported values are empty, `default`, `black`, `red`, `green`, `yellow`,
`blue`, `magenta`, `cyan`, and `white`. Focus color takes precedence over
selected color. A nonempty `NO_COLOR`, `TERM=dumb`, or unavailable terminal
color capability produces plain text. Unknown names produce an input error.

## Keys

Both interactive APIs read these arrays at the start of each call.
Defaults are initialized when the library is sourced:

```bash
PICK_KEYS_UP=(Up k)
PICK_KEYS_DOWN=(Down j)
PICK_KEYS_TOGGLE=(Space)
PICK_KEYS_ALL=(a)
PICK_KEYS_CLEAR=(n)
PICK_KEYS_SUBMIT=(Enter)
PICK_KEYS_CANCEL=(q Q Esc)
```

Assign an array after sourcing to replace that action's bindings. Multiple
elements are aliases; matching is case-sensitive. For example:

```bash
PICK_KEYS_UP=(Up w)
PICK_KEYS_DOWN=(Down s)
PICK_KEYS_TOGGLE=(Space x)
PICK_KEYS_SUBMIT=(Enter f)
```

A token is one printable ASCII character or one of `Up`, `Down`, `Left`,
`Right`, `Space`, `Enter`, `Esc`, `Tab`, `Backspace`. A literal space
normalizes to `Space`. Arrow tokens recognize unmodified CSI and SS3 terminal sequences.
Empty arrays disable an action. Unmapped keys have no effect. Each key
belongs to one action; repeated aliases within that action are deduplicated.
Unknown tokens or conflicting actions fail before opening the UI:
`pick_select` returns `2`, `pick_run` returns `1`.

The help lines show the active bindings. The actions have these semantics:

| Action | `pick_select` | `pick_run` |
|---|---|---|
| Up / down | Move | Move |
| Toggle | Toggle | Toggle with cascading deselection, or refuse a locked row in lock mode |
| All | Select all included rows | Select all included rows if closure succeeds |
| Clear | Clear all | Clear direct choices; retain automatic choices |
| Submit | Submit, including empty | Submit a nonempty selection |
| Cancel | Cancel | Cancel |

Esc waits up to one second to distinguish it from an escape sequence.
Ctrl-C remains a terminal signal handled through the caller's INT handler.
The terminal and caller INT/TERM handlers are restored on exit. Long rows
are clipped to terminal width.

## Helpers

- `pick_find_id <id>` / `pick_find_label <label>` print the first matching
  index, or `-1` if absent. Labels need not be unique; IDs are unique.
- `pick_locked_by <index>` prints labels of selected immediate dependents in
  lock mode, or nothing in cascade mode.
- `pick_split_csv <text>` fills `PICK_SPLIT` with trimmed fields, retaining
  leading, middle and trailing empty fields. Empty input yields no fields.
- `PICK_VERSION` identifies the API version. Other `pick_*` functions and
  `PICK_*` variables are internal.

## Interactive examples

```bash
/bin/bash examples/checkbox.sh
/bin/bash examples/dependencies.sh
/bin/bash examples/dependencies.sh lock
/bin/bash examples/wizard.sh
NO_COLOR=1 /bin/bash examples/checkbox.sh
```

The examples display the prompt and print its result. The first shows initial
selection, repeated labels with distinct IDs, and colors. The second shows
transitive automatic selection and cascading deselection; pass `lock` to
compare the locking behavior.

`examples/wizard.sh` calls `pick_select` for two steps and displays a third
review step. After submitting each prompt with Enter, use `n`/Enter for
Next, `b` for Back, or `e` to edit that step, followed by Enter. Previously
submitted selections are restored when revisiting a step. At review, use
`b` to revisit the second step or `f` to finish. `q` cancels the wizard.
The script keeps its own answers and navigation state and only prints a
result; it adds no wizard API to the library.

`examples/keybindings.sh` uses w/s or arrows to move, x/Space to toggle,
uppercase A/C to select/clear all, f/Enter to submit, and z/Esc to cancel.
The replaced j/k, a/n and q/Q bindings are inactive in this example.

## License

MIT; see [LICENSE](LICENSE).
