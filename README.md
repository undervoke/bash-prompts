# bash-prompts

Grouped interactive selection in Bash:

- `pick_select`: one highlighted item, returned as an ID in `PICK_VALUE`.
- `pick_multiselect`: checked items, returned as flags in `PICK_STATE`.
- `pick_dependencies`: initialized checkboxes with live dependency selection.
- `pick_run`: dependency-aware checked items.

All use the same terminal UI. Requires Bash 3.2+ and system `tput`, `stty`,
and `dd`.

The prompt is drawn inline at the cursor, below earlier output, and erased
when it ends, leaving the cursor where it started; print the result or the
next prompt from there. Start a prompt on a fresh line.
Exercised on macOS; other platforms are not yet verified.

## Single select

```bash
source ./lib/picker.sh
PICK_ID=(terminal editor browser)
PICK_LABEL=(Terminal Editor Browser)
PICK_GROUP=(Workspace Workspace Tools)
PICK_PROMPT='Which app should open?'
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
    pick_selected_indices
    for i in "${PICK_SELECTED_INDICES[@]}"; do
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
| `PICK_SUBGROUP` | Sub-group text inside the group. Unset means none. |
| `PICK_SUBSUBGROUP` | Sub-sub-group text inside the sub-group. Unset means none. |
| `PICK_GROUP_TAIL` | Names of groups rendered after the other groups of their parent. |
| `PICK_VALID` | `0` excludes a row; `1` or unset includes it. |
| `PICK_DISABLED` | Optional reason a visible checkbox is read-only; its initial state is retained. Applies to multi/dependency selection. |
| `PICK_STATE` | Selected flags (`0`/`1`) for multi-selection, input and output. |
| `PICK_VALUE` | Initial and submitted ID for single selection. |
| `PICK_PROMPT` | One line shown above the list. Unset shows a generic title. |

`pick_multiselect` keeps the incoming selected flags, excludes invalid rows,
and accepts an empty selection. Dependency arrays do not affect it.
Both `pick_select` and `pick_multiselect` return `0` on submission, `1` on
cancellation, `2` for invalid input, no selectable rows, or an unavailable
interactive terminal, or `3` when a Back key was pressed. Read results on `0`;
on `3`, `PICK_VALUE` or `PICK_STATE` holds the unsubmitted state at that moment.

Each named group gets a header; multi-selection headers show selected/total
counts. A group can be split into named sub-groups, and a sub-group into named
sub-sub-groups: each named level adds a header, and the items below it are
indented one level per named header above them. A level without text adds no
header and no indent, so rows can sit directly under their parent. Groups are
ordered by first appearance, except that the groups named in
`PICK_GROUP_TAIL` come last within their parent. The whole prompt fits the
terminal height: the list takes the rows it needs, and on a short terminal the
spacer, then hint lines, then the message, then the title give way to keep at
least one list row. When a long list scrolls, the headers of the visible
group, sub-group, and sub-sub-group stay pinned at the top and the
title shows the focused position. A terminal resize repaints the prompt on a
cleared screen.

## Dependency-aware selection

`pick_dependencies` preserves the supplied `PICK_STATE`. Selecting an item adds
its prerequisites; merely opening or submitting leaves the initial choices
unchanged, even if that baseline has missing prerequisites.
It accepts an empty result and supports Back, using the same `0`/`1`/`2`/`3`
return contract as `pick_multiselect`. A read-only row stays checked or
unchecked as supplied; a change requiring it to change is refused with its
reason. It can still be focused to read that reason.

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
checks its transitive prerequisites. An unchecked row lists what it requires;
a checked row names the selected rows that require it, or `auto` when it was
added automatically.

`PICK_DEPENDENCY_MODE=cascade` (the default) lets a prerequisite be unchecked
and also unchecks every selected row that transitively depends on it. Those
removed rows lose their direct and retained automatic selection state.
Other prerequisites remain selected until explicitly unchecked.

`PICK_DEPENDENCY_MODE=lock` instead keeps a selected prerequisite locked
while a selected row requires it. Automatic choices remain checked after
becoming unlocked, until explicitly unchecked. Unknown mode names produce
an input error. This option affects `pick_run` and `pick_dependencies`.

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
Independently of colors, the title is bold and the key hint dim.
Supported values are empty, `default`, `black`, `red`, `green`, `yellow`,
`blue`, `magenta`, `cyan`, and `white`. Focus color takes precedence over
selected color. Selected color applies to checked rows. A nonempty `NO_COLOR`
or `TERM=dumb` produces plain text; without color capability only bold and
dim apply.
Unknown names produce an input error.

## Keys

All interactive APIs read their active bindings at the start of each call.
Single selection uses Up, Down, Submit, Back, and Cancel; multi-selection
also uses Toggle, All, and Clear. `pick_dependencies` supports Back;
the compatibility entry point `pick_run` leaves it unbound.
Defaults are initialized when the library is sourced:

```bash
PICK_KEYS_UP=(Up k)
PICK_KEYS_DOWN=(Down j)
PICK_KEYS_TOGGLE=(Space)
PICK_KEYS_ALL=(a)
PICK_KEYS_CLEAR=(n)
PICK_KEYS_SUBMIT=(Enter)
PICK_KEYS_CANCEL=(q Q Esc)
PICK_KEYS_BACK=()
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
Back is unbound by default; bind it to let a caller step backwards through
its own sequence of prompts. Unknown tokens or conflicting actions fail before opening the UI:
`pick_select`, `pick_multiselect`, and `pick_dependencies` return `2`; `pick_run` returns `1`.

The hint below the list shows the active bindings, wrapped to the terminal width. The actions have these semantics:

| Action | `pick_select` | `pick_multiselect` | `pick_run` |
|---|---|---|---|
| Up / down | Move highlight | Move | Move |
| Toggle | — | Toggle | Toggle with cascading deselection, or refuse a locked row in lock mode |
| All | — | Select editable rows | Select editable rows if closure succeeds |
| Clear | — | Clear editable rows | Clear editable direct choices; retain automatic choices |
| Submit | Return highlighted ID | Submit, including empty | Submit a nonempty selection |
| Back | Return `3` with the highlighted ID | Return `3` with current flags | — |
| Cancel | Cancel | Cancel | Cancel |

`pick_dependencies` uses the dependency actions above, accepts an empty Submit,
and returns `3` on Back with the current flags. Read-only checkbox states are
preserved by Toggle, All, Clear, and dependent deselection.

A lone Esc takes effect after 0.1 seconds, which distinguishes it from an
escape sequence.
Ctrl-C remains a terminal signal handled through the caller's INT handler.
The terminal and caller INT/TERM handlers are restored on exit. Long rows,
including the prompt, are clipped using estimated UTF-8 display widths.
Common CJK, Hangul, and emoji characters count as two cells. Narrow symbols,
combining marks, and joined emoji can be overcounted and clipped early.
This is not full Unicode width calculation: terminals configured to render
ambiguous-width characters as wide can still wrap those rows.

## Helpers

- `pick_find_id <id>` / `pick_find_label <label>` print the first matching
  index, or `-1` if absent. Labels need not be unique; IDs are unique.
- `pick_selected_indices` fills `PICK_SELECTED_INDICES` with the indices of
  included rows whose `PICK_STATE` is `1`, in input order; it is empty when
  nothing is selected. It reads the current arrays, so it also applies after
  `pick_close`.
- `pick_required_by <index>` fills `PICK_REQUIRED_BY_INDICES` with the indices
  of included, selected rows whose `PICK_DEPS` name that row, in input order,
  in either dependency mode. It reads the current arrays.
- `pick_locked_by <index>` prints labels of selected immediate dependents in
  lock mode, or nothing in cascade mode.
- `pick_split_csv <text>` fills `PICK_SPLIT` with trimmed fields, retaining
  leading, middle and trailing empty fields. Empty input yields no fields.
- `PICK_VERSION` identifies the API version. Other `pick_*` functions and
  `PICK_*` variables are internal.

## Interactive examples

Run `./demo` from the repository root. The launcher uses `pick_select`:
move to an example with Up/Down and press Enter to run it immediately.
The example runs in place and prints its result, and the launcher reopens
below it with that item still highlighted. Press `q` or Esc there to exit.
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
transitive automatic selection and cascading deselection, then prints each
selected ID as direct or auto with the selected IDs that require it; `lock`
shows the alternative locking behavior.

`examples/wizard.sh` asks two `pick_multiselect` steps and a `pick_select`
review. Enter moves to the next step; Left or Backspace (bound through
`PICK_KEYS_BACK` from the second step on) returns to the previous one with its
answers kept. The review lists each answer: Enter on one reopens that step and
returns to the review, Enter on Finish prints the result. Esc or `q` cancels.
The script keeps its own answers and step order; the library supplies only
the prompts and the Back return status.

`examples/keybindings.sh` uses w/s or arrows to move, x/Space to toggle,
uppercase A/C to select/clear all, f/Enter to submit, and z/Esc to cancel.
The replaced j/k, a/n and q/Q bindings are inactive in this example.

## License

MIT; see [LICENSE](LICENSE).
