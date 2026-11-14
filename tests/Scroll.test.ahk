;================================================================================
; Scroll.test.ahk - Global Scroller's rules; no click or wheel turn is sent
;================================================================================
; The pointer is made up (Scroll.pointer), far off every screen, so a scroll
; is never sent as a real wheel turn: it is posted to a hidden window of the
; test's own, which counts what arrives. The keys that end a scroll are left
; off (Scroll.clicks), so a real click is never swallowed. The settings file
; is a scratch one in Temp, removed at the end.
;================================================================================
#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\Harness.ahk

global T := A_Temp "\Global-Scroller-test-" A_TickCount
DirCreate(T)
Kit.Adopt({name: "Global Scroller", version: GlobalScrollerVersion, repo: "Someone/Global-Scroller", ini: T "\Global-Scroller.ini", quiet: true})
ini := Kit.ini

;--- The settings file -------------------------------------------------------
CfgSeed(ini, GlobalScrollerIniTemplate())
txt := FileRead(ini, "UTF-8")
CheckTrue("template: plain ASCII, no BOM", !RegExMatch(txt, "[^\x00-\x7F]"))
CheckTrue("template: Windows line ends", !RegExMatch(txt, "(?<!\r)\n"))
Check("template: new downloads start without administrator", CfgStr(ini, "General", "RunAsAdmin", "?"), "0")
Check("template: ... not starting with Windows", CfgStr(ini, "General", "StartWithWindows", "?"), "0")
Check("template: ... looking for updates, dark", CfgStr(ini, "General", "CheckUpdates", "?") "|" CfgStr(ini, "General", "Theme", "?"), "1|dark")
missing := ""
for r in GlobalScrollerRows()
    if (r.HasProp("key") && CfgStr(ini, r.sect, r.key, Chr(2)) == Chr(2))
        missing .= r.sect "." r.key " "
Check("template: has a line for every row of the settings window", missing, "")
for r in GlobalScrollerRows()
    if (r.HasProp("key") && CfgStr(ini, r.sect, r.key, "") != r.def)
        missing .= r.key " "
Check("template: and the same defaults as the rows", missing, "")
CheckTrue("version: MAJOR.MINOR.PATCH", RegExMatch(GlobalScrollerVersion, "^\d+\.\d+\.\d+(-[\w.]+)?$"))

;--- Reading the settings ----------------------------------------------------
Scroll.Init()
Check("load: the defaults", Scroll.speed "|" Round(Scroll.curve, 2) "|" Scroll.dead "|" Scroll.step "|" Scroll.sideways "|" Scroll.mode, "6|1.60|10|30|1|wheel")
Check("load: hold is on, a tap is under 0.3 s", Scroll.hold "|" Scroll.tap, "1|300")
CheckTrue("load: the mark is made at start", IsObject(Scroll.mark))
IniWrite(12, ini, "Scroll", "Speed"), IniWrite("nonsense", ini, "Scroll", "Curve"), IniWrite(0, ini, "Scroll", "Step")
IniWrite("smooth", ini, "Scroll", "Mode"), IniWrite("Photoshop.exe| krita.exe", ini, "Programs", "Ignore")
Scroll.Load()
Check("load: a change is read again", Scroll.speed "|" Scroll.mode, "12|smooth")
IniWrite("touch", ini, "Scroll", "Mode")
Scroll.Load()
Check("load: an old Mode=touch is wheel steps - touch drag has its own key", Scroll.mode, "wheel")
Check("load: nonsense falls back, a step is at least 1", Round(Scroll.curve, 2) "|" Scroll.step, "1.60|1")
CheckTrue("load: programs to leave alone, whatever the case", Scroll.ignore.Has("PHOTOSHOP.EXE") && Scroll.ignore.Has("krita.exe"))
old := Scroll.mark
IniWrite(0, ini, "Scroll", "Sideways")
Scroll.Load()
CheckTrue("load: sideways off draws the mark again, with two arrows", Scroll.mark != old && Scroll.markArrows = 0)
IniWrite(6, ini, "Scroll", "Speed"), IniWrite(1.6, ini, "Scroll", "Curve"), IniWrite(30, ini, "Scroll", "Step")
IniWrite("wheel", ini, "Scroll", "Mode"), IniWrite(1, ini, "Scroll", "Sideways"), IniWrite("", ini, "Programs", "Ignore")
Scroll.Load()

;--- The speed ---------------------------------------------------------------
Check("rate: nothing inside the still zone", Scroll.Rate(10) "|" Scroll.Rate(-4), "0|0")
Check("rate: 100 pixels past it is Speed notches a second", Round(Scroll.Rate(110), 3), Round(6.0, 3))
Check("rate: up is negative", Round(Scroll.Rate(-110), 3), Round(-6.0, 3))
Check("rate: three times as far is about six times as fast", Round(Scroll.Rate(310) / Scroll.Rate(110), 2), Round(3 ** 1.6, 2))
Check("pieces: whole steps only, towards zero", Scroll.Whole(65) "|" Scroll.Whole(-65) "|" Scroll.Whole(20), "60|-60|0")

;--- The key it was started with ----------------------------------------------
Scroll.Trigger("#!RButton")
Check("key: Win + Alt + Right-click holds the right button and waits for Alt", Scroll.trig "|" KitJoin(Scroll.waits, ","), "RButton|Alt")
Check("key: ... and its Win and Alt, left or right, are the keys to hold", KitJoin(Scroll.mods, ","), "LAlt,RAlt,LWin,RWin")
Scroll.Trigger("^+F9")
Check("key: any other key works the same way", Scroll.trig "|" KitJoin(Scroll.waits, ","), "F9|Ctrl,Shift")
Scroll.Trigger("#XButton1")
Check("key: Win alone is not waited for", Scroll.trig "|" KitJoin(Scroll.waits, ","), "XButton1|")
Scroll.state := "sticky"
Check("ready: not while one is running", Scroll.Ready(), 0)
Scroll.state := ""
Check("ready: otherwise", Scroll.Ready(), 1)

;--- A scroll, start to end --------------------------------------------------
; The mark and the pointer are far off every screen, so each piece is posted
; to the window the scroll "started in" - this hidden one.
global Got := {v: 0, h: 0, n: 0, at: ""}
win := Gui()
OnMessage(0x20A, Counted), OnMessage(0x20E, Counted)
Counted(wParam, lParam, msg, hwnd) {
    d := (wParam >> 16) & 0xFFFF
    d := (d > 0x7FFF) ? d - 0x10000 : d
    if (msg = 0x20A)
        Got.v += d
    else
        Got.h += d
    Got.n++
    x := lParam & 0xFFFF, y := (lParam >> 16) & 0xFFFF
    Got.at := ((x > 0x7FFF) ? x - 0x10000 : x) "," ((y > 0x7FFF) ? y - 0x10000 : y)
    return 0
}
global Where := {x: -30000, y: -30000}
Scroll.pointer := () => ({x: Where.x, y: Where.y})
Scroll.clicks := false
Scroll.x := -30000, Scroll.y := -30000, Scroll.accX := 0, Scroll.accY := 0
Scroll.target := win.Hwnd, Scroll.root := win.Hwnd

Where.y := -30000 + 110                         ; 100 pixels past the still zone, below the mark
loop 100                                        ; one second, in 10 ms ticks
    Scroll.WheelMove(Scroll.Cursor(), 0.01)
Sleep(100)
CheckTrue("scroll: down, 6 notches in a second", Abs(Got.v + 720) <= 30, "got " Got.v)
CheckTrue("scroll: in quarter-notch pieces", Got.n >= 20 && Got.n <= 26, Got.n " pieces")
Check("scroll: posted with the mark as its place", Got.at, "-30000,-30000")
Check("scroll: nothing sideways", Got.h, 0)

Got.v := 0, Got.h := 0, Got.n := 0, Scroll.accY := 0
Where.y := -30000 + 5, Where.x := -30000 - 110  ; back in the still zone, and left of the mark
loop 100
    Scroll.WheelMove(Scroll.Cursor(), 0.01)
Sleep(100)
CheckTrue("scroll: left, 6 notches in a second", Abs(Got.h + 720) <= 30, "got " Got.h)
Check("scroll: back on the mark it stops", Got.v, 0)

Got.h := 0, Scroll.sideways := false, Scroll.accX := 0
loop 50
    Scroll.WheelMove(Scroll.Cursor(), 0.01)
Sleep(100)
Check("scroll: sideways off sends nothing sideways", Got.h, 0)
Scroll.sideways := true

; the whole of it: started, ticking, ended
Scroll.state := ""
Where.x := -30000, Where.y := -30000
Scroll.Start("")                                ; no key: it is on until a click
Scroll.target := win.Hwnd, Scroll.root := win.Hwnd  ; before a tick can find no window there and end it
Critical("Off")                                 ; Start is Critical, and here it ran in this very thread
Check("start: with no button held it stays on", Scroll.state, "sticky")
Check("start: the mark is where the pointer was", Scroll.x "," Scroll.y, "-30000,-30000")
Got.v := 0, Where.y := -30000 + 210
Sleep(500)
CheckTrue("tick: the timer scrolls by itself", Got.v < -120, "got " Got.v)
Scroll.Stop()
Sleep(100)                                      ; the pieces already on their way arrive
seen := Got.v
Sleep(200)
Check("stop: off, and nothing more arrives", Scroll.state "|" (Got.v = seen), "|1")
Scroll.Start("")
Scroll.target := win.Hwnd, Scroll.root := win.Hwnd
Critical("Off")
Sleep(100)
Check("start: again", Scroll.state, "sticky")
win.Destroy()
Sleep(200)
Check("tick: the window going away ends it", Scroll.state, "")

;--- Hold or tap ---------------------------------------------------------------
; "Is it still held" is made up here (Scroll.holding): no real key is read.
global Hold := {down: true}
Scroll.holding := () => Hold.down
win := Gui()
Where.x := -30000, Where.y := -30000
Scroll.Start("#!RButton")
Scroll.target := win.Hwnd, Scroll.root := win.Hwnd
Critical("Off")
Check("hold: while the keys are held it is armed", Scroll.state, "armed")
Hold.down := false                              ; let go at once
Sleep(80)
Check("tap: let go quickly and it stays on", Scroll.state, "sticky")
Scroll.Stop()
Sleep(150)
Hold.down := true
Scroll.Start("#!RButton")
Scroll.target := win.Hwnd, Scroll.root := win.Hwnd
Critical("Off")
Got.v := 0, Where.y := -30000 + 210
Sleep(Scroll.tap + 200)
Check("hold: held past the tap time, it is still on", Scroll.state, "armed")
CheckTrue("hold: and it scrolls while held", Got.v < -120, "got " Got.v)
Hold.down := false
Sleep(80)
Check("hold: letting go ends it", Scroll.state, "")
Scroll.holding := ""
Sleep(150)

;--- Smooth wheel, and touch drag ------------------------------------------------
IniWrite("smooth", ini, "Scroll", "Mode")
Scroll.Load()
Check("smooth: the wheel in much smaller pieces", Scroll.mode "|" Scroll.Whole(65) "|" Scroll.Whole(5), "smooth|60|0")
IniWrite("touch-auto", ini, "Scroll", "Mode")
Scroll.Load()
Check("smooth: the old touch-auto setting means smooth now", Scroll.mode, "smooth")
IniWrite("wheel", ini, "Scroll", "Mode")
Scroll.Load()
Check("wheel: its own pieces again", Scroll.Whole(65) "|" Scroll.Whole(20), "60|0")

; The finger is made up (KitTouch.fake): nothing touches the screen.
global Finger := {x: 0, y: 0, downs: 0, ups: 0}
FakeFinger(flags, x, y) {
    Finger.x := x, Finger.y := y
    if (flags = 0x10006)
        Finger.downs++
    else if (flags = 0x40000)
        Finger.ups++
    return 1
}
KitTouch.fake := FakeFinger
Scroll.how := "touch", Scroll.state := "sticky"
Scroll.TouchMove({x: -30000, y: -30000})
Scroll.TouchMove({x: -30000, y: -30050})
Check("touch: the finger follows the pointer", Finger.downs "|" Finger.x "," Finger.y, "1|-30000,-30050")
Scroll.Stop()
Check("touch: ending it lifts at once, so the page glides on", Finger.ups "|" KitTouch.active, "1|0")
; a drag per press, while the keys are held
Scroll.state := "armed", Scroll.drag := true, Scroll.trig := "RButton"
Scroll.Press()
Check("drag: a press puts the finger down at the pointer", Finger.downs "|" KitTouch.active, "2|1")
Scroll.DragMove({x: -30000, y: -30020})
Check("drag: with the button up again, the finger lifts", Finger.ups "|" KitTouch.active, "2|0")
Scroll.Press()
Check("drag: the next press drags again, keys still held", Finger.downs "|" KitTouch.active, "3|1")
Scroll.Stop("*RButton")
Check("drag: the button never ends it while the keys are held", Scroll.state, "armed")
Scroll.Stop()
Check("drag: ending it lifts the finger", Scroll.state "|" Finger.ups "|" Scroll.drag, "|3|0")
; the two keys: the drag key starts a touch drag, the scroll key the Mode
Scroll.holding := () => true
Scroll.Start("#!RButton", true)
Critical("Off")
Check("keys: the drag key drags, a drag per press", Scroll.how "|" Scroll.drag "|" KitTouch.active, "touch|1|1")
Scroll.Stop()
IniWrite("smooth", ini, "Scroll", "Mode")
Scroll.Load()
Scroll.Start("#+RButton")
Critical("Off")
Check("keys: the scroll key scrolls the Mode's way, no finger", Scroll.how "|" Scroll.drag "|" KitTouch.active, "smooth|0|0")
Check("keys: Win + Shift waits for Shift", Scroll.trig "|" KitJoin(Scroll.waits, ","), "RButton|Shift")
Scroll.Stop()
; the defaults since 0.2.1 are on the left click, so a pen's tip starts them
; (Critical stays on until the checks are done: the pointer here is made up,
; with no window under it, so a tick in between would end it - rightly.)
Scroll.Start("+#LButton", true)
Check("left keys: Win + Shift + click drags", Scroll.how "|" Scroll.trig "|" KitJoin(Scroll.waits, ","), "touch|LButton|Shift")
Scroll.Stop("*LButton")
Check("left keys: the next left press is the next drag, not the end", Scroll.state "|" Scroll.drag, "armed|1")
Scroll.Stop()
Scroll.Start("^#LButton")
Check("left keys: Win + Ctrl + click scrolls, waiting for Ctrl", Scroll.how "|" Scroll.trig "|" KitJoin(Scroll.waits, ","), "smooth|LButton|Ctrl")
Scroll.Stop("*LButton")
Check("left keys: a left click while scrolling ends it", Scroll.state, "")
Critical("Off")
Scroll.holding := ""
IniWrite("wheel", ini, "Scroll", "Mode")
Scroll.Load()
KitTouch.fake := ""
Scroll.how := "wheel"

try DirDelete(T, true)
Done()
