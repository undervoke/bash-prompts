#!/bin/bash
# Recursive groups, tail ordering, separators, and opt-in group jumps.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/bash-prompts.sh" || exit 2

PICK_PROMPT='Which parts should be installed?'
PICK_ID=(editor formatter notes lint web templates snippets)
PICK_LABEL=('Editor' 'Formatter' 'Notes' 'Linter' 'Web template' 'Template images' 'Code snippets')
pick_group tools 'Tools'
pick_group code 'Code' tools
pick_group editors 'Editors' code
pick_group terminal 'Terminal' editors
pick_group text 'Text' tools
pick_group lint 'Lint' tools
pick_group documents 'Documents'
pick_group web 'Web' documents
pick_group media 'Media' documents
pick_group images 'Images' media
pick_group snippets 'Snippets' media
PICK_GROUP=(terminal code text lint web images snippets)
PICK_GROUP_TAIL=(text)
# Jump between groups at depth 2: Code, Lint, Text (tail), Web, Media.
PICK_GROUP_JUMP_DEPTH=2
PICK_KEYS_PREV_GROUP=(Left h)
PICK_KEYS_NEXT_GROUP=(Right l)
pick_separator formatter '--- Formatting ---'
pick_separator web '--- Reference material ---'

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
