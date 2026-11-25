#!/bin/bash
# Value rows and a confirmation on the alternate screen.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/bash-prompts.sh" || exit 2

details=('/Applications/Editor.app' '/usr/local/bin/formatter' '/Applications/Notes.app' '/Applications/Sync.app; starts at login and asks for a password once')

review() {
    local i
    for ((i=0; i<${#PICK_ID[@]}; i++)); do
        [[ ${PICK_RESULT[i]} == "${PICK_CURRENT[i]}" ]] || PICK_REVIEW_NOTE[i]=${details[i]}
    done
}

PICK_PROMPT='Software'
PICK_ID=(editor formatter notes sync)
PICK_LABEL=('Editor' 'Formatter' 'Notes' 'Sync service')
PICK_CURRENT=('installed' 'not installed' 'installed' 'not installed')
PICK_VALUES=('installed, remove' 'not installed, install' 'installed, update, remove' 'not installed, install')
PICK_CONFIRM_PROMPT='Apply these changes?'
PICK_REVIEW=review

rc=0
pick_screen pick_choices || rc=$?
if ((rc == 1)); then printf 'Cancelled.\n'
elif ((rc != 0)); then printf 'Prompt failed (status %s).\n' "$rc" >&2
elif [[ ${PICK_RESULT[*]} == "${PICK_CURRENT[*]}" ]]; then printf 'No changes.\n'
else
    for ((i=0; i<${#PICK_ID[@]}; i++)); do
        [[ ${PICK_RESULT[i]} == "${PICK_CURRENT[i]}" ]] || printf '%s: %s -> %s\n' "${PICK_ID[i]}" "${PICK_CURRENT[i]}" "${PICK_RESULT[i]}"
    done
fi
exit "$rc"
