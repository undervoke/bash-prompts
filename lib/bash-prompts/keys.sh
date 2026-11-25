# bash-prompts: key bindings, escape sequences, and the key hint.
# Function definitions only; sourced in the caller shell by lib/bash-prompts.sh.

pick_hint() {
    # $1 = width; fills PICK_HINT with the active bindings, wrapped to width.
    # Verbs follow the PICK_KEY_HELP order set by pick_prepare_keys.
    local cols=$1 i seg line= verbs help
    if [[ $PICK_MODE == single ]]; then verbs=(up down prev next - - - select back cancel)
    elif [[ $PICK_MODE == dependencies ]]; then verbs=(up down prev next toggle all clear submit back cancel)
    else verbs=(up down prev next toggle all none submit back cancel); fi
    help=("${PICK_KEY_HELP[@]}")
    # Up/Down and Prev/Next group each share one segment when both are bound.
    if [[ ${help[0]} != off && ${help[1]} != off ]]; then
        verbs[0]=-
        verbs[1]=move
        help[1]="${help[0]} ${help[1]}"
    fi
    if [[ ${help[2]} != off && ${help[3]} != off ]]; then
        verbs[2]=-
        verbs[3]=prev/next
        help[3]="${help[2]} ${help[3]}"
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
    pick_bind_keys prev_group "${PICK_KEYS_PREV_GROUP[@]}" || return 1
    pick_bind_keys next_group "${PICK_KEYS_NEXT_GROUP[@]}" || return 1
    if [[ $PICK_MODE == single ]]; then
        pick_bind_keys toggle
        pick_bind_keys all
        pick_bind_keys clear
    else
        pick_bind_keys toggle "${PICK_KEYS_TOGGLE[@]}" || return 1
        pick_bind_keys all "${PICK_KEYS_ALL[@]}" || return 1
        pick_bind_keys clear "${PICK_KEYS_CLEAR[@]}" || return 1
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
