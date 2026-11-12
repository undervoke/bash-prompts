#!/bin/bash
# Consumer-side composition: step order, saved answers, and navigation live here.
# Enter moves forward, Left/Backspace goes back, and the review lists each
# answer so it can be changed directly.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/picker.sh" || exit 2

component_ids=(editor formatter preview)
component_labels=(Editor Formatter Preview)
component_state=(1 0 0)
format_ids=(markdown html pdf)
format_labels=(Markdown HTML PDF)
format_state=(1 0 0)

PICK_FOCUS_COLOR=cyan
PICK_SELECTED_COLOR=green
PICK_GROUP_COLOR=blue

# $1 = labels array name, $2 = state array name; prints checked labels.
checked_labels() {
    local labels="$1[@]" states="$2[@]" i out=
    local -a l=("${!labels}") s=("${!states}")
    for ((i=0; i<${#l[@]}; i++)); do
        [[ ${s[i]} == 1 ]] || continue
        out="${out:+$out, }${l[i]}"
    done
    printf '%s' "${out:-none}"
}

# Runs one checkbox step, saving its answers on Enter and on Back.
ask_step() {
    local rc=0
    case $1 in
        1)
            PICK_PROMPT='Step 1 of 3: Which components?'
            PICK_ID=("${component_ids[@]}")
            PICK_LABEL=("${component_labels[@]}")
            PICK_STATE=("${component_state[@]}")
            PICK_KEYS_BACK=()
            ;;
        2)
            PICK_PROMPT='Step 2 of 3: Which output formats?'
            PICK_ID=("${format_ids[@]}")
            PICK_LABEL=("${format_labels[@]}")
            PICK_STATE=("${format_state[@]}")
            PICK_KEYS_BACK=(Left Backspace)
            ;;
    esac
    PICK_GROUP=()
    pick_multiselect || rc=$?
    if ((rc == 0 || rc == 3)); then
        case $1 in
            1) component_state=("${PICK_STATE[@]}") ;;
            2) format_state=("${PICK_STATE[@]}") ;;
        esac
    fi
    return "$rc"
}

# A step opened from the review returns there on Enter; Back leaves that
# edit and resumes ordinary step-by-step navigation.
step=1
return_to_review=0
while true; do
    if ((step < 3)); then
        rc=0
        ask_step "$step" || rc=$?
        case $rc in
            0)
                if ((return_to_review)); then step=3; else step=$((step + 1)); fi
                return_to_review=0
                ;;
            3) step=$((step - 1)); return_to_review=0 ;;
            1) printf 'Cancelled.\n'; exit 1 ;;
            *) printf 'Prompt failed (status %s).\n' "$rc" >&2; exit "$rc" ;;
        esac
        continue
    fi

    PICK_PROMPT='Step 3 of 3: Review. Choose an answer to change it.'
    PICK_ID=(components formats finish)
    PICK_LABEL=(
        "Components:     $(checked_labels component_labels component_state)"
        "Output formats: $(checked_labels format_labels format_state)"
        'Finish'
    )
    PICK_GROUP=('' '' '')
    PICK_VALUE=finish
    PICK_KEYS_BACK=(Left Backspace)
    rc=0
    pick_select || rc=$?
    case $rc in
        0)
            case $PICK_VALUE in
                components) step=1; return_to_review=1 ;;
                formats) step=2; return_to_review=1 ;;
                finish) break ;;
            esac
            ;;
        3) step=2 ;;
        1) printf 'Cancelled.\n'; exit 1 ;;
        *) printf 'Prompt failed (status %s).\n' "$rc" >&2; exit "$rc" ;;
    esac
done

printf 'Components:     %s\n' "$(checked_labels component_labels component_state)"
printf 'Output formats: %s\n' "$(checked_labels format_labels format_state)"
