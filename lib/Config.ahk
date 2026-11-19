;================================================================================
; Config.ahk - the version, the settings window's rows, the settings file
;================================================================================
#Requires AutoHotkey v2.0

; MAJOR.MINOR.PATCH - a dash makes it a test version. The release build reads
; it from this line, and the tag that starts the build must match it.
global GlobalScrollerVersion := "0.2.2"

; The settings window's own rows, under GENERAL and KEYS (Kit\SettingsWin.ahk
; builds the window and saves each row the moment it changes; Scroll.Load
; then reads them again, so they work at once).
GlobalScrollerRows() {
    return [{kind: "head", label: "SCROLLING"}
        , {kind: "list", sect: "Scroll", key: "Mode", def: "wheel", label: "How the scroll key scrolls"
            , choices: ["wheel", "smooth"]
            , names: ["Wheel steps (works everywhere)", "Smooth wheel (finer steps)"]
            , hint: "Smooth wheel: the same, in steps five times smaller. If a program races with it, use wheel steps there. "
                . "Touch drag has its own key (KEYS): hold its keys, and every drag with its button drags the page like a finger; "
                . "it glides on when you let go. Only in programs that take touch; others may select or draw instead."}
        , {kind: "bool", sect: "Scroll", key: "Hold", def: 1, label: "Scroll while the keys are held"
            , hint: "Keep the key's modifiers (Win and Ctrl, for example) or its mouse button held: it scrolls while you hold, and stops when you let go. "
                . "Let go quickly and it stays on until a click or Esc. Off: it waits for you to let go, then stays on."}
        , {kind: "num", sect: "Scroll", key: "TapTime", def: 300, min: 0, max: 2000, unit: "ms", label: "Quick let-go"
            , hint: "Let go sooner than this and it stays on. Later, and letting go ends it."}
        , {kind: "num", sect: "Scroll", key: "Speed", def: 6, min: 1, max: 100, label: "Speed"
            , hint: "How fast, 100 pixels away from the mark (wheel steps and smooth wheel)."}
        , {kind: "num", sect: "Scroll", key: "Curve", def: 1.6, min: 1, max: 4, label: "Speed-up further out"
            , hint: "1 = steady. Higher stays gentle near the mark and gets fast far from it."}
        , {kind: "num", sect: "Scroll", key: "DeadZone", def: 10, min: 0, max: 100, unit: "pixels"
            , label: "Still zone around the mark"
            , hint: "Nothing moves inside it, so a pen held nearly still does not creep."}
        , {kind: "num", sect: "Scroll", key: "Step", def: 30, min: 1, max: 120, label: "Smallest step"
            , hint: "120 is one wheel notch. Set 120 if an old program scrolls far too fast."}
        , {kind: "bool", sect: "Scroll", key: "Sideways", def: 1, label: "Scroll sideways too"}
        , {kind: "head", label: "PROGRAMS"}
        , {kind: "text", sect: "Programs", key: "Ignore", def: "", label: "Leave these programs alone"
            , hint: "Their names as Task Manager's Details tab shows them, with | between. "
                . "Example: Photoshop.exe|krita.exe"}]
}

; Only ever written when the file is NOT there, so it can never overwrite a
; setting you changed. Plain ASCII, and no double quotes in the text.
GlobalScrollerIniTemplate() {
    head := "
    (
; Global Scroller settings - Win+Ctrl+click, then move the mouse to scroll.
; Win+Shift+click-drag drags the page like a finger.
;
; Easiest from the tray menu: Settings. Everything in this file is there, and
; a change made there works at once. If you edit this file by hand instead,
; reload Global Scroller after (tray menu, Reload).
;
; Anything you delete or mistype falls back to its default. Nothing in this
; file can stop the script from starting.


    )"
    own := "
    (
[Scroll]
; How fast, in wheel notches a second, with the pointer 100 pixels past the
; dead zone. Higher is faster everywhere.
Speed=6

; How much faster it gets further out. 1 = twice as far, twice as fast. The
; default 1.6 stays gentle near the mark and runs away quickly far from it.
Curve=1.6

; Pixels around the mark where nothing moves, so a pen held nearly still does
; not creep.
DeadZone=10

; The smallest piece of scroll sent at once. A wheel notch is 120; 30 is a
; quarter notch, which is smooth in browsers and most programs. If an old
; program scrolls far too fast, it is counting every piece as a whole notch -
; set 120 and it will move in notches instead.
Step=30

; 1 = moving sideways scrolls sideways as well. 0 = up and down only.
Sideways=1

; How the scroll key scrolls:
; wheel  = small wheel steps, the further from the mark the faster. Works
;          everywhere.
; smooth = the same in steps five times smaller, so the page moves a few
;          pixels at a time. If a program races with it, use wheel there.
; Touch drag is not a mode: it has its own key (Win+Shift+click). Hold
; Win and Shift, and every click-drag drags the page; it glides on when
; you let go. EXPERIMENTAL - only in programs that take touch; others may
; get a left-button drag (selecting, drawing).
Mode=wheel

; 1 = keep the key's modifiers (or its mouse button) held and it scrolls
; while you hold, and stops when you let go; let go quickly and it stays on
; until a click or Esc. 0 = it waits for you to let go, then stays on.
Hold=1

; Milliseconds. With Hold=1: let go sooner than this and it stays on.
TapTime=300

[Programs]
; Programs where the key is left alone and goes through to the program
; itself, with | between them, spelled the way Task Manager Details tab
; spells them - for example
;   Ignore=Photoshop.exe|krita.exe
; BLANK means it works over every program.
Ignore=

    )"
    return head Kit.IniGeneral("so it also scrolls programs that run as administrator") own
}
