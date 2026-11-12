#!/bin/bash
# Dependency-aware selection using IDs independently of display text.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/picker.sh" || exit 2
PICK_DEPENDENCY_MODE=${1:-cascade}

PICK_PROMPT='Which components should be set up?'
PICK_ID=(base addon bundle notes)
PICK_LABEL=('Base, shared' 'Add-on' 'Bundle' 'Notes')
PICK_GROUP=(Components Components Presets Documents)
PICK_DEPS=('' 'base' 'addon' '')
PICK_FOCUS_COLOR=cyan
PICK_SELECTED_COLOR=green
PICK_GROUP_COLOR=blue

if pick_run; then
    printf '%s\n' "$PICK_PROMPT"
    pick_selected_indices
    for i in "${PICK_SELECTED_INDICES[@]}"; do
        how=direct
        [[ ${PICK_DIRECT[i]} == 1 ]] || how=auto
        pick_required_by "$i"
        by=
        for j in "${PICK_REQUIRED_BY_INDICES[@]}"; do
            by="${by:+$by, }${PICK_ID[j]}"
        done
        printf '  %-7s %s%s\n' "$how" "${PICK_ID[i]}" "${by:+  (required by $by)}"
    done
else
    printf 'Cancelled.\n'
    exit 1
fi
