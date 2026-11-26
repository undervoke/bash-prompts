# bash-prompts

Grouped interactive selection in Bash:

- `pick_select`: one highlighted item, returned as an ID in `PICK_VALUE`.
- `pick_multiselect`: checked items, returned as flags in `PICK_STATE`.
- `pick_dependencies`: initialized checkboxes with live dependency selection.
- `pick_choices`: one value per row, returned in `PICK_RESULT`.
- `pick_keybinding`: one key combination, returned in `PICK_VALUE`.
- `pick_run`: dependency-aware checked items.

All use the same terminal UI. Requires Bash 3.2+ and system `tput`, `stty`,
`dd`, `mktemp`, `cat`, and `rm`; key capture on macOS also uses `mkfifo` and
`osascript`.

The prompt is drawn inline at the cursor, below earlier output, and erased
when it ends, leaving the cursor where it started; print the result or the
next prompt from there. Start a prompt on a fresh line.
Exercised on macOS; other platforms are not yet verified.

## Install

Use a pinned release asset; no build step is needed:

```bash
curl -fsSLO https://github.com/undervoke/bash-prompts/releases/download/v0.11.2/bash-prompts.sh
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
the active one below them. It applies to every prompt with rows; every included row
needs a group. One submission covers all tabs. Tabs follow the display order of the
root groups and each keeps its focus while the prompt is open. `PICK_TAB` is the
active tab's group ID, input and output; an ID without included rows starts at
the first tab. Nested groups keep their headers inside a tab.

`[` and `]` change the tab from anywhere. Up from the first row moves the focus to
the tabs, where Left and Right change the tab, and Down returns to the rows. The
active tab is underlined, and reversed while the tabs have the focus.

On a narrow terminal the active tab and the [submit tab](#submit-tab-and-confirmation)
stay visible and `<` and `>` stand for the tabs left out. Without these styles the
active tab is bracketed, as `[Tab]` and `[> Tab]`.

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

Toggle and Prev/next value change the value in place, a changed value is shown in color, and tabs
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

### Submit tab and confirmation

With `PICK_TABS=1`, `PICK_SUBMIT_TAB` names a root group without items, shown as
the last tab. It holds two actions, Submit and Cancel, that Toggle runs. With
`PICK_CONFIRM_PROMPT`, every submission first opens a screen that lists the rows
that change, as their values before and after, and asks to submit or go back:

```bash
pick_group submit 'Submit'
PICK_SUBMIT_TAB=submit
PICK_CONFIRM_PROMPT='Apply these changes?'
PICK_KEYS_TOGGLE=(Space Enter)
PICK_KEYS_SUBMIT=()
```

The empty Submit binding leaves Enter for Toggle, so submission goes through
the Submit tab.

The list takes no focus: Up and Down scroll it, Left and Right choose between
Submit and Back, and Enter or Space runs the chosen one. Back and Cancel keys return
to the rows as they were.

| Variable | Contract |
|---|---|
| `PICK_CONFIRM_PROMPT` | The line above the list. Empty submits without the screen. |
| `PICK_REVIEW` | Function called before the screen opens. It finds the values in `PICK_RESULT`, and a nonzero status refuses them. It must not print or read standard input. |
| `PICK_REVIEW_NOTE` | Filled by `PICK_REVIEW`: text below a row in the list. A row with one is listed even if it keeps its value. |
| `PICK_REVIEW_MESSAGE` | Set by `PICK_REVIEW`: the reason of a refusal. |

### Edit rows, formats, and columns

An edit row takes text from a function instead of moving through a list. It
mixes with other rows and shares their tabs, prerequisites, and result.

| Array | Contract |
|---|---|
| `PICK_EDIT` | Function Edit runs for the row, as `function <row index>` in the calling shell. It finds the row's value in `PICK_VALUE`, sets `PICK_VALUE`, and returns `0` to change the row; another status leaves it. It must not print, read standard input, or start another prompt, because the prompt still owns the terminal. |
| `PICK_VALUES` | For an edit row, the fixed values offered beside an edited one; may be empty. |
| `PICK_FORMAT` | Function that shows the row's value, as `function <value> <row index>`; it sets `PICK_TEXT`. |
| `PICK_CELLS` | Tab-separated text for the columns between the label and the value. |
| `PICK_COLUMNS` | Headers of the label, each cell, and the value, in order. Omitted ones are blank. |

`PICK_CURRENT` and `PICK_CHOICE` of an edit row may be any text. Toggle and
Prev/next value move it through its fixed values, the texts it started from, and
those entered, so no entered one is lost. For a key row these must be keys. Without
`PICK_KEYS_EDIT`, Toggle runs the function instead. An edit row cannot be edited
while a prerequisite is off.

The headers appear where a shown row has cells or an edit function. On a narrow
terminal labels are shortened first, then the cells give way from the last one.

## Keybindings

```bash
source ./bash-prompts.sh
PICK_PROMPT='Which key opens the terminal?'
if pick_keybinding; then
    pick_keybinding_parse "$PICK_VALUE"
    printf '%s: key code %s, flags %s\n' "$PICK_VALUE" "$PICK_KEYBINDING_CODE" "$PICK_KEYBINDING_FLAGS"
fi
```

`PICK_VALUE` holds the key, input and output; an input that could not be entered
means none yet, and entry starts at once. Toggle enters another key. It returns `0` on
submission, `1` on cancellation, `2` for invalid input or no interactive
terminal, and `3` on Back.

On macOS a key is pressed in a small window. The window receives what a terminal
cannot, including Globe and Command combinations and the hotkeys macOS itself
uses, which stay off while it has the focus. It accepts the first key that can be
used and closes when that key is released. Esc, its close button, and losing the
focus leave the value as it was; Delete takes the row's off value. Tab, or its
button, goes to typing the key as text. Typing also serves keys no window
receives, other systems, SSH, and a Mac without a window to open.

A key is written `[fn+][ctrl+][option+][shift+][cmd+]name`, with the modifiers in
that order, such as `ctrl+tab`, `cmd+comma`, or `fn+h`. The names are positions on
an ANSI keyboard, so a key does not depend on the input source: `a`-`z`, `0`-`9`,
`minus`, `equal`, `leftbracket`, `rightbracket`, `backslash`, `semicolon`, `quote`,
`grave`, `comma`, `period`, `slash`, `return`, `tab`, `space`, `delete`,
`forwarddelete`, `esc`, `left`, `right`, `up`, `down`, `home`, `end`, `pageup`,
`pagedown`, `help`, `f1`-`f20`, `keypad0`-`keypad9`, `keypaddecimal`, `keypadmultiply`,
`keypadplus`, `keypadclear`, `keypaddivide`, `keypadenter`, `keypadminus`,
`keypadequal`, `keypadcomma`, `section`, `yen`, `underscore`, `eisu`, and `kana`. `fn` is the
Globe key. It is shown with the symbols of macOS, `🌐⌃⌥⇧⌘` and the key.

A key needs Control, Option, Command, or Globe so that it does not type a
character; `f1`-`f20` stand alone. Globe does not count for keys macOS marks with
it anyway, such as the arrows. macOS turns Globe with an arrow, Delete, or Return
into Home, End, Page Up, Page Down, Forward Delete, or keypad Enter, and those are
the keys entered.

### Keys in value rows

`PICK_EDIT[i]=pick_keybinding` makes a row of `pick_choices` hold a key. Its
`PICK_VALUES` decide whether it can also be off or at its default: the ones in
`PICK_OFF` hold no key, and the others stand for the default.

| Variable | Contract |
|---|---|
| `PICK_KEYBINDING_DEFAULT` | Key of a row while it stands at its default. |
| `PICK_KEYBINDING_SCOPE` | Rows share a key only with rows of the same text; unset is one common scope. |
| `PICK_KEYBINDING_CHECK` | Function called with each key entered and the row index, which is left out on its own. |
| `PICK_KEYBINDING_MESSAGE` | Set by the check: the reason of a refusal or a warning. |

The check runs in the calling shell, where it can read the other rows. It returns
`0` to accept the key and another status to refuse it; entry then continues with
the message. A message with `0` stays below the list until the next action. It
must not print or read standard input. Without a check any key is accepted.

A key row, and any row with a `PICK_KEYBINDING_DEFAULT`, competes for its key. A
key held by two rows is marked at once and refused on Submit, so two rows can swap
keys. Rows that all stand at their default may share one. `PICK_FORMAT[i]=pick_keybinding_format`
shows a key in a row that is neither edited nor compared, such as a confirmation.

## Alternate screen

`pick_screen <command> [args]` runs a flow of prompts in the calling shell on
the terminal's alternate screen and returns its status. Prompts draw at the top,
and the earlier text comes back when the flow ends, also on exit or a signal.
Without an alternate screen the flow runs inline. The screen has no scrollback,
so print results after it closes. Suspend keys are off while it is open, and
text the flow writes to a terminal's standard error is printed once it closes.

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
| Active tab | Bold underline; reverse video while the tabs have the focus |
| Changed value | Yellow |
| Key that two rows share | Red |
| Column header, note, read-only row, separator, key hint | Dim |
| Message that other rows changed too | Yellow |
| Message that refuses an action | Red |

Checked rows differ only by `[x]`. A nonempty `NO_COLOR` or `TERM=dumb`
produces plain text; without color capability only bold and dim apply.

## Keys

All interactive APIs read their active bindings at the start of each call.
Single selection uses Up, Down, Submit, Back, and Cancel; multi-selection
also uses Toggle, All, and Clear, and value rows use Toggle, Edit, and Prev/next
value. With `PICK_TABS=1` the Prev/next value keys are in use in every prompt, for
the tabs. Prev/next group jumps are available in every interactive API when bound, and prev/next tab with
`PICK_TABS=1`. `pick_dependencies` supports Back; the
compatibility entry point `pick_run` leaves it unbound.
Defaults are initialized when the library is sourced:

```bash
PICK_KEYS_UP=(Up k)
PICK_KEYS_DOWN=(Down j)
PICK_KEYS_PREV_GROUP=()
PICK_KEYS_NEXT_GROUP=()
PICK_KEYS_PREV_TAB=('[')
PICK_KEYS_NEXT_TAB=(']')
PICK_KEYS_PREV_VALUE=(Left h)
PICK_KEYS_NEXT_VALUE=(Right l)
PICK_KEYS_TOGGLE=(Space)
PICK_KEYS_EDIT=()
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
`Right`, `Space`, `Enter`, `Esc`, `Tab`, `Shift+Tab`, `Backspace`, `Cmd+Enter`,
`Option+Enter`. A literal space normalizes to `Space`. Arrow tokens recognize
unmodified CSI and SS3 terminal sequences. `Cmd+Enter` is `CSI 13;9u`, which
requires a custom terminal key mapping; tmux can pass it on as `Option+Enter`.
`Option+Enter` is Esc followed by Enter and requires the terminal to send
Option as Meta (iTerm2's “Esc+” or Terminal.app's “Use Option as Meta key”).
Windows Terminal uses Alt+Enter to toggle full screen by default.
Empty arrays disable an action. Unmapped keys have no effect. Each key
belongs to one action; repeated aliases within that action are deduplicated.

`PICK_WRAP_NAVIGATION` applies to item up/down actions, including configured
aliases, and defaults to `1`: Down from the last row wraps to the first, and
Up from the first wraps to the last, by way of the tabs where there are any. Set it
to `0` to retain bounded movement.
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

`pick_choices` moves the focused row to its next allowed value on Toggle and Next
value and to the previous one on Prev value, and edits it on Edit, which on a row
that cannot be edited does what Toggle does. It submits any values but a shared key,
after the confirmation if there is one, and returns `3` on Back. Prev/next tab keys
wrap around. `pick_keybinding` uses Toggle, Submit, Back, and Cancel;
while a key is typed, Enter takes it, Esc leaves it, and letters are text.

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
- `pick_keybinding_parse <text>` reads a key in any modifier order and case, with
  common aliases such as `command+enter`. It sets `PICK_KEYBINDING_VALUE` to the
  key as written above, `PICK_KEYBINDING_KEY` to its name, `PICK_KEYBINDING_CODE` to its
  virtual key code, `PICK_KEYBINDING_FLAGS` to its modifier flags, with the Globe flag
  for keys macOS always marks with it, and `PICK_KEYBINDING_CHAR` to the code of the
  character the key types unshifted, or `65535`. It returns `1` for other text, with
  the reason in `PICK_KEYBINDING_ERROR`.
- `pick_keybinding_decode <code> <flags>` sets the same variables from a virtual key
  code and modifier flags, leaving Globe out for keys macOS always marks with it.
  It returns `1` for a code without a name.
- `pick_keybinding_format <text>` sets `PICK_TEXT` to the symbols of a key, or of
  modifiers alone; other text stays as it is.
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
./demo keybinding
./demo keys
./demo nested
./demo separators
./demo wizard
./demo screen
NO_COLOR=1 ./demo checkbox
```

Sources are in `examples/`; each script can also be run directly with Bash.
The examples display a prompt and print its result. `select` shows single
selection with an initial focus; `checkbox` shows initial checked state,
repeated labels with distinct IDs, and notes. `dependencies` shows
transitive automatic selection and cascading deselection, then prints each
selected ID as direct or auto with the selected IDs that require it; `lock`
shows the alternative locking behavior. `choices` shows value rows in tabs,
with rows that turn off with what they require, a submit tab, and a confirmation; `keybinding` shows a key per row
in columns, with a check, and a key on its own. `nested` demonstrates four levels,
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

`examples/keys.sh` uses w/s or arrows to move, x/Space to toggle,
uppercase A/C to select/clear all, f/Enter to submit, and z/Esc to cancel.
The replaced j/k, a/n and q/Q bindings are inactive in this example.

## Build and release

`bash scripts/bundle.sh` regenerates the standalone `dist/bash-prompts.sh`
from `lib/bash-prompts.sh` and `lib/bash-prompts/`; the output is
deterministic and ignored by Git. To publish, set `PICK_VERSION`, then push
the matching tag (`v0.11.2` for `"0.11.2"`): the release workflow rebuilds
the bundle, checks it, and attaches `bash-prompts.sh` and `LICENSE` to the
GitHub Release.

## License

MIT; see [LICENSE](LICENSE).
