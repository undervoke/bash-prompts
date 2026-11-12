#!/bin/bash
# Consumer-side composition: step order, saved answers, and navigation live here.
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

wizard_summary() {
    local i
    printf '\nStep 3/3: Review\nComponents:\n'
    for ((i=0; i<${#component_ids[@]}; i++)); do
        [[ ${component_state[i]} == 1 ]] || continue
        printf '  %s -> %s\n' "${component_ids[i]}" "${component_labels[i]}"
    done
    printf 'Output formats:\n'
    for ((i=0; i<${#format_ids[@]}; i++)); do
        [[ ${format_state[i]} == 1 ]] || continue
        printf '  %s -> %s\n' "${format_ids[i]}" "${format_labels[i]}"
    done
}

wizard_step=1
while true; do
    if ((wizard_step < 3)); then
        case $wizard_step in
            1)
                PICK_ID=("${component_ids[@]}")
                PICK_LABEL=("${component_labels[@]}")
                PICK_GROUP=('Step 1/3: Components' 'Step 1/3: Components' 'Step 1/3: Components')
                PICK_STATE=("${component_state[@]}")
                ;;
            2)
                PICK_ID=("${format_ids[@]}")
                PICK_LABEL=("${format_labels[@]}")
                PICK_GROUP=('Step 2/3: Output formats' 'Step 2/3: Output formats' 'Step 2/3: Output formats')
                PICK_STATE=("${format_state[@]}")
                ;;
        esac
        if pick_multiselect; then
            case $wizard_step in
                1) component_state=("${PICK_STATE[@]}") ;;
                2) format_state=("${PICK_STATE[@]}") ;;
            esac
        else
            rc=$?
            if [[ $rc == 1 ]]; then printf 'Wizard cancelled.\n'
            else printf 'Prompt failed (status %s).\n' "$rc" >&2; fi
            exit "$rc"
        fi
    else
        wizard_summary
    fi

    # Navigation follows a submitted prompt; cancelled prompts never save answers.
    while true; do
        if ((wizard_step < 3)); then
            printf '\nStep %s/3 saved. [n/Enter] Next  [e] Edit' "$wizard_step"
        else
            printf '\n[f] Finish'
        fi
        if ((wizard_step > 1)); then printf '  [b] Back'; fi
        printf '  [q] Cancel > '
        IFS= read -r action || { printf '\nWizard cancelled.\n'; exit 1; }
        case $action in
            n|N|'')
                if ((wizard_step < 3)); then wizard_step=$((wizard_step + 1)); break; fi
                ;;
            b|B)
                if ((wizard_step > 1)); then wizard_step=$((wizard_step - 1)); break; fi
                ;;
            e|E)
                if ((wizard_step < 3)); then break; fi
                ;;
            f|F)
                if ((wizard_step == 3)); then
                    printf 'Wizard complete. The selections above are the result.\n'
                    exit 0
                fi
                ;;
            q|Q) printf 'Wizard cancelled.\n'; exit 1 ;;
        esac
        printf 'Choose one of the displayed navigation actions, then press Enter.\n'
    done
done
