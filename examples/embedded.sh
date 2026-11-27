#!/bin/bash
# Left tabs inside a sub-tab, beside ordinary tabs and sub-tabs. The Shared
# actions sub-tab holds a column of actions under their categories, each
# opening into a panel of key rows with column headers of its own; Esc, and Up
# from the first action, leave the column for the sub-tabs, and [ ] move past
# it. The unified key sets the key of every application that is not locked.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/bash-prompts.sh" || exit 2

PICK_PROMPT='Setup'
PICK_TABS=1
pick_group general 'General'
pick_group keys 'Keybindings'
pick_group macos 'macOS' keys
pick_group shared 'Shared actions' keys
PICK_GROUP_COLUMNS[${#PICK_GROUP_ID[@]} - 1]=$'\tDefault key\tKeybinding'
PICK_SUBTABS=(keys)
PICK_LEFTTABS=(shared)
PICK_SUBMIT_TAB=submit
PICK_TAB=shared
PICK_COLUMNS=('Action' 'Default' 'Key')
PICK_KEYS_TOGGLE=(Space)
PICK_KEYS_EDIT=(Enter)
PICK_KEYS_SUBMIT=()
PICK_ON_CHANGE=on_change

PICK_ID=() PICK_LABEL=() PICK_GROUP=() PICK_VALUES=() PICK_CURRENT=() PICK_EDIT=() PICK_CELLS=()
PICK_LABEL_STYLE=() PICK_DISABLED=() PICK_KEYBINDING_DEFAULT=() PICK_KEYBINDING_SCOPE=()
UNIFIED=()
setting() {
    # $1 = ID, $2 = label, $3 = values.
    local i=${#PICK_ID[@]}
    PICK_ID[i]=$1 PICK_LABEL[i]=$2 PICK_GROUP[i]=general PICK_VALUES[i]=$3 UNIFIED[i]=-1
}
row() {
    # $1 = ID, $2 = label, $3 = group, $4 = default key, $5 = current value,
    # $6 = scope, $7 = its Unified row, if any.
    local i=${#PICK_ID[@]}
    PICK_ID[i]=$1 PICK_LABEL[i]=$2 PICK_GROUP[i]=$3 PICK_VALUES[i]='default, off'
    PICK_CURRENT[i]=$5 PICK_EDIT[i]=pick_keybinding PICK_KEYBINDING_DEFAULT[i]=$4
    PICK_KEYBINDING_SCOPE[i]=$6 UNIFIED[i]=${7:--1}
    pick_keybinding_format "$4"
    PICK_CELLS[i]=$PICK_TEXT
}
action() {
    # $1 = ID, $2 = label, $3 = category, then default:current for VS Code,
    # iTerm2, and Chrome, which is locked.
    local u=${#PICK_ID[@]} app spec
    local -a apps=(vscode 'VS Code' iterm 'iTerm2' chrome 'Chrome')
    pick_group "$1" "$2" "$3"
    pick_group "$1-apps" 'Applications' "$1"
    row "$1" 'Unified' "$1" '' default unified "$u"
    shift 3
    for ((app=0; app<6; app+=2)); do
        spec=$1
        shift
        row "${PICK_ID[u]}-${apps[app]}" "${apps[app + 1]}" "${PICK_ID[u]}-apps" "${spec%%:*}" "${spec#*:}" "${apps[app]}" "$u"
    done
    PICK_DISABLED[${#PICK_ID[@]} - 1]='locked'
}
on_change() {
    # $1 = row that changed, if any. A unified value overwrites the
    # applications that are not locked; one that differs warns, and so does
    # its Unified row. A locked one is red.
    local u j
    if [[ -n ${1-} && ${UNIFIED[$1]} == "$1" ]]; then
        for ((j=$1 + 1; j<${#PICK_ID[@]} && UNIFIED[j] == $1; j++)); do
            [[ -n ${PICK_DISABLED[j]-} ]] || PICK_CHOICE[j]=${PICK_RESULT[$1]}
        done
    fi
    for ((u=0; u<${#PICK_ID[@]}; u++)); do
        [[ ${UNIFIED[u]} == "$u" ]] || continue
        PICK_LABEL_STYLE[u]=strong
        for ((j=u + 1; j<${#PICK_ID[@]} && UNIFIED[j] == u; j++)); do
            PICK_LABEL_STYLE[j]=
            if [[ -n ${PICK_DISABLED[j]-} ]]; then PICK_LABEL_STYLE[j]=error; continue; fi
            [[ ${PICK_CHOICE[j]} != "${PICK_CHOICE[u]}" ]] || continue
            PICK_LABEL_STYLE[j]=warning
            PICK_LABEL_STYLE[u]=warning
        done
    done
}

setting appearance 'Appearance' 'auto, light, dark'
setting updates 'Check for updates' 'weekly, daily, never'
row next-window 'Next window' macos cmd+grave default system
row overview 'Overview' macos ctrl+up default system
row capture 'Capture the screen' macos shift+cmd+4 off system
pick_group windows 'Tabs & windows' shared
action new-tab 'New tab' windows cmd+t:default cmd+t:default cmd+t:default
action close-tab 'Close tab' windows cmd+w:default cmd+w:default cmd+w:default
pick_group commands 'Find & commands' shared
action find 'Find' commands cmd+f:default cmd+f:option+f cmd+f:default
action palette 'Command palette' commands shift+cmd+p:default shift+cmd+o:default cmd+l:default
pick_group submit 'Submit'

if pick_choices; then
    printf '%s (last shown: %s)\n' "$PICK_PROMPT" "$PICK_TAB"
    for ((i=0; i<${#PICK_ID[@]}; i++)); do
        [[ ${PICK_RESULT[i]} != "${PICK_CURRENT[i]}" ]] || continue
        printf '  %s: %s -> %s\n' "${PICK_ID[i]}" "${PICK_CURRENT[i]}" "${PICK_RESULT[i]}"
    done
else
    rc=$?
    if [[ $rc == 1 ]]; then printf 'Cancelled.\n'
    else printf 'Prompt failed (status %s).\n' "$rc" >&2; fi
    exit "$rc"
fi
