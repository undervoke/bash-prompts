# bash-prompts: the screen that lists the changes and asks to submit them.
# Function definitions only; sourced in the caller shell by lib/bash-prompts.sh.

pick_confirm_open() {
    # The rows stay as they are behind the screen. The review may refuse.
    PICK_REVIEW_NOTE=()
    PICK_REVIEW_MESSAGE=
    if [[ -n ${PICK_REVIEW-} ]] && ! "$PICK_REVIEW"; then
        pick_message "$PICK_STYLE_ERROR" "${PICK_REVIEW_MESSAGE:-These values cannot be submitted.}"
        return 0
    fi
    PICK_MSG=
    PICK_CONFIRMING=1
    PICK_CONFIRM_AT=0
    PICK_CONFIRM_OFFSET=0
    PICK_CONFIRM_COLS=
}

pick_confirm_action() {
    # Enter and Space always run the focused action here, so a Submit key
    # that is held down does not go through both screens.
    local action=$PICK_KEY_ACTION
    PICK_KEY_ACTION=
    case $PICK_PRESSED in Enter|Space) action=choose ;; esac
    case $action in
        up) ((PICK_CONFIRM_OFFSET == 0)) || PICK_CONFIRM_OFFSET=$((PICK_CONFIRM_OFFSET - 1)) ;;
        down) PICK_CONFIRM_OFFSET=$((PICK_CONFIRM_OFFSET + 1)) ;;
        prev_value|next_value|prev_tab|next_tab) PICK_CONFIRM_AT=$((1 - PICK_CONFIRM_AT)) ;;
        choose)
            if ((PICK_CONFIRM_AT == 0)); then PICK_KEY_ACTION=confirmed
            else PICK_CONFIRMING=0; fi
            ;;
        back|cancel) PICK_CONFIRMING=0 ;;
    esac
}

pick_confirm_line() {
    local n=${#PICK_CONFIRM_LINE[@]}
    PICK_CONFIRM_LINE[n]=$1
    PICK_CONFIRM_STYLE[n]=${2-}
    PICK_CONFIRM_SPANS[n]=${3-}
}

pick_confirm_build() {
    # $1 = width; fills the lines with the rows that change, and those the
    # review has a note for, under the headers of their groups.
    local cols=$1 i j k g common width indent label=0 line was
    local -a rows=() reverse path previous=() PICK_FOCUS=()
    PICK_CONFIRM_COLS=$cols
    PICK_CONFIRM_LINE=()
    PICK_CONFIRM_STYLE=()
    PICK_CONFIRM_SPANS=()
    pick_walk_group 0
    for i in "${PICK_FOCUS[@]}"; do
        [[ ${PICK_RESULT[i]} != "${PICK_CURRENT[i]}" || -n ${PICK_REVIEW_NOTE[i]-} ]] || continue
        rows[${#rows[@]}]=$i
        pick_clip "${PICK_LABEL[i]}" 9999
        width=$((PICK_WIDTH + 2 * PICK_GLEVEL[PICK_IGROUP[i]]))
        ((width <= label)) || label=$width
    done
    ((label <= cols / 2)) || label=$((cols / 2))
    if ((${#rows[@]} == 0)); then pick_confirm_line 'No changes.' "$PICK_STYLE_MUTED"; return 0; fi
    for i in "${rows[@]}"; do
        g=${PICK_IGROUP[i]}
        reverse=(); path=()
        while ((g > 0)); do
            reverse[${#reverse[@]}]=$g
            g=${PICK_GPARENT[g]}
        done
        for ((j=${#reverse[@]}-1; j>=0; j--)); do path[${#path[@]}]=${reverse[j]}; done
        common=0
        while ((common < ${#path[@]} && common < ${#previous[@]})) &&
              [[ ${path[common]} == "${previous[common]}" ]]; do
            common=$((common + 1))
        done
        if ((common == 0 && ${#PICK_CONFIRM_LINE[@]})) && [[ ${path[0]-} != "${previous[0]-}" ]]; then pick_confirm_line ''; fi
        for ((k=common; k<${#path[@]}; k++)); do
            g=${path[k]}
            [[ -n ${PICK_GLABEL[g]} ]] || continue
            printf -v indent '%*s' "$((2 * PICK_GLEVEL[g] - 2))" ''
            pick_confirm_line "$indent${PICK_GLABEL[g]}" "$PICK_STYLE_GROUP"
        done
        previous=("${path[@]}")
        printf -v indent '%*s' "$((2 * PICK_GLEVEL[PICK_IGROUP[i]]))" ''
        pick_fit "${PICK_LABEL[i]}" "$((label - ${#indent}))"
        line=$indent$PICK_FITTED
        pick_format_value "$i" "${PICK_CURRENT[i]}"
        was=$PICK_TEXT
        if [[ ${PICK_RESULT[i]} == "${PICK_CURRENT[i]}" ]]; then pick_confirm_line "$line$was"
        else
            was="$line$was $PICK_ARROW "
            pick_format_value "$i" "${PICK_RESULT[i]}"
            pick_confirm_line "$was$PICK_TEXT" '' "${#line} MUTED ${#was} CHANGED"
        fi
        [[ -n ${PICK_REVIEW_NOTE[i]-} ]] || continue
        pick_wrap "${PICK_REVIEW_NOTE[i]}" "$((cols - ${#indent} - 2))"
        for line in "${PICK_WRAPPED[@]}"; do pick_confirm_line "$indent  $line" "$PICK_STYLE_MUTED"; done
    done
}

pick_confirm_buttons() {
    # Sets PICK_ROW and PICK_ROW_SPANS to the two actions.
    local k label
    local -a labels=(Submit Back)
    PICK_ROW=
    PICK_ROW_SPANS=
    for k in 0 1; do
        label=" ${labels[k]} "
        if ((k != PICK_CONFIRM_AT)); then PICK_ROW_SPANS="$PICK_ROW_SPANS ${#PICK_ROW} PLAIN"
        else
            [[ -n $PICK_STYLE_TAB ]] || label="[${labels[k]}]"
            PICK_ROW_SPANS="$PICK_ROW_SPANS ${#PICK_ROW} TAB"
        fi
        PICK_ROW="$PICK_ROW$label"
        PICK_ROW_SPANS="$PICK_ROW_SPANS ${#PICK_ROW} PLAIN"
        PICK_ROW="$PICK_ROW "
    done
}

pick_render_confirm() {
    # $1 = rows, $2 = width. The actions stay below the lines, which scroll;
    # on a short terminal the spacers, the hint, and the title give way.
    local rows=$1 cols=$2 total h d end avail title counter= show_title=0 hint_rows top=0 middle=0 bottom=0
    [[ $PICK_CONFIRM_COLS == "$cols" ]] || pick_confirm_build "$cols"
    total=${#PICK_CONFIRM_LINE[@]}
    avail=$((rows - 2))
    if ((avail > 0)); then show_title=1; avail=$((avail - 1)); fi
    hint_rows=${#PICK_HINT[@]}
    ((hint_rows <= avail)) || hint_rows=$((avail > 0 ? avail : 0))
    avail=$((avail - hint_rows))
    if ((avail > 0)); then middle=1; avail=$((avail - 1)); fi
    if ((avail > 0)); then bottom=1; avail=$((avail - 1)); fi
    if ((avail > 0)); then top=1; avail=$((avail - 1)); fi
    h=$((avail > 0 ? avail + 1 : 1))
    ((h <= total)) || h=$total
    ((PICK_CONFIRM_OFFSET <= total - h)) || PICK_CONFIRM_OFFSET=$((total - h))
    end=$((PICK_CONFIRM_OFFSET + h))
    ((h == total)) || counter="  ($((PICK_CONFIRM_OFFSET + 1))-$end/$total)"
    title=$PICK_CONFIRM_PROMPT
    pick_clip "$title" "$((cols - ${#counter}))"
    ((!show_title)) || pick_frame_row "$PICK_CLIPPED$counter" "$PICK_STYLE_TITLE"
    ((!top)) || pick_frame_row ''
    for ((d=PICK_CONFIRM_OFFSET; d<end; d++)); do
        pick_frame_row "${PICK_CONFIRM_LINE[d]}" "${PICK_CONFIRM_STYLE[d]}" "${PICK_CONFIRM_SPANS[d]}"
    done
    ((!middle)) || pick_frame_row ''
    pick_confirm_buttons
    pick_frame_row "$PICK_ROW" '' "$PICK_ROW_SPANS"
    ((!bottom)) || pick_frame_row ''
    for ((d=0; d<hint_rows; d++)); do pick_frame_row "${PICK_HINT[d]}" "$PICK_STYLE_MUTED"; done
}
