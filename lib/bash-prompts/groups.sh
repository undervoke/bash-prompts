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

pick_build_tabs() {
    # With PICK_TABS, the root groups become tabs in their display order and
    # the rows of one of them are shown at a time.
    local node g i IFS=' '
    local -a tail=()
    PICK_TAB_GROUPS=(); PICK_TAB_CURSOR=(); PICK_TAB_OFFSET=()
    PICK_TAB_AT=0
    PICK_ROOT=0
    [[ ${PICK_TABS:-0} == 1 ]] || return 0
    for node in ${PICK_GCHILDREN[0]}; do
        case $node in
            g*)
                g=${node#g}
                if pick_group_is_tail "${PICK_GID[g]}"; then tail[${#tail[@]}]=$g
                else PICK_TAB_GROUPS[${#PICK_TAB_GROUPS[@]}]=$g; fi
                ;;
            i*)
                i=${node#i}
                pick_err "item '${PICK_ID[i]-${PICK_LABEL[i]}}' needs a group to appear in a tab"
                return 1
                ;;
        esac
    done
    for g in "${tail[@]}"; do PICK_TAB_GROUPS[${#PICK_TAB_GROUPS[@]}]=$g; done
    ((${#PICK_TAB_GROUPS[@]})) || return 0
    for ((i=0; i<${#PICK_TAB_GROUPS[@]}; i++)); do
        [[ ${PICK_GID[${PICK_TAB_GROUPS[i]}]} != "${PICK_TAB-}" ]] || PICK_TAB_AT=$i
    done
    if [[ $PICK_MODE == single ]] && ((PICK_INITIAL_INDEX >= 0)); then
        pick_ref_group "$PICK_INITIAL_INDEX" 1
        for ((i=0; i<${#PICK_TAB_GROUPS[@]}; i++)); do
            [[ ${PICK_TAB_GROUPS[i]} != "$PICK_REFGROUP" ]] || PICK_TAB_AT=$i
        done
    fi
    PICK_ROOT=${PICK_TAB_GROUPS[PICK_TAB_AT]}
    PICK_TAB=${PICK_GID[PICK_ROOT]}
    return 0
}

pick_switch_tab() {
    # $1 = -1 for the previous tab, 1 for the next; each tab keeps its focus.
    local n=${#PICK_TAB_GROUPS[@]}
    PICK_TAB_CURSOR[PICK_TAB_AT]=$PICK_CURSOR
    PICK_TAB_OFFSET[PICK_TAB_AT]=$PICK_OFFSET
    PICK_TAB_AT=$(((PICK_TAB_AT + $1 + n) % n))
    PICK_ROOT=${PICK_TAB_GROUPS[PICK_TAB_AT]}
    PICK_TAB=${PICK_GID[PICK_ROOT]}
    pick_build_rows
    PICK_CURSOR=${PICK_TAB_CURSOR[PICK_TAB_AT]:-0}
    PICK_OFFSET=${PICK_TAB_OFFSET[PICK_TAB_AT]:-0}
}

pick_build_rows() {
    local i j g k s common context level count spaced=0
    local -a path=() previous=() reverse=()
    PICK_FOCUS=(); PICK_FOCUS_ROW=(); PICK_DKIND=(); PICK_DREF=(); PICK_DGROUP=()
    pick_walk_group "$PICK_ROOT"
    # Blank rows set groups apart; the only group of a tab is already apart.
    if ((PICK_ROOT)); then
        case ${PICK_GCHILDREN[PICK_ROOT]} in ' g'*' '*) ;; ' g'*) spaced=1 ;; esac
    fi

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
        if ((k > 0 && count == ${#PICK_DKIND[@]})) &&
           [[ ${previous[spaced]:-0} != "${path[spaced]:-0}" ]]; then
            pick_display_row blank '' "$context"
        fi
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
    for ((s=0; s<${#PICK_SEP_ANCHOR[@]}; s++)); do
        [[ ${PICK_SEP_ANCHOR[s]} != -1 ]] || pick_display_row separator "$s" "$PICK_ROOT"
    done
    return 0
}

pick_group_counts() {
    local want=$1 i g
    PICK_GTOT=0
    PICK_GSEL=0
    for i in "${!PICK_IGROUP[@]}"; do
        g=${PICK_IGROUP[i]}
        while ((g > 0 && g != want)); do g=${PICK_GPARENT[g]}; done
        ((g == want)) || continue
        PICK_GTOT=$((PICK_GTOT + 1))
        [[ ${PICK_STATE[i]:-0} != 1 ]] || PICK_GSEL=$((PICK_GSEL + 1))
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
