# bash-prompts: grouped selection for Bash 3.2.
#
# SPDX-License-Identifier: MIT
#
# Public API (other pick_* / PICK_* names are internal):
# Input arrays are parallel, dense, zero-based.
#   PICK_ID[i]      unique identity; if unset, uses PICK_LABEL[i].
#   PICK_LABEL[i]   display text.
#   PICK_GROUP[i]   group text (unset means an unnamed group).
#   PICK_VALID[i]   1 includes a row, 0 excludes it; unset means 1.
#   PICK_DISABLED[i] optional reason a visible checkbox cannot change.
#   PICK_STATE[i]   0/1 selected state: input/output for pick_multiselect.
#   PICK_VALUE      single selection input/output ID; unset starts at first row.
#   PICK_PROMPT     one line shown above the list; unset uses a generic title.
# Dependency API additionally uses:
#   PICK_DEPS[i]    comma-separated IDs of earlier rows; tokens are trimmed.
#   PICK_DIRECT[i]  explicit choices.
#   PICK_AUTO[i]    retained automatic choices.
#   PICK_DEPENDENCY_MODE: cascade (default) or lock.
#     cascade: unchecking a prerequisite also unchecks its dependents.
#     lock: a selected prerequisite stays locked while required.
#   IDs referenced by PICK_DEPS must be nonempty, comma-free, and have no
#   leading/trailing spaces or tabs. Display labels have no such token rule.
#
# pick_select: single choice; Up/Down moves focus, Submit returns its ID in
#   PICK_VALUE. A provided initial ID must identify an included row.
# pick_multiselect: grouped checkboxes, retaining incoming PICK_STATE.
#   Empty submission is valid.
# Both return 0 submitted, 1 cancelled, 2 on invalid input or no interactive
# terminal, 3 when a Back key was pressed. Read results on 0; on 3 they hold
# the unsubmitted state at that moment.
# pick_dependencies: retains PICK_STATE, with live prerequisites on selection,
# empty submission and Back. Returns the same 0/1/2/3 statuses as multiselect.
# pick_run: dependency-aware selection, starting with nothing checked.
#   Live closure, dependency-mode deselection, retained auto choices, and
#   nonempty submission.
#   Returns 0 submitted, 1 on cancellation or failure (0.1 compatibility).
# pick_close: noninteractive dependency closure from DIRECT + retained AUTO.
#   Returns 0 or 1; failed closure leaves selection state unchanged.
# pick_find_id / pick_find_label <value>: print index or -1.
# pick_selected_indices: fills PICK_SELECTED_INDICES with included rows whose
#   PICK_STATE is 1, in input order.
# pick_required_by <index>: fills PICK_REQUIRED_BY_INDICES with included,
#   selected rows whose PICK_DEPS name that row, in input order, in any mode.
# pick_locked_by <index>: print labels of selected immediate dependents
#   in lock mode; print nothing in cascade mode.
# pick_split_csv <text>: fills PICK_SPLIT, trimming tokens and preserving
#   empty tokens, including a trailing one; empty input means no tokens.
#
# Optional keys (arrays; assign after sourcing, each replaces its action's keys):
#   PICK_KEYS_UP=(Up k)          PICK_KEYS_DOWN=(Down j)
#   PICK_KEYS_TOGGLE=(Space)     PICK_KEYS_ALL=(a)
#   PICK_KEYS_CLEAR=(n)          PICK_KEYS_SUBMIT=(Enter)
#   PICK_KEYS_CANCEL=(q Q Esc)   PICK_KEYS_BACK=()
# Elements are a single printable ASCII character or one of:
#   Up Down Left Right Space Enter Esc Tab Backspace.
# Empty arrays disable an action. A key may belong to only one action.
# Ctrl-C remains a terminal signal. The map is read on each interactive call.
# Toggle, All, and Clear bindings apply only to multiselect and dependencies.
# Back applies to pick_select, pick_multiselect, and pick_dependencies.
#
# Optional colors: PICK_FOCUS_COLOR, PICK_SELECTED_COLOR, PICK_GROUP_COLOR.
#   Empty/default means terminal default. Names: black, red, green, yellow,
#   blue, magenta, cyan, white. Focus takes precedence over selected color.
#   Nonempty NO_COLOR or TERM=dumb gives plain text; missing color capability
#   omits colors while supported bold title and dim hint remain.
# Prompts draw inline at the cursor and erase themselves when they end.
# The API uses one active PICK_* state in the calling Bash process.
PICK_VERSION="0.3.0"

PICK_ID=()
PICK_LABEL=()
PICK_GROUP=()
PICK_DEPS=()
PICK_VALID=()
PICK_DISABLED=()
PICK_DIRECT=()
PICK_STATE=()
unset PICK_VALUE
PICK_AUTO=()
PICK_SPLIT=()
PICK_SELECTED_INDICES=()
PICK_REQUIRED_BY_INDICES=()
PICK_FOCUS=()
PICK_FLOCK=()
PICK_CURSOR=0
PICK_OFFSET=0
PICK_MSG=
PICK_GROUPS=()
PICK_FOCUS_ROW=()
PICK_DKIND=()
PICK_DREF=()
PICK_DGROUP=()
PICK_GROUP_ROW=()
PICK_STICKY=-1
PICK_HINT=()
PICK_TROWS=24
PICK_TCOLS=80
PICK_CLEAR=0
PICK_CIVIS=0
PICK_UP=
PICK_ED=
PICK_HOME=
PICK_CLIPPED=
PICK_EL=
PICK_PREV_COUNT=0
PICK_PREV_ROWS=
PICK_PREV_COLS=
PICK_FRAME=()
PICK_FRAME_STYLE=()
PICK_ROW=
PICK_ROW_STYLE=
PICK_STYLE_FOCUS=
PICK_STYLE_SELECTED=
PICK_STYLE_GROUP=
PICK_STYLE_TITLE=
PICK_STYLE_HINT=
PICK_STYLE_RESET=
PICK_SAVED_INT=
PICK_SAVED_TERM=
PICK_SAVED_STTY=
PICK_TRAPS_ARMED=0
PICK_SNAP_DIRECT=()
PICK_SNAP_STATE=()
PICK_SNAP_AUTO=()
PICK_GOT_SIGNAL=
PICK_QUIET=0
PICK_DEPNAMES=
PICK_GTOT=0
PICK_GSEL=0
PICK_KEYS_UP=(Up k)
PICK_KEYS_DOWN=(Down j)
PICK_KEYS_TOGGLE=(Space)
PICK_KEYS_ALL=(a)
PICK_KEYS_CLEAR=(n)
PICK_KEYS_SUBMIT=(Enter)
PICK_KEYS_CANCEL=(q Q Esc)
PICK_KEYS_BACK=()
PICK_BOUND_KEYS=()
PICK_BOUND_ACTIONS=()
PICK_KEY_HELP=()
PICK_KEY_ACTION=

pick_err() {
    # With PICK_QUIET set (interactive use), route the message to the
    # on-screen notice instead of writing over the terminal frame.
    if [[ ${PICK_QUIET:-0} == 1 ]]; then
        if [[ -n ${PICK_MSG-} ]]; then PICK_MSG="$PICK_MSG; $*"
        else PICK_MSG="$*"; fi
    else
        printf 'pick: %s\n' "$*" >&2
    fi
}

pick_trim() {
    local s=$1
    while [[ $s == ' '* || $s == $'\t'* ]]; do s=${s#?}; done
    while [[ $s == *' ' || $s == *$'\t' ]]; do s=${s%?}; done
    printf '%s' "$s"
}

pick_split_csv() {
    PICK_SPLIT=()
    local csv=$1 part
    [[ -n $csv ]] || return 0
    while [[ $csv == *,* ]]; do
        part=${csv%%,*}
        PICK_SPLIT[${#PICK_SPLIT[@]}]=$(pick_trim "$part")
        csv=${csv#*,}
    done
    PICK_SPLIT[${#PICK_SPLIT[@]}]=$(pick_trim "$csv")
}

pick_find_id() {
    local want=$1 i
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        if [[ ${PICK_ID[i]-${PICK_LABEL[i]}} == "$want" ]]; then
            printf '%s' "$i"
            return 0
        fi
    done
    printf '%s' "-1"
}

pick_validate_items() {
    local i j id
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        id=${PICK_ID[i]-${PICK_LABEL[i]}}
        for ((j=0; j<i; j++)); do
            if [[ ${PICK_ID[j]-${PICK_LABEL[j]}} == "$id" ]]; then
                pick_err "duplicate ID '$id'"
                return 1
            fi
        done
    done
}

pick_find_label() {
    # $1 = label; prints the row index, or -1.
    local want=$1 i n
    n=${#PICK_LABEL[@]}
    for ((i=0; i<n; i++)); do
        if [[ ${PICK_LABEL[i]} == "$want" ]]; then printf '%s' "$i"; return 0; fi
    done
    printf '%s' "-1"
}

pick_snapshot() {
    # Save the selection triples so a failed closure can restore the exact
    # entry state instead of leaving a partial plan behind.
    local i n
    n=${#PICK_LABEL[@]}
    PICK_SNAP_DIRECT=(); PICK_SNAP_STATE=(); PICK_SNAP_AUTO=()
    for ((i=0; i<n; i++)); do
        PICK_SNAP_DIRECT[i]=${PICK_DIRECT[i]:-0}
        PICK_SNAP_STATE[i]=${PICK_STATE[i]:-0}
        PICK_SNAP_AUTO[i]=${PICK_AUTO[i]:-0}
    done
}

pick_restore_snap() {
    local i n
    n=${#PICK_LABEL[@]}
    PICK_DIRECT=(); PICK_STATE=(); PICK_AUTO=()
    for ((i=0; i<n; i++)); do
        PICK_DIRECT[i]=${PICK_SNAP_DIRECT[i]:-0}
        PICK_STATE[i]=${PICK_SNAP_STATE[i]:-0}
        PICK_AUTO[i]=${PICK_SNAP_AUTO[i]:-0}
    done
}

pick_close() {
    # Atomic closure of explicit and retained automatic choices.
    local n i k dep j b
    local -a expand
    n=${#PICK_LABEL[@]}
    pick_validate_items || return 1
    pick_snapshot
    for ((i=0; i<n; i++)); do
        [[ ${PICK_VALID[i]:-1} == 0 ]] && continue
        pick_split_csv "${PICK_DEPS[i]:-}"
        for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
            dep=${PICK_SPLIT[k]}
            [[ -n $dep ]] || { pick_err "'${PICK_LABEL[i]}' has an empty dependency entry"; return 1; }
            j=$(pick_find_id "$dep")
            if [[ $j -lt 0 ]]; then
                pick_err "'${PICK_LABEL[i]}' requires unknown '$dep'"
                return 1
            fi
            if [[ ${PICK_VALID[j]:-1} == 0 ]]; then
                # Excluded prerequisites cannot join the selected set;
                # accepting their dependents would return an incomplete closure.
                if [[ ${PICK_DIRECT[i]:-0} == 1 && ( -z ${PICK_EXPAND_FROM+x} || $i == "$PICK_EXPAND_FROM" ) ]]; then
                    pick_err "'${PICK_LABEL[i]}' requires '$dep', which is not available"
                    return 1
                fi
                continue
            fi
            if ((j >= i)); then
                pick_err "'${PICK_LABEL[i]}' requires '$dep', which is not ordered before it"
                return 1
            fi
        done
    done
    for ((i=0; i<n; i++)); do
        expand[i]=0
        if [[ -z ${PICK_EXPAND_FROM+x} || $i == "$PICK_EXPAND_FROM" ||
              ( $PICK_EXPAND_FROM == auto && ${PICK_AUTO[i]:-0} == 1 ) ]]; then expand[i]=1; fi
        if [[ ${PICK_VALID[i]:-1} == 0 ]]; then
            PICK_DIRECT[i]=0
            PICK_STATE[i]=0
            PICK_AUTO[i]=0
            continue
        fi
        # Recompute strictly from the explicit input: direct choices plus
        # retained auto selections. Stale PICK_STATE from a previous run
        # never carries over.
        if [[ ${PICK_DIRECT[i]:-0} == 1 || ${PICK_AUTO[i]:-0} == 1 ]]; then
            PICK_STATE[i]=1
        else
            PICK_STATE[i]=0
        fi
    done
    local changed=1
    while ((changed)); do
        changed=0
        for ((i=0; i<n; i++)); do
            [[ ${PICK_STATE[i]:-0} == 1 && ${PICK_VALID[i]:-1} != 0 && ${expand[i]} == 1 ]] || continue
            pick_split_csv "${PICK_DEPS[i]:-}"
            for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
                dep=${PICK_SPLIT[k]}
                [[ -n $dep ]] || continue
                j=$(pick_find_id "$dep")
                [[ $j -ge 0 ]] || continue
                [[ ${PICK_VALID[j]:-1} != 0 ]] || continue
                if [[ ${expand[j]} != 1 ]]; then expand[j]=1; changed=1; fi
                if [[ ${PICK_STATE[j]:-0} != 1 ]]; then
                    PICK_STATE[j]=1
                    [[ ${PICK_DIRECT[j]:-0} == 1 ]] || PICK_AUTO[j]=1
                    changed=1
                fi
            done
        done
    done
    # Phase three verifies the whole candidate closure, not just direct
    # roots: a transitively pulled-in row whose prerequisite is unavailable
    # fails the entire plan instead of publishing a partial one.
    for ((i=0; i<n; i++)); do
        [[ ${PICK_STATE[i]:-0} == 1 && ${PICK_VALID[i]:-1} != 0 && ${expand[i]} == 1 ]] || continue
        pick_split_csv "${PICK_DEPS[i]:-}"
        for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
            dep=${PICK_SPLIT[k]}
            [[ -n $dep ]] || continue
            j=$(pick_find_id "$dep")
            [[ $j -ge 0 ]] || continue
            if [[ ${PICK_VALID[j]:-1} == 0 ]]; then
                pick_err "'${PICK_LABEL[i]}' requires '$dep', which is not available"
                pick_restore_snap
                return 1
            fi
        done
    done
    for ((b=0; b<n; b++)); do
        if [[ -n ${PICK_DISABLED[b]:-} && ${PICK_STATE[b]:-0} != ${PICK_SNAP_STATE[b]:-0} ]]; then
            pick_err "${PICK_LABEL[b]}: ${PICK_DISABLED[b]}"
            pick_restore_snap
            return 1
        fi
        [[ -n ${PICK_DIRECT[b]+set} ]] || PICK_DIRECT[b]=0
    done
    return 0
}

pick_locked_by() {
    [[ ${PICK_DEPENDENCY_MODE:-cascade} == lock ]] || return 0
    pick_dep_names_into "$1"
    printf '%s' "$PICK_DEPNAMES"
}

pick_required_by() {
    # The local keeps a caller's pick_split_csv result intact.
    local -a PICK_SPLIT
    local idx=$1 j k id
    id=${PICK_ID[idx]-${PICK_LABEL[idx]}}
    PICK_REQUIRED_BY_INDICES=()
    for ((j=0; j<${#PICK_LABEL[@]}; j++)); do
        [[ $j != "$idx" && ${PICK_STATE[j]:-0} == 1 && ${PICK_VALID[j]:-1} != 0 ]] || continue
        pick_split_csv "${PICK_DEPS[j]:-}"
        for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
            if [[ ${PICK_SPLIT[k]} == "$id" ]]; then
                PICK_REQUIRED_BY_INDICES[${#PICK_REQUIRED_BY_INDICES[@]}]=$j
                break
            fi
        done
    done
}

pick_dep_names_into() {
    # The local keeps internal label formatting from replacing a caller's
    # pick_required_by result.
    local -a PICK_REQUIRED_BY_INDICES
    local k
    pick_required_by "$1"
    PICK_DEPNAMES=
    for ((k=0; k<${#PICK_REQUIRED_BY_INDICES[@]}; k++)); do
        ((k == 0)) || PICK_DEPNAMES="$PICK_DEPNAMES, "
        PICK_DEPNAMES="$PICK_DEPNAMES${PICK_LABEL[PICK_REQUIRED_BY_INDICES[k]]}"
    done
}

pick_recalc_locks() {
    # Caches each selected row's selected immediate dependents for display;
    # in lock mode they are also what holds the row checked.
    local i n
    n=${#PICK_LABEL[@]}
    for ((i=0; i<n; i++)); do PICK_FLOCK[i]=; done
    [[ ${PICK_MODE:-dependencies} == dependencies ]] || return 0
    for ((i=0; i<n; i++)); do
        [[ ${PICK_STATE[i]:-0} == 1 && ${PICK_VALID[i]:-1} != 0 ]] || continue
        pick_dep_names_into "$i"
        PICK_FLOCK[i]=$PICK_DEPNAMES
    done
}

pick_build_focus() {
    # Focus order: distinct groups in first-appearance order, catalog order
    # inside each group. Display rows: a blank line between groups, a header
    # for each named group, then its items.
    local i g f seen n gi k d
    n=${#PICK_LABEL[@]}
    PICK_FOCUS=()
    PICK_GROUPS=()
    for ((i=0; i<n; i++)); do
        [[ ${PICK_VALID[i]:-1} == 0 ]] && continue
        g=${PICK_GROUP[i]-}
        seen=0
        for ((f=0; f<${#PICK_GROUPS[@]}; f++)); do
            [[ ${PICK_GROUPS[f]} == "$g" ]] && { seen=1; break; }
        done
        ((seen)) || PICK_GROUPS[${#PICK_GROUPS[@]}]=$g
    done
    PICK_FOCUS_ROW=(); PICK_DKIND=(); PICK_DREF=(); PICK_DGROUP=(); PICK_GROUP_ROW=()
    d=0
    for ((gi=0; gi<${#PICK_GROUPS[@]}; gi++)); do
        if ((gi > 0)); then
            PICK_DKIND[d]=blank; PICK_DREF[d]=; PICK_DGROUP[d]=$gi; d=$((d + 1))
        fi
        PICK_GROUP_ROW[gi]=$d
        if [[ -n ${PICK_GROUPS[gi]} ]]; then
            PICK_DKIND[d]=header; PICK_DREF[d]=$gi; PICK_DGROUP[d]=$gi; d=$((d + 1))
        fi
        for ((i=0; i<n; i++)); do
            [[ ${PICK_VALID[i]:-1} == 0 ]] && continue
            [[ ${PICK_GROUP[i]-} == "${PICK_GROUPS[gi]}" ]] || continue
            k=${#PICK_FOCUS[@]}
            PICK_FOCUS[k]=$i
            PICK_FOCUS_ROW[k]=$d
            PICK_DKIND[d]=item; PICK_DREF[d]=$k; PICK_DGROUP[d]=$gi; d=$((d + 1))
        done
    done
}

pick_group_counts() {
    # $1 = group; sets PICK_GTOT/PICK_GSEL over valid rows.
    local g=$1 i n
    n=${#PICK_LABEL[@]}
    PICK_GTOT=0
    PICK_GSEL=0
    for ((i=0; i<n; i++)); do
        [[ ${PICK_VALID[i]:-1} == 0 ]] && continue
        [[ ${PICK_GROUP[i]-} == "$g" ]] || continue
        PICK_GTOT=$((PICK_GTOT + 1))
        [[ ${PICK_STATE[i]:-0} == 1 ]] && PICK_GSEL=$((PICK_GSEL + 1))
    done
}

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
    pick_prepare_colors || return 1
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

pick_cleanup_term() {
    # The prompt is drawn inline below the caller's output; erasing it leaves
    # the cursor where the prompt started, so the caller's next output
    # continues from there.
    if ((PICK_PREV_COUNT > 0)) && pick_inline; then
        pick_frame_home
        printf '%s%s' "$PICK_HOME" "$PICK_ED"
    fi
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
    if ((PICK_CLEAR)); then tput clear || true; else printf '\n\n\n'; fi
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

pick_hint() {
    # $1 = width; fills PICK_HINT with the active bindings, wrapped to width.
    # Verbs follow the PICK_KEY_HELP order set by pick_prepare_keys.
    local cols=$1 i seg line= verbs help
    if [[ $PICK_MODE == single ]]; then verbs=(up down - - - select back cancel)
    elif [[ $PICK_MODE == dependencies ]]; then verbs=(up down toggle all clear submit back cancel)
    else verbs=(up down toggle all none submit back cancel); fi
    help=("${PICK_KEY_HELP[@]}")
    # Up and Down share one segment when both are bound.
    if [[ ${help[0]} != off && ${help[1]} != off ]]; then
        verbs[0]=-
        verbs[1]=move
        help[1]="${help[0]} ${help[1]}"
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

pick_sticky() {
    # A group header that scrolled above the window stays pinned at its top.
    local top=$PICK_OFFSET g
    PICK_STICKY=-1
    [[ ${PICK_DKIND[top]-} == item ]] || return 0
    g=${PICK_DGROUP[top]}
    [[ -n ${PICK_GROUPS[g]} ]] || return 0
    ((PICK_GROUP_ROW[g] < top)) && PICK_STICKY=$g
    return 0
}

pick_render() {
    # A pending interrupt means the terminal is already restored; build
    # nothing so no further frame is composed for a dead screen.
    [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
    local rows cols h d total drow start end title counter avail show_title show_msg hint_rows spacer
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
    PICK_STICKY=-1
    if ((h > 1)); then
        pick_sticky
        # A pinned header takes one list row; scroll once more if that
        # would hide the focused row.
        if ((PICK_STICKY >= 0 && drow >= PICK_OFFSET + h - 1)); then
            PICK_OFFSET=$((PICK_OFFSET + 1))
            pick_sticky
        fi
    fi
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
    if ((PICK_STICKY >= 0)); then
        pick_group_line "$PICK_STICKY"
        PICK_FRAME_STYLE[${#PICK_FRAME[@]}]=$PICK_ROW_STYLE
        PICK_FRAME[${#PICK_FRAME[@]}]=$PICK_ROW
        end=$((end - 1))
    fi
    # A group separator at the top of the window separates nothing; spend
    # that row on the next list row instead. A separator or header at the
    # bottom introduces nothing visible, so it is left out.
    if [[ ${PICK_DKIND[start]-} == blank ]]; then
        start=$((start + 1))
        end=$((end + 1))
    fi
    ((end > total)) && end=$total
    while ((end - 1 > drow)) && [[ ${PICK_DKIND[end - 1]} != item ]]; do
        end=$((end - 1))
    done
    for ((d=start; d<end; d++)); do
        pick_render_row "$d"
        PICK_FRAME_STYLE[${#PICK_FRAME[@]}]=$PICK_ROW_STYLE
        PICK_FRAME[${#PICK_FRAME[@]}]=$PICK_ROW
    done
    ((spacer)) && PICK_FRAME[${#PICK_FRAME[@]}]=
    for ((d=0; d<hint_rows; d++)); do
        PICK_FRAME_STYLE[${#PICK_FRAME[@]}]=$PICK_STYLE_HINT
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

pick_clip() {
    # $1 = text, $2 = cells; sets PICK_CLIPPED to the longest prefix that
    # fits. Each painted element must stay one physical row, because inline
    # repainting moves up by element count. Non-ASCII text is measured in
    # UTF-8 bytes: characters from U+2000 up (CJK, Hangul, kana, fullwidth
    # forms, emoji, and ambiguous-width symbols) count as two cells. Narrow
    # ones among them are overcounted, which clips early but never wraps.
    local text=$1 max=$2
    if ((max <= 0)); then PICK_CLIPPED=; return 0; fi
    if [[ $text != *[![:ascii:]]* ]]; then
        PICK_CLIPPED=${text:0:$max}
        return 0
    fi
    local LC_ALL=C
    local n=${#text} i=0 w=0 b c len cw
    while ((i < n)); do
        b=${text:i:1}
        if [[ $b < $'\x80' ]]; then len=1; cw=1
        elif [[ $b < $'\xe0' ]]; then len=2; cw=1
        elif [[ $b < $'\xf0' ]]; then
            len=3; cw=2
            if [[ $b == $'\xe0' ]]; then cw=1
            elif [[ $b == $'\xe1' ]]; then
                # U+1000-U+1FFF is narrow except Hangul Jamo, U+1100-U+11FF.
                c=${text:i+1:1}
                [[ $c < $'\x84' || $c > $'\x87' ]] && cw=1
            fi
        else len=4; cw=2; fi
        ((w + cw <= max)) || break
        w=$((w + cw))
        i=$((i + len))
    done
    PICK_CLIPPED=${text:0:i}
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
    local cols=$1 i line n out style
    n=${#PICK_FRAME[@]}
    if pick_inline; then
        pick_frame_home
        out=$PICK_HOME
        # One column stays free so a full-width line never leaves the
        # cursor in the pending-wrap state.
        cols=$((cols - 1))
        for ((i=0; i<n; i++)); do
            pick_clip "${PICK_FRAME[i]}" "$cols"
            line=$PICK_CLIPPED
            style=${PICK_FRAME_STYLE[i]-}
            if [[ -n $style && -n $line ]]; then line="$style$line$PICK_STYLE_RESET"; fi
            out+="$line$PICK_EL"
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
            pick_clip "${PICK_FRAME[i]}" "$cols"
            line=$PICK_CLIPPED
            style=${PICK_FRAME_STYLE[i]-}
            if [[ -n $style ]]; then line="$style$line$PICK_STYLE_RESET"; fi
            out+="$line"$'\n'
        done
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
        pick_clear_screen || return 1
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
        printf '%s' "$out"
    fi
}

pick_render_row() {
    # $1 = display row; sets PICK_ROW and PICK_ROW_STYLE.
    local d=$1
    PICK_ROW=
    PICK_ROW_STYLE=
    case ${PICK_DKIND[d]-} in
        header) pick_group_line "${PICK_DREF[d]}" ;;
        item) pick_item_line "${PICK_FOCUS[${PICK_DREF[d]}]}" "${PICK_DREF[d]}" ;;
    esac
}

pick_group_line() {
    local g=${PICK_GROUPS[$1]}
    PICK_ROW=$g
    PICK_ROW_STYLE=$PICK_STYLE_GROUP
    [[ $PICK_MODE != single ]] || return 0
    pick_group_counts "$g"
    PICK_ROW="$g ($PICK_GSEL/$PICK_GTOT)"
}

pick_item_line() {
    local idx=$1 pos=$2 mark="[ ]" notes= reqs= k j
    PICK_ROW_STYLE=
    if [[ $PICK_MODE == single ]]; then
        mark=
    elif [[ ${PICK_STATE[idx]:-0} == 1 ]]; then
        mark="[x]"
        PICK_ROW_STYLE=$PICK_STYLE_SELECTED
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
            [[ $j -ge 0 ]] || continue
            [[ -z $reqs ]] || reqs="$reqs, "
            reqs="$reqs${PICK_LABEL[j]}"
        done
        [[ -z $reqs ]] || notes="requires $reqs"
    fi
    if [[ -n ${PICK_DISABLED[idx]:-} ]]; then
        notes="${notes:+$notes; }${PICK_DISABLED[idx]}"
    fi
    if ((pos == PICK_CURSOR)); then
        PICK_ROW='> '
        PICK_ROW_STYLE=$PICK_STYLE_FOCUS
    else PICK_ROW='  '; fi
    PICK_ROW="$PICK_ROW${mark:+$mark }${PICK_LABEL[idx]}${notes:+  ($notes)}"
}

pick_action() {
    local action=$1 i idx
    if [[ $PICK_MODE == dependencies ]]; then
        case $action in
            toggle) pick_toggle ;; all) pick_check_all ;; clear) pick_clear_directs ;;
        esac
        return
    fi
    PICK_MSG=
    case $action in
        toggle)
            idx=${PICK_FOCUS[PICK_CURSOR]}
            if [[ -n ${PICK_DISABLED[idx]:-} ]]; then PICK_MSG=${PICK_DISABLED[idx]}; return 0; fi
            PICK_STATE[idx]=$((1 - ${PICK_STATE[idx]:-0}))
            ;;
        all|clear)
            for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
                [[ -z ${PICK_DISABLED[i]:-} ]] || continue
                if [[ $action == all && ${PICK_VALID[i]:-1} != 0 ]]; then PICK_STATE[i]=1
                else PICK_STATE[i]=0; fi
            done
            ;;
    esac
    return 0
}

pick_toggle() {
    local idx depnames
    idx=${PICK_FOCUS[PICK_CURSOR]}
    if [[ -n ${PICK_DISABLED[idx]:-} ]]; then PICK_MSG=${PICK_DISABLED[idx]}; return 0; fi
    depnames=$(pick_locked_by "$idx")
    if [[ ${PICK_STATE[idx]:-0} == 1 ]]; then
        if [[ -n $depnames ]]; then PICK_MSG="${PICK_LABEL[idx]} stays checked: required by $depnames."; return 0; fi
        pick_deselect "$idx"
        pick_recalc_locks
        return 0
    fi
    PICK_DIRECT[idx]=1
    PICK_STATE[idx]=1
    if [[ ${PICK_PRESERVE_INITIAL:-0} == 1 ]]; then local PICK_EXPAND_FROM=$idx; fi
    # Route the toggle through the same validated closure as the
    # noninteractive path. Quiet mode shows the reason on screen instead
    # of scribbling over the terminal frame.
    PICK_QUIET=1
    PICK_MSG=
    if ! pick_close; then
        PICK_DIRECT[idx]=0
        PICK_STATE[idx]=0
        PICK_QUIET=0
        pick_recalc_locks
        return 0
    fi
    PICK_QUIET=0
    PICK_MSG=
    pick_recalc_locks
    return 0
}

pick_deselect() {
    local idx=$1 i k j removed=
    local -a removed_rows
    removed_rows[idx]=1
    pick_snapshot
    PICK_STATE[idx]=0
    PICK_DIRECT[idx]=0
    PICK_AUTO[idx]=0
    if [[ ${PICK_DEPENDENCY_MODE:-cascade} == cascade ]]; then
        # Dependencies precede dependents in the validated input, so a
        # forward pass propagates removal through the entire dependent chain.
        for ((i=idx+1; i<${#PICK_LABEL[@]}; i++)); do
            [[ ${PICK_STATE[i]:-0} == 1 ]] || continue
            pick_split_csv "${PICK_DEPS[i]:-}"
            for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
                j=$(pick_find_id "${PICK_SPLIT[k]}")
                if [[ $j -ge 0 && ${removed_rows[j]:-0} == 1 ]]; then
                    # Clear retained history too, so the next closure does
                    # not reintroduce the dependent or its removed prerequisite.
                    PICK_STATE[i]=0
                    PICK_DIRECT[i]=0
                    PICK_AUTO[i]=0
                    removed_rows[i]=1
                    removed="${removed:+$removed, }${PICK_LABEL[i]}"
                    break
                fi
            done
        done
    fi
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        if [[ -n ${PICK_DISABLED[i]:-} && ${PICK_STATE[i]:-0} != ${PICK_SNAP_STATE[i]:-0} ]]; then
            pick_restore_snap
            PICK_MSG="${PICK_LABEL[i]}: ${PICK_DISABLED[i]}"
            return 0
        fi
    done
    PICK_MSG=
    [[ -z $removed ]] || PICK_MSG="Also unchecked $removed."
    return 0
}

pick_check_all() {
    # Operates on included rows only. The pre-change triples are saved so
    # a failed closure restores the coherent prior selection (with its
    # reason already on screen via PICK_QUIET) instead of a partial one.
    local i n
    n=${#PICK_LABEL[@]}
    local -a save_direct save_state save_auto
    for ((i=0; i<n; i++)); do
        save_direct[i]=${PICK_DIRECT[i]:-0}
        save_state[i]=${PICK_STATE[i]:-0}
        save_auto[i]=${PICK_AUTO[i]:-0}
    done
    for ((i=0; i<n; i++)); do
        [[ ${PICK_VALID[i]:-1} != 0 && -z ${PICK_DISABLED[i]:-} ]] || continue
        PICK_DIRECT[i]=1
        PICK_STATE[i]=1
    done
    PICK_QUIET=1
    PICK_MSG=
    if ! pick_close; then
        for ((i=0; i<n; i++)); do
            PICK_DIRECT[i]=${save_direct[i]:-0}
            PICK_STATE[i]=${save_state[i]:-0}
            PICK_AUTO[i]=${save_auto[i]:-0}
        done
        PICK_QUIET=0
        pick_recalc_locks
        return 0
    fi
    PICK_QUIET=0
    pick_recalc_locks
    PICK_MSG="Checked all items."
}

pick_clear_directs() {
    # Retained automatic choices still require their prerequisite chains.
    # Seeded callers expand those chains without repairing unrelated,
    # read-only baseline choices that were already incomplete.
    local i n
    if [[ ${PICK_PRESERVE_INITIAL:-0} == 1 ]]; then local PICK_EXPAND_FROM=auto; fi
    n=${#PICK_LABEL[@]}
    local -a save_direct save_state save_auto
    for ((i=0; i<n; i++)); do
        save_direct[i]=${PICK_DIRECT[i]:-0}
        save_state[i]=${PICK_STATE[i]:-0}
        save_auto[i]=${PICK_AUTO[i]:-0}
    done
    for ((i=0; i<n; i++)); do
        [[ -z ${PICK_DISABLED[i]:-} ]] || continue
        PICK_DIRECT[i]=0
    done
    PICK_QUIET=1
    PICK_MSG=
    if ! pick_close; then
        for ((i=0; i<n; i++)); do
            PICK_DIRECT[i]=${save_direct[i]:-0}
            PICK_STATE[i]=${save_state[i]:-0}
            PICK_AUTO[i]=${save_auto[i]:-0}
        done
        PICK_QUIET=0
        pick_recalc_locks
        return 0
    fi
    PICK_QUIET=0
    pick_recalc_locks
    PICK_MSG="Cleared your choices; auto-checked items stay until unchecked."
}

pick_selected_indices() {
    local i
    PICK_SELECTED_INDICES=()
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        [[ ${PICK_STATE[i]:-0} == 1 && ${PICK_VALID[i]:-1} != 0 ]] || continue
        PICK_SELECTED_INDICES[${#PICK_SELECTED_INDICES[@]}]=$i
    done
}

pick_sel_count() {
    local i n c=0
    n=${#PICK_LABEL[@]}
    for ((i=0; i<n; i++)); do [[ ${PICK_STATE[i]:-0} == 1 ]] && c=$((c + 1)); done
    printf '%s' "$c"
}

pick_run() {
    local PICK_MODE=dependencies PICK_ALLOW_EMPTY=0 PICK_ALLOW_BACK=0 PICK_PRESERVE_INITIAL=0 i
    case ${PICK_DEPENDENCY_MODE:-cascade} in
        cascade|lock) ;;
        *) pick_err "unknown dependency mode '${PICK_DEPENDENCY_MODE}'"; return 1 ;;
    esac
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        PICK_DIRECT[i]=0; PICK_STATE[i]=0; PICK_AUTO[i]=0
    done
    pick_close || return 1
    if pick_interact; then return 0; else return 1; fi
}

pick_interact() {
    local key seq part rc=1 start i resized
    pick_prepare_keys || return 2
    pick_build_focus
    ((${#PICK_FOCUS[@]})) || { pick_err "no selectable items"; return 2; }
    PICK_CURSOR=0
    if [[ $PICK_MODE == single ]]; then
        for ((i=0; i<${#PICK_FOCUS[@]}; i++)); do
            if [[ ${PICK_FOCUS[i]} == "$PICK_INITIAL_INDEX" ]]; then PICK_CURSOR=$i; break; fi
        done
    fi
    PICK_OFFSET=0
    PICK_MSG=
    PICK_GOT_SIGNAL=
    PICK_PREV_COUNT=0
    PICK_PREV_ROWS=
    PICK_PREV_COLS=
    pick_traps_save
    trap 'pick_on_int' INT
    trap 'pick_on_term' TERM
    if ! pick_setup_term; then
        pick_cleanup_term
        PICK_SAVED_STTY=
        pick_traps_restore
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
        pick_err "interactive selection needs a terminal and valid options"
        return 2
    fi
    pick_recalc_locks
    while true; do
        if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break; fi
        # A refused render (pending interrupt, or an unpaintable terminal)
        # ends the session instead of blocking for keys on a dead screen.
        pick_render || { rc=1; break; }
        if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break; fi
        # The read carries a one-second timeout as an interrupt backstop:
        # a returning caller trap resumes inside read, so without it the
        # cancel would wait for the next keypress. A failure ends the
        # session unless it is a proven timeout with no pending interrupt;
        # only elapsed time distinguishes the two on Bash 3.2, where both
        # report the same status.
        key=
        resized=0
        while true; do
            start=$SECONDS
            if IFS= read -rsn1 -t 1 key; then break; fi
            if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break 2; fi
            if (( SECONDS - start >= 1 )); then
                # The timeout tick also picks up a resized terminal.
                pick_term_size
                [[ $PICK_TROWS == "$PICK_PREV_ROWS" && $PICK_TCOLS == "$PICK_PREV_COLS" ]] || { resized=1; break; }
                continue
            fi
            rc=1; break 2
        done
        # A key that arrived after a returning handler fired must not be
        # dispatched: the terminal is already restored, so cancel instead
        # of acting on stale input.
        if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break; fi
        ((resized)) && continue
        if [[ $key == $'\e' ]]; then
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
            if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break; fi
            case $seq in
                '') key=Esc ;;
                '[A'|'OA') key=Up ;;
                '[B'|'OB') key=Down ;;
                '[C'|'OC') key=Right ;;
                '[D'|'OD') key=Left ;;
                *) key= ;;
            esac
        else
            case $key in
                ' ') key=Space ;;
                ''|$'\n'|$'\r') key=Enter ;;
                $'\t') key=Tab ;;
                $'\177'|$'\b') key=Backspace ;;
            esac
        fi
        pick_key_action "$key"
        case $PICK_KEY_ACTION in
            up)
                PICK_MSG=
                if ((PICK_CURSOR > 0)); then PICK_CURSOR=$((PICK_CURSOR - 1)); fi
                ;;
            down)
                PICK_MSG=
                if ((PICK_CURSOR < ${#PICK_FOCUS[@]}-1)); then PICK_CURSOR=$((PICK_CURSOR + 1)); fi
                ;;
            toggle) pick_action toggle ;;
            all) pick_action all ;;
            clear) pick_action clear ;;
            cancel) rc=1; break ;;
            back) rc=3; break ;;
            submit)
                if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break; fi
                if [[ $PICK_MODE == dependencies && ${PICK_ALLOW_EMPTY:-0} == 0 && $(pick_sel_count) == 0 ]]; then PICK_MSG="Check at least one item to submit."
                else rc=0; break; fi
                ;;
        esac
    done
    pick_cleanup_term
    PICK_SAVED_STTY=
    pick_traps_restore
    # Cancellation precedence at the final result boundary: a returning
    # caller trap may have fired as late as the cleanup above, so the
    # pending-signal check decides the outcome after restoration.
    if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; fi
    return "$rc"
}

pick_read_escape() {
    # Sets seq to the byte after Esc, or empty for a lone Esc. dd honors the
    # 0.1-second terminal timeout set up in pick_setup_term.
    # Preserve a newline follower: command substitution alone would strip
    # it and incorrectly treat Esc followed by Enter as a lone Esc.
    seq=$(dd bs=1 count=1 2>/dev/null; printf '.')
    seq=${seq%.}
}

pick_color_number() {
    case $1 in
        ''|default) printf '%s' -1 ;;
        black) printf 0 ;; red) printf 1 ;; green) printf 2 ;;
        yellow) printf 3 ;; blue) printf 4 ;; magenta) printf 5 ;;
        cyan) printf 6 ;; white) printf 7 ;;
        *) pick_err "unknown color '$1'"; return 1 ;;
    esac
}

pick_prepare_colors() {
    local focus selected group colors
    PICK_STYLE_FOCUS=; PICK_STYLE_SELECTED=; PICK_STYLE_GROUP=
    PICK_STYLE_TITLE=; PICK_STYLE_HINT=; PICK_STYLE_RESET=
    focus=$(pick_color_number "${PICK_FOCUS_COLOR-}") || return 1
    selected=$(pick_color_number "${PICK_SELECTED_COLOR-}") || return 1
    group=$(pick_color_number "${PICK_GROUP_COLOR-}") || return 1
    [[ -z ${NO_COLOR-} && ${TERM-} != dumb ]] || return 0
    PICK_STYLE_RESET=$(tput sgr0 2>/dev/null) || { PICK_STYLE_RESET=; return 0; }
    [[ -n $PICK_STYLE_RESET ]] || return 0
    # The title stands out and the key hint recedes without any color.
    PICK_STYLE_TITLE=$(tput bold 2>/dev/null || true)
    PICK_STYLE_HINT=$(tput dim 2>/dev/null || true)
    ((focus >= 0 || selected >= 0 || group >= 0)) || return 0
    colors=$(tput colors 2>/dev/null) || return 0
    case $colors in ''|*[!0-9]*) return 0 ;; esac
    ((colors >= 8)) || return 0
    if ((focus >= 0)); then PICK_STYLE_FOCUS=$(tput setaf "$focus" 2>/dev/null || true); fi
    if ((selected >= 0)); then PICK_STYLE_SELECTED=$(tput setaf "$selected" 2>/dev/null || true); fi
    if ((group >= 0)); then PICK_STYLE_GROUP=$(tput setaf "$group" 2>/dev/null || true); fi
    return 0
}

pick_select() {
    local PICK_MODE=single PICK_INITIAL_INDEX=-1 index
    pick_validate_items || return 2
    if [[ ${PICK_VALUE+x} ]]; then
        index=$(pick_find_id "$PICK_VALUE")
        if ((index < 0)); then
            pick_err "unknown initial ID '$PICK_VALUE'"
            return 2
        fi
        if [[ ${PICK_VALID[index]:-1} == 0 ]]; then
            pick_err "initial ID '$PICK_VALUE' is not available"
            return 2
        fi
        PICK_INITIAL_INDEX=$index
    fi
    local rc=0
    pick_interact || rc=$?
    if ((rc == 0 || rc == 3)); then
        index=${PICK_FOCUS[PICK_CURSOR]}
        PICK_VALUE=${PICK_ID[index]-${PICK_LABEL[index]}}
    fi
    return "$rc"
}

pick_multiselect() {
    local PICK_MODE=multi i
    pick_validate_items || return 2
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        if [[ ${PICK_VALID[i]:-1} != 0 && ${PICK_STATE[i]:-0} == 1 ]]; then PICK_STATE[i]=1
        else PICK_STATE[i]=0; fi
    done
    pick_interact
}

pick_bind_keys() {
    local action=$1 key i found help=
    local LC_ALL=C
    shift
    for key in "$@"; do
        [[ $key != ' ' ]] || key=Space
        case $key in
            Up|Down|Left|Right|Space|Enter|Esc|Tab|Backspace|[[:graph:]]) ;;
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

pick_dependencies() {
    local PICK_MODE=dependencies PICK_ALLOW_EMPTY=1 PICK_ALLOW_BACK=1 PICK_PRESERVE_INITIAL=1 i
    local -a initial=("${PICK_STATE[@]}")
    case ${PICK_DEPENDENCY_MODE:-cascade} in
        cascade|lock) ;;
        *) pick_err "unknown dependency mode '${PICK_DEPENDENCY_MODE}'"; return 2 ;;
    esac
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        PICK_DIRECT[i]=0
        PICK_STATE[i]=0
        PICK_AUTO[i]=0
    done
    # Validate the graph without changing the caller's preselected baseline.
    pick_close || return 2
    for ((i=0; i<${#PICK_LABEL[@]}; i++)); do
        if [[ ${PICK_VALID[i]:-1} != 0 && ${initial[i]:-0} == 1 ]]; then
            PICK_DIRECT[i]=1; PICK_STATE[i]=1
        fi
    done
    pick_interact
}
