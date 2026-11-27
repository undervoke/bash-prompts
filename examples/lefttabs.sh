#!/bin/bash
# Tabs in a left column, each opening into a panel of key rows. Right and
# Space turn a key through default, off, and the keys entered, Enter enters a
# new one, and Left returns to the column. The unified key sets the key of
# every application that is not locked, labels warn where an application's
# key differs from it, and a locked one is red. Submit is an item of the
# column that submits on Enter.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/bash-prompts.sh" || exit 2

PICK_PROMPT='Shared actions'
PICK_LEFTTABS=1
PICK_LEFTTABS_FRAME=1
PICK_SUBMIT_TAB=submit
PICK_TAB=find
PICK_COLUMNS=('' 'Default key' 'Keybinding')
PICK_KEYS_TOGGLE=(Space)
PICK_KEYS_EDIT=(Enter)
PICK_KEYS_SUBMIT=()
PICK_ON_CHANGE=on_change

PICK_ID=() PICK_LABEL=() PICK_GROUP=() PICK_VALUES=() PICK_CURRENT=() PICK_EDIT=() PICK_CELLS=()
PICK_LABEL_STYLE=() PICK_DISABLED=() PICK_KEYBINDING_DEFAULT=() PICK_KEYBINDING_SCOPE=()
UNIFIED=()
row() {
    # $1 = ID, $2 = label, $3 = group, $4 = default key, $5 = current value,
    # $6 = scope, $7 = its Unified row.
    local i=${#PICK_ID[@]}
    PICK_ID[i]=$1 PICK_LABEL[i]=$2 PICK_GROUP[i]=$3 PICK_VALUES[i]='default, off'
    PICK_CURRENT[i]=$5 PICK_EDIT[i]=pick_keybinding PICK_KEYBINDING_DEFAULT[i]=$4
    PICK_KEYBINDING_SCOPE[i]=$6 UNIFIED[i]=${7:-$i}
    pick_keybinding_format "$4"
    PICK_CELLS[i]=$PICK_TEXT
}
action() {
    # $1 = ID, $2 = label, $3 = group of its tab, then default:current for
    # VS Code, iTerm2, Codex, and Chrome, which is locked.
    local u=${#PICK_ID[@]} app spec
    local -a apps=(vscode 'VS Code' iterm 'iTerm2' codex 'Codex' chrome 'Chrome')
    pick_group "$1" "$2" "$3"
    pick_group "$1-apps" 'Applications' "$1"
    row "$1" 'Unified' "$1" '' default unified
    shift 3
    for ((app=0; app<8; app+=2)); do
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

pick_group windows 'Tabs & windows'
action new-tab 'New tab' windows cmd+t:default cmd+t:default cmd+t:default cmd+t:default
action close-tab 'Close tab' windows cmd+w:default cmd+w:default cmd+w:default cmd+w:default
pick_group commands 'Find & commands'
action find 'Find' commands cmd+f:default cmd+f:option+f cmd+f:default cmd+f:default
action find-next 'Find next' commands cmd+g:default cmd+g:default cmd+g:default cmd+g:default
action palette 'Command palette' commands shift+cmd+p:default shift+cmd+o:default cmd+k:default cmd+l:default
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
