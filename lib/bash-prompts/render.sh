# bash-prompts: viewport layout, sticky headers, rows, and frame composition.
# Function definitions only; sourced in the caller shell by lib/bash-prompts.sh.

pick_sticky() {
    # Keep the nearest ancestors when a short viewport cannot fit them all;
    # the caller reserves one row for the focused item.
    local capacity=$1 g=${PICK_DGROUP[PICK_OFFSET]:-0} i keep
    local -a reverse=()
    PICK_STICKY=()
    while ((g > 0 && g != PICK_ROOT)); do
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

pick_frame_row() {
    # $1 = text, $2 = style, $3 = spans: pairs of an offset and the role
    # whose PICK_STYLE_* applies from there. The row goes inside PICK_WALLS
    # frames.
    local n=${#PICK_FRAME[@]}
    PICK_FRAME[n]=$1
    PICK_FRAME_WALLS[n]=$PICK_WALLS
    PICK_FRAME_STYLE[n]=${2-}
    PICK_FRAME_SPANS[n]=${3-}
}

pick_render() {
    # A pending interrupt means the terminal is already restored; build
    # nothing so no further frame is composed for a dead screen.
    [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
    local rows cols h d total drow start end title counter avail show_tabs show_subs framed walls inner show_title show_columns tab_spacer msg_rows msg_style msg_spacer hint_rows spacer pinned g
    pick_term_size
    rows=$PICK_TROWS
    cols=$PICK_TCOLS
    PICK_AT=$PICK_CURSOR
    ((!PICK_ON_TABS)) || PICK_AT=-1
    # The inline painter keeps the last column free.
    pick_hint "$((cols - 1))"
    if ((PICK_CONFIRMING)); then
        PICK_FRAME=(); PICK_FRAME_STYLE=(); PICK_FRAME_SPANS=(); PICK_FRAME_WALLS=(); PICK_WALLS=0
        pick_render_confirm "$rows" "$((cols - 1))"
        pick_paint "$rows" "$cols"
        return
    fi
    # A frame encloses the contents of the active tab, and another those of
    # its active sub-tab, if they fit: three rows for each, and their walls
    # take four columns.
    walls=0
    ((!${#PICK_TAB_GROUPS[@]})) || walls=$((1 + (PICK_TAB_SUBS[PICK_TAB_AT] > 0)))
    while :; do
        inner=$((cols - 1 - 4 * walls))
        [[ $PICK_MODE != choices ]] || pick_value_column "$inner"
        PICK_WRAPPED=()
        msg_style=$PICK_MSG_STYLE
        if [[ -n $PICK_MSG ]]; then pick_wrap "$PICK_MSG" "$((cols - 1))"
        elif [[ $PICK_MODE == choices && -z $PICK_FIELD ]] && ((PICK_AT >= 0)); then
            # The focused row's note, when the row has no room for all of it.
            msg_style=$PICK_STYLE_MUTED
            pick_item_line "${PICK_FOCUS[PICK_CURSOR]}" "$PICK_CURSOR"
            pick_clip "$PICK_ROW" "$inner"
            [[ $PICK_CLIPPED == "$PICK_ROW" ]] || pick_wrap "$PICK_NOTES" "$((cols - 1))"
        fi
        [[ -z $PICK_FIELD ]] || PICK_WRAPPED=("$PICK_FIELD" "${PICK_WRAPPED[@]}")
        # The frame never exceeds the terminal height, or relative repainting
        # would lose rows that scrolled off. The list keeps at least one row;
        # the tabs, sub-tabs, title, message, hint lines, column headers,
        # spacers, and the frame of the tabs take what remains in that order,
        # and the list gets the rest, up to its length.
        total=${#PICK_DKIND[@]}
        avail=$((rows - 1))
        show_tabs=0; show_subs=0; framed=0; show_title=0; show_columns=0; tab_spacer=0; spacer=0; msg_spacer=0
        if ((${#PICK_TAB_GROUPS[@]} > 0 && avail > 0)); then show_tabs=1; avail=$((avail - 1)); fi
        if ((show_tabs && PICK_TAB_SUBS[PICK_TAB_AT] && avail > 0)); then show_subs=1; avail=$((avail - 1)); fi
        if ((avail > 0)); then show_title=1; avail=$((avail - 1)); fi
        msg_rows=${#PICK_WRAPPED[@]}
        ((msg_rows > avail)) && msg_rows=$avail
        avail=$((avail - msg_rows))
        hint_rows=${#PICK_HINT[@]}
        ((hint_rows > avail)) && hint_rows=$avail
        avail=$((avail - hint_rows))
        if [[ $PICK_MODE == choices ]] && ((PICK_HEADED && avail > 0)); then show_columns=1; avail=$((avail - 1)); fi
        if ((avail > 0)); then spacer=1; avail=$((avail - 1)); fi
        if ((msg_rows > 0 && avail > 0)); then msg_spacer=1; avail=$((avail - 1)); fi
        if ((walls && show_tabs && show_subs + 1 >= walls && avail >= 3 * walls)); then
            framed=1; avail=$((avail - 3 * walls))
        elif ((show_tabs && avail > 0)); then tab_spacer=1; avail=$((avail - 1)); fi
        ((framed || !walls)) && break
        walls=0
    done
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
    PICK_FRAME_SPANS=()
    PICK_FRAME_WALLS=()
    PICK_WALLS=0
    if [[ -n ${PICK_PROMPT-} ]]; then title=$PICK_PROMPT
    elif [[ $PICK_MODE == single ]]; then title='Choose one item'
    else title='Select items'; fi
    counter=
    ((total <= h)) || counter="  ($((PICK_CURSOR + 1))/${#PICK_FOCUS[@]})"
    # Shorten the prompt rather than the position it is followed by.
    pick_clip "$title" "$((cols - 1 - ${#counter}))"
    ((show_title)) && pick_frame_row "$PICK_CLIPPED$counter" "$PICK_STYLE_TITLE"
    ((show_tabs)) && pick_tab_rows "$((cols - 1))" "$framed" "$show_subs"
    PICK_WALLS=$walls
    ((tab_spacer)) && pick_frame_row ''
    if ((show_columns)); then
        pick_column_line
        pick_frame_row "$PICK_ROW" "$PICK_STYLE_MUTED"
    fi
    start=$PICK_OFFSET
    end=$((start + h))
    for g in "${PICK_STICKY[@]}"; do
        pick_header_line "$g"
        pick_frame_row "$PICK_ROW" "$PICK_ROW_STYLE"
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
        pick_frame_row "$PICK_ROW" "$PICK_ROW_STYLE" "$PICK_ROW_SPANS"
    done
    # The frame of a sub-tab is light, that of a tab heavy.
    if ((PICK_WALLS > 1)); then
        PICK_WALLS=1
        pick_box_rule "$((cols - 7))"
        pick_frame_row "$PICK_BOX_BL$PICK_RULE$PICK_BOX_BR"
    fi
    if ((PICK_WALLS)); then
        PICK_WALLS=0
        pick_box_rule "$((cols - 3))"
        pick_frame_row "$PICK_HEAVY_BL${PICK_RULE//$PICK_BOX_H/$PICK_HEAVY_H}$PICK_HEAVY_BR"
    fi
    ((spacer)) && pick_frame_row ''
    for ((d=0; d<msg_rows; d++)); do
        if ((d == 0)) && [[ -n $PICK_FIELD ]]; then pick_frame_row "${PICK_WRAPPED[d]}"
        else pick_frame_row "${PICK_WRAPPED[d]}" "$msg_style"; fi
    done
    ((msg_spacer)) && pick_frame_row ''
    for ((d=0; d<hint_rows; d++)); do pick_frame_row "${PICK_HINT[d]}" "$PICK_STYLE_MUTED"; done
    pick_paint "$rows" "$cols"
}

pick_paint() {
    # $1 = rows, $2 = width; puts the frame on the screen.
    local rows=$1 cols=$2
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
    # $1 = display row; sets PICK_ROW, PICK_ROW_STYLE, and PICK_ROW_SPANS.
    local d=$1
    PICK_ROW=
    PICK_ROW_STYLE=
    PICK_ROW_SPANS=
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
    for ((level=1; level<PICK_GLEVEL[g] - PICK_GLEVEL[PICK_ROOT]; level++)); do indent="$indent  "; done
    PICK_TITLE=${PICK_GLABEL[g]}
    [[ $PICK_MODE == choices ]] || pick_group_title "$g"
    PICK_ROW="$indent$PICK_TITLE"
    PICK_ROW_STYLE=$PICK_STYLE_GROUP
}

pick_group_title() {
    # Sets PICK_TITLE to the group's label and its counts: selected and total
    # checkboxes, or a tab's value rows that change.
    PICK_TITLE=${PICK_GLABEL[$1]}
    [[ $PICK_MODE != single ]] || return 0
    # The submit tab counts the rows of every tab.
    if (($1 == PICK_SUBMIT_GROUP)); then pick_group_counts 0
    else pick_group_counts "$1"; fi
    if [[ $PICK_MODE != choices ]]; then PICK_TITLE="$PICK_TITLE ($PICK_GSEL/$PICK_GTOT)"
    elif ((PICK_GSEL)); then PICK_TITLE="$PICK_TITLE ($PICK_GSEL)"; fi
}

pick_tab_rows() {
    # $1 = width, $2 = 1 to frame the tabs, $3 = 1 to show sub-tabs. Adds
    # the tabs to the frame, then the sub-tabs of the active one inside the
    # frame of its contents, framed the same way.
    local cols=$1 box=$2 subs=$3 first=${PICK_TAB_FIRST[PICK_TAB_AT]} k spans= IFS=' '
    local -a sp=() pages=("${PICK_PAGES[@]:first:${PICK_TAB_SUBS[PICK_TAB_AT]}}")
    if ((box)); then
        pick_folder_rows "$cols" "$PICK_TAB_AT" "$((PICK_ON_TABS == 1))" 0 "${PICK_TAB_GROUPS[@]}"
        ((!subs)) || PICK_WALLS=1
        ((!subs)) || pick_folder_rows "$((cols - 4))" "$((PICK_PAGE_AT - first))" "$((PICK_ON_TABS == 2))" 1 "${pages[@]}"
        return 0
    fi
    pick_bar_line "$cols" "$PICK_TAB_AT" "$((PICK_ON_TABS == 1))" 0 "${PICK_TAB_GROUPS[@]}"
    pick_frame_row "$PICK_ROW" '' "$PICK_ROW_SPANS"
    ((subs)) || return 0
    pick_bar_line "$((cols - 2))" "$((PICK_PAGE_AT - first))" "$((PICK_ON_TABS == 2))" 0 "${pages[@]}"
    pick_clip "$PICK_ROW" "$((cols - 2))"
    sp=($PICK_ROW_SPANS)
    for ((k=0; k<${#sp[@]}; k+=2)); do
        ((sp[k] <= ${#PICK_CLIPPED})) || break
        spans="$spans $((sp[k] + 2)) ${sp[k + 1]}"
    done
    pick_frame_row "  $PICK_CLIPPED" '' "0 PLAIN$spans $((2 + ${#PICK_CLIPPED})) PLAIN"
}

pick_folder_rows() {
    # $1 = width, $2 = active tab, $3 = 1 while the bar has the focus, $4 = 1
    # for sub-tabs, then the groups of the tabs. Adds the bar with the active
    # tab as a box open at the bottom onto the frame of its contents, the
    # shape of a folder tab. Tabs are drawn in heavy lines and sub-tabs in
    # light ones, and tabs take two cells of space around their labels.
    local cols=$1 left right edge line pad bar_pad=' '
    if ((!$4)); then
        bar_pad='  '
        local PICK_BOX_H=$PICK_HEAVY_H PICK_BOX_V=$PICK_HEAVY_V PICK_BOX_TL=$PICK_HEAVY_TL
        local PICK_BOX_TR=$PICK_HEAVY_TR PICK_BOX_BL=$PICK_HEAVY_BL PICK_BOX_BR=$PICK_HEAVY_BR
    fi
    pick_bar_line "$cols" "$2" "$3" 1 "${@:5}"
    left=$PICK_BAR_LEFT
    right=$PICK_BAR_RIGHT
    edge=$((cols - 1))
    ((edge >= right)) || edge=$right
    printf -v line '%*s' "$left" ''
    pick_box_rule "$((right - left - 1))"
    pick_frame_row "$line$PICK_BOX_TL$PICK_RULE$PICK_BOX_TR"
    pick_frame_row "$PICK_ROW" '' "$PICK_ROW_SPANS"
    # A wall at the edge runs on down as the frame's; elsewhere it turns
    # along the top of the frame.
    line=$PICK_BOX_V
    if ((left > 0)); then pick_box_rule "$((left - 1))"; line=$PICK_BOX_TL$PICK_RULE$PICK_BOX_BR; fi
    printf -v pad '%*s' "$((right - left - 1))" ''
    line+=$pad
    if ((right == edge)); then line+=$PICK_BOX_V
    else pick_box_rule "$((edge - right - 1))"; line+=$PICK_BOX_BL$PICK_RULE$PICK_BOX_TR; fi
    pick_frame_row "$line"
}

pick_box_rule() {
    # $1 = cells; sets PICK_RULE to a horizontal line that long.
    PICK_RULE=
    (($1 > 0)) || return 0
    printf -v PICK_RULE '%*s' "$1" ''
    PICK_RULE=${PICK_RULE// /$PICK_BOX_H}
}

pick_bar_line() {
    # $1 = width, $2 = active tab, $3 = 1 while the bar has the focus, $4 = 1
    # to frame the active tab, then the groups of the tabs. Sets PICK_ROW and
    # PICK_ROW_SPANS, and when framed PICK_BAR_LEFT and PICK_BAR_RIGHT to the
    # cells of the walls; every tab then has a free cell on each side, so a
    # wall moves no label. The active tab and the submit tab, which is the
    # last one, always show. The neighbors of the active one join while they
    # fit, and < > stand for the tabs left out. Labels take bar_pad of the
    # caller around them, or one space.
    local cols=$1 at=$2 focus=$3 box=$4 n k m first last used total grew cell=0 wall=0
    shift 4
    local -a groups=("$@") text=() cells=()
    n=${#groups[@]}
    total=0
    for ((k=0; k<n; k++)); do
        pick_group_title "${groups[k]}"
        text[k]="${bar_pad:- }$PICK_TITLE${bar_pad:- }"
        if ((k != at)); then :
        elif ((box)); then ((!focus)) || [[ -n $PICK_STYLE_TAB ]] || text[k]="${bar_pad#?}> $PICK_TITLE$bar_pad"
        elif ((focus)); then [[ -n $PICK_STYLE_TAB ]] || text[k]="[> $PICK_TITLE]"
        elif [[ -z $PICK_STYLE_ACTIVE ]]; then text[k]="[$PICK_TITLE]"; fi
        pick_clip "${text[k]}" 9999
        cells[k]=$PICK_WIDTH
        total=$((total + PICK_WIDTH))
    done
    total=$((total + n - 1 + 2 * box))
    m=$n
    ((groups[n - 1] != PICK_SUBMIT_GROUP)) || m=$((n - 1))
    first=0; last=$((m - 1))
    if ((total > cols)); then
        cols=$((cols - box))
        ((m == n)) || cols=$((cols - cells[m] - 1))
        first=$at
        ((first < m)) || first=$((m - 1))
        last=$first
        used=$((cells[first] + 2 + 4 * box))
        grew=1
        if ((at == m && used > cols)); then first=$m; grew=0; fi
        while ((grew)); do
            grew=0
            if ((last < m - 1)) && ((used + 1 + cells[last + 1] <= cols)); then
                last=$((last + 1)); used=$((used + 1 + cells[last])); grew=1
            fi
            if ((first > 0)) && ((used + 1 + cells[first - 1] <= cols)); then
                first=$((first - 1)); used=$((used + 1 + cells[first])); grew=1
            fi
        done
    fi
    PICK_ROW=
    PICK_ROW_SPANS='0 MUTED'
    PICK_BAR_LEFT=-1
    PICK_BAR_RIGHT=-1
    # Framed, a space keeps < and > off the walls.
    if ((first > 0)); then PICK_ROW='<'; cell=1; fi
    if ((first > 0 && box)); then PICK_ROW+=' '; cell=2; fi
    if ((box)); then wall=$((first == at)); pick_bar_gap; fi
    for ((k=first; k<=last; k++)); do
        if ((k > first)); then
            ((!box || k != at)) || wall=1
            pick_bar_gap 1
        fi
        pick_bar_tab "$k"
    done
    if ((last < m - 1)); then
        if ((box)); then
            pick_bar_gap
            PICK_ROW_SPANS="$PICK_ROW_SPANS ${#PICK_ROW} MUTED"
            PICK_ROW+=' '
            cell=$((cell + 1))
        fi
        PICK_ROW="$PICK_ROW>"
        cell=$((cell + 1))
    fi
    if ((m < n)); then
        ((!box || m != at)) || wall=1
        pick_bar_gap
        pick_bar_tab "$m"
    fi
    ((!box)) || pick_bar_gap
}

pick_bar_gap() {
    # $1 = 1 between two tabs. Adds a free cell beside a tab for
    # pick_bar_line, or a wall beside the framed one.
    ((!wall && !${1:-0})) || PICK_ROW_SPANS="$PICK_ROW_SPANS ${#PICK_ROW} PLAIN"
    if ((wall)); then PICK_ROW+=$PICK_BOX_V; else PICK_ROW+=' '; fi
    cell=$((cell + 1))
    wall=0
}

pick_bar_tab() {
    # $1 = tab; adds it to PICK_ROW for pick_bar_line.
    local role=PLAIN
    if (($1 == at)); then
        if ((focus)); then role=TAB
        elif ((box)); then role=FOCUS
        else role=ACTIVE; fi
        if ((box)); then
            PICK_BAR_LEFT=$((cell - 1))
            PICK_BAR_RIGHT=$((cell + cells[$1]))
            wall=1
        fi
    fi
    PICK_ROW_SPANS="$PICK_ROW_SPANS ${#PICK_ROW} $role"
    PICK_ROW=$PICK_ROW${text[$1]}
    PICK_ROW_SPANS="$PICK_ROW_SPANS ${#PICK_ROW} MUTED"
    cell=$((cell + cells[$1]))
}

pick_submit_line() {
    # $1 = focus position of an action on the submit page.
    PICK_ROW=Submit
    (($1 == 0)) || PICK_ROW=Cancel
    PICK_ROW_STYLE=
    PICK_ROW_SPANS=
    PICK_NOTES=
    if (($1 == PICK_AT)); then
        PICK_ROW="> $PICK_ROW"
        PICK_ROW_STYLE=$PICK_STYLE_FOCUS
    else PICK_ROW="  $PICK_ROW"; fi
}

pick_item_line() {
    local idx=$1 pos=$2 mark="[ ]" notes why= reqs= k j g indent=
    if ((idx >= ${#PICK_LABEL[@]})); then pick_submit_line "$pos"; return 0; fi
    g=${PICK_IGROUP[idx]}
    for ((k=PICK_GLEVEL[PICK_ROOT]; k<PICK_GLEVEL[g]; k++)); do indent="$indent  "; done
    if [[ $PICK_MODE == choices ]]; then pick_value_line "$idx" "$pos" "$indent"; return 0; fi
    notes=${PICK_NOTE[idx]-}
    PICK_ROW_STYLE=
    [[ -z ${PICK_DISABLED[idx]:-} ]] || PICK_ROW_STYLE=$PICK_STYLE_MUTED
    if [[ $PICK_MODE == single ]]; then
        mark=
    elif [[ ${PICK_STATE[idx]:-0} == 1 ]]; then
        mark="[x]"
    fi
    # A checked row explains what keeps it checked; an unchecked row shows
    # what checking it would add.
    if [[ $PICK_MODE == dependencies && ${PICK_STATE[idx]:-0} == 1 ]]; then
        if [[ -n ${PICK_FLOCK[idx]:-} ]]; then
            why="required by ${PICK_FLOCK[idx]}"
            [[ ${PICK_DEPENDENCY_MODE:-cascade} != lock ]] || why="$why; locked"
        elif [[ ${PICK_DIRECT[idx]:-0} != 1 ]]; then
            why=auto
        fi
    elif [[ $PICK_MODE == dependencies ]]; then
        pick_split_csv "${PICK_DEPS[idx]-}"
        for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
            j=$(pick_find_id "${PICK_SPLIT[k]}")
            [[ $j -lt 0 ]] && continue
            [[ -z $reqs ]] || reqs="$reqs, "
            reqs="$reqs${PICK_LABEL[j]}"
        done
        [[ -z $reqs ]] || why="requires $reqs"
    fi
    [[ -z $why ]] || notes="${notes:+$notes; }$why"
    [[ -z ${PICK_DISABLED[idx]:-} ]] || notes="${notes:+$notes; }${PICK_DISABLED[idx]}"
    if ((pos == PICK_AT)); then
        PICK_ROW="$indent> "
        PICK_ROW_STYLE=$PICK_STYLE_FOCUS
    else PICK_ROW="$indent  "; fi
    PICK_ROW="$PICK_ROW${mark:+$mark }${PICK_LABEL[idx]}"
    PICK_ROW_SPANS="${#PICK_ROW} MUTED"
    PICK_ROW="$PICK_ROW${notes:+  $notes}"
}
