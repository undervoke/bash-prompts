# bash-prompts: value rows, the values their prerequisites leave, and changes.
# Function definitions only; sourced in the caller shell by lib/bash-prompts.sh.

pick_csv_has() {
    # $1 = value, $2 = CSV. The local keeps a caller's pick_split_csv result.
    local -a PICK_SPLIT
    local k
    pick_split_csv "$2"
    for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
        [[ ${PICK_SPLIT[k]} != "$1" ]] || return 0
    done
    return 1
}

pick_prepare_choices() {
    # Fills unset current and picked values and resolves prerequisites to
    # row indices once, because every change settles all rows again.
    local i j k value
    PICK_DEP_ROWS=()
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        PICK_DEP_ROWS[i]=
        [[ ${PICK_VALID[i]:-1} != 0 ]] || continue
        pick_split_csv "${PICK_VALUES[i]-}"
        [[ -n ${PICK_CURRENT[i]+set} ]] || PICK_CURRENT[i]=${PICK_SPLIT[0]-}
        [[ -n ${PICK_CHOICE[i]+set} ]] || PICK_CHOICE[i]=${PICK_CURRENT[i]}
        for value in "${PICK_CURRENT[i]}" "${PICK_CHOICE[i]}"; do
            if ! pick_csv_has "$value" "${PICK_VALUES[i]}"; then
                pick_err "'${PICK_LABEL[i]}' has no value '$value'"
                return 1
            fi
        done
        pick_split_csv "${PICK_DEPS[i]-}"
        for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
            j=$(pick_find_id "${PICK_SPLIT[k]}")
            if ((j < 0)); then
                pick_err "'${PICK_LABEL[i]}' requires unknown '${PICK_SPLIT[k]}'"
                return 1
            fi
            if ((j >= i)); then
                pick_err "'${PICK_LABEL[i]}' requires '${PICK_SPLIT[k]}', which is not ordered before it"
                return 1
            fi
            [[ ${PICK_VALID[j]:-1} == 0 ]] || PICK_DEP_ROWS[i]="${PICK_DEP_ROWS[i]} $j"
        done
    done
    pick_settle
}

pick_settle() {
    # Sets PICK_RESULT to the values in effect. Rows follow their
    # prerequisites, so one pass is enough. PICK_CHOICE keeps what was
    # picked, so a row returns to it when its prerequisites do.
    local i j value current off parked IFS=' '
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        PICK_RESULT[i]=; PICK_ON[i]=1; PICK_MISSING[i]=; PICK_WITHDRAWN[i]=0
        [[ ${PICK_VALID[i]:-1} != 0 ]] || continue
        value=${PICK_CHOICE[i]}
        current=${PICK_CURRENT[i]}
        off=${PICK_OFF[i]-}
        parked=${PICK_WHILE_OFF[i]-}
        if [[ -z ${PICK_DISABLED[i]:-} ]]; then
            for j in ${PICK_DEP_ROWS[i]}; do
                [[ ${PICK_ON[j]} == 0 ]] || continue
                PICK_MISSING[i]="${PICK_MISSING[i]} $j"
                pick_csv_has "${PICK_CURRENT[j]}" "${PICK_OFF[j]-}" || PICK_WITHDRAWN[i]=1
            done
        fi
        # A picked PICK_WHILE_OFF value ends when the prerequisites are on.
        if [[ -n $parked && -z ${PICK_DISABLED[i]:-} && $value == "$parked" ]] && ! pick_while_off "$i"; then
            pick_split_csv "${PICK_VALUES[i]}"
            value=${PICK_SPLIT[0]}
        fi
        # A prerequisite that was already off keeps the row where it started;
        # one that is being turned off takes the row with it.
        if pick_while_off "$i"; then
            pick_csv_has "$value" "$off" || value=$parked
        elif [[ -n ${PICK_MISSING[i]} ]] && ! pick_csv_has "$value" "$off"; then
            if [[ ${PICK_WITHDRAWN[i]} == 0 ]] || pick_csv_has "$current" "$off"; then
                value=$current
            else
                pick_split_csv "$off"
                value=${PICK_SPLIT[0]-$value}
            fi
        fi
        PICK_RESULT[i]=$value
        ! pick_csv_has "$value" "$off" || PICK_ON[i]=0
    done
}

pick_while_off() {
    [[ -n ${PICK_WHILE_OFF[$1]-} && -n ${PICK_MISSING[$1]} &&
        ( ${PICK_WITHDRAWN[$1]} == 1 || ${PICK_CURRENT[$1]} == "${PICK_WHILE_OFF[$1]}" ) ]]
}

pick_value_allowed() {
    # $1 = row, $2 = value. A row whose prerequisite is off can only stay
    # where it started or turn off.
    if [[ -n ${PICK_WHILE_OFF[$1]-} && $2 == "${PICK_WHILE_OFF[$1]}" ]]; then
        pick_while_off "$1"
        return $?
    fi
    [[ -n ${PICK_MISSING[$1]} ]] || return 0
    pick_csv_has "$2" "${PICK_OFF[$1]-}" && return 0
    ! pick_while_off "$1" || return 1
    [[ ${PICK_WITHDRAWN[$1]} == 0 && $2 == "${PICK_CURRENT[$1]}" ]]
}

pick_next_allowed() {
    # $1 = row; sets PICK_NEXT to the value after the one in effect, or to
    # nothing when the row has no other value to take.
    local idx=$1 k n at=0
    PICK_NEXT=
    pick_split_csv "${PICK_VALUES[idx]}"
    n=${#PICK_SPLIT[@]}
    for ((k=0; k<n; k++)); do
        [[ ${PICK_SPLIT[k]} != "${PICK_RESULT[idx]}" ]] || at=$k
    done
    for ((k=1; k<n; k++)); do
        pick_value_allowed "$idx" "${PICK_SPLIT[(at + k) % n]}" || continue
        PICK_NEXT=${PICK_SPLIT[(at + k) % n]}
        return 0
    done
    return 1
}

pick_missing_names() {
    # $1 = row; sets PICK_DEPNAMES to the prerequisites that are off, with
    # the tab of those shown elsewhere.
    local j tab IFS=' '
    PICK_DEPNAMES=
    for j in ${PICK_MISSING[$1]-}; do
        PICK_DEPNAMES="${PICK_DEPNAMES:+$PICK_DEPNAMES, }${PICK_LABEL[j]}"
        ((${#PICK_TAB_GROUPS[@]})) || continue
        pick_ref_group "$j" 1
        tab=$PICK_REFGROUP
        pick_ref_group "$1" 1
        [[ $tab == "$PICK_REFGROUP" ]] || PICK_DEPNAMES="$PICK_DEPNAMES (${PICK_GLABEL[tab]})"
    done
}

pick_next_value() {
    local idx=${PICK_FOCUS[PICK_CURSOR]} i also=
    local -a before=("${PICK_RESULT[@]}")
    PICK_MSG=
    if [[ -n ${PICK_DISABLED[idx]:-} ]]; then pick_message "$PICK_STYLE_ERROR" "${PICK_DISABLED[idx]}"; return 0; fi
    if ! pick_next_allowed "$idx"; then
        pick_missing_names "$idx"
        [[ -z $PICK_DEPNAMES ]] || pick_message "$PICK_STYLE_ERROR" "${PICK_LABEL[idx]} requires $PICK_DEPNAMES."
        return 0
    fi
    PICK_CHOICE[idx]=$PICK_NEXT
    pick_settle
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        [[ $i != "$idx" && ${PICK_RESULT[i]} != "${before[i]}" ]] || continue
        also="${also:+$also, }${PICK_LABEL[i]}"
    done
    [[ -z $also ]] || pick_message "$PICK_STYLE_WARNING" "Also changed $also."
}

pick_measure_values() {
    # Widths of the shown rows' labels and values, so the value column stays
    # put while values change.
    local i k g width
    PICK_LABEL_CELLS=0
    PICK_VALUE_CELLS=0
    for i in "${PICK_FOCUS[@]}"; do
        g=${PICK_IGROUP[i]}
        pick_clip "${PICK_LABEL[i]}" 9999
        width=$((PICK_CELLS + 2 + 2 * (PICK_GLEVEL[g] - PICK_GLEVEL[PICK_ROOT])))
        ((width <= PICK_LABEL_CELLS)) || PICK_LABEL_CELLS=$width
        pick_split_csv "${PICK_VALUES[i]}"
        for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
            pick_clip "${PICK_SPLIT[k]}" 9999
            ((PICK_CELLS <= PICK_VALUE_CELLS)) || PICK_VALUE_CELLS=$PICK_CELLS
        done
    done
}

pick_value_column() {
    # $1 = width; sets PICK_VALUE_COLUMN. Long labels are shortened so the
    # widest value fits, but never below a third of the width.
    local cols=$1
    PICK_VALUE_COLUMN=$PICK_LABEL_CELLS
    ((PICK_VALUE_COLUMN + 2 + PICK_VALUE_CELLS <= cols)) || PICK_VALUE_COLUMN=$((cols - 2 - PICK_VALUE_CELLS))
    ((PICK_VALUE_COLUMN >= cols / 3)) || PICK_VALUE_COLUMN=$((cols / 3))
    ((PICK_VALUE_COLUMN <= PICK_LABEL_CELLS)) || PICK_VALUE_COLUMN=$PICK_LABEL_CELLS
}

pick_value_line() {
    # $1 = row, $2 = focus position, $3 = indent. Also sets PICK_NOTES.
    local idx=$1 label=${PICK_LABEL[$1]} notes=${PICK_NOTE[$1]-}
    local result=${PICK_RESULT[$1]} role=PLAIN lead="$3  " cells pad
    pick_missing_names "$idx"
    [[ -z $PICK_DEPNAMES ]] || notes="${notes:+$notes; }requires $PICK_DEPNAMES"
    [[ -z ${PICK_DISABLED[idx]:-} ]] || notes="${notes:+$notes; }${PICK_DISABLED[idx]}"
    PICK_ROW_STYLE=
    if [[ -n ${PICK_DISABLED[idx]:-} ]] || ! pick_next_allowed "$idx"; then
        PICK_ROW_STYLE=$PICK_STYLE_MUTED
        role=MUTED
    fi
    if (($2 == PICK_CURSOR)); then
        lead="$3> "
        PICK_ROW_STYLE=$PICK_STYLE_FOCUS
    fi
    pick_clip "$label" "$((PICK_VALUE_COLUMN - ${#lead}))"
    cells=$PICK_CELLS
    if [[ $PICK_CLIPPED != "$label" ]]; then
        pick_clip "$label" "$((PICK_VALUE_COLUMN - ${#lead} - ${#PICK_ELLIPSIS}))"
        label=$PICK_CLIPPED$PICK_ELLIPSIS
        cells=$((PICK_CELLS + ${#PICK_ELLIPSIS}))
    fi
    printf -v pad '%*s' "$((PICK_VALUE_COLUMN - ${#lead} - cells + 2))" ''
    PICK_ROW=$lead$label$pad
    [[ $result == "${PICK_CURRENT[idx]}" ]] || role=CHANGED
    PICK_ROW_SPANS="${#PICK_ROW} $role"
    PICK_ROW=$PICK_ROW$result
    PICK_ROW_SPANS="$PICK_ROW_SPANS ${#PICK_ROW} MUTED"
    PICK_ROW="$PICK_ROW${notes:+  $notes}"
    PICK_NOTES=$notes
}
