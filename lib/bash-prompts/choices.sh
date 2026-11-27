# bash-prompts: value rows, the values their prerequisites leave, changes, and columns.
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
    PICK_EDITS=0
    PICK_KEY_ROWS=()
    PICK_KEPT_ROW=()
    PICK_KEPT_TEXT=()
    PICK_HELD_AS=()
    PICK_CLASH=()
    PICK_CELL_COUNT=0
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        PICK_DEP_ROWS[i]=
        [[ ${PICK_VALID[i]:-1} != 0 ]] || continue
        pick_split_csv "${PICK_VALUES[i]-}"
        [[ -n ${PICK_CURRENT[i]+set} ]] || PICK_CURRENT[i]=${PICK_SPLIT[0]-}
        [[ -n ${PICK_CHOICE[i]+set} ]] || PICK_CHOICE[i]=${PICK_CURRENT[i]}
        if [[ -n ${PICK_EDIT[i]-} ]]; then
            PICK_EDITS=1
            pick_keep "$i" "${PICK_CURRENT[i]}"
            pick_keep "$i" "${PICK_CHOICE[i]}"
        else
            for value in "${PICK_CURRENT[i]}" "${PICK_CHOICE[i]}"; do
                if ! pick_csv_has "$value" "${PICK_VALUES[i]}"; then
                    pick_err "'${PICK_LABEL[i]}' has no value '$value'"
                    return 1
                fi
            done
        fi
        if [[ ${PICK_EDIT[i]-} == pick_keybinding || -n ${PICK_KEYBINDING_DEFAULT[i]-} ]]; then
            PICK_KEY_ROWS[${#PICK_KEY_ROWS[@]}]=$i
        fi
        if [[ -n ${PICK_CELLS[i]-} ]]; then
            pick_split_cells "${PICK_CELLS[i]}"
            ((${#PICK_SPLIT_CELLS[@]} <= PICK_CELL_COUNT)) || PICK_CELL_COUNT=${#PICK_SPLIT_CELLS[@]}
        fi
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
    PICK_SHOWN=()
    PICK_STUCK=()
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
    if ((${#PICK_KEY_ROWS[@]})); then pick_find_clashes; fi
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

pick_keep() {
    # $1 = edit row, $2 = text; keeps it among the row's values, after the
    # fixed ones. A key row keeps only what could be entered.
    local k
    ! pick_csv_has "$2" "${PICK_VALUES[$1]-}" || return 0
    if [[ ${PICK_EDIT[$1]} == pick_keybinding ]]; then
        pick_keybinding_parse "$2" && pick_keybinding_usable || return 0
    fi
    for ((k=0; k<${#PICK_KEPT_ROW[@]}; k++)); do
        [[ ${PICK_KEPT_ROW[k]} != "$1" || ${PICK_KEPT_TEXT[k]} != "$2" ]] || return 0
    done
    PICK_KEPT_ROW[k]=$1
    PICK_KEPT_TEXT[k]=$2
}

pick_row_values() {
    # $1 = row; fills PICK_SPLIT with the values it moves through.
    local k
    pick_split_csv "${PICK_VALUES[$1]-}"
    [[ -n ${PICK_EDIT[$1]-} ]] || return 0
    for ((k=0; k<${#PICK_KEPT_ROW[@]}; k++)); do
        [[ ${PICK_KEPT_ROW[k]} != "$1" ]] || PICK_SPLIT[${#PICK_SPLIT[@]}]=${PICK_KEPT_TEXT[k]}
    done
}

pick_next_allowed() {
    # $1 = row, $2 = -1 to go backwards; sets PICK_NEXT to the value after
    # the one in effect, or to nothing when the row has no other to take.
    local idx=$1 dir=${2:-1} k n at=-1 to
    PICK_NEXT=
    pick_row_values "$idx"
    n=${#PICK_SPLIT[@]}
    for ((k=0; k<n; k++)); do
        [[ ${PICK_SPLIT[k]} != "${PICK_RESULT[idx]}" ]] || at=$k
    done
    for ((k=1; k<n + (at < 0); k++)); do
        if ((at >= 0)); then to=$(((at + dir * k + n * k) % n))
        elif ((dir > 0)); then to=$((k - 1))
        else to=$((n - k)); fi
        pick_value_allowed "$idx" "${PICK_SPLIT[to]}" || continue
        PICK_NEXT=${PICK_SPLIT[to]}
        return 0
    done
    return 1
}

pick_missing_names() {
    # $1 = row; sets PICK_DEPNAMES to the prerequisites that are off.
    pick_row_names "$1" "${PICK_MISSING[$1]-}"
}

pick_row_names() {
    # $1 = row, $2 = other rows; sets PICK_DEPNAMES to the labels of the
    # others, with the page of those shown elsewhere: its tab, and its
    # sub-tab after a colon.
    local j page where IFS=' '
    PICK_DEPNAMES=
    for j in $2; do
        PICK_DEPNAMES="${PICK_DEPNAMES:+$PICK_DEPNAMES, }${PICK_LABEL[j]}"
        ((${#PICK_PAGES[@]})) || continue
        pick_page_of "$j"
        page=$PICK_PAGE_OF
        pick_page_of "$1"
        ((page != PICK_PAGE_OF)) || continue
        where=${PICK_GLABEL[${PICK_PAGES[page]}]}
        ((!PICK_TAB_SUBS[PICK_PAGE_TAB[page]])) ||
            where="${PICK_GLABEL[${PICK_TAB_GROUPS[${PICK_PAGE_TAB[page]}]}]}: $where"
        PICK_DEPNAMES="$PICK_DEPNAMES ($where)"
    done
}

pick_change_value() {
    # Toggle: without an Edit key it edits a row that can be edited.
    local idx=${PICK_FOCUS[PICK_CURSOR]}
    if [[ -n ${PICK_EDIT[idx]-} ]] && ((${#PICK_KEYS_EDIT[@]} == 0)); then pick_edit_value "$idx"
    else pick_next_value; fi
}

pick_edit_row() {
    local idx=${PICK_FOCUS[PICK_CURSOR]}
    if [[ -n ${PICK_EDIT[idx]-} ]]; then pick_edit_value "$idx"
    else pick_next_value; fi
}

pick_tab_action() {
    # With the focus on the tabs or the sub-tabs, Left and Right move between
    # them, and an action on a row goes to the rows first.
    ((PICK_ON_TABS)) || return 0
    case $PICK_KEY_ACTION in
        prev_value) PICK_KEY_ACTION=prev_bar ;;
        next_value) PICK_KEY_ACTION=next_bar ;;
        toggle|edit) PICK_KEY_ACTION=down ;;
        prev_group|next_group) PICK_ON_TABS=0 ;;
        submit) [[ $PICK_MODE != single ]] || PICK_KEY_ACTION=down ;;
    esac
}

pick_page_action() {
    # On the submit page Toggle and Edit run the focused action.
    pick_on_submit_page || return 0
    case $PICK_KEY_ACTION in
        toggle|edit)
            if ((PICK_CURSOR == 0)); then PICK_KEY_ACTION=submit
            else PICK_KEY_ACTION=cancel; fi
            ;;
        prev_value|next_value) PICK_KEY_ACTION= ;;
    esac
}

pick_next_value() {
    # $1 = -1 to go backwards.
    local idx=${PICK_FOCUS[PICK_CURSOR]}
    PICK_MSG=
    if [[ -n ${PICK_DISABLED[idx]:-} ]]; then pick_message "$PICK_STYLE_ERROR" "${PICK_DISABLED[idx]}"; return 0; fi
    if ! pick_next_allowed "$idx" "${1-}"; then
        pick_missing_names "$idx"
        [[ -z $PICK_DEPNAMES ]] || pick_message "$PICK_STYLE_ERROR" "${PICK_LABEL[idx]} requires $PICK_DEPNAMES."
        return 0
    fi
    pick_take_value "$idx" "$PICK_NEXT"
}

pick_edit_value() {
    # $1 = row; runs its edit function, which reads and sets PICK_VALUE.
    local idx=$1 PICK_VALUE
    PICK_MSG=
    if [[ -n ${PICK_DISABLED[idx]:-} ]]; then pick_message "$PICK_STYLE_ERROR" "${PICK_DISABLED[idx]}"; return 0; fi
    if [[ -n ${PICK_MISSING[idx]} ]]; then
        pick_missing_names "$idx"
        pick_message "$PICK_STYLE_ERROR" "${PICK_LABEL[idx]} requires $PICK_DEPNAMES."
        return 0
    fi
    PICK_VALUE=${PICK_RESULT[idx]}
    "${PICK_EDIT[idx]}" "$idx" || return 0
    pick_take_value "$idx" "$PICK_VALUE"
}

pick_take_value() {
    # $1 = row, $2 = picked value; says what else it changed and whether the
    # key is taken, after any warning already shown.
    local idx=$1 i also= notes=
    local -a before=("${PICK_RESULT[@]}")
    PICK_CHOICE[idx]=$2
    [[ -z ${PICK_EDIT[idx]-} ]] || pick_keep "$idx" "$2"
    pick_settle
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        [[ $i != "$idx" && ${PICK_RESULT[i]} != "${before[i]}" ]] || continue
        also="${also:+$also, }${PICK_LABEL[i]}"
    done
    [[ -z $also ]] || notes="Also changed $also."
    if [[ -n ${PICK_CLASH[idx]-} ]]; then
        pick_row_names "$idx" "${PICK_CLASH[idx]}"
        notes="${notes:+$notes }Same key as $PICK_DEPNAMES."
    fi
    [[ -z $notes ]] || pick_message "$PICK_STYLE_WARNING" "${PICK_MSG:+$PICK_MSG }$notes"
}

pick_refuse_choices() {
    # Whether something keeps the values from being submitted.
    if ((PICK_ALONE)) && [[ -z ${PICK_RESULT[0]} ]]; then
        pick_message "$PICK_STYLE_ERROR" 'No key is entered yet.'
        return 0
    fi
    pick_refuse_clash
}

pick_format_value() {
    # $1 = row, $2 = value; sets PICK_TEXT to how the row shows it.
    local format=${PICK_FORMAT[$1]-}
    [[ -n $format || ${PICK_EDIT[$1]-} != pick_keybinding ]] || format=pick_keybinding_format
    PICK_TEXT=$2
    if [[ -z $2 && -n ${PICK_EDIT[$1]-} ]]; then PICK_TEXT=none
    elif [[ -n $format ]]; then "$format" "$2" "$1"; fi
}

pick_split_cells() {
    # $1 = tab-separated cells; fills PICK_SPLIT_CELLS.
    local rest=$1
    PICK_SPLIT_CELLS=()
    [[ -n $rest ]] || return 0
    while true; do
        PICK_SPLIT_CELLS[${#PICK_SPLIT_CELLS[@]}]=${rest%%$'\t'*}
        [[ $rest == *$'\t'* ]] || break
        rest=${rest#*$'\t'}
    done
}

pick_measure_values() {
    # Widths of the shown rows' labels, cells, and values, so the columns
    # stay put while values change.
    local i k g width
    PICK_LABEL_CELLS=0
    PICK_VALUE_CELLS=0
    PICK_CELL_CELLS=()
    PICK_HEADED=0
    for i in "${PICK_FOCUS[@]}"; do
        ((i < ${#PICK_LABEL[@]})) || continue
        g=${PICK_IGROUP[i]}
        pick_clip "${PICK_LABEL[i]}" 9999
        width=$((PICK_WIDTH + 2 + 2 * (PICK_GLEVEL[g] - PICK_GLEVEL[PICK_ROOT])))
        ((width <= PICK_LABEL_CELLS)) || PICK_LABEL_CELLS=$width
        if [[ -n ${PICK_CELLS[i]-} ]]; then
            PICK_HEADED=1
            pick_split_cells "${PICK_CELLS[i]}"
            for ((k=0; k<${#PICK_SPLIT_CELLS[@]}; k++)); do
                pick_clip "${PICK_SPLIT_CELLS[k]}" 9999
                ((PICK_WIDTH <= ${PICK_CELL_CELLS[k]:-0})) || PICK_CELL_CELLS[k]=$PICK_WIDTH
            done
        fi
        pick_split_csv "${PICK_VALUES[i]-}"
        if [[ -n ${PICK_EDIT[i]-} ]]; then
            PICK_HEADED=1
            # The widest key is five modifiers with Space.
            if [[ ${PICK_EDIT[i]} != pick_keybinding ]]; then pick_row_values "$i"
            elif ((PICK_VALUE_CELLS < 11)); then PICK_VALUE_CELLS=11; fi
        fi
        for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
            PICK_TEXT=${PICK_SPLIT[k]}
            [[ -z ${PICK_FORMAT[i]-} ]] || pick_format_value "$i" "$PICK_TEXT"
            pick_clip "$PICK_TEXT" 9999
            ((PICK_WIDTH <= PICK_VALUE_CELLS)) || PICK_VALUE_CELLS=$PICK_WIDTH
        done
    done
    if ((${#PICK_COLUMNS[@]} == 0)); then PICK_HEADED=0; fi
    ((PICK_HEADED)) || return 0
    pick_clip "${PICK_COLUMNS[0]-}" 9999
    ((PICK_WIDTH + 2 <= PICK_LABEL_CELLS)) || PICK_LABEL_CELLS=$((PICK_WIDTH + 2))
    for k in "${!PICK_CELL_CELLS[@]}"; do
        pick_clip "${PICK_COLUMNS[k + 1]-}" 9999
        ((PICK_WIDTH <= PICK_CELL_CELLS[k])) || PICK_CELL_CELLS[k]=$PICK_WIDTH
    done
    pick_clip "${PICK_COLUMNS[PICK_CELL_COUNT + 1]-}" 9999
    ((PICK_WIDTH <= PICK_VALUE_CELLS)) || PICK_VALUE_CELLS=$PICK_WIDTH
}

pick_value_column() {
    # $1 = width; sets PICK_VALUE_COLUMN and PICK_CELL_COLUMNS. Long labels
    # are shortened so the cells and the widest value fit, but never below a
    # third of the width; then cells give way, from the last one.
    local cols=$1 k width rest=$((PICK_VALUE_CELLS + 2)) over
    PICK_CELL_COLUMNS=()
    for k in "${!PICK_CELL_CELLS[@]}"; do
        PICK_CELL_COLUMNS[k]=${PICK_CELL_CELLS[k]}
        ((PICK_CELL_CELLS[k] == 0)) || rest=$((rest + PICK_CELL_CELLS[k] + 2))
    done
    PICK_VALUE_COLUMN=$PICK_LABEL_CELLS
    ((PICK_VALUE_COLUMN + rest <= cols)) || PICK_VALUE_COLUMN=$((cols - rest))
    ((PICK_VALUE_COLUMN >= cols / 3)) || PICK_VALUE_COLUMN=$((cols / 3))
    ((PICK_VALUE_COLUMN <= PICK_LABEL_CELLS)) || PICK_VALUE_COLUMN=$PICK_LABEL_CELLS
    over=$((PICK_VALUE_COLUMN + rest - cols))
    for ((k=PICK_CELL_COUNT-1; k>=0 && over>0; k--)); do
        width=${PICK_CELL_COLUMNS[k]:-0}
        ((width)) || continue
        if ((width - over >= 4)); then
            PICK_CELL_COLUMNS[k]=$((width - over))
            over=0
        else
            PICK_CELL_COLUMNS[k]=0
            over=$((over - width - 2))
        fi
    done
    # The label takes back what a dropped cell left over.
    if ((over < 0)); then
        PICK_VALUE_COLUMN=$((PICK_VALUE_COLUMN - over))
        ((PICK_VALUE_COLUMN <= PICK_LABEL_CELLS)) || PICK_VALUE_COLUMN=$PICK_LABEL_CELLS
    fi
}

pick_fit() {
    # $1 = text, $2 = cells; sets PICK_FITTED to the text, shortened if it is
    # too wide, with two spaces after the column.
    local text=$1 cells pad
    pick_clip "$text" "$2"
    cells=$PICK_WIDTH
    if [[ $PICK_CLIPPED != "$text" ]]; then
        pick_clip "$text" "$(($2 - ${#PICK_ELLIPSIS}))"
        text=$PICK_CLIPPED$PICK_ELLIPSIS
        cells=$((PICK_WIDTH + ${#PICK_ELLIPSIS}))
    fi
    printf -v pad '%*s' "$(($2 - cells + 2))" ''
    PICK_FITTED=$text$pad
}

pick_fit_cells() {
    # Sets PICK_FITTED_CELLS to the cells in PICK_SPLIT_CELLS, each in its
    # column.
    local k
    PICK_FITTED_CELLS=
    for k in "${!PICK_CELL_COLUMNS[@]}"; do
        ((PICK_CELL_COLUMNS[k])) || continue
        pick_fit "${PICK_SPLIT_CELLS[k]-}" "${PICK_CELL_COLUMNS[k]}"
        PICK_FITTED_CELLS+=$PICK_FITTED
    done
}

pick_column_line() {
    # Sets PICK_ROW to the column headers.
    pick_fit "${PICK_COLUMNS[0]-}" "$((PICK_VALUE_COLUMN - 2))"
    PICK_ROW="  $PICK_FITTED"
    PICK_SPLIT_CELLS=("${PICK_COLUMNS[@]:1:PICK_CELL_COUNT}")
    pick_fit_cells
    PICK_ROW+=$PICK_FITTED_CELLS${PICK_COLUMNS[PICK_CELL_COUNT + 1]-}
}

pick_value_line() {
    # $1 = row, $2 = focus position, $3 = indent. Also sets PICK_NOTES.
    local idx=$1 notes=${PICK_NOTE[$1]-} role=PLAIN lead="$3  "
    # Neither changes until a value does.
    if [[ -z ${PICK_SHOWN[idx]+set} ]]; then
        pick_format_value "$idx" "${PICK_RESULT[idx]}"
        PICK_SHOWN[idx]=$PICK_TEXT
        PICK_STUCK[idx]=0
        if [[ -n ${PICK_DISABLED[idx]:-} ]]; then PICK_STUCK[idx]=1
        elif [[ -z ${PICK_EDIT[idx]-} || -n ${PICK_MISSING[idx]} ]] && ! pick_next_allowed "$idx"; then PICK_STUCK[idx]=1; fi
    fi
    if [[ -n ${PICK_MISSING[idx]} ]]; then
        pick_missing_names "$idx"
        notes="${notes:+$notes; }requires $PICK_DEPNAMES"
    fi
    [[ -z ${PICK_DISABLED[idx]:-} ]] || notes="${notes:+$notes; }${PICK_DISABLED[idx]}"
    PICK_ROW_STYLE=
    if ((PICK_STUCK[idx])); then
        PICK_ROW_STYLE=$PICK_STYLE_MUTED
        role=MUTED
    fi
    if (($2 == PICK_AT)); then
        lead="$3> "
        PICK_ROW_STYLE=$PICK_STYLE_FOCUS
    fi
    [[ ${PICK_RESULT[idx]} == "${PICK_CURRENT[idx]}" ]] || role=CHANGED
    if [[ -n ${PICK_CLASH[idx]-} ]]; then
        role=ERROR
        pick_row_names "$idx" "${PICK_CLASH[idx]}"
        notes="same key as $PICK_DEPNAMES${notes:+; $notes}"
    fi
    pick_fit "${PICK_LABEL[idx]}" "$((PICK_VALUE_COLUMN - ${#lead}))"
    PICK_ROW=$lead$PICK_FITTED
    if ((${#PICK_CELL_COLUMNS[@]})); then
        pick_split_cells "${PICK_CELLS[idx]-}"
        pick_fit_cells
        PICK_ROW+=$PICK_FITTED_CELLS
    fi
    PICK_ROW_SPANS="${#PICK_ROW} $role"
    PICK_ROW=$PICK_ROW${PICK_SHOWN[idx]}
    PICK_ROW_SPANS="$PICK_ROW_SPANS ${#PICK_ROW} MUTED"
    PICK_ROW="$PICK_ROW${notes:+  $notes}"
    PICK_NOTES=$notes
}
