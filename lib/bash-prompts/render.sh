# bash-prompts: viewport layout, sticky headers, rows, and frame composition.
# Function definitions only; sourced in the caller shell by lib/bash-prompts.sh.

pick_sticky() {
    # Keep the nearest ancestors when a short viewport cannot fit them all;
    # the caller reserves one row for the focused item.
    local capacity=$1 g=${PICK_DGROUP[PICK_OFFSET]:-0} i keep
    local -a reverse=()
    PICK_STICKY=()
    while ((g > 0)); do
        if [[ -n ${PICK_GLABEL[g]} ]] && ((PICK_GROW[g] < PICK_OFFSET)); then
            reverse[${#reverse[@]}]=$g
        fi
        g=${PICK_GPARENT[g]}
    done
    keep=${#reverse[@]}
    ((keep <= capacity)) || keep=$capacity
    for ((i=keep-1; i>=0; i--)); do PICK_STICKY[${#PICK_STICKY[@]}]=${reverse[i]}; done
    return 0
}

pick_render() {
    # A pending interrupt means the terminal is already restored; build
    # nothing so no further frame is composed for a dead screen.
    [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
    local rows cols h d total drow start end title counter avail show_title show_msg hint_rows spacer pinned g
    pick_term_size
    rows=$PICK_TROWS
    cols=$PICK_TCOLS
    # The inline painter keeps the last column free.
    pick_hint "$((cols - 1))"
    # The frame never exceeds the terminal height, or relative repainting
    # would lose rows that scrolled off. The list keeps at least one row;
    # the title, message, hint lines, and spacer take what remains in that
    # order, and the list gets the rest, up to its length.
    total=${#PICK_DKIND[@]}
    avail=$((rows - 1))
    show_title=0; show_msg=0; hint_rows=0; spacer=0
    if ((avail > 0)); then show_title=1; avail=$((avail - 1)); fi
    if [[ -n $PICK_MSG ]] && ((avail > 0)); then show_msg=1; avail=$((avail - 1)); fi
    hint_rows=${#PICK_HINT[@]}
    ((hint_rows > avail)) && hint_rows=$avail
    avail=$((avail - hint_rows))
    if ((avail > 0)); then spacer=1; avail=$((avail - 1)); fi
    h=$((avail + 1))
    ((h > total)) && h=$total
    drow=${PICK_FOCUS_ROW[PICK_CURSOR]:-0}
    ((drow < PICK_OFFSET)) && PICK_OFFSET=$drow
    ((drow >= PICK_OFFSET + h)) && PICK_OFFSET=$((drow - h + 1))
    ((PICK_OFFSET > total - h)) && PICK_OFFSET=$((total - h))
    ((PICK_OFFSET < 0)) && PICK_OFFSET=0
    # Moving the offset forward can expose another ancestor header. Rebuild
    # until the focus fits; the reserved item row bounds the offset by drow.
    while :; do
        pick_sticky "$((h - 1))"
        pinned=${#PICK_STICKY[@]}
        ((drow < PICK_OFFSET + h - pinned)) && break
        PICK_OFFSET=$((drow - h + pinned + 1))
    done
    PICK_FRAME=()
    PICK_FRAME_STYLE=()
    if [[ -n ${PICK_PROMPT-} ]]; then title=$PICK_PROMPT
    elif [[ $PICK_MODE == single ]]; then title='Choose one item'
    else title='Select items'; fi
    if ((total > h)); then
        # Shorten the prompt rather than the position it is followed by.
        counter="  ($((PICK_CURSOR + 1))/${#PICK_FOCUS[@]})"
        pick_clip "$title" "$((cols - 1 - ${#counter}))"
        title=$PICK_CLIPPED$counter
    fi
    if ((show_title)); then
        PICK_FRAME[0]=$title
        PICK_FRAME_STYLE[0]=$PICK_STYLE_TITLE
    fi
    start=$PICK_OFFSET
    end=$((start + h))
    for g in "${PICK_STICKY[@]}"; do
        pick_header_line "$g"
        PICK_FRAME_STYLE[${#PICK_FRAME[@]}]=$PICK_ROW_STYLE
        PICK_FRAME[${#PICK_FRAME[@]}]=$PICK_ROW
        end=$((end - 1))
    done
    # Automatic spacing at the top separates nothing. Trailing headers
    # introduce no visible items; explicit separators remain visible.
    if [[ ${PICK_DKIND[start]-} == blank ]]; then
        start=$((start + 1))
        end=$((end + 1))
    fi
    ((end > total)) && end=$total
    while ((end - 1 > drow)) && [[ ${PICK_DKIND[end - 1]} == blank || ${PICK_DKIND[end - 1]} == header ]]; do
        end=$((end - 1))
    done
    for ((d=start; d<end; d++)); do
        pick_render_row "$d"
        PICK_FRAME_STYLE[${#PICK_FRAME[@]}]=$PICK_ROW_STYLE
        PICK_FRAME[${#PICK_FRAME[@]}]=$PICK_ROW
    done
    ((spacer)) && PICK_FRAME[${#PICK_FRAME[@]}]=
    for ((d=0; d<hint_rows; d++)); do
        PICK_FRAME_STYLE[${#PICK_FRAME[@]}]=$PICK_STYLE_MUTED
        PICK_FRAME[${#PICK_FRAME[@]}]=${PICK_HINT[d]}
    done
    ((show_msg)) && PICK_FRAME[${#PICK_FRAME[@]}]=$PICK_MSG
    if [[ -n $PICK_PREV_ROWS && ( $rows != "$PICK_PREV_ROWS" || $cols != "$PICK_PREV_COLS" ) ]]; then
        # A resize may reflow the painted lines, so their height is unknown;
        # repaint from a cleared screen instead of erasing by line count.
        # A handler may have run during the size probe; the refusal lives in
        # pick_clear_screen itself so this clear cannot be missed.
        pick_clear_screen || return 1
        PICK_PREV_COUNT=0
    fi
    PICK_PREV_ROWS=$rows
    PICK_PREV_COLS=$cols
    # Propagate the refusal: assigning PICK_PREV_COUNT afterwards would mask
    # a nonzero return into a successful render.
    pick_emit_frame "$cols" || return 1
    PICK_PREV_COUNT=${#PICK_FRAME[@]}
}

pick_render_row() {
    # $1 = display row; sets PICK_ROW and PICK_ROW_STYLE.
    local d=$1
    PICK_ROW=
    PICK_ROW_STYLE=
    case ${PICK_DKIND[d]-} in
        header) pick_header_line "${PICK_DREF[d]}" ;;
        separator)
            PICK_ROW=${PICK_SEPARATOR_LABEL[${PICK_DREF[d]}]:-'---------------'}
            PICK_ROW_STYLE=$PICK_STYLE_MUTED
            ;;
        item) pick_item_line "${PICK_FOCUS[${PICK_DREF[d]}]}" "${PICK_DREF[d]}" ;;
    esac
}

pick_header_line() {
    local g=$1 level indent=
    for ((level=1; level<PICK_GLEVEL[g]; level++)); do indent="$indent  "; done
    PICK_ROW="$indent${PICK_GLABEL[g]}"
    PICK_ROW_STYLE=$PICK_STYLE_GROUP
    [[ $PICK_MODE != single ]] || return 0
    pick_group_counts "$g"
    PICK_ROW="$PICK_ROW ($PICK_GSEL/$PICK_GTOT)"
}

pick_item_line() {
    local idx=$1 pos=$2 mark="[ ]" notes= reqs= k j g indent=
    PICK_ROW_STYLE=
    [[ -z ${PICK_DISABLED[idx]:-} ]] || PICK_ROW_STYLE=$PICK_STYLE_MUTED
    g=${PICK_IGROUP[idx]}
    for ((k=0; k<PICK_GLEVEL[g]; k++)); do indent="$indent  "; done
    if [[ $PICK_MODE == single ]]; then
        mark=
    elif [[ ${PICK_STATE[idx]:-0} == 1 ]]; then
        mark="[x]"
    fi
    # A checked row explains what keeps it checked; an unchecked row shows
    # what checking it would add.
    if [[ $PICK_MODE == dependencies && ${PICK_STATE[idx]:-0} == 1 ]]; then
        if [[ -n ${PICK_FLOCK[idx]:-} ]]; then
            notes="required by ${PICK_FLOCK[idx]}"
            [[ ${PICK_DEPENDENCY_MODE:-cascade} != lock ]] || notes="$notes; locked"
        elif [[ ${PICK_DIRECT[idx]:-0} != 1 ]]; then
            notes=auto
        fi
    elif [[ $PICK_MODE == dependencies ]]; then
        pick_split_csv "${PICK_DEPS[idx]-}"
        for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
            j=$(pick_find_id "${PICK_SPLIT[k]}")
            [[ $j -lt 0 ]] && continue
            [[ -z $reqs ]] || reqs="$reqs, "
            reqs="$reqs${PICK_LABEL[j]}"
        done
        [[ -z $reqs ]] || notes="requires $reqs"
    fi
    if [[ -n ${PICK_DISABLED[idx]:-} ]]; then
        notes="${notes:+$notes; }${PICK_DISABLED[idx]}"
    fi
    if ((pos == PICK_CURSOR)); then
        PICK_ROW="$indent> "
        PICK_ROW_STYLE=$PICK_STYLE_FOCUS
    else PICK_ROW="$indent  "; fi
    PICK_ROW="$PICK_ROW${mark:+$mark }${PICK_LABEL[idx]}${notes:+  ($notes)}"
}
