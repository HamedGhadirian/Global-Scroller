;================================================================================
; Global-Scroller.ahk - scroll any window by moving the mouse or the pen
;================================================================================
; AutoHotkey v2 (2.0 or later).
;
; KEYS - the defaults. Both can be changed in Settings (tray menu).
;   Win + Ctrl + click    SCROLL. A round mark appears where you clicked. Move away
;                         from it and the window scrolls that way - the
;                         further from the mark, the faster. Back on the mark,
;                         it stops moving.
;   Win + Shift + click   TOUCH DRAG (experimental). While Win and Shift are
;                         held, every click-drag drags the page like a
;                         finger, and it glides on when you let go.
;   any click, or Esc     ends it. That click does nothing else.
; A left click, so a pen's tip is enough (until 0.2.0 both were Win + Shift /
; Win + Alt + right-click; those still work if set in Settings).
; Scroll is wheel steps, or smooth (finer steps) - Settings, How it scrolls.
; With a mouse you can also keep the button held instead of the keys: scroll
; while holding, let go to end. A quick click (under 0.3 s) leaves it on until
; the next click - the way a browser's middle-click scroll works.
;
; WHY. With Windows Ink switched off for a drawing tablet, dragging the pen
; across a page no longer scrolls it the way a finger does on a phone. This
; gives scrolling by pen back for every program, in the browser's own
; middle-click style.
;
; Win is part of the key because programs keep Ctrl + click and Shift + click
; (selecting) and Alt + right-click (Photoshop, Clip Studio) for themselves.
; Programs where even the key should go
; through untouched can be listed in Settings > PROGRAMS - none are, by
; default.
;
; THE CODE
;   This file only starts things.
;   lib\Scroll.ahk    the scrolling itself, and the mark
;   lib\Config.ahk    the version, the settings window's rows, the .ini template
;   lib\Kit\          what every script of this family shares: the tray menu,
;                     the settings window, keys you can change, Start with
;                     Windows, Run as administrator, updates (lib\Kit\Kit.ahk
;                     lists the parts)
;   tests\            checks them (run-tests.ps1)
;
; FILES it makes, next to this script
;   Global-Scroller.ini    your settings - made on first run, never part of an update
;   errors.log        anything that went wrong, instead of a dialog in your face
;================================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\lib\Kit\Kit.ahk
#Include %A_LineFile%\..\lib\Config.ahk
#Include %A_LineFile%\..\lib\Scroll.ahk

CoordMode("Mouse", "Screen")    ; every thread inherits this

Kit.Start({name: "Global Scroller", version: GlobalScrollerVersion, repo: "HamedGhadirian/Global-Scroller"
    , nameWas: ["AutoScroll"]
    , icon: "icon.png", template: GlobalScrollerIniTemplate()
    , adminWhy: "So it also scrolls programs that run as administrator."
    , init: () => Scroll.Init()
    , keys: [{id: "Start", name: "Scroll", short: "scroll", def: "^#LButton"
            , fn: (hk) => Scroll.Start(hk), cond: (hk) => Scroll.Ready()}
        , {id: "Drag", name: "Touch drag", short: "drag", def: "+#LButton"
            , fn: (hk) => Scroll.Start(hk, true), cond: (hk) => Scroll.Ready()}]
    , rows: () => GlobalScrollerRows()
    , apply: () => Scroll.Load()})
