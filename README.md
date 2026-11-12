# bash-prompts

Grouped interactive selection in Bash:

- `pick_select`: one highlighted item, returned as an ID in `PICK_VALUE`.
- `pick_multiselect`: checked items, returned as flags in `PICK_STATE`.
- `pick_run`: dependency-aware checked items.

All use the same terminal UI. Requires Bash 3.2+ and system `tput`/`stty`.
Exercised on macOS; other platforms are not yet verified.

## Single select

```bash
source ./lib/picker.sh
PICK_ID=(terminal editor browser)
PICK_LABEL=(Terminal Editor Browser)
PICK_GROUP=(Workspace Workspace Tools)
PICK_VALUE=editor

if pick_select; then
    printf 'Selected ID: %s\n' "$PICK_VALUE"
fi
```

Move with Up/Down or k/j and press Enter to submit the highlighted row.
`PICK_VALUE` supplies the initial focus and receives the submitted ID.
Use `unset PICK_VALUE` to start at the first included row. A supplied initial
ID must exist and be included. Cancel leaves `PICK_VALUE` unchanged.
Checkbox state and dependency inputs do not affect single selection.

## Multi-select

```bash
source ./lib/picker.sh
PICK_ID=(editor formatter notes)
PICK_LABEL=('Editor' 'Formatter' 'Notes, drafts')
PICK_GROUP=(Tools Tools Documents)
PICK_STATE=(1 0 0)

if pick_multiselect; then
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        [[ ${PICK_STATE[i]} == 1 ]] || continue
        printf '%s\n' "${PICK_ID[i]}"
    done
else
    rc=$?
    printf 'Selection ended with status %s\n' "$rc" >&2
fi
```

Parallel, dense, zero-based arrays describe each row; `PICK_VALUE` is a scalar:

| Input | Contract |
|---|---|
| `PICK_ID` | Unique identity. An unset entry falls back to its label. |
| `PICK_LABEL` | Display text; labels may repeat when IDs differ. |
| `PICK_GROUP` | Group text. Unset means an unnamed group. |
| `PICK_VALID` | `0` excludes a row; `1` or unset includes it. |
| `PICK_STATE` | Selected flags (`0`/`1`) for multi-selection, input and output. |
| `PICK_VALUE` | Initial and submitted ID for single selection. |

`pick_multiselect` keeps the incoming selected flags, excludes invalid rows,
and accepts an empty selection. Dependency arrays do not affect it.
Both `pick_select` and `pick_multiselect` return `0` on submission, `1` on
cancellation, or `2` for invalid input, no selectable rows, or an unavailable
interactive terminal. Read results on `0`.

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
an input error. This option affects only `pick_run`.

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

Colors are optional for all interactive entry points and default to terminal colors.
Supported values are empty, `default`, `black`, `red`, `green`, `yellow`,
`blue`, `magenta`, `cyan`, and `white`. Focus color takes precedence over
selected color. Selected color applies to checked rows. A nonempty `NO_COLOR`,
`TERM=dumb`, or unavailable terminal color capability produces plain text.
Unknown names produce an input error.

## Keys

All interactive APIs read their active bindings at the start of each call.
Single selection uses Up, Down, Submit, and Cancel; multi-selection and
dependency selection also use Toggle, All, and Clear.
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
`pick_select` and `pick_multiselect` return `2`; `pick_run` returns `1`.

The help lines show the active bindings. The actions have these semantics:

| Action | `pick_select` | `pick_multiselect` | `pick_run` |
|---|---|---|---|
| Up / down | Move highlight | Move | Move |
| Toggle | — | Toggle | Toggle with cascading deselection, or refuse a locked row in lock mode |
| All | — | Select all included rows | Select all included rows if closure succeeds |
| Clear | — | Clear all | Clear direct choices; retain automatic choices |
| Submit | Return highlighted ID | Submit, including empty | Submit a nonempty selection |
| Cancel | Cancel | Cancel | Cancel |

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

Run `./demo` from the repository root. The launcher uses `pick_select`:
move to an example with Up/Down and press Enter to run it immediately.
Completing or cancelling the example returns to the launcher with that item
still highlighted. Press `q` or Esc there to exit.
Use a name to run an example directly and return its exit status:

```bash
./demo
./demo --list
./demo select
./demo checkbox
./demo dependencies
./demo lock
./demo keybindings
./demo wizard
NO_COLOR=1 ./demo checkbox
```

Sources are in `examples/`; each script can also be run directly with Bash.
The examples display a prompt and print its result. `select` shows single
selection with an initial focus; `checkbox` shows initial checked state,
repeated labels with distinct IDs, and colors. `dependencies` shows
transitive automatic selection and cascading deselection; `lock` shows
the alternative locking behavior.

`examples/wizard.sh` calls `pick_multiselect` for two steps and displays a third
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
