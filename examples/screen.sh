#!/bin/bash
# Value rows and a confirmation on the alternate screen.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/bash-prompts.sh" || exit 2

ids=(editor formatter notes sync)
labels=('Editor' 'Formatter' 'Notes' 'Sync service')
current=('installed' 'not installed' 'installed' 'not installed')
values=('installed, remove' 'not installed, install' 'installed, update, remove' 'not installed, install')
details=('/Applications/Editor.app' '/usr/local/bin/formatter' '/Applications/Notes.app' '/Applications/Sync.app; starts at login and asks for a password once')
choice=("${current[@]}")

choose() {
    local rc=0
    PICK_PROMPT='Software'
    PICK_ID=("${ids[@]}")
    PICK_LABEL=("${labels[@]}")
    PICK_VALID=(); PICK_NOTE=()
    PICK_VALUES=("${values[@]}")
    PICK_CURRENT=("${current[@]}")
    PICK_CHOICE=("${choice[@]}")
    PICK_KEYS_TOGGLE=(Space); PICK_KEYS_BACK=()
    pick_choices || rc=$?
    choice=("${PICK_CHOICE[@]}")
    return "$rc"
}

# The same rows without a Toggle key, limited to those that change.
confirm() {
    local i rc=0
    PICK_PROMPT='Apply these changes?'
    for ((i=0; i<${#ids[@]}; i++)); do
        PICK_VALID[i]=1
        [[ ${choice[i]} != "${current[i]}" ]] || PICK_VALID[i]=0
        PICK_NOTE[i]=${details[i]}
    done
    PICK_KEYS_TOGGLE=(); PICK_KEYS_BACK=(Shift+Tab)
    pick_choices || rc=$?
    return "$rc"
}

flow() {
    local rc
    while true; do
        choose || return
        [[ ${choice[*]} != "${current[*]}" ]] || return 0
        rc=0
        confirm || rc=$?
        ((rc == 3)) || return "$rc"
    done
}

rc=0
pick_screen flow || rc=$?
if ((rc == 1)); then printf 'Cancelled.\n'
elif ((rc != 0)); then printf 'Prompt failed (status %s).\n' "$rc" >&2
elif [[ ${choice[*]} == "${current[*]}" ]]; then printf 'No changes.\n'
else
    for ((i=0; i<${#ids[@]}; i++)); do
        [[ ${choice[i]} == "${current[i]}" ]] || printf '%s: %s -> %s\n' "${ids[i]}" "${current[i]}" "${choice[i]}"
    done
fi
exit "$rc"
