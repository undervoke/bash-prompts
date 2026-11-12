#!/bin/bash
# Rebind every action; the same key arrays serve the interactive APIs.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/picker.sh" || exit 2

PICK_ID=(editor formatter preview)
PICK_LABEL=(Editor Formatter Preview)
PICK_GROUP=(Tools Tools Tools)
PICK_STATE=(0 0 0)

PICK_KEYS_UP=(Up w)
PICK_KEYS_DOWN=(Down s)
PICK_KEYS_TOGGLE=(Space x)
PICK_KEYS_ALL=(A)
PICK_KEYS_CLEAR=(C)
PICK_KEYS_SUBMIT=(Enter f)
PICK_KEYS_CANCEL=(Esc z)

PICK_FOCUS_COLOR=cyan
PICK_SELECTED_COLOR=green
PICK_GROUP_COLOR=blue

if pick_multiselect; then
    printf 'Submitted selection:\n'
    for ((i=0; i<${#PICK_ID[@]}; i++)); do
        [[ ${PICK_STATE[i]} == 1 ]] || continue
        printf '  %s -> %s\n' "${PICK_ID[i]}" "${PICK_LABEL[i]}"
    done
else
    rc=$?
    if [[ $rc == 1 ]]; then printf 'Selection cancelled.\n'
    else printf 'Prompt failed (status %s).\n' "$rc" >&2; fi
    exit "$rc"
fi
