# bash-prompts: recursive group model, display order, separators, and group jumps.
# Function definitions only; sourced in the caller shell by lib/bash-prompts.sh.

pick_group_index() {
    local id=$1 g
    PICK_GROUP_INDEX=-1
    for ((g=${2:-0}; g<${#PICK_GID[@]}; g++)); do
        if [[ ${PICK_GID[g]} == "$id" ]]; then PICK_GROUP_INDEX=$g; break; fi
    done
}

pick_resolve_group() {
    local g=$1 trail=$2 parent
    # Count cached ancestor depth too. This bound also terminates cycles
    # before they can recurse indefinitely.
    if ((trail + ${PICK_GDEPTH[g]:-1} - 1 > PICK_DEPTH_LIMIT)); then
        pick_err "group '${PICK_GID[g]}' exceeds maximum depth $PICK_DEPTH_LIMIT; check parent links"
        return 1
    fi
    [[ -z ${PICK_GDEPTH[g]+set} ]] || return 0
    parent=${PICK_GPARENT[g]}
    pick_resolve_group "$parent" "$((trail + 1))" || return 1
    PICK_GDEPTH[g]=$((PICK_GDEPTH[parent] + 1))
    PICK_GLEVEL[g]=${PICK_GLEVEL[parent]}
    [[ -z ${PICK_GLABEL[g]} ]] || PICK_GLEVEL[g]=$((PICK_GLEVEL[g] + 1))
    return 0
}

pick_link_group() {
    # Link only groups with included descendants, in first-appearance order.
    local g=$1 parent
    [[ ${PICK_GLINKED[g]:-0} != 1 ]] || return 0
    parent=${PICK_GPARENT[g]}
    pick_link_group "$parent"
    PICK_GCHILDREN[parent]="${PICK_GCHILDREN[parent]-} g$g"
    PICK_GLINKED[g]=1
}

pick_group_is_tail() {
    local id=$1 i
    for ((i=0; i<${#PICK_GROUP_TAIL[@]}; i++)); do
        [[ ${PICK_GROUP_TAIL[i]} == "$id" ]] && return 0
    done
    return 1
}

pick_walk_group() {
    local g=$1 node child IFS=' '
    local -a tail=()
    # Tokens contain only internally generated numeric indices.
    for node in ${PICK_GCHILDREN[g]-}; do
        case $node in
            g*)
                child=${node#g}
                if pick_group_is_tail "${PICK_GID[child]}"; then
                    tail[${#tail[@]}]=$child
                else
                    pick_walk_group "$child"
                fi
                ;;
            i*) PICK_FOCUS[${#PICK_FOCUS[@]}]=${node#i} ;;
        esac
    done
    for child in "${tail[@]}"; do pick_walk_group "$child"; done
    return 0
}

pick_display_row() {
    local d=${#PICK_DKIND[@]}
    PICK_DKIND[d]=$1
    PICK_DREF[d]=$2
    PICK_DGROUP[d]=$3
}

pick_group() {
    local i=${#PICK_GROUP_ID[@]}
    PICK_GROUP_ID[i]=${1-}
    PICK_GROUP_LABEL[i]=${2-${1-}}
    PICK_GROUP_PARENT[i]=${3-}
}

pick_separator() {
    local i=${#PICK_SEPARATOR_BEFORE[@]}
    PICK_SEPARATOR_BEFORE[i]=${1-}
    PICK_SEPARATOR_LABEL[i]=${2-}
}

pick_build_focus() {
    local i g parent id s
    case ${PICK_MAX_GROUP_DEPTH-} in
        ''|*[!0-9]*) pick_err 'PICK_MAX_GROUP_DEPTH must be a positive integer'; return 1 ;;
    esac
    PICK_DEPTH_LIMIT=$((10#$PICK_MAX_GROUP_DEPTH))
    if ((PICK_DEPTH_LIMIT < 1)); then
        pick_err 'PICK_MAX_GROUP_DEPTH must be a positive integer'
        return 1
    fi
    case ${PICK_GROUP_JUMP_DEPTH-} in
        ''|*[!0-9]*) pick_err 'PICK_GROUP_JUMP_DEPTH must be a positive integer'; return 1 ;;
    esac
    PICK_JUMP_DEPTH=$((10#$PICK_GROUP_JUMP_DEPTH))
    if ((PICK_JUMP_DEPTH < 1)); then
        pick_err 'PICK_GROUP_JUMP_DEPTH must be a positive integer'
        return 1
    fi

    # Node zero is the invisible root. Item arrays stay independent of the
    # display tree, so headers and separators never become selection values.
    PICK_GID=(''); PICK_GLABEL=(''); PICK_GPARENT=(-1)
    PICK_GDEPTH=(0); PICK_GLEVEL=(0)
    PICK_GCHILDREN=(''); PICK_GLINKED=(1); PICK_GROW=(-1)
    PICK_IGROUP=(); PICK_SEP_ANCHOR=()
    for ((i=0; i<${#PICK_GROUP_ID[@]}; i++)); do
        id=${PICK_GROUP_ID[i]}
        pick_group_index "$id"
        if [[ -z $id ]] || ((PICK_GROUP_INDEX >= 0)); then
            pick_err "group IDs must be nonempty and unique: '$id'"
            return 1
        fi
        g=${#PICK_GID[@]}
        PICK_GID[g]=$id
        PICK_GLABEL[g]=${PICK_GROUP_LABEL[i]-$id}
    done
    for ((g=1; g<${#PICK_GID[@]}; g++)); do
        parent=${PICK_GROUP_PARENT[g - 1]-}
        pick_group_index "$parent"
        if ((PICK_GROUP_INDEX < 0)); then
            pick_err "group '${PICK_GID[g]}' has unknown parent '$parent'"
            return 1
        fi
        PICK_GPARENT[g]=$PICK_GROUP_INDEX
    done
    for ((g=1; g<${#PICK_GID[@]}; g++)); do
        pick_resolve_group "$g" 1 || return 1
    done
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        [[ ${PICK_VALID[i]:-1} != 0 ]] || continue
        id=${PICK_GROUP[i]-}
        if ((${#PICK_GROUP_ID[@]} > 0)); then
            pick_group_index "$id"
        else
            # Flat input coalesces empty text into one unnamed group too.
            pick_group_index "$id" 1
        fi
        g=$PICK_GROUP_INDEX
        if ((g < 0)); then
            if ((${#PICK_GROUP_ID[@]} > 0)); then
                pick_err "item '${PICK_ID[i]-${PICK_LABEL[i]}}' has unknown group '$id'"
                return 1
            fi
            g=${#PICK_GID[@]}
            PICK_GID[g]=$id; PICK_GLABEL[g]=$id; PICK_GPARENT[g]=0
            PICK_GDEPTH[g]=1; PICK_GLEVEL[g]=0
            [[ -z $id ]] || PICK_GLEVEL[g]=1
        fi
        PICK_IGROUP[i]=$g
        pick_link_group "$g"
        PICK_GCHILDREN[g]="${PICK_GCHILDREN[g]-} i$i"
    done
    for ((s=0; s<${#PICK_SEPARATOR_BEFORE[@]}; s++)); do
        id=${PICK_SEPARATOR_BEFORE[s]}
        i=-1
        if [[ -n $id ]]; then
            i=$(pick_find_id "$id")
            if ((i < 0)); then
                pick_err "separator refers to unknown item '$id'"
                return 1
            fi
        fi
        PICK_SEP_ANCHOR[s]=$i
    done
    pick_build_tabs || return 1
    pick_build_rows
}

pick_group_has_subtabs() {
    local id=$1 i
    for ((i=0; i<${#PICK_SUBTABS[@]}; i++)); do
        [[ ${PICK_SUBTABS[i]} == "$id" ]] && return 0
    done
    return 1
}

pick_child_tabs() {
    # $1 = group, $2 = what its children are; fills PICK_CHILD_TABS with its
    # child groups in display order. Its own items have no tab to appear in.
    local node g i IFS=' '
    local -a tail=()
    PICK_CHILD_TABS=()
    for node in ${PICK_GCHILDREN[$1]}; do
        case $node in
            g*)
                g=${node#g}
                if pick_group_is_tail "${PICK_GID[g]}"; then tail[${#tail[@]}]=$g
                else PICK_CHILD_TABS[${#PICK_CHILD_TABS[@]}]=$g; fi
                ;;
            i*)
                i=${node#i}
                pick_err "item '${PICK_ID[i]-${PICK_LABEL[i]}}' needs a group to appear in a $2"
                return 1
                ;;
        esac
    done
    for g in "${tail[@]}"; do PICK_CHILD_TABS[${#PICK_CHILD_TABS[@]}]=$g; done
    return 0
}

pick_left_root() {
    # Whether left tabs stand in place of the tabs: PICK_LEFTTABS is 1.
    [[ ${PICK_LEFTTABS[*]-} == 1 ]]
}

pick_group_has_lefttabs() {
    local id=$1 i
    for ((i=0; i<${#PICK_LEFTTABS[@]}; i++)); do
        [[ ${PICK_LEFTTABS[i]} == "$id" ]] && return 0
    done
    return 1
}

pick_build_tabs() {
    # With PICK_TABS, the root groups become tabs in their display order, and
    # with PICK_SUBTABS the child groups of a tab become its sub-tabs. The
    # rows of one page are shown at a time: a tab without sub-tabs, or a
    # sub-tab. Pages follow the order of the tabs, sub-tabs in turn. With
    # PICK_LEFTTABS at 1 every root group holds sub-tabs, which are the tabs
    # of the left column, and the root groups head them there. A tab or
    # sub-tab that PICK_LEFTTABS names holds such a column in turn: each tab
    # of it is a page, and the column stands for them in the bars.
    local g k p left=0 what=sub-tab
    PICK_TAB_GROUPS=(); PICK_TAB_FIRST=(); PICK_TAB_SUBS=(); PICK_TAB_PAGE=()
    PICK_PAGES=(); PICK_PAGE_TAB=(); PICK_PAGE_SIDE=(); PICK_PAGE_CURSOR=(); PICK_PAGE_OFFSET=()
    PICK_SIDE_PAGE=()
    PICK_SIDE_LEVEL=0
    PICK_TAB_AT=0
    PICK_PAGE_AT=0
    PICK_ROOT=0
    PICK_SUBMIT_GROUP=-1
    if pick_left_root; then left=1; what='left tab'
    elif [[ ${PICK_TABS:-0} != 1 ]]; then return 0; fi
    pick_child_tabs 0 tab || return 1
    PICK_TAB_GROUPS=("${PICK_CHILD_TABS[@]}")
    ((${#PICK_TAB_GROUPS[@]})) || return 0
    pick_build_submit_tab || return 1
    for ((k=0; k<${#PICK_TAB_GROUPS[@]}; k++)); do
        g=${PICK_TAB_GROUPS[k]}
        PICK_TAB_FIRST[k]=${#PICK_PAGES[@]}
        PICK_TAB_PAGE[k]=${#PICK_PAGES[@]}
        PICK_TAB_SUBS[k]=0
        PICK_CHILD_TABS=("$g")
        if ((g != PICK_SUBMIT_GROUP)) && { ((left)) || pick_group_has_subtabs "${PICK_GID[g]}"; }; then
            pick_child_tabs "$g" "$what" || return 1
            PICK_TAB_SUBS[k]=${#PICK_CHILD_TABS[@]}
        fi
        for g in "${PICK_CHILD_TABS[@]}"; do
            if ((left)) || ! pick_group_has_lefttabs "${PICK_GID[g]}"; then pick_add_page "$k" "$g" 0
            else pick_add_column "$k" "$g" || return 1; fi
        done
    done
    # PICK_TAB names a tab, which opens at its first sub-tab, a sub-tab, or a
    # left tab; a column opens at its first tab.
    for ((k=0; k<${#PICK_TAB_GROUPS[@]}; k++)); do
        [[ ${PICK_GID[${PICK_TAB_GROUPS[k]}]} != "${PICK_TAB-}" ]] || PICK_PAGE_AT=${PICK_TAB_FIRST[k]}
    done
    for ((p=${#PICK_PAGES[@]} - 1; p>=0; p--)); do
        ((!PICK_PAGE_SIDE[p])) || [[ ${PICK_GID[${PICK_PAGE_SIDE[p]}]} != "${PICK_TAB-}" ]] || PICK_PAGE_AT=$p
    done
    for ((p=0; p<${#PICK_PAGES[@]}; p++)); do
        [[ ${PICK_GID[${PICK_PAGES[p]}]} != "${PICK_TAB-}" ]] || PICK_PAGE_AT=$p
    done
    if [[ $PICK_MODE == single ]] && ((PICK_INITIAL_INDEX >= 0)); then
        pick_page_of "$PICK_INITIAL_INDEX"
        PICK_PAGE_AT=$PICK_PAGE_OF
    fi
    PICK_TAB_AT=${PICK_PAGE_TAB[PICK_PAGE_AT]}
    PICK_TAB_PAGE[PICK_TAB_AT]=$PICK_PAGE_AT
    PICK_ROOT=${PICK_PAGES[PICK_PAGE_AT]}
    PICK_TAB=${PICK_GID[PICK_ROOT]}
    pick_side_page
    return 0
}

pick_add_page() {
    # $1 = tab, $2 = group of the page, $3 = group of the column it is a tab
    # of inside a tab or sub-tab, or 0.
    local p=${#PICK_PAGES[@]}
    PICK_PAGE_TAB[p]=$1
    PICK_PAGES[p]=$2
    PICK_PAGE_SIDE[p]=$3
}

pick_add_column() {
    # $1 = tab, $2 = group; adds the tabs of its column as pages, each under
    # the child group that heads it, and the column opens at the first.
    local h t
    local -a heads=()
    pick_child_tabs "$2" 'left tab' || return 1
    heads=("${PICK_CHILD_TABS[@]}")
    PICK_SIDE_PAGE[$2]=${#PICK_PAGES[@]}
    for h in "${heads[@]}"; do
        pick_child_tabs "$h" 'left tab' || return 1
        for t in "${PICK_CHILD_TABS[@]}"; do pick_add_page "$1" "$t" "$2"; done
    done
}

pick_side_page() {
    # Sets PICK_SIDE_LEVEL to the PICK_ON_TABS value that focuses the column
    # of left tabs beside the active page: 1 for left tabs in place of the
    # tabs, 3 for those of a tab or sub-tab, or 0 without a column. Sets
    # PICK_SIDE_FIRST and PICK_SIDE_LAST to its first and last pages, and the
    # column remembers the active one.
    local side=${PICK_PAGE_SIDE[PICK_PAGE_AT]}
    PICK_SIDE_LEVEL=0
    if pick_left_root; then PICK_SIDE_LEVEL=1
    elif ((side)); then PICK_SIDE_LEVEL=3; PICK_SIDE_PAGE[side]=$PICK_PAGE_AT; fi
    PICK_SIDE_FIRST=$PICK_PAGE_AT
    PICK_SIDE_LAST=$PICK_PAGE_AT
    ((PICK_SIDE_LEVEL)) || return 0
    while ((PICK_SIDE_FIRST > 0)) && ((PICK_PAGE_SIDE[PICK_SIDE_FIRST - 1] == side)); do
        PICK_SIDE_FIRST=$((PICK_SIDE_FIRST - 1))
    done
    while ((PICK_SIDE_LAST < ${#PICK_PAGES[@]} - 1)) && ((PICK_PAGE_SIDE[PICK_SIDE_LAST + 1] == side)); do
        PICK_SIDE_LAST=$((PICK_SIDE_LAST + 1))
    done
}

pick_build_submit_tab() {
    # The group in PICK_SUBMIT_TAB becomes the last tab. Its two actions take
    # the indices after the items, so they are never values of a row. Left
    # tabs show it as an item that submits, without a page of its own.
    local g i n=${#PICK_LABEL[@]}
    [[ $PICK_MODE == choices && -n ${PICK_SUBMIT_TAB-} ]] || return 0
    pick_group_index "$PICK_SUBMIT_TAB" 1
    g=$PICK_GROUP_INDEX
    if ((g < 0)) || ((PICK_GPARENT[g] != 0)) || [[ ${PICK_GLINKED[g]:-0} == 1 ]]; then
        pick_err "PICK_SUBMIT_TAB must name a root group without items: '$PICK_SUBMIT_TAB'"
        return 1
    fi
    PICK_SUBMIT_GROUP=$g
    PICK_GCHILDREN[g]=
    for ((i=n; i<n+2; i++)); do PICK_IGROUP[i]=$g; done
    pick_left_root || PICK_TAB_GROUPS[${#PICK_TAB_GROUPS[@]}]=$g
}

pick_on_submit_page() {
    ((PICK_ROOT == PICK_SUBMIT_GROUP))
}

pick_page_of() {
    # $1 = item index; sets PICK_PAGE_OF to the page that shows it.
    local p
    PICK_PAGE_OF=$PICK_PAGE_AT
    for ((p=0; p<${#PICK_PAGES[@]}; p++)); do
        pick_ref_group "$1" "${PICK_GDEPTH[${PICK_PAGES[p]}]}"
        ((PICK_REFGROUP != PICK_PAGES[p])) || { PICK_PAGE_OF=$p; return 0; }
    done
}

pick_show_page() {
    # $1 = page; each keeps its focus. The sub-tabs lose the focus to the
    # tabs on a page without them, and so does a column of left tabs.
    PICK_PAGE_CURSOR[PICK_PAGE_AT]=$PICK_CURSOR
    PICK_PAGE_OFFSET[PICK_PAGE_AT]=$PICK_OFFSET
    PICK_PAGE_AT=$1
    PICK_TAB_AT=${PICK_PAGE_TAB[$1]}
    PICK_TAB_PAGE[PICK_TAB_AT]=$1
    PICK_ROOT=${PICK_PAGES[$1]}
    PICK_TAB=${PICK_GID[PICK_ROOT]}
    PICK_SIDE_SUBMIT=0
    pick_side_page
    pick_build_rows
    PICK_CURSOR=${PICK_PAGE_CURSOR[$1]:-0}
    PICK_OFFSET=${PICK_PAGE_OFFSET[$1]:-0}
    ((PICK_ON_TABS != 3 || PICK_SIDE_LEVEL == 3)) || PICK_ON_TABS=2
    ((PICK_ON_TABS != 2 || PICK_TAB_SUBS[PICK_TAB_AT])) || PICK_ON_TABS=1
}

pick_units() {
    # $1 = tab, or -1 for every tab. Fills PICK_UNIT_GROUPS with the groups
    # that the bars show for its pages, and PICK_UNIT_PAGES with the page
    # each one opens at, and sets PICK_UNIT_AT to the active one. A page
    # stands for itself, and the tabs of a column for the group that holds
    # them, which opens at the one it showed last.
    local p g last=-1
    PICK_UNIT_GROUPS=(); PICK_UNIT_PAGES=(); PICK_UNIT_AT=0
    for ((p=0; p<${#PICK_PAGES[@]}; p++)); do
        (($1 < 0 || PICK_PAGE_TAB[p] == $1)) || continue
        g=${PICK_PAGE_SIDE[p]}
        if ((!g)); then
            g=${PICK_PAGES[p]}
            PICK_UNIT_PAGES[${#PICK_UNIT_GROUPS[@]}]=$p
            PICK_UNIT_GROUPS[${#PICK_UNIT_GROUPS[@]}]=$g
        elif ((g != last)); then
            PICK_UNIT_PAGES[${#PICK_UNIT_GROUPS[@]}]=${PICK_SIDE_PAGE[g]}
            PICK_UNIT_GROUPS[${#PICK_UNIT_GROUPS[@]}]=$g
        fi
        last=$g
        ((p != PICK_PAGE_AT)) || PICK_UNIT_AT=$((${#PICK_UNIT_GROUPS[@]} - 1))
    done
}

pick_switch_unit() {
    # $1 = units of pick_units to move by, $2 = its tab argument.
    local n
    pick_units "$2"
    n=${#PICK_UNIT_PAGES[@]}
    pick_show_page "${PICK_UNIT_PAGES[(PICK_UNIT_AT + $1 + n) % n]}"
}

pick_switch_page() {
    # $1 = pages to move by, -1 for the previous one; a column of left tabs
    # inside a tab or sub-tab moves as one.
    pick_switch_unit "$1" -1
}

pick_side_move() {
    # $1 = -1 to move up the column of left tabs, 1 down. Its submit item
    # comes after the last tab; leaving it shows the tab it is left for. A
    # column inside a tab or sub-tab leaves its first tab up for the bars
    # above, as the first row does, and its last down for the tabs.
    local first=$PICK_SIDE_FIRST last=$PICK_SIDE_LAST
    if ((PICK_SIDE_SUBMIT)); then
        if (($1 > 0)); then pick_show_page "$first"; else pick_show_page "$last"; fi
    elif ((PICK_PAGE_AT != ($1 > 0 ? last : first))); then pick_show_page "$((PICK_PAGE_AT + $1))"
    elif ((PICK_SIDE_LEVEL == 1 && PICK_SUBMIT_GROUP >= 0)); then PICK_SIDE_SUBMIT=1
    elif ((PICK_SIDE_LEVEL == 1)); then pick_show_page "$(($1 > 0 ? first : last))"
    elif (($1 < 0)); then PICK_ON_TABS=$((1 + (PICK_TAB_SUBS[PICK_TAB_AT] > 0)))
    elif [[ ${PICK_WRAP_NAVIGATION:-1} != 0 ]]; then pick_show_page "$first"; PICK_ON_TABS=1; fi
}

pick_switch_tab() {
    # $1 = tabs to move by; a tab shows the sub-tab it showed last.
    local n=${#PICK_TAB_GROUPS[@]}
    pick_show_page "${PICK_TAB_PAGE[(PICK_TAB_AT + $1 + n) % n]}"
}

pick_switch_subtab() {
    # $1 = sub-tabs of the active tab to move by.
    pick_switch_unit "$1" "$PICK_TAB_AT"
}

pick_focus_row() {
    # $1 = item index; focuses it, on its page.
    local idx=$1 k
    PICK_ON_TABS=0
    if ((${#PICK_PAGES[@]})); then
        pick_page_of "$idx"
        ((PICK_PAGE_OF == PICK_PAGE_AT)) || pick_show_page "$PICK_PAGE_OF"
    fi
    for ((k=0; k<${#PICK_FOCUS[@]}; k++)); do
        [[ ${PICK_FOCUS[k]} != "$idx" ]] || PICK_CURSOR=$k
    done
}

pick_apart_level() {
    # $1 = root group; sets PICK_APART_LEVEL to how far below it the groups
    # lie that blank rows set apart. The only group of a tab is already
    # apart, so its children are set apart instead.
    PICK_APART_LEVEL=0
    (($1)) || return 0
    case ${PICK_GCHILDREN[$1]} in ' g'*' '*) ;; ' g'*) PICK_APART_LEVEL=1 ;; esac
}

pick_apart_key() {
    # $1 = group of a line, $2 = root group; sets PICK_APART_KEY to its
    # ancestor, or itself, PICK_APART_LEVEL below the root's children, or to
    # 0 when it lies above. A blank row goes between neighbors whose keys
    # differ.
    local g=$1 n=0
    local -a up=()
    while ((g > 0 && g != $2)); do up[n]=$g; n=$((n + 1)); g=${PICK_GPARENT[g]}; done
    PICK_APART_KEY=0
    ((n <= PICK_APART_LEVEL)) || PICK_APART_KEY=${up[n - 1 - PICK_APART_LEVEL]}
}

pick_build_rows() {
    local i j g k s common context level count apart=0
    local -a path=() previous=() reverse=()
    PICK_FOCUS=(); PICK_FOCUS_ROW=(); PICK_DKIND=(); PICK_DREF=(); PICK_DGROUP=()
    if pick_on_submit_page; then PICK_FOCUS=("${#PICK_LABEL[@]}" "$((${#PICK_LABEL[@]} + 1))")
    else pick_walk_group "$PICK_ROOT"; fi
    [[ $PICK_MODE != choices ]] || pick_measure_values
    pick_apart_level "$PICK_ROOT"

    # A separator precedes its item and any newly entered headers. Its
    # context is the common ancestor, so it creates no group or indentation.
    for ((k=0; k<${#PICK_FOCUS[@]}; k++)); do
        i=${PICK_FOCUS[k]}
        g=${PICK_IGROUP[i]}
        reverse=(); path=()
        while ((g > 0 && g != PICK_ROOT)); do
            reverse[${#reverse[@]}]=$g
            g=${PICK_GPARENT[g]}
        done
        for ((j=${#reverse[@]}-1; j>=0; j--)); do path[${#path[@]}]=${reverse[j]}; done
        common=0
        while ((common < ${#path[@]} && common < ${#previous[@]})) &&
              [[ ${path[common]} == "${previous[common]}" ]]; do
            common=$((common + 1))
        done
        context=$PICK_ROOT
        ((common == 0)) || context=${path[common - 1]}
        count=${#PICK_DKIND[@]}
        for ((s=0; s<${#PICK_SEP_ANCHOR[@]}; s++)); do
            [[ ${PICK_SEP_ANCHOR[s]} != "$i" ]] || pick_display_row separator "$s" "$context"
        done
        pick_apart_key "${PICK_IGROUP[i]}" "$PICK_ROOT"
        if ((k > 0 && count == ${#PICK_DKIND[@]} && PICK_APART_KEY != apart)); then
            pick_display_row blank '' "$context"
        fi
        apart=$PICK_APART_KEY
        for ((level=common; level<${#path[@]}; level++)); do
            g=${path[level]}
            [[ -n ${PICK_GLABEL[g]} ]] || continue
            PICK_GROW[g]=${#PICK_DKIND[@]}
            pick_display_row header "$g" "$g"
        done
        PICK_FOCUS_ROW[k]=${#PICK_DKIND[@]}
        pick_display_row item "$k" "${PICK_IGROUP[i]}"
        previous=("${path[@]}")
    done
    ! pick_on_submit_page || return 0
    for ((s=0; s<${#PICK_SEP_ANCHOR[@]}; s++)); do
        [[ ${PICK_SEP_ANCHOR[s]} != -1 ]] || pick_display_row separator "$s" "$PICK_ROOT"
    done
    return 0
}

pick_count_groups() {
    # Fills PICK_GTOTS with the number of rows under each group and the root,
    # and PICK_GSELS with those that change or are checked: each group's own
    # rows, then added to every group above it.
    local i g up
    local -a tot=() sel=()
    for i in "${!PICK_IGROUP[@]}"; do
        g=${PICK_IGROUP[i]}
        tot[g]=$((${tot[g]:-0} + 1))
        if [[ $PICK_MODE == choices ]]; then
            [[ ${PICK_RESULT[i]} == "${PICK_CURRENT[i]}" ]] || sel[g]=$((${sel[g]:-0} + 1))
        elif [[ ${PICK_STATE[i]:-0} == 1 ]]; then sel[g]=$((${sel[g]:-0} + 1)); fi
    done
    PICK_GTOTS=()
    PICK_GSELS=()
    for g in "${!tot[@]}"; do
        up=$g
        while :; do
            PICK_GTOTS[up]=$((${PICK_GTOTS[up]:-0} + tot[g]))
            PICK_GSELS[up]=$((${PICK_GSELS[up]:-0} + ${sel[g]:-0}))
            ((up > 0)) || break
            up=${PICK_GPARENT[up]}
        done
    done
}

pick_ref_group() {
    # $1 = item index, $2 = structural depth; sets PICK_REFGROUP to the
    # ancestor at that depth, or -1 when the item sits above it.
    local g=${PICK_IGROUP[$1]} depth=$2
    while ((g > 0 && PICK_GDEPTH[g] > depth)); do g=${PICK_GPARENT[g]}; done
    if ((g > 0 && PICK_GDEPTH[g] == depth)); then PICK_REFGROUP=$g
    else PICK_REFGROUP=-1; fi
}

pick_jump_group() {
    # $1 = -1 for the previous group, 1 for the next. Focuses the first
    # included item of the adjacent group at PICK_JUMP_DEPTH. Items above
    # that depth use their display position to pick the nearest group in
    # the requested direction. No destination leaves the focus in place.
    local dir=$1 i ref cur=-1 last=-2
    local -a refs=() starts=()
    for ((i=0; i<${#PICK_FOCUS[@]}; i++)); do
        pick_ref_group "${PICK_FOCUS[i]}" "$PICK_JUMP_DEPTH"
        ref=$PICK_REFGROUP
        if ((i == 0 || ref != last)); then
            refs[${#refs[@]}]=$ref
            starts[${#starts[@]}]=$i
            last=$ref
        fi
        if ((i == PICK_CURSOR)); then cur=$((${#refs[@]} - 1)); fi
    done
    ((cur >= 0)) || return 0
    if ((dir > 0)); then
        for ((i=cur + 1; i<${#refs[@]}; i++)); do
            ((refs[i] >= 0)) || continue
            PICK_CURSOR=${starts[i]}
            return 0
        done
    else
        for ((i=cur - 1; i>=0; i--)); do
            ((refs[i] >= 0)) || continue
            PICK_CURSOR=${starts[i]}
            return 0
        done
    fi
    return 0
}
