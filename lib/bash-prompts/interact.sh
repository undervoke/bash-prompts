# bash-prompts: public entry points and the interactive loop.
# Function definitions only; sourced in the caller shell by lib/bash-prompts.sh.

pick_run() {
    local PICK_MODE=dependencies PICK_ALLOW_EMPTY=0 PICK_ALLOW_BACK=0 PICK_PRESERVE_INITIAL=0 i
    case ${PICK_DEPENDENCY_MODE:-cascade} in
        cascade|lock) ;;
        *) pick_err "unknown dependency mode '${PICK_DEPENDENCY_MODE}'"; return 1 ;;
    esac
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        PICK_DIRECT[i]=0; PICK_STATE[i]=0; PICK_AUTO[i]=0
    done
    pick_close || return 1
    if pick_interact; then return 0; else return 1; fi
}

pick_interact() {
    local key seq part rc=1 start i resized
    pick_prepare_keys || return 2
    pick_build_focus || return 2
    ((${#PICK_FOCUS[@]})) || { pick_err "no selectable items"; return 2; }
    PICK_CURSOR=0
    if [[ $PICK_MODE == single ]]; then
        for ((i=0; i<${#PICK_FOCUS[@]}; i++)); do
            if [[ ${PICK_FOCUS[i]} == "$PICK_INITIAL_INDEX" ]]; then PICK_CURSOR=$i; break; fi
        done
    fi
    PICK_OFFSET=0
    PICK_MSG=
    PICK_GOT_SIGNAL=
    PICK_PREV_COUNT=0
    PICK_PREV_ROWS=
    PICK_PREV_COLS=
    pick_traps_save
    trap 'pick_on_int' INT
    trap 'pick_on_term' TERM
    if ! pick_setup_term; then
        pick_cleanup_term
        PICK_SAVED_STTY=
        pick_traps_restore
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
        pick_err "interactive selection needs a terminal"
        return 2
    fi
    pick_recalc_locks
    while true; do
        if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break; fi
        # A refused render (pending interrupt, or an unpaintable terminal)
        # ends the session instead of blocking for keys on a dead screen.
        pick_render || { rc=1; break; }
        if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break; fi
        # The read carries a one-second timeout as an interrupt backstop:
        # a returning caller trap resumes inside read, so without it the
        # cancel would wait for the next keypress. A failure ends the
        # session unless it is a proven timeout with no pending interrupt;
        # only elapsed time distinguishes the two on Bash 3.2, where both
        # report the same status.
        key=
        resized=0
        while true; do
            start=$SECONDS
            if IFS= read -rsn1 -t 1 key; then break; fi
            if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break 2; fi
            if (( SECONDS - start >= 1 )); then
                # The timeout tick also picks up a resized terminal.
                pick_term_size
                [[ $PICK_TROWS == "$PICK_PREV_ROWS" && $PICK_TCOLS == "$PICK_PREV_COLS" ]] || { resized=1; break; }
                continue
            fi
            rc=1; break 2
        done
        # A key that arrived after a returning handler fired must not be
        # dispatched: the terminal is already restored, so cancel instead
        # of acting on stale input.
        if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break; fi
        ((resized)) && continue
        if [[ $key == $'\e' ]]; then
            pick_read_escape
            if [[ -n $seq ]]; then
                case $seq in
                    '['|'O')
                        # Consume the whole terminal sequence, even if it
                        # is unmapped, so its tail cannot trigger a plain key.
                        while IFS= read -rsn1 -t 1 part; do
                            [[ -z ${PICK_GOT_SIGNAL:-} ]] || break
                            seq="$seq$part"
                            [[ $part == [@-~] ]] && break
                            [[ $part == [\ -?] ]] || break
                        done
                        ;;
                esac
            fi
            if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break; fi
            case $seq in
                '') key=Esc ;;
                '[A'|'OA') key=Up ;;
                '[B'|'OB') key=Down ;;
                '[C'|'OC') key=Right ;;
                '[D'|'OD') key=Left ;;
                '[Z') key=Shift+Tab ;;
                *) key= ;;
            esac
        else
            case $key in
                ' ') key=Space ;;
                ''|$'\n'|$'\r') key=Enter ;;
                $'\t') key=Tab ;;
                $'\177'|$'\b') key=Backspace ;;
            esac
        fi
        pick_key_action "$key"
        case $PICK_KEY_ACTION in
            up)
                PICK_MSG=
                if ((PICK_CURSOR > 0)); then PICK_CURSOR=$((PICK_CURSOR - 1))
                elif [[ ${PICK_WRAP_NAVIGATION:-1} != 0 ]]; then PICK_CURSOR=$((${#PICK_FOCUS[@]} - 1)); fi
                ;;
            down)
                PICK_MSG=
                if ((PICK_CURSOR < ${#PICK_FOCUS[@]}-1)); then PICK_CURSOR=$((PICK_CURSOR + 1))
                elif [[ ${PICK_WRAP_NAVIGATION:-1} != 0 ]]; then PICK_CURSOR=0; fi
                ;;
            prev_group) PICK_MSG=; pick_jump_group -1 ;;
            next_group) PICK_MSG=; pick_jump_group 1 ;;
            prev_tab) PICK_MSG=; pick_switch_tab -1 ;;
            next_tab) PICK_MSG=; pick_switch_tab 1 ;;
            toggle) pick_action toggle ;;
            all) pick_action all ;;
            clear) pick_action clear ;;
            cancel) rc=1; break ;;
            back) rc=3; break ;;
            submit)
                if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break; fi
                if [[ $PICK_MODE == dependencies && ${PICK_ALLOW_EMPTY:-0} == 0 && $(pick_sel_count) == 0 ]]; then pick_message "$PICK_STYLE_ERROR" "Check at least one item to submit."
                else rc=0; break; fi
                ;;
        esac
    done
    pick_cleanup_term
    PICK_SAVED_STTY=
    pick_traps_restore
    # Cancellation precedence at the final result boundary: a returning
    # caller trap may have fired as late as the cleanup above, so the
    # pending-signal check decides the outcome after restoration.
    if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; fi
    return "$rc"
}

pick_select() {
    local PICK_MODE=single PICK_INITIAL_INDEX=-1 index
    pick_validate_items || return 2
    if [[ ${PICK_VALUE+x} ]]; then
        index=$(pick_find_id "$PICK_VALUE")
        if ((index < 0)); then
            pick_err "unknown initial ID '$PICK_VALUE'"
            return 2
        fi
        if [[ ${PICK_VALID[index]:-1} == 0 ]]; then
            pick_err "initial ID '$PICK_VALUE' is not available"
            return 2
        fi
        PICK_INITIAL_INDEX=$index
    fi
    local rc=0
    pick_interact || rc=$?
    if ((rc == 0 || rc == 3)); then
        index=${PICK_FOCUS[PICK_CURSOR]}
        PICK_VALUE=${PICK_ID[index]-${PICK_LABEL[index]}}
    fi
    return "$rc"
}

pick_multiselect() {
    local PICK_MODE=multi i
    pick_validate_items || return 2
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        if [[ ${PICK_VALID[i]:-1} != 0 && ${PICK_STATE[i]:-0} == 1 ]]; then PICK_STATE[i]=1
        else PICK_STATE[i]=0; fi
    done
    pick_interact
}

pick_dependencies() {
    local PICK_MODE=dependencies PICK_ALLOW_EMPTY=1 PICK_ALLOW_BACK=1 PICK_PRESERVE_INITIAL=1 i
    local -a initial=("${PICK_STATE[@]}")
    case ${PICK_DEPENDENCY_MODE:-cascade} in
        cascade|lock) ;;
        *) pick_err "unknown dependency mode '${PICK_DEPENDENCY_MODE}'"; return 2 ;;
    esac
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        PICK_DIRECT[i]=0
        PICK_STATE[i]=0
        PICK_AUTO[i]=0
    done
    # Validate the graph without changing the caller's preselected baseline.
    pick_close || return 2
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        if [[ ${PICK_VALID[i]:-1} != 0 && ${initial[i]:-0} == 1 ]]; then
            PICK_DIRECT[i]=1; PICK_STATE[i]=1
        fi
    done
    pick_interact
}
