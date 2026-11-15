#!/bin/bash
# Separators organize a flat list without defining any groups.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/bash-prompts.sh" || exit 2

PICK_PROMPT='What should happen next?'
PICK_ID=(open edit save quit)
PICK_LABEL=('Open file' 'Edit file' 'Save file' 'Quit')
pick_separator open '--- File actions ---'
pick_separator save '--- Write actions ---'
pick_separator quit
PICK_FOCUS_COLOR=cyan

if pick_select; then
    printf '%s %s\n' "$PICK_PROMPT" "$PICK_VALUE"
else
    rc=$?
    if [[ $rc == 1 ]]; then printf 'Cancelled.\n'
    else printf 'Prompt failed (status %s).\n' "$rc" >&2; fi
    exit "$rc"
fi
