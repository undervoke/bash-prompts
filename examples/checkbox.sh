#!/bin/bash
# bash-prompts example: open the real interactive checkbox picker on
# harmless sample items, then print the chosen results. No installation,
# downloads, or system changes: the script only reads the terminal and
# prints the selection, or reports the cancel.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
# shellcheck disable=SC1091
source "$ROOT/lib/picker.sh" || exit 1

PICK_LABEL=(editor linter bundle notes)
PICK_GROUP=(tools tools tools notes)
PICK_DEPS=('' 'editor' 'linter' '')
PICK_VALID=(1 1 1 1)
PICK_DIRECT=(0 0 0 0)
PICK_STATE=(0 0 0 0)
PICK_AUTO=(0 0 0 0)

if pick_run; then
    printf 'checked selection:\n'
    i=
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        [[ ${PICK_STATE[i]} == 1 ]] || continue
        kind=direct
        [[ ${PICK_DIRECT[i]} == 1 ]] || kind=auto
        printf '  [%s] %s %s\n' "$kind" "[${PICK_GROUP[i]}]" "${PICK_LABEL[i]}"
    done
else
    printf 'selection cancelled; nothing chosen\n'
fi
