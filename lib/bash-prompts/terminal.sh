# bash-prompts: terminal setup and teardown, signals, styles, widths, frame output.
# Function definitions only; sourced in the caller shell by lib/bash-prompts.sh.

pick_traps_save() {
    PICK_SAVED_INT=$(trap -p INT || true)
    PICK_SAVED_TERM=$(trap -p TERM || true)
    PICK_TRAPS_ARMED=1
}

pick_traps_restore() {
    # Idempotent: only the first call restores, so cleanup paths and signal
    # handlers cannot delete the caller's handlers by restoring twice.
    if ((PICK_TRAPS_ARMED)); then
        if [[ -n $PICK_SAVED_INT ]]; then eval "$PICK_SAVED_INT"; else trap - INT; fi
        if [[ -n $PICK_SAVED_TERM ]]; then eval "$PICK_SAVED_TERM"; else trap - TERM; fi
        PICK_SAVED_INT=
        PICK_SAVED_TERM=
        PICK_TRAPS_ARMED=0
    fi
}

pick_on_int() {
    # Mark the interrupt so the main loop stops instead of re-rendering.
    # The restored caller handler (if any) runs via the re-raised signal;
    # with the default disposition the process terminates here with 130.
    pick_cleanup_term
    pick_traps_restore
    PICK_GOT_SIGNAL=INT
    kill -INT $$ || true
}

pick_on_term() {
    pick_cleanup_term
    pick_traps_restore
    PICK_GOT_SIGNAL=TERM
    kill -TERM $$ || true
}

pick_setup_term() {
    [[ -t 0 && -t 1 ]] || return 1
    pick_prepare_styles
    PICK_SAVED_STTY=$(stty -g) || return 1
    [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
    # ISIG stays enabled so Ctrl-C still reaches the caller's signal handler.
    # Bash's own read -n imposes VMIN=1 for its duration; min/time here only
    # bound pick_read_escape, so a lone Esc resolves after 0.1 seconds.
    stty -echo -icanon min 0 time 1 || return 1
    [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
    # Capability checks stay silent; the sequences below go to the terminal.
    if tput clear >/dev/null 2>&1; then PICK_CLEAR=1; else PICK_CLEAR=0; fi
    if tput civis >/dev/null 2>&1; then PICK_CIVIS=1; else PICK_CIVIS=0; fi
    # Cache the paint sequences once; per-frame emission then needs no
    # further tput invocations. An empty result means unsupported.
    PICK_UP=$(tput cuu1 2>/dev/null || true)
    PICK_EL=$(tput el 2>/dev/null || true)
    PICK_ED=$(tput ed 2>/dev/null || true)
    [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
    if ((PICK_CIVIS)); then tput civis || true; fi
    return 0
}

pick_inline() {
    [[ -n $PICK_UP && -n $PICK_EL && -n $PICK_ED ]]
}

pick_frame_home() {
    # Sets PICK_HOME to the sequence that returns from the last painted line
    # to the start of the frame's first line.
    local r
    PICK_HOME=$'\r'
    for ((r=1; r<PICK_PREV_COUNT; r++)); do PICK_HOME+=$PICK_UP; done
}

pick_erase_frame() {
    # iTerm2 copies an alternate screen that is erased whole, or from its
    # first cell on, to the scrollback; rows erased one by one leave nothing.
    local r out
    if ((PICK_SCREEN)); then
        out=$'\r'$PICK_EL
        for ((r=1; r<PICK_PREV_COUNT; r++)); do out+=$PICK_UP$PICK_EL; done
    else
        pick_frame_home
        out=$PICK_HOME$PICK_ED
    fi
    printf '%s' "$out"
}

pick_cleanup_term() {
    # The prompt is drawn inline below the caller's output; erasing it leaves
    # the cursor where the prompt started, so the caller's next output
    # continues from there.
    pick_capture_stop
    if ((PICK_PREV_COUNT > 0)) && pick_inline; then pick_erase_frame; fi
    PICK_PREV_COUNT=0
    if ((PICK_CIVIS)); then tput cnorm || true; fi
    PICK_CIVIS=0
    if [[ -n $PICK_STYLE_RESET ]]; then printf '%s' "$PICK_STYLE_RESET"; fi
    PICK_STYLE_RESET=
    if [[ -n $PICK_SAVED_STTY ]]; then stty "$PICK_SAVED_STTY" || true; fi
    # Keep the snapshot until pick_interact exits: after a returning signal
    # handler, Bash read can reinstate its own noncanonical terminal settings.
}

pick_clear_screen() {
    # Best effort: tput genuinely fails on unsupported terminals, and a
    # failed clear must never break selection or cleanup. Refuses when a
    # pending interrupt already restored the screen, so no caller can
    # clear over it by missing its own check.
    [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
    if ((PICK_SCREEN)); then pick_blank_screen
    elif ((PICK_CLEAR)); then tput clear || true
    else printf '\n\n\n'; fi
}

pick_blank_screen() {
    # Row by row, as in pick_erase_frame.
    local r out=$PICK_TOP$PICK_EL
    for ((r=1; r<PICK_TROWS; r++)); do out+=$'\n'$PICK_EL; done
    printf '%s%s' "$out" "$PICK_TOP"
}

pick_term_size() {
    # Sets PICK_TROWS/PICK_TCOLS. stty reads the terminal on stdin; tput
    # inside a command substitution sees no terminal and reports 24x80.
    local size
    size=$(stty size 2>/dev/null) || size=
    PICK_TROWS=${size% *}
    PICK_TCOLS=${size#* }
    case $PICK_TROWS in ''|*[!0-9]*) PICK_TROWS=24 ;; esac
    case $PICK_TCOLS in ''|*[!0-9]*) PICK_TCOLS=80 ;; esac
    ((PICK_TROWS > 0)) || PICK_TROWS=24
    ((PICK_TCOLS > 0)) || PICK_TCOLS=80
}

pick_prepare_styles() {
    # Each role has one look in every prompt. The ANSI colors leave the
    # shades to the terminal's theme.
    local bold colors
    PICK_STYLE_TITLE=; PICK_STYLE_GROUP=; PICK_STYLE_FOCUS=; PICK_STYLE_MUTED=
    PICK_STYLE_WARNING=; PICK_STYLE_ERROR=; PICK_STYLE_RESET=
    PICK_STYLE_TAB=; PICK_STYLE_ACTIVE=; PICK_STYLE_CHANGED=
    [[ -z ${NO_COLOR-} && ${TERM-} != dumb ]] || return 0
    PICK_STYLE_RESET=$(tput sgr0 2>/dev/null) || { PICK_STYLE_RESET=; return 0; }
    [[ -n $PICK_STYLE_RESET ]] || return 0
    # These stand out or recede without any color.
    bold=$(tput bold 2>/dev/null || true)
    PICK_STYLE_TITLE=$bold
    PICK_STYLE_FOCUS=$bold
    PICK_STYLE_MUTED=$(tput dim 2>/dev/null || true)
    PICK_STYLE_TAB=$(tput rev 2>/dev/null || true)
    PICK_STYLE_ACTIVE=$(tput smul 2>/dev/null || true)
    [[ -z $PICK_STYLE_ACTIVE ]] || PICK_STYLE_ACTIVE=$bold$PICK_STYLE_ACTIVE
    PICK_STYLE_CHANGED=$bold
    colors=$(tput colors 2>/dev/null) || return 0
    case $colors in ''|*[!0-9]*) return 0 ;; esac
    ((colors >= 8)) || return 0
    PICK_STYLE_ERROR=$(tput setaf 1 2>/dev/null || true)
    PICK_STYLE_WARNING=$(tput setaf 3 2>/dev/null || true)
    PICK_STYLE_CHANGED=$PICK_STYLE_WARNING
    PICK_STYLE_GROUP=$(tput setaf 6 2>/dev/null || true)
    PICK_STYLE_TITLE=$bold$PICK_STYLE_GROUP
    return 0
}

pick_prepare_text() {
    # Drawn by the library itself, in ASCII outside UTF-8 locales.
    PICK_ELLIPSIS='..'
    PICK_ARROW='->'
    PICK_BOX_H=-; PICK_BOX_V='|'
    PICK_BOX_TL=+; PICK_BOX_TR=+; PICK_BOX_BL=+; PICK_BOX_BR=+
    PICK_HEAVY_H='='; PICK_HEAVY_V='|'
    PICK_HEAVY_TL=+; PICK_HEAVY_TR=+; PICK_HEAVY_BL=+; PICK_HEAVY_BR=+
    case ${LC_ALL:-${LC_CTYPE:-${LANG-}}} in
        *UTF-8*|*utf-8*|*UTF8*|*utf8*)
            PICK_ELLIPSIS='…'; PICK_ARROW='→'
            PICK_BOX_H='─'; PICK_BOX_V='│'
            PICK_BOX_TL='╭'; PICK_BOX_TR='╮'; PICK_BOX_BL='╰'; PICK_BOX_BR='╯'
            PICK_HEAVY_H='━'; PICK_HEAVY_V='┃'
            PICK_HEAVY_TL='┏'; PICK_HEAVY_TR='┓'; PICK_HEAVY_BL='┗'; PICK_HEAVY_BR='┛'
            ;;
    esac
}

pick_clip() {
    # $1 = text, $2 = cells; sets PICK_CLIPPED to the longest prefix that
    # fits and PICK_WIDTH to its width. Each painted element must stay one physical row, because inline
    # repainting moves up by element count. Non-ASCII text is measured in
    # UTF-8 bytes: characters from U+2000 up (CJK, Hangul, kana, fullwidth
    # forms, emoji, and ambiguous-width symbols) count as two cells. Narrow
    # ones among them are overcounted, which clips early but never wraps,
    # except that arrows and technical symbols, which show keys, and box
    # drawing, which frames tabs, are exact.
    local text=$1 max=$2
    if ((max <= 0)); then PICK_CLIPPED=; PICK_WIDTH=0; return 0; fi
    if [[ $text != *[![:ascii:]]* ]]; then
        PICK_CLIPPED=${text:0:$max}
        PICK_WIDTH=${#PICK_CLIPPED}
        return 0
    fi
    local LC_ALL=C
    local n=${#text} i=0 w=0 b c len cw
    while ((i < n)); do
        b=${text:i:1}
        if [[ $b < $'\x80' ]]; then
            # Plain text goes by the run.
            c=${text:i}
            c=${c%%[$'\x80'-$'\xff']*}
            len=${#c}
            ((len <= max - w)) || len=$((max - w))
            cw=$len
            ((len)) || break
        elif [[ $b < $'\xe0' ]]; then len=2; cw=1
        elif [[ $b < $'\xf0' ]]; then
            len=3; cw=2
            if [[ $b == $'\xe0' ]]; then cw=1
            elif [[ $b == $'\xe1' ]]; then
                # U+1000-U+1FFF is narrow except Hangul Jamo, U+1100-U+11FF.
                c=${text:i+1:1}
                [[ $c < $'\x84' || $c > $'\x87' ]] && cw=1
            elif [[ $b == $'\xe2' ]]; then
                # U+2180-U+21FF and U+2300-U+23BF, without the wide watch,
                # hourglass, and angle brackets, and U+2500-U+257F.
                case ${text:i+1:2} in
                    $'\x8c'[$'\x9a\x9b\xa9\xaa']) ;;
                    $'\x86'?|$'\x87'?|$'\x8c'?|$'\x8e'?|$'\x94'?|$'\x95'?) cw=1 ;;
                esac
            fi
        else len=4; cw=2; fi
        ((w + cw <= max)) || break
        w=$((w + cw))
        i=$((i + len))
    done
    PICK_CLIPPED=${text:0:i}
    PICK_WIDTH=$w
}

pick_wrap() {
    # $1 = text, $2 = cells; fills PICK_WRAPPED with the text folded at
    # spaces. A word wider than a line is left for painting to clip.
    local text=$1 max=$2 line= word
    PICK_WRAPPED=()
    while true; do
        word=${text%% *}
        pick_clip "$line${line:+ }$word" "$max"
        if [[ -n $line && $PICK_CLIPPED != "$line $word" ]]; then
            PICK_WRAPPED[${#PICK_WRAPPED[@]}]=$line
            line=$word
        else line="$line${line:+ }$word"; fi
        [[ $text == *' '* ]] || break
        text=${text#* }
    done
    [[ -z $line ]] || PICK_WRAPPED[${#PICK_WRAPPED[@]}]=$line
}

pick_paint_line() {
    # Styles PICK_CLIPPED, the text of frame row $1, into PICK_LINE: the
    # row's own style, then each span's style from its offset on.
    local text=$PICK_CLIPPED style=${PICK_FRAME_STYLE[$1]-} at=0 k=0 end part IFS=' '
    local -a spans=(${PICK_FRAME_SPANS[$1]-})
    PICK_LINE=
    while true; do
        end=${spans[k]-${#text}}
        ((end <= ${#text})) || end=${#text}
        part=${text:at:end - at}
        if [[ -n $style && -n $part ]]; then part="$style$part$PICK_STYLE_RESET"; fi
        PICK_LINE+=$part
        ((end < ${#text})) || break
        style=PICK_STYLE_${spans[k + 1]}
        style=${!style}
        at=$end
        k=$((k + 2))
    done
}

pick_frame_line() {
    # $1 = frame row, $2 = width; sets PICK_LINE to the row painted inside
    # the walls of its frames: a tab's heavy, then a sub-tab's light.
    # The frames span the width pick_render laid out, one column short of
    # the terminal.
    local walls=${PICK_FRAME_WALLS[$1]:-0} width=$2 left= right= pad
    if ((walls)); then
        width=$((PICK_TCOLS - 1 - 4 * walls))
        left="$PICK_HEAVY_V "
        right=" $PICK_HEAVY_V"
        if ((walls > 1)); then
            left+="$PICK_BOX_V "
            right=" $PICK_BOX_V$right"
        fi
    fi
    pick_clip "${PICK_FRAME[$1]}" "$width"
    pick_paint_line "$1"
    ((walls)) || return 0
    # The ellipsis, measured as two cells for clipping, takes one like the
    # walls.
    pick_clip "${PICK_CLIPPED//…/.}" "$width"
    printf -v pad '%*s' "$((width - PICK_WIDTH))" ''
    PICK_LINE=$left$PICK_LINE$pad$right
}

pick_emit_frame() {
    # $1 = width. The whole frame goes out in a single write that returns to
    # the frame's first line, with stale tails and leftover rows erased as
    # part of the same payload, so ordinary keys emit no clear.
    # The painting boundary: never emit onto a screen the signal handler
    # already restored. Payload construction above writes nothing; each
    # actual output site rechecks the flag, which shrinks post-cleanup
    # painting to the check-to-write gap. A signal inside that gap, or
    # truly mid-write, can still leave one partial or full write — that
    # bounded residue is inherent to async signals. No second write
    # follows a refusal, because every refusal breaks the main loop.
    [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
    local cols=$1 i n out
    n=${#PICK_FRAME[@]}
    if pick_inline; then
        pick_frame_home
        out=$PICK_HOME
        # One column stays free so a full-width line never leaves the
        # cursor in the pending-wrap state.
        cols=$((cols - 1))
        for ((i=0; i<n; i++)); do
            pick_frame_line "$i" "$cols"
            out+="$PICK_LINE$PICK_EL"
            if ((i < n-1)); then out+=$'\n'; fi
        done
        out+=$PICK_ED
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
        printf '%s' "$out"
    else
        # Same interrupted-output handling as the fast path: batch into one
        # write with a check immediately before it, instead of emitting
        # line by line past a single early check.
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
        out=
        for ((i=0; i<n; i++)); do
            pick_frame_line "$i" "$cols"
            out+="$PICK_LINE"$'\n'
        done
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
        pick_clear_screen || return 1
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
        printf '%s' "$out"
    fi
}
