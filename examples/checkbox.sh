#!/bin/bash
# Ordinary multi-selection: initial state, independent IDs, and optional colors.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/picker.sh" || exit 2

PICK_ID=(editor_primary formatter editor_notes drafts)
PICK_LABEL=('Editor' 'Formatter' 'Editor' 'Notes, drafts')
PICK_GROUP=(Tools Tools Documents Documents)
PICK_STATE=(1 0 0 0)
PICK_FOCUS_COLOR=cyan
PICK_SELECTED_COLOR=green
PICK_GROUP_COLOR=blue

if pick_select; then
    printf 'Submitted selection (empty is valid):\n'
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        [[ ${PICK_STATE[i]} == 1 ]] || continue
        printf '  %s -> %s\n' "${PICK_ID[i]}" "${PICK_LABEL[i]}"
    done
else
    rc=$?
    if [[ $rc == 1 ]]; then printf 'Selection cancelled.\n'
    else printf 'Unable to open selection (status %s).\n' "$rc" >&2; fi
    exit "$rc"
fi
