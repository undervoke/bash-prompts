# bash-prompts: core item utilities and non-interactive helpers.
# Function definitions only; sourced in the caller shell by lib/bash-prompts.sh.

pick_err() {
    # With PICK_QUIET set (interactive use), route the message to the
    # on-screen notice instead of writing over the terminal frame.
    if [[ ${PICK_QUIET:-0} == 1 ]]; then
        if [[ -n ${PICK_MSG-} ]]; then PICK_MSG="$PICK_MSG; $*"
        else PICK_MSG="$*"; fi
    else
        printf 'pick: %s\n' "$*" >&2
    fi
}

pick_trim() {
    local s=$1
    while [[ $s == ' '* || $s == $'\t'* ]]; do s=${s#?}; done
    while [[ $s == *' ' || $s == *$'\t' ]]; do s=${s%?}; done
    printf '%s' "$s"
}

pick_split_csv() {
    # Keep per-token normalization in the current shell because dependency
    # refresh calls it repeatedly; trim spaces/tabs, then trailing newlines
    # for compatibility with the previous $(pick_trim ...) substitution.
    PICK_SPLIT=()
    local csv=$1 part
    [[ -n $csv ]] || return 0
    while true; do
        part=${csv%%,*}
        while [[ $part == ' '* || $part == $'\t'* ]]; do part=${part#?}; done
        while [[ $part == *' ' || $part == *$'\t' ]]; do part=${part%?}; done
        while [[ $part == *$'\n' ]]; do part=${part%?}; done
        PICK_SPLIT[${#PICK_SPLIT[@]}]=$part
        [[ $csv == *,* ]] || break
        csv=${csv#*,}
    done
}

pick_find_id() {
    local want=$1 i
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        if [[ ${PICK_ID[i]-${PICK_LABEL[i]}} == "$want" ]]; then
            printf '%s' "$i"
            return 0
        fi
    done
    printf '%s' "-1"
}

pick_validate_items() {
    local i j id
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        id=${PICK_ID[i]-${PICK_LABEL[i]}}
        for ((j=0; j<i; j++)); do
            if [[ ${PICK_ID[j]-${PICK_LABEL[j]}} == "$id" ]]; then
                pick_err "duplicate ID '$id'"
                return 1
            fi
        done
    done
}

pick_find_label() {
    # $1 = label; prints the row index, or -1.
    local want=$1 i n
    n=${#PICK_LABEL[@]}
    for ((i=0; i<n; i++)); do
        if [[ ${PICK_LABEL[i]} == "$want" ]]; then printf '%s' "$i"; return 0; fi
    done
    printf '%s' "-1"
}

pick_selected_indices() {
    local i
    PICK_SELECTED_INDICES=()
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        [[ ${PICK_STATE[i]:-0} == 1 && ${PICK_VALID[i]:-1} != 0 ]] || continue
        PICK_SELECTED_INDICES[${#PICK_SELECTED_INDICES[@]}]=$i
    done
}

pick_sel_count() {
    local i n c=0
    n=${#PICK_LABEL[@]}
    for ((i=0; i<n; i++)); do [[ ${PICK_STATE[i]:-0} == 1 ]] && c=$((c + 1)); done
    printf '%s' "$c"
}
