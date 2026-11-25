#!/bin/bash
# A key per action in columns, with off and default, a check, and one more key.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/bash-prompts.sh" || exit 2

check_key() {
    case $1 in
        cmd+space) PICK_KEYBINDING_MESSAGE='Spotlight uses this key.'; return 1 ;;
        cmd+q) PICK_KEYBINDING_MESSAGE='Most apps quit with this key.' ;;
    esac
}
PICK_KEYBINDING_CHECK=check_key

PICK_PROMPT='Keys'
PICK_COLUMNS=('Action' 'Default' 'Key')
PICK_ID=(next previous overview capture open close)
PICK_LABEL=('Next window' 'Previous window' 'Overview' 'Capture the screen' 'Open a file' 'Close a file')
pick_group system 'System'
pick_group editor 'Editor'
PICK_GROUP=(system system system system editor editor)
PICK_EDIT=(pick_keybinding pick_keybinding pick_keybinding pick_keybinding pick_keybinding pick_keybinding)
PICK_VALUES=('default, off' 'default, off' 'default, off' 'off' 'default' 'default')
PICK_OFF=(off off off off)
PICK_CURRENT=(default default ctrl+w off default default)
PICK_KEYBINDING_DEFAULT=(cmd+tab shift+cmd+tab ctrl+up '' cmd+o cmd+w)
# The editor's keys work only in the editor, so they may repeat the system's.
PICK_KEYBINDING_SCOPE=(system system system system editor editor)
for ((i=0; i<${#PICK_ID[@]}; i++)); do
    pick_keybinding_format "${PICK_KEYBINDING_DEFAULT[i]:--}"
    PICK_CELLS[i]=$PICK_TEXT
done

stop() {
    if [[ $1 == 1 ]]; then printf 'Cancelled.\n'
    else printf 'Prompt failed (status %s).\n' "$1" >&2; fi
    exit "$1"
}

pick_choices || stop "$?"
ids=("${PICK_ID[@]}"); current=("${PICK_CURRENT[@]}"); result=("${PICK_RESULT[@]}")
PICK_PROMPT='Which key opens these settings?'
pick_keybinding || stop "$?"
for ((i=0; i<${#ids[@]}; i++)); do
    [[ ${result[i]} != "${current[i]}" ]] || continue
    printf '  %s: %s -> %s\n' "${ids[i]}" "${current[i]}" "${result[i]}"
done
pick_keybinding_parse "$PICK_VALUE"
printf '  settings: %s (key code %s, flags %s)\n' "$PICK_VALUE" "$PICK_KEYBINDING_CODE" "$PICK_KEYBINDING_FLAGS"
