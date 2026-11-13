#!/bin/bash
# Nested groups: a group split into sub-groups, and a group kept last.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/picker.sh" || exit 2

PICK_PROMPT='Which parts should be installed?'
PICK_ID=(editor formatter notes lint web templates snippets)
PICK_LABEL=('Editor' 'Formatter' 'Notes' 'Linter' 'Web template' 'Template images' 'Code snippets')
PICK_GROUP=(Tools Tools Tools Tools Documents Documents Documents)
PICK_SUBGROUP=(Code Code Text Lint Web Media Media)
PICK_SUBSUBGROUP=('Editor' 'Formatter' '' '' '' 'Images' 'Snippets')
PICK_GROUP_TAIL=(Text)
PICK_FOCUS_COLOR=cyan
PICK_SELECTED_COLOR=green
PICK_GROUP_COLOR=blue

if pick_multiselect; then
    printf '%s\n' "$PICK_PROMPT"
    pick_selected_indices
    for i in "${PICK_SELECTED_INDICES[@]}"; do
        printf '  %s\n' "${PICK_ID[i]}"
    done
else
    rc=$?
    if [[ $rc == 1 ]]; then printf 'Cancelled.\n'
    else printf 'Prompt failed (status %s).\n' "$rc" >&2; fi
    exit "$rc"
fi
