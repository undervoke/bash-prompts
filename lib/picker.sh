# bash-prompts: grouped dependency-aware checkbox selector for Bash 3.2.
#
# SPDX-License-Identifier: MIT
#
# Public API (all other pick_* / PICK_* names are internal):
#
#   Input arrays (caller fills, parallel, dense, zero-based):
#     PICK_LABEL[i]  display name; labels must be unique.
#     PICK_GROUP[i]  group label shown on every row and header; caller-defined.
#     PICK_DEPS[i]   comma-separated dependency labels (may be empty).
#     PICK_VALID[i]  1 to include, 0 to exclude (unset counts as included).
#
#   State arrays (library owns during pick_close / pick_run):
#     PICK_DIRECT[i] explicitly chosen rows.
#     PICK_STATE[i]  selected rows: direct plus required dependencies.
#     PICK_AUTO[i]   auto-added rows retained until explicitly unchecked.
#
#   Entry points:
#     pick_close      resolve and expand PICK_DIRECT into PICK_STATE.
#                     Two-phase: validates the whole graph first, so a
#                     failure leaves PICK_STATE untouched. Recomputes the
#                     selection strictly from PICK_DIRECT plus retained
#                     PICK_AUTO rows. Prints "pick: ..." to stderr and
#                     returns 1 on structural errors (duplicate label,
#                     unknown or unavailable dependency, empty dependency
#                     entry, dependency ordered at or after its dependent).
#     pick_run        interactive checkbox UI; starts with nothing checked.
#                     Validates the graph through pick_close before touching
#                     the terminal. Returns 0 with PICK_DIRECT/PICK_STATE/
#                     PICK_AUTO set, 1 when cancelled or invalid. The caller
#                     confirms the printed plan before acting on the result.
#     pick_locked_by <idx>
#                     print comma-separated labels of selected rows that
#                     require row <idx> (empty output when none).
#     pick_find_label <label>
#                     print the row index, or -1 when absent.
#     pick_split_csv <csv>
#                     split into PICK_SPLIT, trimmed; empty entries kept.
#
#   PICK_VERSION holds the library version.
#
# The picker draws from these arrays only and never probes the outside
# world, so drawing costs nothing beyond terminal output. Bash 3.2 safe:
# indexed arrays only, no associative arrays, no mapfile, no =~, no nameref
# (callers pass data through the fixed PICK_* names above).
PICK_VERSION="0.1.0"

PICK_LABEL=()
PICK_GROUP=()
PICK_DEPS=()
PICK_VALID=()
PICK_DIRECT=()
PICK_STATE=()
PICK_AUTO=()
PICK_SPLIT=()
PICK_FOCUS=()
PICK_FLOCK=()
PICK_CURSOR=0
PICK_OFFSET=0
PICK_MSG=
PICK_GROUPS=()
PICK_FOCUS_ROW=()
PICK_CLEAR=0
PICK_SMCUP=0
PICK_CIVIS=0
PICK_CUP=
PICK_EL=
PICK_PREV_COUNT=0
PICK_PREV_ROWS=
PICK_PREV_COLS=
PICK_FRAME=()
PICK_ROW=
PICK_SAVED_INT=
PICK_SAVED_TERM=
PICK_TRAPS_ARMED=0
PICK_SNAP_DIRECT=()
PICK_SNAP_STATE=()
PICK_SNAP_AUTO=()
PICK_GOT_SIGNAL=
PICK_QUIET=0
PICK_DEPNAMES=
PICK_GTOT=0
PICK_GSEL=0

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
    # $1 = comma-separated value; sets PICK_SPLIT, trimmed per entry.
    PICK_SPLIT=()
    local csv=$1 i part
    [[ -n $csv ]] || return 0
    IFS=',' read -r -a PICK_SPLIT <<< "$csv"
    for ((i=0; i<${#PICK_SPLIT[@]}; i++)); do
        part=$(pick_trim "${PICK_SPLIT[i]}")
        PICK_SPLIT[i]=$part
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
    # Expand PICK_DIRECT into PICK_STATE through the dependency closure.
    # Retained PICK_AUTO rows stay selected. The closure is atomic: the
    # entry triples are snapshotted first, and any failure restores the
    # snapshot instead of returning a successful incomplete plan.
    local n i k dep j a b
    n=${#PICK_LABEL[@]}
    pick_snapshot
    for ((i=0; i<n; i++)); do
        [[ ${PICK_VALID[i]:-1} == 0 ]] && continue
        for ((a=0; a<i; a++)); do
            [[ ${PICK_LABEL[a]} == "${PICK_LABEL[i]}" ]] || continue
            pick_err "duplicate label '${PICK_LABEL[i]}'"
            return 1
        done
        pick_split_csv "${PICK_DEPS[i]:-}"
        for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
            dep=${PICK_SPLIT[k]}
            [[ -n $dep ]] || { pick_err "'${PICK_LABEL[i]}' has an empty dependency entry"; return 1; }
            j=$(pick_find_label "$dep")
            if [[ $j -lt 0 ]]; then
                pick_err "'${PICK_LABEL[i]}' requires unknown '$dep'"
                return 1
            fi
            if [[ ${PICK_VALID[j]:-1} == 0 ]]; then
                # An excluded prerequisite can never be satisfied: selecting
                # its dependent would publish a plan the executor cannot
                # fulfill, so reject it here instead of silently dropping it.
                if [[ ${PICK_DIRECT[i]:-0} == 1 ]]; then
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
            [[ ${PICK_STATE[i]:-0} == 1 && ${PICK_VALID[i]:-1} != 0 ]] || continue
            pick_split_csv "${PICK_DEPS[i]:-}"
            for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
                dep=${PICK_SPLIT[k]}
                [[ -n $dep ]] || continue
                j=$(pick_find_label "$dep")
                [[ $j -ge 0 ]] || continue
                [[ ${PICK_VALID[j]:-1} != 0 ]] || continue
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
        [[ ${PICK_STATE[i]:-0} == 1 && ${PICK_VALID[i]:-1} != 0 ]] || continue
        pick_split_csv "${PICK_DEPS[i]:-}"
        for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
            dep=${PICK_SPLIT[k]}
            [[ -n $dep ]] || continue
            j=$(pick_find_label "$dep")
            [[ $j -ge 0 ]] || continue
            if [[ ${PICK_VALID[j]:-1} == 0 ]]; then
                pick_err "'${PICK_LABEL[i]}' requires '$dep', which is not available"
                pick_restore_snap
                return 1
            fi
        done
    done
    for ((b=0; b<n; b++)); do
        [[ -n ${PICK_DIRECT[b]+set} ]] || PICK_DIRECT[b]=0
    done
    return 0
}

pick_locked_by() {
    # $1 = row index; print comma-separated labels of selected rows that
    # require it (other than itself), or nothing.
    local idx=$1 j k dep first=1 out=
    local n
    n=${#PICK_LABEL[@]}
    for ((j=0; j<n; j++)); do
        [[ $j != "$idx" && ${PICK_STATE[j]:-0} == 1 && ${PICK_VALID[j]:-1} != 0 ]] || continue
        pick_split_csv "${PICK_DEPS[j]:-}"
        for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
            if [[ ${PICK_SPLIT[k]} == "${PICK_LABEL[idx]}" ]]; then
                if ((first)); then out=${PICK_LABEL[j]}; first=0
                else out="$out, ${PICK_LABEL[j]}"; fi
                break
            fi
        done
    done
    printf '%s' "$out"
}

pick_dep_names_into() {
    # Internal: like pick_locked_by but sets PICK_DEPNAMES without a fork.
    local idx=$1 j k dep first=1
    local n
    n=${#PICK_LABEL[@]}
    PICK_DEPNAMES=
    for ((j=0; j<n; j++)); do
        [[ $j != "$idx" && ${PICK_STATE[j]:-0} == 1 && ${PICK_VALID[j]:-1} != 0 ]] || continue
        pick_split_csv "${PICK_DEPS[j]:-}"
        for ((k=0; k<${#PICK_SPLIT[@]}; k++)); do
            if [[ ${PICK_SPLIT[k]} == "${PICK_LABEL[idx]}" ]]; then
                if ((first)); then PICK_DEPNAMES=${PICK_LABEL[j]}; first=0
                else PICK_DEPNAMES="$PICK_DEPNAMES, ${PICK_LABEL[j]}"; fi
                break
            fi
        done
    done
}

pick_recalc_locks() {
    local i n
    n=${#PICK_LABEL[@]}
    for ((i=0; i<n; i++)); do PICK_FLOCK[i]=; done
    for ((i=0; i<n; i++)); do
        [[ ${PICK_STATE[i]:-0} == 1 && ${PICK_VALID[i]:-1} != 0 ]] || continue
        pick_dep_names_into "$i"
        PICK_FLOCK[i]=$PICK_DEPNAMES
    done
}

pick_build_focus() {
    # Focus order: distinct groups in first-appearance order, catalog order
    # inside each group. Also records each focus position's display row.
    local i g f seen n
    n=${#PICK_LABEL[@]}
    PICK_FOCUS=()
    PICK_GROUPS=()
    for ((i=0; i<n; i++)); do
        [[ ${PICK_VALID[i]:-1} == 0 ]] && continue
        g=${PICK_GROUP[i]}
        seen=0
        for ((f=0; f<${#PICK_GROUPS[@]}; f++)); do
            [[ ${PICK_GROUPS[f]} == "$g" ]] && { seen=1; break; }
        done
        ((seen)) || PICK_GROUPS[${#PICK_GROUPS[@]}]=$g
    done
    local gi
    for ((gi=0; gi<${#PICK_GROUPS[@]}; gi++)); do
        for ((i=0; i<n; i++)); do
            [[ ${PICK_VALID[i]:-1} == 0 ]] && continue
            [[ ${PICK_GROUP[i]} == "${PICK_GROUPS[gi]}" ]] || continue
            PICK_FOCUS[${#PICK_FOCUS[@]}]=$i
        done
    done
    PICK_FOCUS_ROW=()
    local k drow=0
    for ((k=0; k<${#PICK_FOCUS[@]}; k++)); do
        if ((k == 0)); then drow=1
        else
            if [[ ${PICK_GROUP[${PICK_FOCUS[k]}]} != "${PICK_GROUP[${PICK_FOCUS[k-1]}]}" ]]; then
                drow=$((drow + 2))
            else
                drow=$((drow + 1))
            fi
        fi
        PICK_FOCUS_ROW[k]=$drow
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
        [[ ${PICK_GROUP[i]} == "$g" ]] || continue
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
    # Capability checks stay silent; the sequences below go to the terminal.
    if tput clear >/dev/null 2>&1; then PICK_CLEAR=1; else PICK_CLEAR=0; fi
    if tput smcup >/dev/null 2>&1; then PICK_SMCUP=1; else PICK_SMCUP=0; fi
    if tput civis >/dev/null 2>&1; then PICK_CIVIS=1; else PICK_CIVIS=0; fi
    # Cache the paint sequences once; per-frame emission then needs no
    # further tput invocations. An empty result means unsupported.
    PICK_CUP=$(tput cup 0 0 2>/dev/null || true)
    PICK_EL=$(tput el 2>/dev/null || true)
    if ((PICK_CIVIS)); then tput civis || true; fi
    if ((PICK_SMCUP)); then tput smcup || true; else pick_clear_screen; fi
    return 0
}

pick_cleanup_term() {
    if ((PICK_SMCUP)); then tput rmcup || true; fi
    if ((PICK_CIVIS)); then tput cnorm || true; fi
    PICK_SMCUP=0
    PICK_CIVIS=0
}

pick_clear_screen() {
    # Best effort: tput genuinely fails on unsupported terminals, and a
    # failed clear must never break selection or cleanup. Refuses when a
    # pending interrupt already restored the screen, so no caller can
    # clear over it by missing its own check.
    [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
    if ((PICK_CLEAR)); then tput clear || true; else printf '\n\n\n'; fi
}

pick_title() {
    # One-line header with per-group selected/total counts.
    local gi g out=
    for ((gi=0; gi<${#PICK_GROUPS[@]}; gi++)); do
        g=${PICK_GROUPS[gi]}
        pick_group_counts "$g"
        [[ -n $out ]] && out="$out  "
        out="$out$g [$PICK_GSEL/$PICK_GTOT]"
    done
    printf 'Select items (space toggles; locked rows show why)  %s\n' "$out"
}

pick_render() {
    # A pending interrupt means the terminal is already restored; build
    # nothing so no further frame is composed for a dead screen.
    [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
    local rows cols h d
    rows=$(tput lines 2>/dev/null || echo 24)
    cols=$(tput cols 2>/dev/null || echo 80)
    case $rows in ''|*[!0-9]*) rows=24 ;; esac
    case $cols in ''|*[!0-9]*) cols=80 ;; esac
    h=$((rows - 6))
    ((h < 3)) && h=3
    local drow
    drow=${PICK_FOCUS_ROW[PICK_CURSOR]:-0}
    ((drow < PICK_OFFSET)) && PICK_OFFSET=$drow
    ((drow >= PICK_OFFSET + h)) && PICK_OFFSET=$((drow - h + 1))
    PICK_FRAME=()
    local title
    title=$(pick_title)
    PICK_FRAME[${#PICK_FRAME[@]}]="$title"
    for ((d=PICK_OFFSET; d<PICK_OFFSET+h; d++)); do
        pick_render_row "$d"
        PICK_FRAME[${#PICK_FRAME[@]}]="$PICK_ROW"
    done
    PICK_FRAME[${#PICK_FRAME[@]}]="up/down j/k move - space toggle - a check all - n clear directs - enter done - q cancel"
    if [[ -n $PICK_MSG ]]; then PICK_FRAME[${#PICK_FRAME[@]}]="$PICK_MSG"
    else PICK_FRAME[${#PICK_FRAME[@]}]="Enter shows the checked plan for confirmation; nothing is installed by selecting."; fi
    if [[ $rows != "$PICK_PREV_ROWS" || $cols != "$PICK_PREV_COLS" ]]; then
        # A handler may have run during the tput probes above; the refusal
        # lives in pick_clear_screen itself so this clear cannot be missed.
        PICK_PREV_ROWS=$rows
        PICK_PREV_COLS=$cols
        pick_clear_screen || return 1
        PICK_PREV_COUNT=0
    fi
    # Propagate the refusal: assigning PICK_PREV_COUNT afterwards would mask
    # a nonzero return into a successful render.
    pick_emit_frame "$cols" || return 1
    PICK_PREV_COUNT=${#PICK_FRAME[@]}
}

pick_emit_frame() {
    # $1 = width. The whole frame goes out in a single write from the home
    # position, with stale tails and leftover rows erased as part of the
    # same payload, so ordinary keys emit no clear and no per-line command.
    # The painting boundary: never emit onto a screen the signal handler
    # already restored. Payload construction above writes nothing; each
    # actual output site rechecks the flag, which shrinks post-cleanup
    # painting to the check-to-write gap. A signal inside that gap, or
    # truly mid-write, can still leave one partial or full write — that
    # bounded residue is inherent to async signals. No second write
    # follows a refusal, because every refusal breaks the main loop.
    [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
    local cols=$1 i line n r out
    n=${#PICK_FRAME[@]}
    if [[ -n $PICK_CUP && -n $PICK_EL ]]; then
        out=$PICK_CUP
        for ((i=0; i<n; i++)); do
            line=${PICK_FRAME[i]}
            if ((${#line} > cols)); then line=${line:0:$cols}; fi
            out+="$line$PICK_EL"
            if ((i < n-1)); then out+=$'\n'; fi
        done
        if ((PICK_PREV_COUNT > n)); then
            for ((r=n; r<PICK_PREV_COUNT; r++)); do out+=$'\n'"$PICK_EL"; done
        fi
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
        printf '%s' "$out"
    else
        # Same interrupted-output handling as the fast path: batch into one
        # write with a check immediately before it, instead of emitting
        # line by line past a single early check.
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
        out=
        for ((i=0; i<n; i++)); do
            line=${PICK_FRAME[i]}
            if ((${#line} > cols)); then line=${line:0:$cols}; fi
            out+="$line"$'\n'
        done
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
        pick_clear_screen || return 1
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 1
        printf '%s' "$out"
    fi
}

pick_render_row() {
    # $1 = display row; sets PICK_ROW (empty past the end). Every item row
    # carries its group tag so the group stays visible once headers scroll
    # out.
    local d=$1
    local gi k idx g base
    base=0
    for ((gi=0; gi<${#PICK_GROUPS[@]}; gi++)); do
        g=${PICK_GROUPS[gi]}
        if ((d == base)); then
            PICK_ROW="-- $g --"
            return 0
        fi
        k=0
        for ((k=0; k<${#PICK_FOCUS[@]}; k++)); do
            [[ ${PICK_GROUP[${PICK_FOCUS[k]}]} == "$g" ]] || continue
            base=$((base + 1))
            if ((d == base)); then
                pick_item_line "${PICK_FOCUS[k]}" "$k"
                return 0
            fi
        done
        base=$((base + 1))
    done
    PICK_ROW=
}

pick_item_line() {
    # $1 = row index, $2 = focus position. Sets PICK_ROW.
    # NOTE: name is assigned separately because an array subscript in the
    # same local command would not see the just-assigned idx.
    local idx=$1 pos=$2 mark="[ ]" suffix= kind= name=
    name=${PICK_LABEL[idx]}
    if [[ ${PICK_STATE[idx]:-0} == 1 ]]; then
        mark="[x]"
        if [[ ${PICK_DIRECT[idx]:-0} == 1 ]]; then kind=direct; else kind="auto"; fi
        suffix="($kind"
        [[ -n ${PICK_DEPS[idx]:-} ]] && suffix="$suffix; requires: ${PICK_DEPS[idx]}"
        [[ -n ${PICK_FLOCK[idx]:-} ]] && suffix="$suffix; locked: ${PICK_FLOCK[idx]}"
        suffix="$suffix)"
    else
        if [[ -n ${PICK_DEPS[idx]:-} ]]; then suffix="(requires: ${PICK_DEPS[idx]})"; else suffix=; fi
    fi
    local group_tag="[${PICK_GROUP[idx]}]"
    if ((pos == PICK_CURSOR)); then mark=">$mark"; else mark=" $mark"; fi
    if [[ -n $suffix ]]; then PICK_ROW="$mark $group_tag $name $suffix"
    else PICK_ROW="$mark $group_tag $name"; fi
}

pick_toggle() {
    local idx depnames
    idx=${PICK_FOCUS[PICK_CURSOR]}
    depnames=$(pick_locked_by "$idx")
    if [[ ${PICK_STATE[idx]:-0} == 1 ]]; then
        if [[ -n $depnames ]]; then PICK_MSG="Locked: required by $depnames"; return 0; fi
        PICK_STATE[idx]=0
        PICK_DIRECT[idx]=0
        # Explicit deselection clears retained history so a later clear of
        # directs cannot resurrect this item; a live dependency re-adds it.
        PICK_AUTO[idx]=0
        PICK_MSG=
        pick_recalc_locks
        return 0
    fi
    PICK_DIRECT[idx]=1
    PICK_STATE[idx]=1
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
        [[ ${PICK_VALID[i]:-1} != 0 ]] || continue
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
    PICK_MSG="Checked every valid item."
}

pick_clear_directs() {
    # Only currently retained auto selections stay checked; anything the
    # user explicitly unchecked stays unchecked. Runs the same closure so
    # the result is always a satisfied plan: retained rows pull back the
    # prerequisites they need as auto selections.
    local i n
    n=${#PICK_LABEL[@]}
    local -a save_direct save_state save_auto
    for ((i=0; i<n; i++)); do
        save_direct[i]=${PICK_DIRECT[i]:-0}
        save_state[i]=${PICK_STATE[i]:-0}
        save_auto[i]=${PICK_AUTO[i]:-0}
    done
    for ((i=0; i<n; i++)); do PICK_DIRECT[i]=0; done
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
    PICK_MSG="Cleared direct choices; retained auto-checked rows stay until unchecked."
}

pick_sel_count() {
    local i n c=0
    n=${#PICK_LABEL[@]}
    for ((i=0; i<n; i++)); do [[ ${PICK_STATE[i]:-0} == 1 ]] && c=$((c + 1)); done
    printf '%s' "$c"
}

pick_run() {
    # Starts with no direct selections; returns 0 with PICK_DIRECT,
    # PICK_STATE and PICK_AUTO set, or 1 when cancelled. The caller
    # confirms the printed plan before acting on the result.
    local i key seq rc=1 start
    local n
    n=${#PICK_LABEL[@]}
    for ((i=0; i<n; i++)); do PICK_DIRECT[i]=0; PICK_STATE[i]=0; PICK_AUTO[i]=0; done
    pick_build_focus
    ((${#PICK_FOCUS[@]})) || { pick_err "no selectable items"; return 1; }
    # Validate through the same closure contract as noninteractive
    # selection before accepting any plan; an invalid graph fails here,
    # before the terminal is touched.
    pick_close || return 1
    PICK_CURSOR=0
    PICK_OFFSET=0
    PICK_MSG=
    PICK_GOT_SIGNAL=
    PICK_PREV_COUNT=0
    PICK_PREV_ROWS=
    PICK_PREV_COLS=
    pick_setup_term || { pick_err "interactive selection needs a terminal; use pick_close for explicit selection"; return 1; }
    pick_traps_save
    trap 'pick_on_int' INT
    trap 'pick_on_term' TERM
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
        while true; do
            start=$SECONDS
            if IFS= read -rsn1 -t 1 key; then break; fi
            if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break 2; fi
            if (( SECONDS - start >= 1 )); then continue; fi
            rc=1; break 2
        done
        # A key that arrived after a returning handler fired must not be
        # dispatched: the terminal is already restored, so cancel instead
        # of acting on stale input.
        if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break; fi
        if [[ $key == $'\e' ]]; then
            seq=
            IFS= read -rsn2 -t 1 seq || { rc=1; break; }
            if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break; fi
            case $seq in
                '[A'|'OA') PICK_MSG=; ((PICK_CURSOR > 0)) && PICK_CURSOR=$((PICK_CURSOR-1)) ;;
                '[B'|'OB') PICK_MSG=; ((PICK_CURSOR < ${#PICK_FOCUS[@]}-1)) && PICK_CURSOR=$((PICK_CURSOR+1)) ;;
                *) PICK_MSG="Unknown key." ;;
            esac
        else
            case $key in
                ' ') pick_toggle ;;
                j) PICK_MSG=; ((PICK_CURSOR < ${#PICK_FOCUS[@]}-1)) && PICK_CURSOR=$((PICK_CURSOR+1)) ;;
                k) PICK_MSG=; ((PICK_CURSOR > 0)) && PICK_CURSOR=$((PICK_CURSOR-1)) ;;
                a) pick_check_all ;;
                n) pick_clear_directs ;;
                q|Q) rc=1; break ;;
                ''|$'\n'|$'\r')
                    if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; break; fi
                    if [[ $(pick_sel_count) == 0 ]]; then PICK_MSG="Nothing selected."
                    else rc=0; break; fi ;;
                *) ;;
            esac
        fi
    done
    pick_cleanup_term
    pick_traps_restore
    # Cancellation precedence at the final result boundary: a returning
    # caller trap may have fired as late as the cleanup above, so the
    # pending-signal check decides the outcome after restoration.
    if [[ -n ${PICK_GOT_SIGNAL:-} ]]; then rc=1; fi
    return "$rc"
}
