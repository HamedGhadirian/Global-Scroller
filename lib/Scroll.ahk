;================================================================================
; Scroll.ahk - the scrolling itself
;================================================================================
; TWO KEYS, each changeable in Settings:
;   Scroll      Win + Shift + Right-click - wheel steps, or smooth ([Scroll] Mode)
;   Touch drag  Win + Alt + Right-click   - a made-up finger drags the page
;
; The scroll key puts a round mark where you
; clicked. Move away from it and the window scrolls that way - the further
; from the mark, the faster. Back on the mark, it stops moving. Any click, or
; Esc, ends it; that click does nothing else.
;
; HOLD OR TAP ([Scroll] Hold=1, the default)
;   hold   keep the key's Win and Alt (or its mouse button) held after the
;          click: it scrolls while you hold, and stops when you let go.
;   tap    let go quickly (under TapTime, 0.3 s) and it stays on until a
;          click or Esc - the way a browser's middle-click scroll works.
; It is made for a mouse. A pen works where its driver makes it behave as one.
;
; THE HELD KEYS ARE HIDDEN FROM PROGRAMS. A wheel step with Alt down is
; Alt + wheel, which some programs read as back / forward; with Ctrl it is
; zoom, with Shift sideways. So while you hold, the key's Ctrl, Alt, Shift and
; Win are let go *for the programs* (a key-up is sent) and their repeats are
; swallowed, while this script still watches whether you are really holding
; them. They are given back once every one of them is up - not before, or the
; repeat of a key still held would press it again and its release would open
; the menu bar.
;
; With Hold=0 it works as it used to: nothing moves until you let go of Ctrl,
; Alt and Shift, and only a held mouse button scrolls while holding.
;
; TWO WAYS TO SCROLL ([Scroll] Mode), for the scroll key
;   wheel        small wheel steps. Works everywhere.
;   smooth       the wheel again, in pieces five times smaller (6 where a
;                notch is 120), so the page moves a few pixels at a time. No
;                finger is involved, so the pointer stays yours. A program
;                that counts every piece as a whole notch races - use wheel
;                there.
; TOUCH DRAG has its own key. Experimental. While you hold its modifiers
; (Win and Alt), every right-click-drag drags the page, and it glides on when
; you let go of the button. (Hold off: it follows the pointer until a click.)
; Touch only works in programs that take touch; others are handed it as a
; left-button drag, which may select text or draw.
;
; WHERE A WHEEL SCROLL GOES. To the window under the pointer, as a wheel does -
; while the pointer is still over the window you started in. Once it leaves
; that window, the scroll is posted to the spot you started on instead, so a
; long pull past the edge of a small window still scrolls it. A few programs
; (Store apps like Settings) do not take a posted scroll; those just stop
; scrolling while the pointer is outside them.
;
; Every position here is real pixels: each step runs per-monitor DPI aware for
; its length and switches back after, so the mark lands on the spot and a
; posted scroll names it right on a scaled monitor too.
;================================================================================
#Requires AutoHotkey v2.0

class Scroll {
    static state := ""              ; "" off, "armed" still held, "sticky" on until a click
    static speed := 6, curve := 1.6, dead := 10, step := 30, sideways := true, mode := "wheel"
    static hold := true, tap := 300
    static how := "wheel"           ; this run: "wheel", "smooth" (the Mode) or "touch" (the drag key)
    static ignore := Map()
    static mark := "", markArrows := ""
    static x := 0, y := 0, downAt := 0, lastTick := 0, accX := 0, accY := 0
    static target := 0, root := 0
    static trig := "", mods := [], waits := [], stopKeys := []
    static hidden := false, hiddenKeys := []
    static ticker := "", stopper := "", swallow := "", piece := 30
    static drag := false            ; touch: a drag per right-click while the keys are held
    ; for the tests: a pointer and a "still held?" of their own, and no live
    ; keys, so a real click is never swallowed
    static pointer := "", holding := "", clicks := true

    static SmoothStep := 6          ; smooth: the piece of wheel sent at once (a notch is 120)
    static MarkSize := 28

    ; once, before the key is switched on (Kit.Start's "init")
    static Init() {
        this.ticker := ObjBindMethod(Scroll, "Tick")
        this.stopper := ObjBindMethod(Scroll, "Stop")
        this.swallow := (*) => 0
        ; A held Alt repeats some 30 times a second and each repeat is swallowed by a
        ; hotkey here - far past AutoHotkey's "70 hotkeys in 2 seconds" alarm.
        A_MaxHotkeysPerInterval := 5000
        ; both hooks from the start: "is it really held" is only known for
        ; keys that went down while the hook was watching
        InstallKeybdHook()
        InstallMouseHook()
        this.Load()
    }

    ; The settings, read from the .ini - at start, and again whenever the
    ; settings window changes one (Kit.Start's "apply").
    static Load() {
        ini := Kit.ini
        this.speed    := CfgNum(ini, "Scroll", "Speed", 6)
        this.curve    := CfgNum(ini, "Scroll", "Curve", 1.6)
        this.dead     := CfgNum(ini, "Scroll", "DeadZone", 10)
        this.step     := Max(1, Round(CfgNum(ini, "Scroll", "Step", 30)))
        this.sideways := CfgBool(ini, "Scroll", "Sideways", true)
        this.hold     := CfgBool(ini, "Scroll", "Hold", true)
        this.tap      := Max(0, CfgNum(ini, "Scroll", "TapTime", 300))
        m := StrLower(CfgStr(ini, "Scroll", "Mode", "wheel"))
        ; touch drag has its own key now: an old Mode=touch reads as wheel
        this.mode     := (m = "smooth" || m = "touch-auto") ? "smooth" : "wheel"
        this.piece    := (this.mode = "smooth") ? Scroll.SmoothStep : this.step
        ig := Map()
        ig.CaseSense := false
        for exe in CfgList(ini, "Programs", "Ignore", "")
            ig[exe] := true
        this.ignore := ig
        ; The mark is made now rather than on the first scroll, so the first
        ; one is as quick as every other. Its arrows follow Sideways.
        if (!this.mark || this.markArrows != this.sideways) {
            this.Stop()
            this.MakeMark()
        }
    }

    ;----------------------------------------------------------------------------
    ; Starting and stopping
    ;----------------------------------------------------------------------------
    ; The key's own condition - and it is only asked with the key's modifiers
    ; already down. Not already scrolling, and not over a program in
    ; [Programs] Ignore.
    static Ready() {
        if (this.state != "")
            return false
        if !this.ignore.Count
            return true
        try {
            MouseGetPos(, , &win)
            return !this.ignore.Has(WinGetProcessName(win))
        }
        return true
    }

    ; touch: started by the touch drag key rather than the scroll key
    static Start(hk := "", touch := false) {
        Critical
        if (this.state != "")
            return
        ctx := DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
        p := this.Cursor()
        this.x := p.x, this.y := p.y
        this.downAt := A_TickCount, this.lastTick := A_TickCount
        this.accX := 0, this.accY := 0
        ; The window the scroll belongs to - the control under the click, which
        ; is what a posted scroll is sent to, and its top-level window.
        win := DllCall("WindowFromPoint", "int64", (p.x & 0xFFFFFFFF) | (p.y << 32), "ptr")
        this.target := win
        this.root := win ? DllCall("GetAncestor", "ptr", win, "uint", 2, "ptr") : 0   ; GA_ROOT
        this.state := "armed"
        this.how := touch ? "touch" : this.mode
        this.Trigger(hk)
        this.drag := (this.how = "touch" && this.hold && this.mods.Length > 0)
        if this.drag
            KitTouch.Down(p.x, p.y)               ; the button is down: this is the first drag
        else
            this.ShowMark(p.x, p.y)
        DllCall("SetThreadDpiAwarenessContext", "ptr", ctx, "ptr")
        ; Win and Alt are still down. A tap of vkE8 - a key no keyboard has -
        ; keeps letting go of them from opening the Start menu or the
        ; program's menu bar.
        SendInput("{Blind}{vkE8}")
        if (this.hold && this.mods.Length)
            this.Hide(true)
        this.Keys(true)
        this.LetGo()                            ; a click that is over already
        SetTimer(this.ticker, 10)
    }

    ; What the key that started this is made of: its own button or key (the
    ; one that may still be held), its modifiers as the keys to watch (left
    ; and right of each), and the ones a wheel step must not meet. The key
    ; can be changed in Settings, so this is read each time.
    static Trigger(hk) {
        p := KitKeys.Parse(hk)
        this.trig := Trim(RegExReplace(p.key, "^.*&"))
        this.mods := [], this.waits := []
        for m in [["^", "Ctrl"], ["!", "Alt"], ["+", "Shift"], ["#", "Win"]]
            if InStr(p.mods, m[1]) {
                this.mods.Push("L" m[2], "R" m[2])
                if (m[2] != "Win")
                    this.waits.Push(m[2])
            }
    }

    ; Is the key still held - its button, or (with Hold on) any of its modifiers?
    static Held() {
        if this.holding
            return this.holding.Call()
        if (this.trig != "" && GetKeyState(this.trig, "P"))
            return true
        return this.hold && this.ModsDown()
    }

    static ModsDown() {
        for k in this.mods
            if GetKeyState(k, "P")
                return true
        return false
    }

    ; Everything let go for the first time decides what kind this is: quickly
    ; (a tap), it stays on until the next click; after a hold, it ends now.
    static LetGo() {
        if (this.state != "armed" || this.Held())
            return
        if (!this.drag && A_TickCount - this.downAt < this.tap)
            this.state := "sticky"
        else
            this.Stop()
    }

    ; A click or Esc while scrolling, the window going away, or the held keys
    ; let go.
    static Stop(hk := "") {
        if (this.state = "")
            return
        ; A program that does not take touch is handed the touch as a left
        ; click. The first one, right after the touch went down, is that -
        ; not you.
        if (KitTouch.active && hk = "*LButton" && A_TickCount - KitTouch.at < 250)
            return
        if (this.drag && this.trig != "" && hk = "*" this.trig) {
            this.Press()                            ; touch drag: the button again is the next drag
            return
        }
        this.state := ""
        this.drag := false
        this.Keys(false)
        this.mark.Hide()
        KitTouch.Up()                           ; lifted moving, so the page glides on
        if !this.hidden
            SetTimer(this.ticker, 0)
    }

    ; While it is on, every click ends it and is swallowed - and AutoHotkey
    ; then swallows that click's button-up by itself, so no program is left
    ; with half a click.
    ;
    ; These keys have NO condition, and that is the whole point. A condition
    ; on a click makes every click, in every program, wait while this script
    ; works out the answer. So they are switched on only while a scroll is
    ; running, and the rest of the time they do not exist. Each is switched
    ; on WITH its action, every time (see Kit\Keys.ahk).
    static Keys(on) {
        if !this.clicks
            return
        HotIf()
        if on {
            this.stopKeys := ["*LButton", "*MButton", "*RButton", "Esc"]
            if (this.trig != "" && !(this.trig ~= "i)^(Esc|Escape)$")) {
                own := "*" this.trig, has := false
                for k in this.stopKeys
                    has := has || (k = own)
                if !has
                    this.stopKeys.Push(own)
            }
            for k in this.stopKeys
                try Hotkey(k, this.stopper, "On")
            return
        }
        for k in this.stopKeys
            try Hotkey(k, "Off")
    }

    ; The key's modifiers, hidden from programs while they are held (see the
    ; top of this file): their repeats swallowed first, then a key-up sent for
    ; each that programs still see as down. Given back by Tick once every one
    ; of them is really up.
    static Hide(on) {
        if !this.clicks
            return
        HotIf()
        if on {
            this.hiddenKeys := this.mods.Clone()
            ups := ""
            for k in this.hiddenKeys {
                try Hotkey("*" k, this.swallow, "On")
                if GetKeyState(k)
                    ups .= "{" k " up}"
            }
            if (ups != "")
                SendInput("{Blind}" ups)
            this.hidden := true
            return
        }
        for k in this.hiddenKeys
            try Hotkey("*" k, "Off")
        this.hidden := false
    }

    ;----------------------------------------------------------------------------
    ; The scrolling
    ;----------------------------------------------------------------------------
    ; Every 10 ms (about 16 in practice - Windows' timer): how far the pointer
    ; is from the mark, per axis, turned into a speed in wheel notches a
    ; second. Inside DeadZone pixels nothing moves; past it the speed is
    ;   Speed x (pixels past the dead zone / 100) ^ Curve
    ; so 100 pixels out is Speed notches a second, and 300 is about 6x that
    ; with the default Curve.
    static Tick() {
        ; Critical: the per-monitor DPI context below is the thread's, and
        ; another timer of the script's must not run inside it. A tick is a
        ; few ms.
        Critical
        if (this.hidden && !this.ModsDown())
            this.Hide(false)
        if (this.state = "") {
            if !this.hidden
                SetTimer(this.ticker, 0)
            return
        }
        if !DllCall("IsWindow", "ptr", this.root) {
            this.Stop()
            return
        }
        this.LetGo()
        if (this.state = "")
            return
        ; Hold off: nothing moves while a Ctrl, Alt or Shift of the key is
        ; still down - that would be Alt + wheel. Let go and it starts.
        if !this.hold
            for k in this.waits
                if GetKeyState(k) {
                    this.lastTick := A_TickCount, this.accX := 0, this.accY := 0
                    return
                }
        ctx := DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
        p := this.Cursor()
        now := A_TickCount
        ; Capped, so a tick held up by something else does not land as one big jump.
        dt := Min(now - this.lastTick, 50) / 1000
        this.lastTick := now
        if (this.how = "touch")
            (this.drag) ? this.DragMove(p) : this.TouchMove(p)
        else
            this.WheelMove(p, dt)
        DllCall("SetThreadDpiAwarenessContext", "ptr", ctx, "ptr")
    }

    ; WHEEL. The wheel amounts add up between ticks and go out in Step-sized
    ; pieces - a notch is 120, so 30 is a quarter notch, which is what makes
    ; it smooth rather than jumping a notch at a time.
    static WheelMove(p, dt) {
        ; Down the screen is a wheel turned towards you, which is a negative amount.
        r := this.Rate(p.y - this.y)
        this.accY := r ? this.accY - r * dt * 120 : 0
        if (n := this.Whole(this.accY)) {
            this.Wheel(0x0800, n, p)                    ; MOUSEEVENTF_WHEEL
            this.accY -= n
        }
        if !this.sideways
            return
        ; Sideways the sign is the screen's: to the right is positive.
        r := this.Rate(p.x - this.x)
        this.accX := r ? this.accX + r * dt * 120 : 0
        if (n := this.Whole(this.accX)) {
            this.Wheel(0x1000, n, p)                    ; MOUSEEVENTF_HWHEEL
            this.accX -= n
        }
    }

    ; Notches a second for a pointer d pixels from the mark along one axis.
    static Rate(d) {
        e := Abs(d) - this.dead
        if (e <= 0)
            return 0
        return (d < 0 ? -1 : 1) * this.speed * (e / 100) ** this.curve
    }

    ; the Step-sized pieces in what has added up, rounded towards zero
    static Whole(acc) => (acc > 0 ? Floor(acc / this.piece) : Ceil(acc / this.piece)) * this.piece

    ; One piece of scroll. Over the window it started in: a real wheel event,
    ; which every program takes. Tagged 0xFFC3D44F, AutoHotkey's own mark for
    ; events its scripts send, so other scripts' wheel hotkeys pass over it -
    ; one with a wheel hotkey counted all 60 a second and stopped with a
    ; warning. Anywhere else: posted to the control under the mark, with the
    ; mark as the point it happened at.
    static Wheel(flag, amount, p) {
        win := DllCall("WindowFromPoint", "int64", (p.x & 0xFFFFFFFF) | (p.y << 32), "ptr")
        root := win ? DllCall("GetAncestor", "ptr", win, "uint", 2, "ptr") : 0
        if (root = this.root) {
            DllCall("mouse_event", "uint", flag, "int", 0, "int", 0, "int", amount, "uptr", 0xFFC3D44F)
            return
        }
        msg := (flag = 0x0800) ? 0x20A : 0x20E          ; WM_MOUSEWHEEL / WM_MOUSEHWHEEL
        DllCall("PostMessage", "ptr", this.target, "uint", msg
            , "ptr", (amount & 0xFFFF) << 16, "ptr", ((this.y & 0xFFFF) << 16) | (this.x & 0xFFFF))
    }

    ; TOUCH DRAG. A finger, made up (Kit\Touch.ahk): one contact goes down
    ; where the pointer is, moves with the pointer every tick, and lifts when
    ; the scroll ends - still moving, so the page glides on like a phone's.
    static TouchMove(p) {
        if KitTouch.active {
            KitTouch.Move(p.x, p.y)
            return
        }
        if !KitTouch.Ready() {                          ; no touch on this PC: wheel steps
            this.how := "wheel"
            return
        }
        KitTouch.Down(p.x, p.y)
    }

    ; TOUCH DRAG, WHILE THE KEYS ARE HELD (Hold on). Each press of the key's
    ; button is one drag: the finger goes down where the pointer is, follows
    ; it while the button is held, and lifts when the button comes up - still
    ; moving, so the page glides on. The keys stay held between drags; letting
    ; go of them ends it all.
    static DragMove(p) {
        if !KitTouch.active
            return
        if GetKeyState(this.trig, "P")
            KitTouch.Move(p.x, p.y)
        else
            KitTouch.Up()
    }

    ; the key's button, pressed again while the keys are still held
    static Press() {
        if KitTouch.active
            return
        ctx := DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
        p := this.Cursor()
        this.x := p.x, this.y := p.y
        KitTouch.Down(p.x, p.y)
        DllCall("SetThreadDpiAwarenessContext", "ptr", ctx, "ptr")
    }

    static Cursor() {
        if this.pointer
            return this.pointer.Call()
        pt := Buffer(8, 0)
        DllCall("GetCursorPos", "ptr", pt)
        return {x: NumGet(pt, 0, "int"), y: NumGet(pt, 4, "int")}
    }

    ;----------------------------------------------------------------------------
    ; The mark
    ;----------------------------------------------------------------------------
    ; A small dark disc with arrows, centred on where you clicked - four
    ; arrows, or only up and down with sideways off. Click-through (E0x20 on a
    ; see-through window), so the mouse and the scroll pass straight through
    ; it, and shown without being activated - it never takes the keyboard.
    ; Made inside a per-monitor DPI context like Start's, so its position is
    ; in real pixels like everything else here.
    static MakeMark() {
        if this.mark
            try this.mark.Destroy()
        ctx := DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
        size := Scroll.MarkSize
        g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
        g.BackColor := "202020"
        g.MarginX := 0, g.MarginY := 0
        g.SetFont("s12 cFFFFFF", "Segoe UI Symbol")
        g.Add("Text", "x0 y0 w" size " h" size " Center 0x200 BackgroundTrans"
            , this.sideways ? Chr(0x2725) : Chr(0x2B0D))
        WinSetTransparent(210, g)
        WinSetRegion("0-0 W" size " H" size " E", g)
        DllCall("SetThreadDpiAwarenessContext", "ptr", ctx, "ptr")
        this.mark := g, this.markArrows := this.sideways
    }

    static ShowMark(x, y) {
        size := Scroll.MarkSize
        this.mark.Show("NA x" (x - size // 2) " y" (y - size // 2) " w" size " h" size)
    }
}
