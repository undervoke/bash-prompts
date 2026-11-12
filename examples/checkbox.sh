#!/bin/bash
# Ordinary multi-selection: initial state, independent IDs, and optional colors.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/picker.sh" || exit 2

PICK_PROMPT='Which items should be included?'
PICK_ID=(editor_primary formatter editor_notes drafts)
PICK_LABEL=('Editor' 'Formatter' 'Editor' 'Notes, drafts')
PICK_GROUP=(Tools Tools Documents Documents)
PICK_STATE=(1 0 0 0)
PICK_FOCUS_COLOR=cyan
PICK_SELECTED_COLOR=green
PICK_GROUP_COLOR=blue

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
