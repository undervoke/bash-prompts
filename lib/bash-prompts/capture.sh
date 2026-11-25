# bash-prompts: the macOS window that receives one key combination.
# Function definitions only; sourced in the caller shell by lib/bash-prompts.sh.

pick_capture_usable() {
    # A window opened over SSH would appear on the remote machine's display.
    [[ $OSTYPE == darwin* && -x /usr/bin/osascript && -z ${SSH_CONNECTION-}${SSH_TTY-} ]] && ((!PICK_NO_WINDOW))
}

pick_capture() {
    # $1 = title, $2 = value Delete stands for, $3 = value of the default
    # button, $4 = row; $2 to $4 may be empty. Sets PICK_CAPTURE to key (with
    # the key in PICK_KEYBINDING_VALUE), off, default, type, or cancel; empty
    # when no window opened.
    PICK_CAPTURE=
    PICK_CAPTURE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bash-prompts.XXXXXX") || { PICK_CAPTURE_DIR=; PICK_NO_WINDOW=1; return 0; }
    if mkfifo "$PICK_CAPTURE_DIR/out" "$PICK_CAPTURE_DIR/in"; then
        # Opened for reading and writing, neither end waits for the other.
        pick_capture_talk "$@" 8<>"$PICK_CAPTURE_DIR/out" 9<>"$PICK_CAPTURE_DIR/in"
    fi
    pick_capture_stop
    # A window that did not open once would only be waited for again.
    [[ -n $PICK_CAPTURE ]] || PICK_NO_WINDOW=1
    [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 0
    # Keys pressed around the window were not meant for the prompt.
    stty min 0 time 0
    dd bs=1024 count=1 >/dev/null 2>&1
    stty min 0 time 1
}

pick_capture_talk() {
    # The window runs in the background, because Bash handles a signal only
    # between commands and between reads.
    local title=$1 off=$2 default=$3 row=$4 line start opened=0 waited=0
    {
        /usr/bin/osascript -l JavaScript -e "$(pick_capture_script)" <"$PICK_CAPTURE_DIR/in" >"$PICK_CAPTURE_DIR/out" 8>&- 9>&- &
    } 2>/dev/null
    PICK_CAPTURE_PID=$!
    [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 0
    printf '%s\n' "${title//$'\n'/ }" "$off" "$default" >&9
    while true; do
        start=$SECONDS
        if ! IFS= read -r -t 1 -u 8 line; then
            [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 0
            kill -0 "$PICK_CAPTURE_PID" 2>/dev/null || return 0
            ((opened || (waited += SECONDS - start) < 5)) || return 0
            continue
        fi
        [[ -z ${PICK_GOT_SIGNAL:-} ]] || return 0
        case $line in
            open)
                opened=1
                # Both ends are open now and need no name.
                rm -rf "$PICK_CAPTURE_DIR"
                PICK_CAPTURE_DIR=
                ;;
            'key '*)
                line=${line#key }
                if ! pick_keybinding_decode "${line% *}" "${line#* }"; then
                    printf 'no %s\n' "$PICK_KEYBINDING_ERROR" >&9
                    continue
                fi
                if ! pick_keybinding_admit "$row"; then
                    printf 'no %s\n' "${PICK_KEYBINDING_MESSAGE//$'\n'/ }" >&9
                    continue
                fi
                pick_keybinding_format "$PICK_KEYBINDING_VALUE"
                printf 'ok %s\n' "$PICK_TEXT" >&9
                PICK_CAPTURE=key
                wait "$PICK_CAPTURE_PID" 2>/dev/null
                return 0
                ;;
            none) return 0 ;;
            off|default|type|cancel)
                PICK_CAPTURE=$line
                wait "$PICK_CAPTURE_PID" 2>/dev/null
                return 0
                ;;
        esac
    done
}

pick_capture_stop() {
    # Also run when a signal ends the prompt.
    if [[ -n $PICK_CAPTURE_PID ]]; then
        kill "$PICK_CAPTURE_PID" 2>/dev/null
        wait "$PICK_CAPTURE_PID" 2>/dev/null
    fi
    PICK_CAPTURE_PID=
    if [[ -n $PICK_CAPTURE_DIR ]]; then rm -rf "$PICK_CAPTURE_DIR"; fi
    PICK_CAPTURE_DIR=
}

pick_capture_script() {
    # Reads the title and the off and default values, one per line, then one
    # reply per key; writes the words pick_capture_talk reads. It names no
    # keys and judges none of them: typed keys go through the same rules.
    cat <<'SCRIPT'
ObjC.import('AppKit');
ObjC.import('stdlib');
ObjC.bindFunction('getppid', ['int', []]);
ObjC.bindFunction('CGEventSourceKeyState', ['bool', ['int', 'unsigned short']]);

const SHIFT = 0x20000, CTRL = 0x40000, OPTION = 0x80000, CMD = 0x100000, GLOBE = 0x800000;
const ESC = 53, TAB = 48, DELETE = 51, FORWARD_DELETE = 117;
const input = $.NSFileHandle.fileHandleWithStandardInput;
const output = $.NSFileHandle.fileHandleWithStandardOutput;
const parent = $.getppid();
let pending = '';

function say(line) {
    output.writeData($(line + '\n').dataUsingEncoding($.NSUTF8StringEncoding));
}

function hear() {
    while (!pending.includes('\n')) {
        const data = input.availableData;
        if (Number(data.length) === 0) $.exit(0);
        pending += $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js;
    }
    const at = pending.indexOf('\n'), line = pending.slice(0, at);
    pending = pending.slice(at + 1);
    return line;
}

// System hotkeys reach the window as keys while they are off. This setting
// belongs to the process and ends with it; without it they stay with macOS.
let hotkeys = () => {};
try {
    ObjC.bindFunction('CGSMainConnectionID', ['int', []]);
    ObjC.bindFunction('CGSSetGlobalHotKeyOperatingMode', ['int', ['int', 'int']]);
    const connection = $.CGSMainConnectionID();
    hotkeys = on => { $.CGSSetGlobalHotKeyOperatingMode(connection, on ? 0 : 1); };
} catch (error) {}

const title = hear(), offValue = hear(), defaultValue = hear();
const app = $.NSApplication.sharedApplication;
app.setActivationPolicy($.NSApplicationActivationPolicyAccessory);
app.finishLaunching;

const WIDTH = 420, HEIGHT = 148;
const win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(
    $.NSMakeRect(0, 0, WIDTH, HEIGHT), $.NSWindowStyleMaskTitled | $.NSWindowStyleMaskClosable,
    $.NSBackingStoreBuffered, false);
win.releasedWhenClosed = false;
win.title = title;
win.level = $.NSFloatingWindowLevel;
win.collectionBehavior = $.NSWindowCollectionBehaviorCanJoinAllSpaces | $.NSWindowCollectionBehaviorFullScreenAuxiliary;

function label(y, size) {
    const field = $.NSTextField.labelWithString('');
    field.font = $.NSFont.systemFontOfSize(size);
    field.lineBreakMode = $.NSLineBreakByTruncatingTail;
    win.contentView.addSubview(field);
    return { field: field, y: y };
}

// Centered by position; the bridged alignment constants are those of Intel.
function show(line, text, color) {
    const field = line.field;
    field.stringValue = text;
    field.textColor = color;
    field.toolTip = text;
    field.sizeToFit;
    const size = field.frame.size, width = Math.min(size.width, WIDTH - 32);
    field.frame = $.NSMakeRect((WIDTH - width) / 2, line.y, width, size.height);
}

const keyField = label(88, 28), noteField = label(60, 12);
const guide = 'Esc cancels' + (offValue ? ', Delete: ' + offValue : '') + ', Tab: type it instead';
const waiting = () => show(keyField, 'Press the new key', $.NSColor.tertiaryLabelColor);
waiting();
show(noteField, guide, $.NSColor.secondaryLabelColor);

// Pressing a button, with the mouse or through accessibility, turns it on.
const buttons = [];
let used = -8;
function button(text, answer) {
    const view = $.NSButton.buttonWithTitleTargetAction(text, $(), $());
    view.setButtonType($.NSButtonTypePushOnPushOff);
    view.refusesFirstResponder = true;
    view.sizeToFit;
    used += view.frame.size.width + 8;
    buttons.push({ view: view, answer: answer });
    win.contentView.addSubview(view);
}
if (offValue) button(offValue, 'off');
if (defaultValue) button(defaultValue, 'default');
button('Type it…', 'type');
button('Cancel', 'cancel');
let x = Math.max(16, (WIDTH - used) / 2);
for (const b of buttons) {
    b.view.setFrameOrigin($.NSMakePoint(x, 14));
    x += b.view.frame.size.width + 8;
}

// A held key repeats into whatever window is next, so the window closes once
// the key that ended it is released.
function finish(answer, code) {
    if (answer) say(answer);
    if (code !== undefined) {
        const held = () => $.CGEventSourceKeyState(0, code), known = held();
        const until = Date.now() + (known ? 5000 : 2000);
        while (Date.now() < until && app.isActive && (!known || held())) {
            const event = next(0.02);
            if (!event.isNil() && Number(event.type) === 11 && Number(event.keyCode) === code) break;
        }
    }
    hotkeys(true);
    win.orderOut($());
    $.exit(0);
}

function next(seconds) {
    if ($.getppid() !== parent) $.exit(0);
    return app.nextEventMatchingMaskUntilDateInModeDequeue(
        0xffffffffffff, $.NSDate.dateWithTimeIntervalSinceNow(seconds), $.NSDefaultRunLoopMode, true);
}

function symbols(flags) {
    return (flags & GLOBE ? '🌐' : '') + (flags & CTRL ? '⌃' : '') + (flags & OPTION ? '⌥' : '') +
        (flags & SHIFT ? '⇧' : '') + (flags & CMD ? '⌘' : '');
}

win.center;
app.activateIgnoringOtherApps(true);
win.makeKeyAndOrderFront($());

const ALL = SHIFT | CTRL | OPTION | CMD | GLOBE;
let opened = false, globe = false;

// Arrow and function keys carry the Globe flag themselves; only a modifier
// event, and the state with no key down, tells whether Globe is held.
function hold(flags) {
    globe = (flags & GLOBE) !== 0;
    const held = symbols(flags & ALL);
    if (held) show(keyField, held, $.NSColor.labelColor);
    else waiting();
}

const start = Date.now();
while (true) {
    const event = next(0.1);
    if (!opened) {
        if (win.isKeyWindow && app.isActive) {
            opened = true;
            hotkeys(false);
            hold(Number($.NSEvent.modifierFlags));
            say('open');
        } else if (Date.now() - start > 2000) {
            finish('none');
        }
    } else if (!app.isActive || !win.isKeyWindow || !win.isVisible) {
        finish('cancel');
    }
    const pressed = buttons.find(b => Number(b.view.state) !== 0);
    if (pressed) finish(pressed.answer);
    if (event.isNil()) continue;
    const type = Number(event.type);
    if (type === 12) {
        hold(Number(event.modifierFlags));
        continue;
    }
    if (type === 11) continue;
    if (type === 10) {
        if (!opened || event.isARepeat) continue;
        const code = Number(event.keyCode);
        const flags = Number(event.modifierFlags) & (ALL & ~GLOBE) | (globe ? GLOBE : 0);
        if (flags === 0 && code === ESC) finish('cancel', code);
        if (flags === 0 && code === TAB) finish('type', code);
        if (flags === 0 && offValue && (code === DELETE || code === FORWARD_DELETE)) finish('off', code);
        say('key ' + code + ' ' + flags);
        const reply = hear();
        if (reply.startsWith('ok ')) {
            show(keyField, reply.slice(3), $.NSColor.labelColor);
            show(noteField, '', $.NSColor.secondaryLabelColor);
            win.displayIfNeeded;
            finish('', code);
        }
        $.NSBeep();
        show(noteField, reply.slice(3), $.NSColor.systemRedColor);
        continue;
    }
    app.sendEvent(event);
}
SCRIPT
}
