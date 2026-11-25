# bash-prompts: key bindings, escape sequences, and the key hint.
# Function definitions only; sourced in the caller shell by lib/bash-prompts.sh.

pick_hint() {
    # $1 = width; fills PICK_HINT with the active bindings, wrapped to width.
    # Verbs follow the PICK_KEY_HELP order set by pick_prepare_keys.
    local cols=$1 i seg line= verbs help
    if [[ -n $PICK_FIELD ]]; then PICK_HINT=('Enter save  Esc cancel'); return 0; fi
    if [[ $PICK_MODE == single ]]; then verbs=(up down prev next prev next - - - - select back cancel)
    elif [[ $PICK_MODE == dependencies ]]; then verbs=(up down prev next prev next toggle - all clear submit back cancel)
    elif [[ $PICK_MODE == choices ]]; then
        verbs=(up down prev next prev next change - - - submit back cancel)
        i=${PICK_FOCUS[PICK_CURSOR]}
        if pick_on_submit_page; then
            verbs[6]=choose
            ((PICK_CURSOR < 2)) || verbs[6]=-
        elif [[ -n ${PICK_EDIT[i]-} ]]; then
            verbs[6]=edit
            if pick_next_allowed "$i"; then pick_format_value "$i" "$PICK_NEXT"; verbs[7]=$PICK_TEXT; fi
        fi
    else verbs=(up down prev next prev next toggle - all none submit back cancel); fi
    help=("${PICK_KEY_HELP[@]}")
    # Each pair shares one segment when both its keys are bound.
    if [[ ${help[0]} != off && ${help[1]} != off ]]; then
        verbs[0]=-
        verbs[1]=move
        help[1]="${help[0]} ${help[1]}"
    fi
    if [[ ${help[2]} != off && ${help[3]} != off ]]; then
        verbs[2]=-
        verbs[3]=tab
        help[3]="${help[2]} ${help[3]}"
    fi
    if [[ ${help[4]} != off && ${help[5]} != off ]]; then
        verbs[4]=-
        verbs[5]=prev/next
        help[5]="${help[4]} ${help[5]}"
    fi
    PICK_HINT=()
    for ((i=0; i<${#verbs[@]}; i++)); do
        [[ ${verbs[i]} != - && ${help[i]} != off ]] || continue
        seg="${help[i]} ${verbs[i]}"
        if [[ -z $line ]]; then line=$seg
        elif ((${#line} + 2 + ${#seg} <= cols)); then line="$line  $seg"
        else PICK_HINT[${#PICK_HINT[@]}]=$line; line=$seg; fi
    done
    [[ -z $line ]] || PICK_HINT[${#PICK_HINT[@]}]=$line
}

pick_read_escape() {
    # Sets seq to the byte after Esc, or empty for a lone Esc. dd honors the
    # 0.1-second terminal timeout set up in pick_setup_term.
    # Preserve a newline follower: command substitution alone would strip
    # it and incorrectly treat Esc followed by Enter as a lone Esc.
    seq=$(dd bs=1 count=1 2>/dev/null; printf '.')
    seq=${seq%.}
}

pick_read_key() {
    # Sets PICK_PRESSED to the next key, or to nothing for an unknown one.
    # Returns 1 when a signal or a lost terminal ends the prompt, and 2 when
    # the terminal was resized.
    local start seq part
    # The read carries a one-second timeout as an interrupt backstop:
    # a returning caller trap resumes inside read, so without it the
    # cancel would wait for the next keypress. A failure ends the
    # session unless it is a proven timeout with no pending interrupt;
    # only elapsed time distinguishes the two on Bash 3.2, where both
    # report the same status.
    PICK_PRESSED=
    while true; do
        start=$SECONDS
        if IFS= read -rsn1 -t 1 PICK_PRESSED; then break; fi
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
        ((SECONDS - start >= 1)) || return 1
        # The timeout tick also picks up a resized terminal.
        pick_term_size
        [[ $PICK_TROWS == "$PICK_PREV_ROWS" && $PICK_TCOLS == "$PICK_PREV_COLS" ]] || return 2
    done
    # A key that arrived after a returning handler fired must not be
    # dispatched: the terminal is already restored, so cancel instead
    # of acting on stale input.
    [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
    if [[ $PICK_PRESSED == $'\e' ]]; then
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
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
        case $seq in
            '') PICK_PRESSED=Esc ;;
            '[A'|'OA') PICK_PRESSED=Up ;;
            '[B'|'OB') PICK_PRESSED=Down ;;
            '[C'|'OC') PICK_PRESSED=Right ;;
            '[D'|'OD') PICK_PRESSED=Left ;;
            '[Z') PICK_PRESSED=Shift+Tab ;;
            *) PICK_PRESSED= ;;
        esac
    else
        case $PICK_PRESSED in
            ' ') PICK_PRESSED=Space ;;
            ''|$'\n'|$'\r') PICK_PRESSED=Enter ;;
            $'\t') PICK_PRESSED=Tab ;;
            $'\177'|$'\b') PICK_PRESSED=Backspace ;;
        esac
    fi
}

pick_bind_keys() {
    local action=$1 key i found help=
    local LC_ALL=C
    shift
    for key in "$@"; do
        [[ $key != ' ' ]] || key=Space
        case $key in
            Up|Down|Left|Right|Space|Enter|Esc|Tab|Shift+Tab|Backspace|[[:graph:]]) ;;
            *) pick_err "invalid key token '$key' for $action"; return 1 ;;
        esac
        found=0
        for ((i=0; i<${#PICK_BOUND_KEYS[@]}; i++)); do
            [[ ${PICK_BOUND_KEYS[i]} == "$key" ]] || continue
            if [[ ${PICK_BOUND_ACTIONS[i]} != "$action" ]]; then
                pick_err "key '$key' is assigned to both ${PICK_BOUND_ACTIONS[i]} and $action"
                return 1
            fi
            found=1
            break
        done
        ((found)) && continue
        PICK_BOUND_ACTIONS[${#PICK_BOUND_KEYS[@]}]=$action
        PICK_BOUND_KEYS[${#PICK_BOUND_KEYS[@]}]=$key
        [[ -z $help ]] || help="$help/"
        help="$help$key"
    done
    PICK_KEY_HELP[${#PICK_KEY_HELP[@]}]=${help:-off}
}

pick_prepare_keys() {
    PICK_BOUND_KEYS=()
    PICK_BOUND_ACTIONS=()
    PICK_KEY_HELP=()
    pick_bind_keys up "${PICK_KEYS_UP[@]}" || return 1
    pick_bind_keys down "${PICK_KEYS_DOWN[@]}" || return 1
    if [[ ${PICK_TABS:-0} == 1 ]]; then
        pick_bind_keys prev_tab "${PICK_KEYS_PREV_TAB[@]}" || return 1
        pick_bind_keys next_tab "${PICK_KEYS_NEXT_TAB[@]}" || return 1
    else
        pick_bind_keys prev_tab
        pick_bind_keys next_tab
    fi
    pick_bind_keys prev_group "${PICK_KEYS_PREV_GROUP[@]}" || return 1
    pick_bind_keys next_group "${PICK_KEYS_NEXT_GROUP[@]}" || return 1
    if [[ $PICK_MODE == single ]]; then
        pick_bind_keys toggle
        pick_bind_keys next_value
        pick_bind_keys all
        pick_bind_keys clear
    else
        pick_bind_keys toggle "${PICK_KEYS_TOGGLE[@]}" || return 1
        if [[ $PICK_MODE == choices ]] && ((PICK_EDITS)); then
            pick_bind_keys next_value "${PICK_KEYS_NEXT_VALUE[@]}" || return 1
        else pick_bind_keys next_value; fi
        if [[ $PICK_MODE == choices ]]; then
            pick_bind_keys all
            pick_bind_keys clear
        else
            pick_bind_keys all "${PICK_KEYS_ALL[@]}" || return 1
            pick_bind_keys clear "${PICK_KEYS_CLEAR[@]}" || return 1
        fi
    fi
    pick_bind_keys submit "${PICK_KEYS_SUBMIT[@]}" || return 1
    if [[ $PICK_MODE == dependencies && ${PICK_ALLOW_BACK:-0} == 0 ]]; then pick_bind_keys back
    else pick_bind_keys back "${PICK_KEYS_BACK[@]}" || return 1; fi
    pick_bind_keys cancel "${PICK_KEYS_CANCEL[@]}" || return 1
}

pick_key_action() {
    local key=$1 i
    PICK_KEY_ACTION=
    for ((i=0; i<${#PICK_BOUND_KEYS[@]}; i++)); do
        if [[ ${PICK_BOUND_KEYS[i]} == "$key" ]]; then
            PICK_KEY_ACTION=${PICK_BOUND_ACTIONS[i]}
            return 0
        fi
    done
}
