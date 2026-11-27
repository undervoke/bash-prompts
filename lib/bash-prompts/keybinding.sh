# bash-prompts: key values and their symbols, key entry, and rows that share a key.
# Function definitions only; sourced in the caller shell by lib/bash-prompts.sh.

pick_key_lookup() {
    # $1 = key name, or @ and a virtual key code. Sets PICK_KEY to the name,
    # the code, and the glyph. The names are positions on an ANSI keyboard,
    # so they do not depend on the input source.
    case $1 in
        a|@0) set -- a 0 A ;; s|@1) set -- s 1 S ;; d|@2) set -- d 2 D ;;
        f|@3) set -- f 3 F ;; h|@4) set -- h 4 H ;; g|@5) set -- g 5 G ;;
        z|@6) set -- z 6 Z ;; x|@7) set -- x 7 X ;; c|@8) set -- c 8 C ;;
        v|@9) set -- v 9 V ;; section|@10) set -- section 10 § ;; b|@11) set -- b 11 B ;;
        q|@12) set -- q 12 Q ;; w|@13) set -- w 13 W ;; e|@14) set -- e 14 E ;;
        r|@15) set -- r 15 R ;; y|@16) set -- y 16 Y ;; t|@17) set -- t 17 T ;;
        1|@18) set -- 1 18 1 ;; 2|@19) set -- 2 19 2 ;; 3|@20) set -- 3 20 3 ;;
        4|@21) set -- 4 21 4 ;; 6|@22) set -- 6 22 6 ;; 5|@23) set -- 5 23 5 ;;
        equal|@24) set -- equal 24 = ;; 9|@25) set -- 9 25 9 ;; 7|@26) set -- 7 26 7 ;;
        minus|@27) set -- minus 27 - ;; 8|@28) set -- 8 28 8 ;; 0|@29) set -- 0 29 0 ;;
        rightbracket|@30) set -- rightbracket 30 ']' ;; o|@31) set -- o 31 O ;;
        u|@32) set -- u 32 U ;; leftbracket|@33) set -- leftbracket 33 '[' ;;
        i|@34) set -- i 34 I ;; p|@35) set -- p 35 P ;; return|@36) set -- return 36 ↩ ;;
        l|@37) set -- l 37 L ;; j|@38) set -- j 38 J ;; quote|@39) set -- quote 39 "'" ;;
        k|@40) set -- k 40 K ;; semicolon|@41) set -- semicolon 41 ';' ;;
        backslash|@42) set -- backslash 42 '\' ;; comma|@43) set -- comma 43 , ;;
        slash|@44) set -- slash 44 / ;; n|@45) set -- n 45 N ;; m|@46) set -- m 46 M ;;
        period|@47) set -- period 47 . ;; tab|@48) set -- tab 48 ⇥ ;;
        space|@49) set -- space 49 Space ;; grave|@50) set -- grave 50 '`' ;;
        delete|@51) set -- delete 51 ⌫ ;; esc|@53) set -- esc 53 ⎋ ;;
        f17|@64) set -- f17 64 F17 ;; keypaddecimal|@65) set -- keypaddecimal 65 Num. ;;
        keypadmultiply|@67) set -- keypadmultiply 67 Num\* ;;
        keypadplus|@69) set -- keypadplus 69 Num+ ;; keypadclear|@71) set -- keypadclear 71 ⌧ ;;
        keypaddivide|@75) set -- keypaddivide 75 Num/ ;; keypadenter|@76) set -- keypadenter 76 ⌤ ;;
        keypadminus|@78) set -- keypadminus 78 Num- ;; f18|@79) set -- f18 79 F18 ;;
        f19|@80) set -- f19 80 F19 ;; keypadequal|@81) set -- keypadequal 81 Num= ;;
        keypad0|@82) set -- keypad0 82 Num0 ;; keypad1|@83) set -- keypad1 83 Num1 ;;
        keypad2|@84) set -- keypad2 84 Num2 ;; keypad3|@85) set -- keypad3 85 Num3 ;;
        keypad4|@86) set -- keypad4 86 Num4 ;; keypad5|@87) set -- keypad5 87 Num5 ;;
        keypad6|@88) set -- keypad6 88 Num6 ;; keypad7|@89) set -- keypad7 89 Num7 ;;
        f20|@90) set -- f20 90 F20 ;; keypad8|@91) set -- keypad8 91 Num8 ;;
        keypad9|@92) set -- keypad9 92 Num9 ;; yen|@93) set -- yen 93 ¥ ;;
        underscore|@94) set -- underscore 94 _ ;; keypadcomma|@95) set -- keypadcomma 95 Num, ;;
        f5|@96) set -- f5 96 F5 ;; f6|@97) set -- f6 97 F6 ;; f7|@98) set -- f7 98 F7 ;;
        f3|@99) set -- f3 99 F3 ;; f8|@100) set -- f8 100 F8 ;; f9|@101) set -- f9 101 F9 ;;
        eisu|@102) set -- eisu 102 英数 ;; f11|@103) set -- f11 103 F11 ;;
        kana|@104) set -- kana 104 かな ;; f13|@105) set -- f13 105 F13 ;;
        f16|@106) set -- f16 106 F16 ;; f14|@107) set -- f14 107 F14 ;;
        f10|@109) set -- f10 109 F10 ;; f12|@111) set -- f12 111 F12 ;;
        f15|@113) set -- f15 113 F15 ;; help|@114) set -- help 114 Help ;;
        home|@115) set -- home 115 ↖ ;; pageup|@116) set -- pageup 116 ⇞ ;;
        forwarddelete|@117) set -- forwarddelete 117 ⌦ ;; f4|@118) set -- f4 118 F4 ;;
        end|@119) set -- end 119 ↘ ;; f2|@120) set -- f2 120 F2 ;;
        pagedown|@121) set -- pagedown 121 ⇟ ;; f1|@122) set -- f1 122 F1 ;;
        left|@123) set -- left 123 ← ;; right|@124) set -- right 124 → ;;
        down|@125) set -- down 125 ↓ ;; up|@126) set -- up 126 ↑ ;;
        *) return 1 ;;
    esac
    PICK_KEY=("$@")
}

pick_key_has_globe() {
    # Whether macOS marks the key with the Globe flag, held or not.
    case $1 in
        f[1-9]|f1[0-9]|f20|help|home|end|pageup|pagedown|forwarddelete|left|right|down|up) return 0 ;;
    esac
    return 1
}

pick_key_set() {
    # $1 = modifier flags; sets the parts of the key in PICK_KEY.
    local flags=$1 char LC_ALL=C
    PICK_KEYBINDING_KEY=${PICK_KEY[0]}
    PICK_KEYBINDING_CODE=${PICK_KEY[1]}
    PICK_KEYBINDING_VALUE=
    ((!(flags & 0x800000))) || PICK_KEYBINDING_VALUE=fn+
    ((!(flags & 0x40000))) || PICK_KEYBINDING_VALUE+=ctrl+
    ((!(flags & 0x80000))) || PICK_KEYBINDING_VALUE+=option+
    ((!(flags & 0x20000))) || PICK_KEYBINDING_VALUE+=shift+
    ((!(flags & 0x100000))) || PICK_KEYBINDING_VALUE+=cmd+
    PICK_KEYBINDING_VALUE+=$PICK_KEYBINDING_KEY
    ! pick_key_has_globe "$PICK_KEYBINDING_KEY" || flags=$((flags | 0x800000))
    PICK_KEYBINDING_FLAGS=$flags
    PICK_KEYBINDING_CHAR=65535
    char=
    case $PICK_KEYBINDING_KEY in
        ?) char=$PICK_KEYBINDING_KEY ;;
        space) char=' ' ;;
        *) case ${PICK_KEY[2]} in ?) char=${PICK_KEY[2]} ;; Num?) char=${PICK_KEY[2]#Num} ;; esac ;;
    esac
    [[ -z $char ]] || printf -v PICK_KEYBINDING_CHAR %d "'$char"
}

pick_key_clear() {
    PICK_KEYBINDING_VALUE=; PICK_KEYBINDING_KEY=; PICK_KEYBINDING_CODE=
    PICK_KEYBINDING_FLAGS=; PICK_KEYBINDING_CHAR=; PICK_KEYBINDING_ERROR=
}

pick_keybinding_parse() {
    local text=${1//[ $'\t']/} rest part flags=0 c lower= i
    local LC_ALL=C
    pick_key_clear
    if [[ $text == *[A-Z]* ]]; then
        for ((i=0; i<${#text}; i++)); do
            c=${text:i:1}
            if [[ $c == [A-Z] ]]; then
                part=ABCDEFGHIJKLMNOPQRSTUVWXYZ
                part=${part%%"$c"*}
                c=abcdefghijklmnopqrstuvwxyz
                c=${c:${#part}:1}
            fi
            lower+=$c
        done
        text=$lower
    fi
    rest=$text
    while [[ $rest == *+* ]]; do
        part=${rest%%+*}
        case $part in
            fn|globe) flags=$((flags | 0x800000)) ;;
            ctrl|control) flags=$((flags | 0x40000)) ;;
            option|opt|alt) flags=$((flags | 0x80000)) ;;
            shift) flags=$((flags | 0x20000)) ;;
            cmd|command) flags=$((flags | 0x100000)) ;;
            '') rest=; break ;;
            *) PICK_KEYBINDING_ERROR="No modifier is called '$part'."; return 1 ;;
        esac
        rest=${rest#*+}
    done
    case $rest in
        '') PICK_KEYBINDING_ERROR='Type a key, such as ctrl+option+f5.'; return 1 ;;
        fn|globe|ctrl|control|option|opt|alt|shift|cmd|command)
            PICK_KEYBINDING_ERROR='A modifier needs a key to go with it.'; return 1 ;;
        enter) rest=return ;; escape) rest=esc ;; backspace) rest=delete ;;
        pgup) rest=pageup ;; pgdn) rest=pagedown ;; backtick) rest=grave ;;
        -) rest=minus ;; =) rest=equal ;; '[') rest=leftbracket ;; ']') rest=rightbracket ;;
        '\') rest=backslash ;; ';') rest=semicolon ;; "'") rest=quote ;; '`') rest=grave ;;
        ,) rest=comma ;; .) rest=period ;; /) rest=slash ;;
    esac
    if [[ $rest == @* ]] || ! pick_key_lookup "$rest"; then
        PICK_KEYBINDING_ERROR="No key is called '$rest'."
        return 1
    fi
    pick_key_set "$flags"
}

pick_keybinding_decode() {
    local flags
    pick_key_clear
    if ! pick_key_lookup "@$1"; then
        PICK_KEYBINDING_ERROR='This key cannot be used.'
        return 1
    fi
    flags=$(($2 & 0x9e0000))
    ! pick_key_has_globe "${PICK_KEY[0]}" || flags=$((flags & ~0x800000))
    pick_key_set "$flags"
}

pick_keybinding_format() {
    local rest=$1 part flags=0
    local -a PICK_KEY
    PICK_TEXT=$1
    while [[ -n $rest ]]; do
        part=${rest%%+*}
        case $part in
            fn) flags=$((flags | 0x800000)) ;;
            ctrl) flags=$((flags | 0x40000)) ;;
            option) flags=$((flags | 0x80000)) ;;
            shift) flags=$((flags | 0x20000)) ;;
            cmd) flags=$((flags | 0x100000)) ;;
            *) break ;;
        esac
        if [[ $rest == *+* ]]; then rest=${rest#*+}; else rest=; fi
    done
    if [[ -n $rest ]]; then
        [[ $rest != @* ]] && pick_key_lookup "$rest" || return 0
        rest=${PICK_KEY[2]}
    elif ((flags == 0)); then return 0; fi
    PICK_TEXT=
    ((!(flags & 0x800000))) || PICK_TEXT=🌐
    ((!(flags & 0x40000))) || PICK_TEXT+=⌃
    ((!(flags & 0x80000))) || PICK_TEXT+=⌥
    ((!(flags & 0x20000))) || PICK_TEXT+=⇧
    ((!(flags & 0x100000))) || PICK_TEXT+=⌘
    PICK_TEXT+=$rest
}

pick_keybinding() {
    if (($#)); then pick_keybinding_edit "$1"
    else pick_keybinding_alone; fi
}

pick_keybinding_alone() {
    # One edit row of its own; the caller's rows and groups stay untouched.
    local PICK_MODE=choices PICK_ALONE=1 PICK_EDIT_FIRST=0 PICK_TABS=0 PICK_LEFTTABS=0 PICK_TAB= PICK_CONFIRM_PROMPT= PICK_ON_CHANGE= rc=0
    local PICK_PROMPT=${PICK_PROMPT:-Choose a key}
    local -a PICK_ID=(key) PICK_LABEL=(Key) PICK_EDIT=(pick_keybinding)
    local -a PICK_NOTE=() PICK_GROUP=() PICK_GROUP_ID=() PICK_GROUP_LABEL=() PICK_GROUP_PARENT=() PICK_GROUP_TAIL=()
    local -a PICK_SEPARATOR_BEFORE=() PICK_SEPARATOR_LABEL=() PICK_DEPS=() PICK_VALID=() PICK_DISABLED=()
    local -a PICK_VALUES=() PICK_CURRENT=() PICK_CHOICE=() PICK_OFF=() PICK_WHILE_OFF=() PICK_RESULT=()
    local -a PICK_COLUMNS=() PICK_CELLS=() PICK_FORMAT=() PICK_LABEL_STYLE=() PICK_KEYBINDING_DEFAULT=() PICK_KEYBINDING_SCOPE=() PICK_KEYS_EDIT=()
    if pick_keybinding_parse "${PICK_VALUE-}" && pick_keybinding_usable; then PICK_CURRENT=("$PICK_KEYBINDING_VALUE")
    else PICK_EDIT_FIRST=1; fi
    pick_prepare_choices || return 2
    pick_interact || rc=$?
    if ((rc == 0 || rc == 3)); then PICK_VALUE=${PICK_RESULT[0]}; fi
    return "$rc"
}

pick_keybinding_edit() {
    # $1 = row; sets PICK_VALUE to the key entered for it, or to the off or
    # default value taken instead.
    local row=$1 title=${PICK_LABEL[$1]} k off= default=
    local -a PICK_SPLIT
    ((!PICK_ALONE)) || title=$PICK_PROMPT
    pick_split_csv "${PICK_VALUES[row]-}"
    for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
        if pick_csv_has "${PICK_SPLIT[k]}" "${PICK_OFF[row]-}"; then off=${off:-${PICK_SPLIT[k]}}
        else default=${default:-${PICK_SPLIT[k]}}; fi
    done
    if pick_capture_usable; then
        pick_message '' 'Press the new key in the window.'
        pick_render || return 1
        pick_capture "$title" "$off" "$default" "$row"
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
        PICK_MSG=
        case $PICK_CAPTURE in
            key) pick_keybinding_take; return 0 ;;
            off) PICK_VALUE=$off; return 0 ;;
            default) PICK_VALUE=$default; return 0 ;;
            cancel) return 1 ;;
        esac
    fi
    pick_keybinding_type "$row"
}

pick_keybinding_type() {
    # $1 = row; reads the key as text below the list. Letters are text here,
    # so only Enter, Esc, and Backspace act.
    local row=$1 text= got
    PICK_MSG=
    while true; do
        PICK_FIELD="Key: ${text}_"
        [[ -n $text ]] || PICK_FIELD="$PICK_FIELD  such as ctrl+option+f5"
        pick_render || break
        got=0
        pick_read_key || got=$?
        ((got != 1)) || break
        ((got != 2)) || continue
        case $PICK_PRESSED in
            Enter)
                if [[ -n $text ]] && pick_csv_has "$text" "${PICK_VALUES[row]-}"; then
                    PICK_FIELD=
                    PICK_VALUE=$text
                    return 0
                fi
                if ! pick_keybinding_parse "$text"; then
                    pick_message "$PICK_STYLE_ERROR" "$PICK_KEYBINDING_ERROR"
                elif ! pick_keybinding_admit "$row"; then
                    pick_message "$PICK_STYLE_ERROR" "$PICK_KEYBINDING_MESSAGE"
                else
                    PICK_FIELD=
                    PICK_MSG=
                    pick_keybinding_take
                    return 0
                fi
                ;;
            Esc) break ;;
            Backspace) text=${text%?}; PICK_MSG= ;;
            ?) [[ $PICK_PRESSED != [[:graph:]] ]] || { text+=$PICK_PRESSED; PICK_MSG=; } ;;
        esac
    done
    PICK_FIELD=
    PICK_MSG=
    return 1
}

pick_keybinding_usable() {
    # Whether the key just read can be entered at all: a key that also types a
    # character needs a modifier that keeps it from doing so. Leaves the reason
    # in PICK_KEYBINDING_MESSAGE.
    PICK_KEYBINDING_MESSAGE=
    case $PICK_KEYBINDING_VALUE in
        *ctrl+*|*option+*|*cmd+*|f[1-9]|f1[0-9]|f20|shift+f[1-9]|shift+f1[0-9]|shift+f20) ;;
        *)
            if pick_key_has_globe "$PICK_KEYBINDING_KEY"; then
                PICK_KEYBINDING_MESSAGE='Hold Control, Option, or Command with this key.'
                return 1
            fi
            if [[ $PICK_KEYBINDING_VALUE != fn+* ]]; then
                PICK_KEYBINDING_MESSAGE='Hold Control, Option, Command, or Globe with this key.'
                return 1
            fi
            ;;
    esac
}

pick_keybinding_admit() {
    # $1 = row. Whether the key just read can be entered for it. Leaves the
    # reason or the check's warning in PICK_KEYBINDING_MESSAGE.
    local value=$PICK_KEYBINDING_VALUE rc=0
    pick_keybinding_usable || return 1
    [[ -n ${PICK_KEYBINDING_CHECK-} ]] || return 0
    if ((PICK_ALONE)); then "$PICK_KEYBINDING_CHECK" "$value" || rc=1
    else "$PICK_KEYBINDING_CHECK" "$value" "$1" || rc=1; fi
    # The check may have read other keys.
    PICK_KEYBINDING_VALUE=$value
    if ((rc)) && [[ -z $PICK_KEYBINDING_MESSAGE ]]; then
        pick_keybinding_format "$value"
        PICK_KEYBINDING_MESSAGE="$PICK_TEXT cannot be used."
    fi
    return "$rc"
}

pick_keybinding_take() {
    PICK_VALUE=$PICK_KEYBINDING_VALUE
    [[ -z $PICK_KEYBINDING_MESSAGE ]] || pick_message "$PICK_STYLE_WARNING" "$PICK_KEYBINDING_MESSAGE"
}

pick_row_key() {
    # $1 = row; sets PICK_HELD to the key in effect, and PICK_OWN to whether
    # the row holds it itself rather than through a fixed value.
    local value=${PICK_RESULT[$1]}
    PICK_HELD_AS[$1]=$value
    PICK_HELD[$1]=
    PICK_OWN[$1]=0
    if pick_csv_has "$value" "${PICK_VALUES[$1]-}"; then
        if pick_csv_has "$value" "${PICK_OFF[$1]-}" || ! pick_keybinding_parse "${PICK_KEYBINDING_DEFAULT[$1]-}"; then return 0; fi
        PICK_HELD[$1]=$PICK_KEYBINDING_VALUE
    elif [[ ${PICK_EDIT[$1]-} == pick_keybinding ]] && pick_keybinding_parse "$value"; then
        PICK_HELD[$1]=$PICK_KEYBINDING_VALUE
        PICK_OWN[$1]=1
    fi
}

pick_find_clashes() {
    # Fills PICK_CLASH with the rows that share a row's key. Rows that all
    # hold a fixed value keep what they were given.
    local i j tag seen=$'\n'
    local -a tags=()
    PICK_CLASH=()
    for i in "${PICK_KEY_ROWS[@]}"; do
        [[ ${PICK_HELD_AS[i]-} == "${PICK_RESULT[i]}" && -n ${PICK_HELD_AS[i]+set} ]] || pick_row_key "$i"
        [[ -n ${PICK_HELD[i]} ]] || continue
        tag="${PICK_HELD[i]} ${PICK_KEYBINDING_SCOPE[i]-}"
        # Most keys are new, so the rows before are compared only on a match.
        if [[ $seen == *$'\n'"$tag"$'\n'* ]]; then
            for j in "${!tags[@]}"; do
                [[ ${tags[j]} == "$tag" ]] && ((PICK_OWN[i] || PICK_OWN[j])) || continue
                PICK_CLASH[i]="${PICK_CLASH[i]-} $j"
                PICK_CLASH[j]="${PICK_CLASH[j]-} $i"
            done
        else seen+=$tag$'\n'; fi
        tags[i]=$tag
    done
}

pick_refuse_clash() {
    # Whether two rows share a key; focuses the first one and says so.
    local i
    for i in "${!PICK_CLASH[@]}"; do
        pick_focus_row "$i"
        pick_keybinding_format "${PICK_HELD[i]}"
        pick_row_names "$i" "${PICK_CLASH[i]}"
        pick_message "$PICK_STYLE_ERROR" "${PICK_LABEL[i]} and $PICK_DEPNAMES have the same key, $PICK_TEXT."
        return 0
    done
    return 1
}
