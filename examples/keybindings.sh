#!/bin/bash
# Rebind every action; the same key arrays serve the interactive APIs.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/picker.sh" || exit 2

PICK_PROMPT='Which tools should be included?'
PICK_ID=(editor formatter preview)
PICK_LABEL=(Editor Formatter Preview)
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

if pick_multiselect; then
    ids=
    pick_selected_indices
    for i in "${PICK_SELECTED_INDICES[@]}"; do
        ids="${ids:+$ids, }${PICK_ID[i]}"
    done
    printf '%s %s\n' "$PICK_PROMPT" "${ids:-(none)}"
else
    rc=$?
    if [[ $rc == 1 ]]; then printf 'Cancelled.\n'
    else printf 'Prompt failed (status %s).\n' "$rc" >&2; fi
    exit "$rc"
fi
