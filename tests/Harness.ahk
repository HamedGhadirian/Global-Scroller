;================================================================================
; Harness.ahk - what every test file starts with
;================================================================================
; The whole script is included (the kit, lib\Config.ahk, lib\Scroll.ahk), but
; nothing of Global-Scroller.ahk's start-up runs: no tray menu, no keys. A test
; adopts the script by hand (Kit.Adopt) with its settings file in a scratch
; folder in Temp, never the real one, and "quiet" set so no notice shows.
;
;   Check(name, got, want)        passes when got == want (case-sensitive)
;   CheckHas(name, got, parts*)   passes when got contains every part
;   CheckTrue(name, cond, note)   passes when cond is true; note explains a fail
;   Done()                        writes the results and exits
;
; Results go to results-<test file name>.txt, one "PASS name" or "FAIL name:
; ..." per line and "DONE" at the end - run-tests.ps1 reads them.
;================================================================================
#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
#Include %A_LineFile%\..\..\lib\Kit\Kit.ahk
#Include %A_LineFile%\..\..\lib\Config.ahk
#Include %A_LineFile%\..\..\lib\Scroll.ahk

global T_Out := A_ScriptDir "\results-" RegExReplace(A_ScriptName, "\.ahk$") ".txt"
try FileDelete(T_Out)

; an error in a test is a failed test, not a dialog that stops the run
OnError(T_Crash)
T_Crash(e, mode) {
    FileAppend("FAIL crashed: " e.Message " " e.Extra " (" e.What ", " RegExReplace(e.File, ".*\\") " line " e.Line ")`nDONE`n"
        , T_Out, "UTF-8")
    ExitApp 1
}

T_Line(s) => FileAppend(s "`n", T_Out, "UTF-8")

Check(name, got, want) {
    if (String(got) == String(want))
        T_Line("PASS " name)
    else
        T_Line("FAIL " name ":`n    got:  [" String(got) "]`n    want: [" String(want) "]")
}

CheckHas(name, got, parts*) {
    missing := []
    for p in parts
        if !InStr(got, p, true)
            missing.Push(p)
    if !missing.Length
        T_Line("PASS " name)
    else
        T_Line("FAIL " name ":`n    got:     [" got "]`n    missing: [" KitJoin(missing, "] [") "]")
}

CheckTrue(name, cond, note := "") {
    T_Line((cond ? "PASS " : "FAIL ") name ((!cond && note != "") ? ": " note : ""))
}

Done() {
    T_Line("DONE")
    ExitApp 0
}
