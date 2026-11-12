#!/bin/bash
# Dependency-aware selection using IDs independently of display text.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/picker.sh" || exit 2
PICK_DEPENDENCY_MODE=${1:-cascade}

PICK_ID=(base addon bundle notes)
PICK_LABEL=('Base, shared' 'Add-on' 'Bundle' 'Notes')
PICK_GROUP=(Components Components Presets Documents)
PICK_DEPS=('' 'base' 'addon' '')
PICK_FOCUS_COLOR=cyan
PICK_SELECTED_COLOR=green
PICK_GROUP_COLOR=blue

if pick_run; then
    printf 'Submitted selection:\n'
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        [[ ${PICK_STATE[i]} == 1 ]] || continue
        kind=auto
        [[ ${PICK_DIRECT[i]} == 1 ]] && kind=direct
        printf '  [%s] %s -> %s\n' "$kind" "${PICK_ID[i]}" "${PICK_LABEL[i]}"
    done
else
    printf 'Selection cancelled or unavailable.\n' >&2
    exit 1
fi
