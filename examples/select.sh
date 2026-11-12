#!/bin/bash
# One focused item, returned as an ID when submitted.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/picker.sh" || exit 2

PICK_ID=(terminal editor browser)
PICK_LABEL=(Terminal Editor Browser)
PICK_GROUP=(Workspace Workspace Tools)
PICK_VALUE=editor
PICK_FOCUS_COLOR=cyan
PICK_GROUP_COLOR=blue

if pick_select; then
    printf 'Selected ID: %s\n' "$PICK_VALUE"
else
    rc=$?
    if [[ $rc == 1 ]]; then printf 'Selection cancelled.\n'
    else printf 'Prompt failed (status %s).\n' "$rc" >&2; fi
    exit "$rc"
fi
