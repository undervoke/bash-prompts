# bash-prompts: dependency closure, locks, and checkbox mutations.
# Function definitions only; sourced in the caller shell by lib/bash-prompts.sh.

pick_snapshot() {
    # Save the selection triples so a failed closure can restore the exact
    # entry state instead of leaving a partial plan behind.
    local i n
    n=${#PICK_LABEL[@]}
    PICK_SNAP_DIRECT=(); PICK_SNAP_STATE=(); PICK_SNAP_AUTO=()
    for ((i=0; i<n; i++)); do
        PICK_SNAP_DIRECT[i]=${PICK_DIRECT[i]:-0}
        PICK_SNAP_STATE[i]=${PICK_STATE[i]:-0}
        PICK_SNAP_AUTO[i]=${PICK_AUTO[i]:-0}
    done
}

pick_restore_snap() {
    local i n
    n=${#PICK_LABEL[@]}
    PICK_DIRECT=(); PICK_STATE=(); PICK_AUTO=()
    for ((i=0; i<n; i++)); do
        PICK_DIRECT[i]=${PICK_SNAP_DIRECT[i]:-0}
        PICK_STATE[i]=${PICK_SNAP_STATE[i]:-0}
        PICK_AUTO[i]=${PICK_SNAP_AUTO[i]:-0}
    done
}

pick_close() {
    # Atomic closure of explicit and retained automatic choices.
    local n i k dep j b
    local -a expand
    n=${#PICK_LABEL[@]}
    pick_validate_items || return 1
    pick_snapshot
    for ((i=0; i<n; i++)); do
        [[ ${PICK_VALID[i]:-1} == 0 ]] && continue
        pick_split_csv "${PICK_DEPS[i]:-}"
        for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
            dep=${PICK_SPLIT[k]}
            [[ -n $dep ]] || { pick_err "'${PICK_LABEL[i]}' has an empty dependency entry"; return 1; }
            j=$(pick_find_id "$dep")
            if [[ $j -lt 0 ]]; then
                pick_err "'${PICK_LABEL[i]}' requires unknown '$dep'"
                return 1
            fi
            if [[ ${PICK_VALID[j]:-1} == 0 ]]; then
                # Excluded prerequisites cannot join the selected set;
                # accepting their dependents would return an incomplete closure.
                if [[ ${PICK_DIRECT[i]:-0} == 1 && ( -z ${PICK_EXPAND_FROM+x} || $i == "$PICK_EXPAND_FROM" ) ]]; then
                    pick_err "'${PICK_LABEL[i]}' requires '$dep', which is not available"
                    return 1
                fi
                continue
            fi
            if ((j >= i)); then
                pick_err "'${PICK_LABEL[i]}' requires '$dep', which is not ordered before it"
                return 1
            fi
        done
    done
    for ((i=0; i<n; i++)); do
        expand[i]=0
        if [[ -z ${PICK_EXPAND_FROM+x} || $i == "$PICK_EXPAND_FROM" ||
              ( $PICK_EXPAND_FROM == auto && ${PICK_AUTO[i]:-0} == 1 ) ]]; then expand[i]=1; fi
        if [[ ${PICK_VALID[i]:-1} == 0 ]]; then
            PICK_DIRECT[i]=0
            PICK_STATE[i]=0
            PICK_AUTO[i]=0
            continue
        fi
        # Recompute strictly from the explicit input: direct choices plus
        # retained auto selections. Stale PICK_STATE from a previous run
        # never carries over.
        if [[ ${PICK_DIRECT[i]:-0} == 1 || ${PICK_AUTO[i]:-0} == 1 ]]; then
            PICK_STATE[i]=1
        else
            PICK_STATE[i]=0
        fi
    done
    local changed=1
    while ((changed)); do
        changed=0
        for ((i=0; i<n; i++)); do
            [[ ${PICK_STATE[i]:-0} == 1 && ${PICK_VALID[i]:-1} != 0 && ${expand[i]} == 1 ]] || continue
            pick_split_csv "${PICK_DEPS[i]:-}"
            for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
                dep=${PICK_SPLIT[k]}
                [[ -n $dep ]] || continue
                j=$(pick_find_id "$dep")
                [[ $j -ge 0 ]] || continue
                [[ ${PICK_VALID[j]:-1} != 0 ]] || continue
                if [[ ${expand[j]} != 1 ]]; then expand[j]=1; changed=1; fi
                if [[ ${PICK_STATE[j]:-0} != 1 ]]; then
                    PICK_STATE[j]=1
                    [[ ${PICK_DIRECT[j]:-0} == 1 ]] || PICK_AUTO[j]=1
                    changed=1
                fi
            done
        done
    done
    # Phase three verifies the whole candidate closure, not just direct
    # roots: a transitively pulled-in row whose prerequisite is unavailable
    # fails the entire plan instead of publishing a partial one.
    for ((i=0; i<n; i++)); do
        [[ ${PICK_STATE[i]:-0} == 1 && ${PICK_VALID[i]:-1} != 0 && ${expand[i]} == 1 ]] || continue
        pick_split_csv "${PICK_DEPS[i]:-}"
        for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
            dep=${PICK_SPLIT[k]}
            [[ -n $dep ]] || continue
            j=$(pick_find_id "$dep")
            [[ $j -ge 0 ]] || continue
            if [[ ${PICK_VALID[j]:-1} == 0 ]]; then
                pick_err "'${PICK_LABEL[i]}' requires '$dep', which is not available"
                pick_restore_snap
                return 1
            fi
        done
    done
    for ((b=0; b<n; b++)); do
        if [[ -n ${PICK_DISABLED[b]:-} && ${PICK_STATE[b]:-0} != ${PICK_SNAP_STATE[b]:-0} ]]; then
            pick_err "${PICK_LABEL[b]}: ${PICK_DISABLED[b]}"
            pick_restore_snap
            return 1
        fi
        [[ -n ${PICK_DIRECT[b]+set} ]] || PICK_DIRECT[b]=0
    done
    return 0
}

pick_locked_by() {
    [[ ${PICK_DEPENDENCY_MODE:-cascade} == lock ]] || return 0
    pick_dep_names_into "$1"
    printf '%s' "$PICK_DEPNAMES"
}

pick_required_by() {
    # The local keeps a caller's pick_split_csv result intact.
    local -a PICK_SPLIT
    local idx=$1 j k id
    id=${PICK_ID[idx]-${PICK_LABEL[idx]}}
    PICK_REQUIRED_BY_INDICES=()
    for ((j=0; j<${#PICK_LABEL[@]}; j++)); do
        [[ $j != "$idx" && ${PICK_STATE[j]:-0} == 1 && ${PICK_VALID[j]:-1} != 0 ]] || continue
        pick_split_csv "${PICK_DEPS[j]:-}"
        for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
            if [[ ${PICK_SPLIT[k]} == "$id" ]]; then
                PICK_REQUIRED_BY_INDICES[${#PICK_REQUIRED_BY_INDICES[@]}]=$j
                break
            fi
        done
    done
}

pick_dep_names_into() {
    # The local keeps internal label formatting from replacing a caller's
    # pick_required_by result.
    local -a PICK_REQUIRED_BY_INDICES
    local k
    pick_required_by "$1"
    PICK_DEPNAMES=
    for ((k=0; k<${#PICK_REQUIRED_BY_INDICES[@]}; k++)); do
        ((k == 0)) || PICK_DEPNAMES="$PICK_DEPNAMES, "
        PICK_DEPNAMES="$PICK_DEPNAMES${PICK_LABEL[PICK_REQUIRED_BY_INDICES[k]]}"
    done
}

pick_recalc_locks() {
    # Caches each selected row's selected immediate dependents for display;
    # in lock mode they are also what holds the row checked.
    local i n
    n=${#PICK_LABEL[@]}
    for ((i=0; i<n; i++)); do PICK_FLOCK[i]=; done
    [[ ${PICK_MODE:-dependencies} == dependencies ]] || return 0
    for ((i=0; i<n; i++)); do
        [[ ${PICK_STATE[i]:-0} == 1 && ${PICK_VALID[i]:-1} != 0 ]] || continue
        pick_dep_names_into "$i"
        PICK_FLOCK[i]=$PICK_DEPNAMES
    done
}

pick_action() {
    local action=$1 i idx
    if [[ $PICK_MODE == dependencies ]]; then
        case $action in
            toggle) pick_toggle ;; all) pick_check_all ;; clear) pick_clear_directs ;;
        esac
        return
    fi
    PICK_MSG=
    case $action in
        toggle)
            idx=${PICK_FOCUS[PICK_CURSOR]}
            if [[ -n ${PICK_DISABLED[idx]:-} ]]; then pick_message "$PICK_STYLE_ERROR" "${PICK_DISABLED[idx]}"; return 0; fi
            PICK_STATE[idx]=$((1 - ${PICK_STATE[idx]:-0}))
            ;;
        all|clear)
            for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
                [[ -z ${PICK_DISABLED[i]:-} ]] || continue
                if [[ $action == all && ${PICK_VALID[i]:-1} != 0 ]]; then PICK_STATE[i]=1
                else PICK_STATE[i]=0; fi
            done
            ;;
    esac
    return 0
}

pick_toggle() {
    local idx depnames
    idx=${PICK_FOCUS[PICK_CURSOR]}
    if [[ -n ${PICK_DISABLED[idx]:-} ]]; then pick_message "$PICK_STYLE_ERROR" "${PICK_DISABLED[idx]}"; return 0; fi
    depnames=$(pick_locked_by "$idx")
    if [[ ${PICK_STATE[idx]:-0} == 1 ]]; then
        if [[ -n $depnames ]]; then pick_message "$PICK_STYLE_ERROR" "${PICK_LABEL[idx]} stays checked: required by $depnames."; return 0; fi
        pick_deselect "$idx"
        pick_recalc_locks
        return 0
    fi
    PICK_DIRECT[idx]=1
    PICK_STATE[idx]=1
    if [[ ${PICK_PRESERVE_INITIAL:-0} == 1 ]]; then local PICK_EXPAND_FROM=$idx; fi
    # Route the toggle through the same validated closure as the
    # noninteractive path. Quiet mode shows the reason on screen instead
    # of scribbling over the terminal frame.
    PICK_QUIET=1
    PICK_MSG=
    if ! pick_close; then
        PICK_DIRECT[idx]=0
        PICK_STATE[idx]=0
        PICK_QUIET=0
        pick_recalc_locks
        return 0
    fi
    PICK_QUIET=0
    PICK_MSG=
    pick_recalc_locks
    return 0
}

pick_deselect() {
    local idx=$1 i k j removed=
    local -a removed_rows
    removed_rows[idx]=1
    pick_snapshot
    PICK_STATE[idx]=0
    PICK_DIRECT[idx]=0
    PICK_AUTO[idx]=0
    if [[ ${PICK_DEPENDENCY_MODE:-cascade} == cascade ]]; then
        # Dependencies precede dependents in the validated input, so a
        # forward pass propagates removal through the entire dependent chain.
        for ((i=idx+1; i<${#PICK_LABEL[@]}; i++)); do
            [[ ${PICK_STATE[i]:-0} == 1 ]] || continue
            pick_split_csv "${PICK_DEPS[i]:-}"
            for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
                j=$(pick_find_id "${PICK_SPLIT[k]}")
                if [[ $j -ge 0 && ${removed_rows[j]:-0} == 1 ]]; then
                    # Clear retained history too, so the next closure does
                    # not reintroduce the dependent or its removed prerequisite.
                    PICK_STATE[i]=0
                    PICK_DIRECT[i]=0
                    PICK_AUTO[i]=0
                    removed_rows[i]=1
                    removed="${removed:+$removed, }${PICK_LABEL[i]}"
                    break
                fi
            done
        done
    fi
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        if [[ -n ${PICK_DISABLED[i]:-} && ${PICK_STATE[i]:-0} != ${PICK_SNAP_STATE[i]:-0} ]]; then
            pick_restore_snap
            pick_message "$PICK_STYLE_ERROR" "${PICK_LABEL[i]}: ${PICK_DISABLED[i]}"
            return 0
        fi
    done
    PICK_MSG=
    [[ -z $removed ]] || pick_message "$PICK_STYLE_WARNING" "Also unchecked $removed."
    return 0
}

pick_check_all() {
    # Operates on included rows only. The pre-change triples are saved so
    # a failed closure restores the coherent prior selection (with its
    # reason already on screen via PICK_QUIET) instead of a partial one.
    local i n
    n=${#PICK_LABEL[@]}
    local -a save_direct save_state save_auto
    for ((i=0; i<n; i++)); do
        save_direct[i]=${PICK_DIRECT[i]:-0}
        save_state[i]=${PICK_STATE[i]:-0}
        save_auto[i]=${PICK_AUTO[i]:-0}
    done
    for ((i=0; i<n; i++)); do
        [[ ${PICK_VALID[i]:-1} != 0 && -z ${PICK_DISABLED[i]:-} ]] || continue
        PICK_DIRECT[i]=1
        PICK_STATE[i]=1
    done
    PICK_QUIET=1
    PICK_MSG=
    if ! pick_close; then
        for ((i=0; i<n; i++)); do
            PICK_DIRECT[i]=${save_direct[i]:-0}
            PICK_STATE[i]=${save_state[i]:-0}
            PICK_AUTO[i]=${save_auto[i]:-0}
        done
        PICK_QUIET=0
        pick_recalc_locks
        return 0
    fi
    PICK_QUIET=0
    pick_recalc_locks
    pick_message '' "Checked all items."
}

pick_clear_directs() {
    # Retained automatic choices still require their prerequisite chains.
    # Seeded callers expand those chains without repairing unrelated,
    # read-only baseline choices that were already incomplete.
    local i n
    if [[ ${PICK_PRESERVE_INITIAL:-0} == 1 ]]; then local PICK_EXPAND_FROM=auto; fi
    n=${#PICK_LABEL[@]}
    local -a save_direct save_state save_auto
    for ((i=0; i<n; i++)); do
        save_direct[i]=${PICK_DIRECT[i]:-0}
        save_state[i]=${PICK_STATE[i]:-0}
        save_auto[i]=${PICK_AUTO[i]:-0}
    done
    for ((i=0; i<n; i++)); do
        [[ -z ${PICK_DISABLED[i]:-} ]] || continue
        PICK_DIRECT[i]=0
    done
    PICK_QUIET=1
    PICK_MSG=
    if ! pick_close; then
        for ((i=0; i<n; i++)); do
            PICK_DIRECT[i]=${save_direct[i]:-0}
            PICK_STATE[i]=${save_state[i]:-0}
            PICK_AUTO[i]=${save_auto[i]:-0}
        done
        PICK_QUIET=0
        pick_recalc_locks
        return 0
    fi
    PICK_QUIET=0
    pick_recalc_locks
    pick_message '' "Cleared your choices; auto-checked items stay until unchecked."
}
