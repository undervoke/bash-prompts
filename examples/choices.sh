#!/bin/bash
# One value per row in tabs; rows turn off with what they require, and the last
# tab asks to submit.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/bash-prompts.sh" || exit 2

PICK_PROMPT='Settings'
PICK_TABS=1
pick_group editor 'Editor'
pick_group system 'System'
pick_group power 'Power' system
pick_group network 'Network' system
pick_group submit 'Submit'
PICK_SUBMIT_TAB=submit
PICK_SUBMIT_PROMPT='Apply these settings?'
PICK_KEYS_TOGGLE=(Space Enter)
PICK_KEYS_SUBMIT=()
PICK_ID=(editor keymap font sync sleep firewall)
PICK_LABEL=('Editor' 'Editor key map' 'Editor font' 'Editor sync service' 'Sleep rules' 'Firewall')
PICK_GROUP=(editor editor editor network power network)
PICK_VALUES=(
    'installed, update, remove'
    'applied, remove'
    'not applied, apply'
    'not applied, apply'
    'custom, laptop, server'
    'on'
)
PICK_OFF=('remove' 'remove' 'not applied' 'not applied')
PICK_DEPS=('' editor editor editor)
PICK_DISABLED=('' '' '' '' '' 'Managed by your organization')

if pick_choices; then
    printf '%s\n' "$PICK_PROMPT"
    for ((i=0; i<${#PICK_ID[@]}; i++)); do
        [[ ${PICK_RESULT[i]} != "${PICK_CURRENT[i]}" ]] || continue
        printf '  %s: %s -> %s\n' "${PICK_ID[i]}" "${PICK_CURRENT[i]}" "${PICK_RESULT[i]}"
    done
else
    rc=$?
    if [[ $rc == 1 ]]; then printf 'Cancelled.\n'
    else printf 'Prompt failed (status %s).\n' "$rc" >&2; fi
    exit "$rc"
fi
