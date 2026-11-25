# bash-prompts

Grouped interactive selection in Bash:

- `pick_select`: one highlighted item, returned as an ID in `PICK_VALUE`.
- `pick_multiselect`: checked items, returned as flags in `PICK_STATE`.
- `pick_dependencies`: initialized checkboxes with live dependency selection.
- `pick_choices`: one value per row, returned in `PICK_RESULT`.
- `pick_run`: dependency-aware checked items.

All use the same terminal UI. Requires Bash 3.2+ and system `tput`, `stty`,
and `dd`.

The prompt is drawn inline at the cursor, below earlier output, and erased
when it ends, leaving the cursor where it started; print the result or the
next prompt from there. Start a prompt on a fresh line.
Exercised on macOS; other platforms are not yet verified.

## Install

Use a pinned release asset; no build step is needed:

```bash
curl -fsSLO https://github.com/undervoke/bash-prompts/releases/download/v0.7.0/bash-prompts.sh
source ./bash-prompts.sh
```

From a checkout, source the development entry instead:

```bash
source ./lib/bash-prompts.sh
```

The entry loads the feature modules in `lib/bash-prompts/` in the calling
shell, so `demo` and `examples/` run directly from a checkout. Snippets
below source `./bash-prompts.sh`; in a checkout use `./lib/bash-prompts.sh`.

## Single select

```bash
source ./bash-prompts.sh
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
source ./bash-prompts.sh
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
| `PICK_NOTE` | Optional text after the label, such as a status. Messages name a row by its label alone. |
| `PICK_GROUP` | Group ID when groups are declared; otherwise single-level group text. Empty or unset places an item at the root. |
| `PICK_GROUP_TAIL` | Group IDs rendered after their siblings, including at the root. |
| `PICK_VALID` | `0` excludes a row; `1` or unset includes it. |
| `PICK_DISABLED` | Optional reason a visible checkbox or value is read-only; its initial state is retained. Applies to multi/dependency selection and value rows. |
| `PICK_STATE` | Selected flags (`0`/`1`) for multi-selection, input and output. |
| `PICK_VALUE` | Initial and submitted ID for single selection. |
| `PICK_PROMPT` | One line shown above the list. Unset shows a generic title. |
| `PICK_TABS` / `PICK_TAB` | Tabs over the root groups; see [Tabs](#tabs). |

`pick_multiselect` keeps the incoming selected flags, excludes invalid rows,
and accepts an empty selection. Dependency arrays do not affect it.
Both `pick_select` and `pick_multiselect` return `0` on submission, `1` on
cancellation, `2` for invalid input, no selectable rows, or an unavailable
interactive terminal, or `3` when a Back key was pressed. Read results on `0`;
on `3`, `PICK_VALUE` or `PICK_STATE` holds the unsubmitted state at that moment.

Each named group gets a header; multi-selection headers show selected/total
counts across its included descendants. The whole prompt fits the terminal
height: on a short terminal the spacers, hint lines, message, and title give
way to keep at least one list row. Scrolled-off ancestor headers stay pinned;
when space is tight, the nearest ancestors take priority and the focused
item stays visible. The title shows the focused position while scrolling.
A terminal resize repaints the prompt on a cleared screen.

## Recursive groups and separators

`pick_group <id> [label [parent-id]]` declares a group. `PICK_GROUP[i]` assigns
an item to that group; an empty parent places a group at the root. Labels
default to IDs and may repeat. An explicitly empty label adds neither a
header nor indentation. Each named ancestor adds one level of indentation.

```bash
source ./bash-prompts.sh
pick_group tools 'Tools'
pick_group code 'Code' tools
pick_group editors 'Editors' code
pick_group terminal 'Terminal' editors
pick_group documents 'Documents'

PICK_ID=(vim formatter notes)
PICK_LABEL=('Vim' 'Formatter' 'Notes')
PICK_GROUP=(terminal code documents)
PICK_GROUP_TAIL=(documents)
PICK_MAX_GROUP_DEPTH=8
PICK_GROUP_JUMP_DEPTH=1
PICK_KEYS_PREV_GROUP=(Left h)
PICK_KEYS_NEXT_GROUP=(Right l)

pick_separator formatter 'Formatting'
pick_separator notes                 # A plain divider
pick_separator '' 'End of options'    # A trailing separator

if pick_multiselect; then
    pick_selected_indices
fi
```

Group IDs are unique and nonempty so parent references identify one node.
Declarations may precede or follow their parents. `PICK_MAX_GROUP_DEPTH` is a
positive integer, defaulting to `8`; it counts parent links, including groups
with empty labels. Unknown group references, cycles, and excess depth return
an input error before terminal setup. Groups with no included descendants
have no display rows.

Sibling groups and direct items follow their first appearance in the included
item list. `PICK_GROUP_TAIL` moves the named group IDs after their siblings,
retaining relative order within the ordinary and tail groups. With no group
declarations, existing `PICK_GROUP=(Tools Tools Documents)` input creates
single-level groups with matching IDs and labels; empty text collects items
into one unnamed group.

`PICK_GROUP_JUMP_DEPTH` sets the structural depth for group jumps and defaults
to `1`; root groups are depth 1. It must be a positive integer; other values
return an input error. `PICK_KEYS_PREV_GROUP` and
`PICK_KEYS_NEXT_GROUP` are unbound by default. Bind them to focus the first
included item of the previous or next group at that depth. Jumps follow
display order, including tail ordering, and change only the focus, preserving
selection and dependency state. An item above the reference depth moves to the
nearest eligible group in that direction. Unnamed groups remain eligible
destinations. A jump past either end leaves the focus unchanged. A reference
depth deeper than the tree has no destination.

`pick_separator [before-id [label]]` inserts a display-only row before the
specified item and any headers newly entered for that item. An empty or
omitted ID appends it to the list; an empty or omitted label draws a line.
Separators have no indentation or group membership, are skipped by the cursor,
and contribute nothing to selection results, dependencies, or group counts.
They follow their anchor when groups reorder; an excluded anchor hides its
separators, and an unknown ID returns an input error. Multiple separators at
the same position retain declaration order. They scroll with the list.

The helpers append to parallel `PICK_GROUP_ID`, `PICK_GROUP_LABEL`,
`PICK_GROUP_PARENT` and `PICK_SEPARATOR_BEFORE`, `PICK_SEPARATOR_LABEL` arrays.
These arrays can also be assigned directly. Clear the corresponding arrays
when replacing definitions between prompts; all are initialized empty when
the library is sourced.

## Tabs

`PICK_TABS=1` shows the root groups as tabs below the prompt, and the rows of
the active one below them. It applies to every entry point; every included row needs
a group. One submission covers all tabs. Tabs follow the display order of the
root groups and each keeps its focus while the prompt is open. `PICK_TAB` is the
active tab's group ID, input and output; an ID without included rows starts at
the first tab. Nested groups keep their headers inside a tab.

On a narrow terminal the active tab stays visible and `<` and `>` stand for the
tabs left out. Without reverse video the active tab is bracketed.

## Value rows

`pick_choices` gives each row a list of values and no checkbox: the row always
holds exactly one of them, shown in a column beside the labels.

```bash
PICK_ID=(editor keymap sleep)
PICK_LABEL=('Editor' 'Editor key map' 'Sleep rules')
PICK_VALUES=('installed, update, remove' 'not applied, apply' 'custom, laptop, server')
PICK_OFF=('remove' 'not applied')
PICK_DEPS=('' 'editor')
if pick_choices; then
    printf '%s\n' "${PICK_RESULT[@]}"
fi
```

| Array | Contract |
|---|---|
| `PICK_VALUES` | Comma-separated values, in the order Toggle moves through them; trimmed like `PICK_DEPS`. |
| `PICK_CURRENT` | Value the row starts from. Unset uses the first value. |
| `PICK_CHOICE` | Picked value, input and output. Unset uses the current value. |
| `PICK_OFF` | Comma-separated values that leave the row off. |
| `PICK_WHILE_OFF` | Optional value from `PICK_VALUES` used when a prerequisite is turned off, unless a `PICK_OFF` value is picked. |
| `PICK_RESULT` | Output: the value in effect. |

Toggle changes the value in place, a changed value is shown in color, and tabs
count the rows that change. A long label is shortened before its value. A note
that does not fit its row is shown in full below the list while focused.

`PICK_DEPS` names prerequisites with the grammar described below, and a
prerequisite is met while its value is not one of its `PICK_OFF` values. While
one is off, a row can only stay at its current value or turn off, and it names
what it requires, with the tab of a prerequisite shown elsewhere. Turning a
prerequisite off moves the rows that need it to their current off value or else
their first one, and a message names them. A prerequisite that was off from the
start leaves the row's current value alone. `PICK_CHOICE` keeps what was picked,
so a row returns to it when its prerequisites do; pass `PICK_CHOICE` back to
reopen the prompt and act on `PICK_RESULT`. A row with `PICK_DISABLED` keeps its
value whatever its prerequisites hold.

With `PICK_WHILE_OFF`, Toggle offers that value and any `PICK_OFF` values while
a prerequisite is being turned off. Set `PICK_CURRENT` to the `PICK_WHILE_OFF`
value to use it for a row whose prerequisite is already off. List the ordinary
value first in `PICK_VALUES`: that is the fallback when the picked value is
`PICK_WHILE_OFF` and prerequisites are on again.

It uses the `0`/`1`/`2`/`3` return contract of `pick_multiselect`; on `3`,
`PICK_CHOICE` and `PICK_RESULT` hold the unsubmitted state.

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
added automatically. These follow the row's note.

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

## Styles

Each part of a prompt has one look, following the text roles of
[teakit](https://github.com/undervoke/teakit):

| Part | Look |
|---|---|
| Title | Bold cyan |
| Group header | Cyan |
| Focused row | Bold |
| Active tab | Reverse video |
| Changed value | Yellow |
| Note, read-only row, separator, key hint | Dim |
| Message that other rows changed too | Yellow |
| Message that refuses an action | Red |

Checked rows differ only by `[x]`. A nonempty `NO_COLOR` or `TERM=dumb`
produces plain text; without color capability only bold and dim apply.

## Keys

All interactive APIs read their active bindings at the start of each call.
Single selection uses Up, Down, Submit, Back, and Cancel; multi-selection
also uses Toggle, All, and Clear, and value rows use Toggle. Prev/next group
jumps are available in every interactive API when bound, and prev/next tab with
`PICK_TABS=1`. `pick_dependencies` supports Back; the
compatibility entry point `pick_run` leaves it unbound.
Defaults are initialized when the library is sourced:

```bash
PICK_KEYS_UP=(Up k)
PICK_KEYS_DOWN=(Down j)
PICK_KEYS_PREV_GROUP=()
PICK_KEYS_NEXT_GROUP=()
PICK_KEYS_PREV_TAB=(Left h)
PICK_KEYS_NEXT_TAB=(Right l)
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
`Right`, `Space`, `Enter`, `Esc`, `Tab`, `Shift+Tab`, `Backspace`. A literal
space normalizes to `Space`. Arrow tokens recognize unmodified CSI and SS3
terminal sequences.
Empty arrays disable an action. Unmapped keys have no effect. Each key
belongs to one action; repeated aliases within that action are deduplicated.

`PICK_WRAP_NAVIGATION` applies to item up/down actions, including configured
aliases, and defaults to `1`: Down from the last row wraps to the first, and
Up from the first wraps to the last. Set it to `0` to retain bounded movement.
Back is unbound by default; bind it to let a caller step backwards through
its own sequence of prompts. Unknown tokens or conflicting actions fail before opening the UI:
`pick_run` returns `1` and the others return `2`.

The hint below the list shows the active bindings, and a message appears above it until the next action; both wrap to the terminal width. The actions have these semantics:

| Action | `pick_select` | `pick_multiselect` | `pick_run` |
|---|---|---|---|
| Up / down | Move highlight | Move | Move |
| Prev / next group | Jump at `PICK_GROUP_JUMP_DEPTH` | Jump | Jump |
| Toggle | — | Toggle | Toggle with cascading deselection, or refuse a locked row in lock mode |
| All | — | Select editable rows | Select editable rows if closure succeeds |
| Clear | — | Clear editable rows | Clear editable direct choices; retain automatic choices |
| Submit | Return highlighted ID | Submit, including empty | Submit a nonempty selection |
| Back | Return `3` with the highlighted ID | Return `3` with current flags | — |
| Cancel | Cancel | Cancel | Cancel |

`pick_dependencies` uses the dependency actions above, accepts an empty Submit,
and returns `3` on Back with the current flags. Read-only checkbox states are
preserved by Toggle, All, Clear, and dependent deselection.

`pick_choices` moves the focused row to its next allowed value on Toggle,
submits any values, and returns `3` on Back. Prev/next tab keys wrap around.

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
./demo choices
./demo keybindings
./demo nested
./demo separators
./demo wizard
NO_COLOR=1 ./demo checkbox
```

Sources are in `examples/`; each script can also be run directly with Bash.
The examples display a prompt and print its result. `select` shows single
selection with an initial focus; `checkbox` shows initial checked state,
repeated labels with distinct IDs, and notes. `dependencies` shows
transitive automatic selection and cascading deselection, then prints each
selected ID as direct or auto with the selected IDs that require it; `lock`
shows the alternative locking behavior. `choices` shows value rows in tabs,
with rows that turn off with what they require. `nested` demonstrates four levels,
parent counts, tail ordering, separators inside and between groups, and
Left/Right group jumps at depth 2; `separators` demonstrates dividers in a
single-select list without groups.

`examples/wizard.sh` asks two `pick_multiselect` steps and a `pick_select`
review. Enter moves to the next step; Shift+Tab (bound through
`PICK_KEYS_BACK` from the second step on) returns to the previous one with its
answers kept. The review lists each answer: Enter on one reopens that step and
returns to the review, Enter on Finish prints the result. Esc or `q` cancels.
The script keeps its own answers and step order; the library supplies only
the prompts and the Back return status.

`examples/keybindings.sh` uses w/s or arrows to move, x/Space to toggle,
uppercase A/C to select/clear all, f/Enter to submit, and z/Esc to cancel.
The replaced j/k, a/n and q/Q bindings are inactive in this example.

## Build and release

`bash scripts/bundle.sh` regenerates the standalone `dist/bash-prompts.sh`
from `lib/bash-prompts.sh` and `lib/bash-prompts/`; the output is
deterministic and ignored by Git. To publish, set `PICK_VERSION`, then push
the matching tag (`v0.7.0` for `"0.7.0"`): the release workflow rebuilds
the bundle, checks it, and attaches `bash-prompts.sh` and `LICENSE` to the
GitHub Release.

## License

MIT; see [LICENSE](LICENSE).
