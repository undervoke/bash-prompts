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
    local rc=1 i got
    pick_prepare_keys || return 2
    pick_prepare_text
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
    PICK_FIELD=
    PICK_ON_TABS=0
    PICK_SIDE_SUBMIT=0
    PICK_CONFIRMING=0
    PICK_NO_WINDOW=0
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
        if ((PICK_EDIT_FIRST)); then
            PICK_EDIT_FIRST=0
            pick_change_value
            continue
        fi
        got=0
        pick_read_key || got=$?
        ((got != 1)) || { rc=1; break; }
        ((got != 2)) || continue
        pick_key_action "$PICK_PRESSED"
        if ((PICK_CONFIRMING)); then pick_confirm_action
        else
            pick_tab_action
            pick_page_action
        fi
        case $PICK_KEY_ACTION in
            up)
                # PICK_ON_TABS is 1 on the tabs, 2 on the sub-tabs, and 3 on
                # a column of left tabs inside them, which wraps as the rows.
                PICK_MSG=
                if ((PICK_ON_TABS == 2)); then PICK_ON_TABS=1
                elif ((PICK_ON_TABS)); then
                    if [[ ${PICK_WRAP_NAVIGATION:-1} == 0 ]]; then :
                    elif ((PICK_SIDE_LEVEL == 3)); then pick_show_page "$PICK_SIDE_LAST"; PICK_ON_TABS=3
                    else
                        PICK_ON_TABS=0
                        PICK_CURSOR=$((${#PICK_FOCUS[@]} - 1))
                    fi
                elif ((PICK_CURSOR > 0)); then PICK_CURSOR=$((PICK_CURSOR - 1))
                elif ((${#PICK_TAB_GROUPS[@]} && !PICK_SIDE_LEVEL)); then
                    PICK_ON_TABS=1
                    ((!PICK_TAB_SUBS[PICK_TAB_AT])) || PICK_ON_TABS=2
                elif [[ ${PICK_WRAP_NAVIGATION:-1} != 0 ]]; then PICK_CURSOR=$((${#PICK_FOCUS[@]} - 1)); fi
                ;;
            down)
                PICK_MSG=
                if ((PICK_ON_TABS == 1 && PICK_TAB_SUBS[PICK_TAB_AT])); then PICK_ON_TABS=2
                elif ((PICK_ON_TABS)); then PICK_ON_TABS=$((PICK_SIDE_LEVEL == 3 ? 3 : 0))
                elif ((PICK_CURSOR < ${#PICK_FOCUS[@]}-1)); then PICK_CURSOR=$((PICK_CURSOR + 1))
                elif [[ ${PICK_WRAP_NAVIGATION:-1} != 0 ]]; then
                    PICK_CURSOR=0
                    if ((${#PICK_TAB_GROUPS[@]} && !PICK_SIDE_LEVEL)); then PICK_ON_TABS=1; fi
                fi
                ;;
            leave)
                PICK_MSG=
                if ((!PICK_ON_TABS && PICK_SIDE_LEVEL)); then PICK_ON_TABS=$PICK_SIDE_LEVEL
                elif ((PICK_ON_TABS != 2 && PICK_TAB_SUBS[PICK_TAB_AT])); then PICK_ON_TABS=2
                else PICK_ON_TABS=1; fi
                ;;
            open) PICK_MSG=; PICK_ON_TABS=0 ;;
            side_prev) PICK_MSG=; pick_side_move -1 ;;
            side_next) PICK_MSG=; pick_side_move 1 ;;
            prev_group) PICK_MSG=; pick_jump_group -1 ;;
            next_group) PICK_MSG=; pick_jump_group 1 ;;
            prev_tab) PICK_MSG=; pick_switch_page -1 ;;
            next_tab) PICK_MSG=; pick_switch_page 1 ;;
            prev_bar) PICK_MSG=; if ((PICK_ON_TABS == 2)); then pick_switch_subtab -1; else pick_switch_tab -1; fi ;;
            next_bar) PICK_MSG=; if ((PICK_ON_TABS == 2)); then pick_switch_subtab 1; else pick_switch_tab 1; fi ;;
            toggle) if [[ $PICK_MODE == choices ]]; then pick_change_value; else pick_action toggle; fi ;;
            edit) pick_edit_row ;;
            prev_value) [[ $PICK_MODE != choices ]] || pick_next_value -1 ;;
            next_value) [[ $PICK_MODE != choices ]] || pick_next_value ;;
            confirmed) rc=0; break ;;
            all) pick_action all ;;
            clear) pick_action clear ;;
            cancel) rc=1; break ;;
            back) rc=3; break ;;
            submit)
                if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break; fi
                if [[ $PICK_MODE == dependencies && ${PICK_ALLOW_EMPTY:-0} == 0 && $(pick_sel_count) == 0 ]]; then pick_message "$PICK_STYLE_ERROR" "Check at least one item to submit."
                elif [[ $PICK_MODE == choices ]] && pick_refuse_choices; then :
                elif [[ $PICK_MODE == choices && -n ${PICK_CONFIRM_PROMPT-} ]]; then pick_confirm_open
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

pick_choices() {
    local PICK_MODE=choices
    pick_validate_items || return 2
    pick_prepare_choices || return 2
    pick_interact
}
