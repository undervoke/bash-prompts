#!/bin/bash
# Tabs that hold sub-tabs: the Keys tab opens into a row of its own, and
# headers still group the rows of a sub-tab.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P) || exit 1
source "$ROOT/lib/bash-prompts.sh" || exit 2

PICK_PROMPT='Settings'
PICK_TABS=1
pick_group system 'System'
pick_group appearance 'Appearance' system
pick_group power 'Power' system
pick_group dock 'Dock' system
pick_group keys 'Keys'
pick_group shared 'Shared actions' keys
pick_group clipboard 'Clipboard' shared
pick_group edit 'Edit' shared
pick_group find 'Find' shared
pick_group desktop 'Desktop' keys
pick_group windows 'Windows' desktop
pick_group spaces 'Spaces' desktop
pick_group terminal 'Terminal' keys
pick_group term-tabs 'Tabs' terminal
pick_group panes 'Panes' terminal
pick_group editor 'Editor' keys
pick_group navigation 'Navigation' editor
pick_group editing 'Editing' editor
pick_group view 'View' editor
pick_group browser 'Browser' keys
pick_group browser-tabs 'Tabs' browser
pick_group page 'Page' browser
pick_group apps 'Apps'
pick_group editors 'Editors' apps
pick_group browsers 'Browsers' apps
pick_group tools 'Tools' apps
pick_group submit 'Submit'
PICK_SUBTABS=(keys)
PICK_SUBMIT_TAB=submit
PICK_CONFIRM_PROMPT='Apply these settings?'
PICK_KEYS_TOGGLE=(Space Enter)
PICK_KEYS_SUBMIT=()
PICK_TAB=desktop

PICK_ID=() PICK_LABEL=() PICK_GROUP=() PICK_VALUES=() PICK_OFF=()
row() { PICK_ID+=("$1"); PICK_LABEL+=("$2"); PICK_GROUP+=("$3"); PICK_VALUES+=("$4"); PICK_OFF+=("$5"); }
key() { row "$1" "$2" "$3" "$4, off" off; }
app() { row "$1" "$2" "$3" 'installed, remove' remove; }

row dark 'Dark mode' appearance 'on, off, auto' ''
row accent 'Accent color' appearance 'blue, graphite, multicolor' ''
row motion 'Reduce motion' appearance 'off, on' ''
row scroll 'Show scroll bars' appearance 'auto, always, scrolling' ''
row sleep 'Sleep rules' power 'custom, laptop, server' ''
row display-sleep 'Display sleep' power '10 min, 5 min, never' ''
row low-power 'Low power mode' power 'battery, always, never' ''
row autohide 'Hide the Dock' dock 'on, off' ''
row dock-side 'Dock position' dock 'bottom, left, right' ''
row magnify 'Magnification' dock 'off, on' ''

key copy 'Copy' clipboard 'Cmd+C'
key paste 'Paste' clipboard 'Cmd+V'
key cut 'Cut' clipboard 'Cmd+X'
key paste-plain 'Paste as plain text' clipboard 'Cmd+Shift+V'
key undo 'Undo' edit 'Cmd+Z'
key redo 'Redo' edit 'Cmd+Shift+Z'
key select-all 'Select all' edit 'Cmd+A'
key find 'Find' find 'Cmd+F'
key find-next 'Find next' find 'Cmd+G'
key find-prev 'Find previous' find 'Cmd+Shift+G'

key next-window 'Next window' windows 'Cmd+`'
key close-window 'Close window' windows 'Cmd+W'
key minimize 'Minimize' windows 'Cmd+M'
key fullscreen 'Full screen' windows 'Ctrl+Cmd+F'
key tile-left 'Tile left' windows 'Ctrl+Opt+Left'
key tile-right 'Tile right' windows 'Ctrl+Opt+Right'
key next-space 'Next space' spaces 'Ctrl+Right'
key prev-space 'Previous space' spaces 'Ctrl+Left'
key mission 'Mission Control' spaces 'Ctrl+Up'
key show-desktop 'Show desktop' spaces 'F11'

key term-new-tab 'New tab' term-tabs 'Cmd+T'
key term-close-tab 'Close tab' term-tabs 'Cmd+W'
key term-next-tab 'Next tab' term-tabs 'Cmd+Shift+]'
key term-prev-tab 'Previous tab' term-tabs 'Cmd+Shift+['
key split-right 'Split right' panes 'Cmd+D'
key split-down 'Split down' panes 'Cmd+Shift+D'
key next-pane 'Next pane' panes 'Cmd+]'
key prev-pane 'Previous pane' panes 'Cmd+['
key zoom-pane 'Zoom pane' panes 'Cmd+Shift+Enter'
key clear 'Clear buffer' panes 'Cmd+K'

key palette 'Command palette' navigation 'Cmd+Shift+P'
key goto-file 'Go to file' navigation 'Cmd+P'
key goto-symbol 'Go to symbol' navigation 'Cmd+Shift+O'
key go-back 'Go back' navigation 'Ctrl+-'
key duplicate 'Duplicate line' editing 'Opt+Shift+Down'
key line-up 'Move line up' editing 'Opt+Up'
key line-down 'Move line down' editing 'Opt+Down'
key comment 'Toggle comment' editing 'Cmd+/'
key sidebar 'Toggle sidebar' view 'Cmd+B'
key panel 'Toggle panel' view 'Cmd+J'

key new-tab 'New tab' browser-tabs 'Cmd+T'
key reopen 'Reopen closed tab' browser-tabs 'Cmd+Shift+T'
key next-tab 'Next tab' browser-tabs 'Ctrl+Tab'
key prev-tab 'Previous tab' browser-tabs 'Ctrl+Shift+Tab'
key address 'Focus address bar' browser-tabs 'Cmd+L'
key reload 'Reload' page 'Cmd+R'
key find-page 'Find in page' page 'Cmd+F'
key zoom-in 'Zoom in' page 'Cmd+='
key zoom-out 'Zoom out' page 'Cmd+-'
key devtools 'Developer tools' page 'Cmd+Opt+I'

app notes 'Notes' editors
app vscode 'VS Code' editors
app zed 'Zed' editors
app chrome 'Chrome' browsers
app firefox 'Firefox' browsers
app safari-tp 'Safari Technology Preview' browsers
app iterm 'iTerm2' tools
app rectangle 'Rectangle' tools
app raycast 'Raycast' tools
app password '1Password' tools

if pick_choices; then
    printf '%s (last shown: %s)\n' "$PICK_PROMPT" "$PICK_TAB"
    for ((i=0; i<${#PICK_ID[@]}; i++)); do
        [[ ${PICK_RESULT[i]} != "${PICK_CURRENT[i]}" ]] || continue
        printf '  %s: %s -> %s\n' "${PICK_ID[i]}" "${PICK_CURRENT[i]}" "${PICK_RESULT[i]}"
    done
else
    rc=$?
    if [[ $rc == 1 ]]; then printf 'Cancelled.\n'
    else printf 'Prompt failed (status %s).\n' "$rc" >&2; fi
    exit "$rc"
fi
