# bash-prompts: the alternate screen around a flow of prompts.
# Function definitions only; sourced in the caller shell by lib/bash-prompts.sh.

pick_screen() {
    # Runs "$@" in the caller shell, on the alternate screen when the
    # terminal has one.
    local rc=0
    if ((PICK_SCREEN)) || ! pick_screen_open; then
        "$@" || rc=$?
        return "$rc"
    fi
    if [[ -n $PICK_SCREEN_HELD ]]; then "$@" 2>"$PICK_SCREEN_HELD" || rc=$?
    else "$@" || rc=$?; fi
    pick_screen_close
    return "$rc"
}

pick_screen_open() {
    local enter
    [[ -t 0 && -t 1 ]] || return 1
    enter=$(tput smcup 2>/dev/null) || return 1
    PICK_SCREEN_LEAVE=$(tput rmcup 2>/dev/null) || return 1
    PICK_TOP=$(tput home 2>/dev/null) || return 1
    PICK_EL=$(tput el 2>/dev/null) || return 1
    PICK_ED=$(tput ed 2>/dev/null) || return 1
    [[ -n $enter && -n $PICK_SCREEN_LEAVE && -n $PICK_TOP && -n $PICK_EL && -n $PICK_ED ]] || return 1
    PICK_SCREEN_STTY=$(stty -g) || return 1
    # Error text would disturb the screen and then vanish with it.
    PICK_SCREEN_HELD=
    if [[ -t 2 ]]; then PICK_SCREEN_HELD=$(mktemp "${TMPDIR:-/tmp}/bash-prompts.XXXXXX") || PICK_SCREEN_HELD=; fi
    PICK_SCREEN_TRAPS=$(trap -p EXIT INT QUIT TERM)
    PICK_SCREEN_EXIT=$(trap -p EXIT)
    # Set before the handlers, which only undo an open screen.
    PICK_SCREEN=1
    trap 'pick_on_screen_exit' EXIT
    trap 'pick_on_screen_signal INT' INT
    trap 'pick_on_screen_signal QUIT' QUIT
    trap 'pick_on_screen_signal TERM' TERM
    # Suspending would leave the shell on this screen. dsusp is macOS's
    # second suspend key. iTerm2 takes echo off in canonical mode for a
    # password field.
    stty -echo -icanon susp undef dsusp undef 2>/dev/null || stty -echo -icanon susp undef || true
    printf '%s' "$enter$PICK_TOP$PICK_ED"
}

pick_screen_close() {
    ((PICK_SCREEN)) || return 0
    pick_cleanup_term
    pick_traps_restore
    PICK_SCREEN=0
    trap - EXIT INT QUIT TERM
    eval "$PICK_SCREEN_TRAPS"
    printf '%s' "$PICK_SCREEN_LEAVE"
    stty "$PICK_SCREEN_STTY" || true
    # A prompt that was cut short applies its saved settings again as it ends.
    [[ -z $PICK_SAVED_STTY ]] || PICK_SAVED_STTY=$PICK_SCREEN_STTY
    [[ -n $PICK_SCREEN_HELD ]] || return 0
    cat "$PICK_SCREEN_HELD"
    rm -f "$PICK_SCREEN_HELD"
}

pick_screen_abort() {
    # The flow's redirection is still in place here.
    [[ -z $PICK_SCREEN_HELD ]] || exec 2>&1
    pick_screen_close
}

pick_on_screen_signal() {
    local handler
    pick_screen_abort
    PICK_GOT_SIGNAL=$1
    handler=$(trap -p "$1")
    if [[ -z $handler ]]; then kill -"$1" $$ || true
    else
        # Bash 3.2 drops an interrupt that its own handler raises again while
        # a command runs, so the caller's handler is run here.
        eval "set -- $handler"
        eval "$3"
    fi
}

pick_on_screen_exit() {
    local rc=$?
    pick_screen_abort
    # Bash runs no EXIT trap that was set inside one.
    eval "set -- $PICK_SCREEN_EXIT"
    pick_exit_status "$rc"
    eval "${3-}"
}

pick_exit_status() {
    return "$1"
}
