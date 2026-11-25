# bash-prompts: grouped selection for Bash 3.2.
#
# SPDX-License-Identifier: MIT
#
# Public API (other pick_* / PICK_* names are internal):
# Input arrays are parallel, dense, zero-based.
#   PICK_ID[i]      unique identity; if unset, uses PICK_LABEL[i].
#   PICK_LABEL[i]   display text.
#   PICK_NOTE[i]    optional muted text after the label, such as a status.
#   PICK_GROUP[i]   group ID, or single-level text without group definitions.
#   PICK_GROUP_ID / PICK_GROUP_LABEL / PICK_GROUP_PARENT: parallel group
#     definitions; an empty parent is the root, an unset label uses the ID.
#   PICK_MAX_GROUP_DEPTH: maximum parent-chain depth (default 8).
#   PICK_GROUP_JUMP_DEPTH: structural depth targeted by prev/next group
#     jumps (default 1; root groups are depth 1).
#   PICK_GROUP_TAIL: group IDs rendered last among their siblings.
#   PICK_SEPARATOR_BEFORE / PICK_SEPARATOR_LABEL: parallel display-only
#     separators, anchored before item IDs; an empty anchor appends one.
#     An empty label draws a line. Excluded anchors hide their separators.
#   PICK_VALID[i]   1 includes a row, 0 excludes it; unset means 1.
#   PICK_DISABLED[i] optional reason a visible checkbox cannot change.
#   PICK_STATE[i]   0/1 selected state: input/output for pick_multiselect.
#   PICK_VALUE      single selection input/output ID; unset starts at first row.
#   PICK_PROMPT     one line shown above the list; unset uses a generic title.
#   PICK_TABS       1 shows the root groups as tabs below the prompt.
#   PICK_TAB        active tab's group ID: input/output; an unknown or unset
#     ID starts at the first tab.
# Value rows (pick_choices) additionally use:
#   PICK_VALUES[i]  comma-separated values; a row always holds one of them.
#   PICK_CURRENT[i] value the row starts from; unset uses the first value.
#   PICK_CHOICE[i]  picked value: input/output; unset uses the current value.
#   PICK_OFF[i]     comma-separated values that leave the row off for the
#     rows whose PICK_DEPS name it.
#   PICK_WHILE_OFF[i] optional value from PICK_VALUES, used when a prerequisite
#     is turned off or the row starts at that value with a prerequisite off.
#     Only PICK_OFF values can override it while it applies. With prerequisites
#     on, a choice of this value falls back to the first value in PICK_VALUES.
#   PICK_RESULT[i]  output: value in effect after prerequisites.
# Dependency API additionally uses:
#   PICK_DEPS[i]    comma-separated IDs of earlier rows; tokens are trimmed.
#   PICK_DIRECT[i]  explicit choices.
#   PICK_AUTO[i]    retained automatic choices.
#   PICK_DEPENDENCY_MODE: cascade (default) or lock.
#     cascade: unchecking a prerequisite also unchecks its dependents.
#     lock: a selected prerequisite stays locked while required.
#   IDs referenced by PICK_DEPS must be nonempty, comma-free, and have no
#   leading/trailing spaces or tabs. Display labels have no such token rule.
#
# pick_group <id> [label [parent-id]]: appends a group definition.
# pick_separator [before-id [label]]: appends a display-only separator.
# pick_select: single choice; Up/Down moves focus, Submit returns its ID in
#   PICK_VALUE. A provided initial ID must identify an included row.
# pick_multiselect: grouped checkboxes, retaining incoming PICK_STATE.
#   Empty submission is valid.
# Both return 0 submitted, 1 cancelled, 2 on invalid input or no interactive
# terminal, 3 when a Back key was pressed. Read results on 0; on 3 they hold
# the unsubmitted state at that moment.
# pick_dependencies: retains PICK_STATE, with live prerequisites on selection,
# empty submission and Back. Returns the same 0/1/2/3 statuses as multiselect.
# pick_choices: one value per row, with the same 0/1/2/3 statuses. While a
#   prerequisite is off, a row can only stay at its current value or turn off;
#   turning a prerequisite off uses PICK_WHILE_OFF if set, else turns the row off.
# pick_run: dependency-aware selection, starting with nothing checked.
#   Live closure, dependency-mode deselection, retained auto choices, and
#   nonempty submission.
#   Returns 0 submitted, 1 on cancellation or failure (0.1 compatibility).
# pick_close: noninteractive dependency closure from DIRECT + retained AUTO.
#   Returns 0 or 1; failed closure leaves selection state unchanged.
# pick_screen <command> [args]: runs a flow of prompts on the alternate screen
#   and returns its status. The screen closes however the flow ends.
# pick_find_id / pick_find_label <value>: print index or -1.
# pick_selected_indices: fills PICK_SELECTED_INDICES with included rows whose
#   PICK_STATE is 1, in input order.
# pick_required_by <index>: fills PICK_REQUIRED_BY_INDICES with included,
#   selected rows whose PICK_DEPS name that row, in input order, in any mode.
# pick_locked_by <index>: print labels of selected immediate dependents
#   in lock mode; print nothing in cascade mode.
# pick_split_csv <text>: fills PICK_SPLIT, trimming tokens and preserving
#   empty tokens, including a trailing one; empty input means no tokens.
#
# Optional keys (arrays; assign after sourcing, each replaces its action's keys):
#   PICK_KEYS_UP=(Up k)          PICK_KEYS_DOWN=(Down j)
#   PICK_KEYS_PREV_GROUP=()      PICK_KEYS_NEXT_GROUP=()
#   PICK_KEYS_PREV_TAB=(Left h)  PICK_KEYS_NEXT_TAB=(Right l)
#   PICK_KEYS_TOGGLE=(Space)     PICK_KEYS_ALL=(a)
#   PICK_KEYS_CLEAR=(n)          PICK_KEYS_SUBMIT=(Enter)
#   PICK_KEYS_CANCEL=(q Q Esc)   PICK_KEYS_BACK=()
# Elements are a single printable ASCII character or one of:
#   Up Down Left Right Space Enter Esc Tab Shift+Tab Backspace.
# Empty arrays disable an action. A key may belong to only one action.
# Prev/next group focus the first included item of the adjacent group at
# PICK_GROUP_JUMP_DEPTH; an item above that depth moves to the nearest group
# in that direction. Ctrl-C remains a terminal signal. The map is read on
# each interactive call.
# PICK_WRAP_NAVIGATION applies to item up/down actions, including
# configured aliases (default 1). Down from the last row wraps to the
# first, and Up from the first wraps to the last; 0 retains bounded
# movement.
# Toggle moves a value row to its next value. All and Clear bindings apply
# only to multiselect and dependencies; tab bindings only with PICK_TABS.
# Back applies to every entry point but pick_run.
#
# Styles are fixed by role: bold cyan title, cyan group headers, bold focused
#   row, reversed active tab, yellow changed value and warning, dim notes,
#   read-only rows, separators and key hint, red error. Nonempty NO_COLOR or TERM=dumb gives plain text; missing color
#   capability omits colors while supported bold and dim remain.
# Prompts draw inline at the cursor and erase themselves when they end, also
#   on the alternate screen.
# The API uses one active PICK_* state in the calling Bash process.
PICK_VERSION="0.7.0"

PICK_ID=()
PICK_LABEL=()
PICK_NOTE=()
PICK_GROUP=()
PICK_GROUP_ID=()
PICK_GROUP_LABEL=()
PICK_GROUP_PARENT=()
PICK_MAX_GROUP_DEPTH=8
PICK_GROUP_JUMP_DEPTH=1
PICK_WRAP_NAVIGATION=1
PICK_GROUP_TAIL=()
PICK_TABS=0
PICK_TAB=
PICK_SEPARATOR_BEFORE=()
PICK_SEPARATOR_LABEL=()
PICK_DEPS=()
PICK_VALID=()
PICK_DISABLED=()
PICK_DIRECT=()
PICK_STATE=()
unset PICK_VALUE
PICK_AUTO=()
PICK_VALUES=()
PICK_CURRENT=()
PICK_CHOICE=()
PICK_OFF=()
PICK_WHILE_OFF=()
PICK_RESULT=()
PICK_SPLIT=()
PICK_SELECTED_INDICES=()
PICK_REQUIRED_BY_INDICES=()
PICK_FOCUS=()
PICK_FLOCK=()
PICK_CURSOR=0
PICK_OFFSET=0
PICK_MSG=
PICK_MSG_STYLE=
PICK_GID=()
PICK_GLABEL=()
PICK_GPARENT=()
PICK_GDEPTH=()
PICK_GLEVEL=()
PICK_GCHILDREN=()
PICK_GLINKED=()
PICK_GROW=()
PICK_IGROUP=()
PICK_ROOT=0
PICK_TAB_GROUPS=()
PICK_TAB_CURSOR=()
PICK_TAB_OFFSET=()
PICK_TAB_AT=0
PICK_DEP_ROWS=()
PICK_ON=()
PICK_MISSING=()
PICK_WITHDRAWN=()
PICK_NEXT=
PICK_LABEL_CELLS=0
PICK_VALUE_CELLS=0
PICK_VALUE_COLUMN=0
PICK_SEP_ANCHOR=()
PICK_FOCUS_ROW=()
PICK_DKIND=()
PICK_DREF=()
PICK_DGROUP=()
PICK_STICKY=()
PICK_HINT=()
PICK_TROWS=24
PICK_TCOLS=80
PICK_CLEAR=0
PICK_CIVIS=0
PICK_UP=
PICK_ED=
PICK_HOME=
PICK_TOP=
PICK_SCREEN=0
PICK_SCREEN_LEAVE=
PICK_SCREEN_STTY=
PICK_SCREEN_HELD=
PICK_SCREEN_TRAPS=
PICK_SCREEN_EXIT=
PICK_CLIPPED=
PICK_CELLS=0
PICK_ELLIPSIS=
PICK_WRAPPED=()
PICK_NOTES=
PICK_LINE=
PICK_EL=
PICK_PREV_COUNT=0
PICK_PREV_ROWS=
PICK_PREV_COLS=
PICK_FRAME=()
PICK_FRAME_STYLE=()
PICK_FRAME_SPANS=()
PICK_ROW=
PICK_ROW_STYLE=
PICK_ROW_SPANS=
PICK_TITLE=
PICK_STYLE_TITLE=
PICK_STYLE_PLAIN=
PICK_STYLE_GROUP=
PICK_STYLE_TAB=
PICK_STYLE_CHANGED=
PICK_STYLE_FOCUS=
PICK_STYLE_MUTED=
PICK_STYLE_WARNING=
PICK_STYLE_ERROR=
PICK_STYLE_RESET=
PICK_SAVED_INT=
PICK_SAVED_TERM=
PICK_SAVED_STTY=
PICK_TRAPS_ARMED=0
PICK_SNAP_DIRECT=()
PICK_SNAP_STATE=()
PICK_SNAP_AUTO=()
PICK_GOT_SIGNAL=
PICK_QUIET=0
PICK_DEPNAMES=
PICK_GTOT=0
PICK_GSEL=0
PICK_JUMP_DEPTH=1
PICK_REFGROUP=-1
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
PICK_BOUND_KEYS=()
PICK_BOUND_ACTIONS=()
PICK_KEY_HELP=()
PICK_KEY_ACTION=

# Development entry: load the feature modules in the caller shell.
# The modules hold function definitions only, so dynamic-scope behavior
# matches the previous single file. An ordinary checkout runs demo and
# examples from this file with no build step; releases distribute these
# same sources as one generated bash-prompts.sh.
_BASH_PROMPTS_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || return 1
source "$_BASH_PROMPTS_DIR/bash-prompts/core.sh" || return 1
source "$_BASH_PROMPTS_DIR/bash-prompts/groups.sh" || return 1
source "$_BASH_PROMPTS_DIR/bash-prompts/selection.sh" || return 1
source "$_BASH_PROMPTS_DIR/bash-prompts/choices.sh" || return 1
source "$_BASH_PROMPTS_DIR/bash-prompts/terminal.sh" || return 1
source "$_BASH_PROMPTS_DIR/bash-prompts/screen.sh" || return 1
source "$_BASH_PROMPTS_DIR/bash-prompts/keys.sh" || return 1
source "$_BASH_PROMPTS_DIR/bash-prompts/render.sh" || return 1
source "$_BASH_PROMPTS_DIR/bash-prompts/interact.sh" || return 1
unset _BASH_PROMPTS_DIR
