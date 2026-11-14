<#
  run-tests.ps1 - check Global Scroller before a release

  1. AutoHotkey's syntax check of Global-Scroller.ahk and everything it includes,
     and of lib\Kit\Updater.ahk (the update helper), which runs on its own
  2. tests\Scroll.test.ahk - the rules. No real key, click or wheel is sent,
     and nothing shows on screen.
  3. where the kit's master is beside this folder (the author's PC): this
     copy of lib\Kit must be the same as the master

    .\run-tests.ps1                  everything
    .\run-tests.ps1 -Ahk <path>      a particular AutoHotkey64.exe (v2)

  Exit code 0 when everything passed.
#>
param([string]$Ahk = "")

$here = $PSScriptRoot
$root = Split-Path $here -Parent

if (-not $Ahk) {
    $candidates = @($env:AHK_EXE,
        "$root\AutoHotkey64.exe",
        "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe")
    $Ahk = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $Ahk -or -not (Test-Path $Ahk)) { Write-Host "AutoHotkey v2 not found - pass -Ahk <path to AutoHotkey64.exe>"; exit 2 }
Write-Host "AutoHotkey: $Ahk"

$failed = 0

# 1. syntax
foreach ($f in @("$root\Global-Scroller.ahk", "$root\lib\Kit\Updater.ahk")) {
    $p = Start-Process $Ahk -ArgumentList "/Validate /ErrorStdOut `"$f`"" -PassThru -NoNewWindow -Wait -RedirectStandardError "$here\validate.err"
    $err = Get-Content "$here\validate.err" -Raw -ErrorAction SilentlyContinue
    if ($p.ExitCode -eq 0) { Write-Host "PASS syntax: $(Split-Path $f -Leaf)" }
    else { Write-Host "FAIL syntax: $(Split-Path $f -Leaf)`n$err"; $failed++ }
}
Remove-Item "$here\validate.err" -ErrorAction SilentlyContinue

# 2. the tests
foreach ($t in @("Scroll.test.ahk")) {
    $out = "$here\results-" + ($t -replace "\.ahk$", "") + ".txt"
    Remove-Item $out -ErrorAction SilentlyContinue
    $p = Start-Process $Ahk -ArgumentList "/ErrorStdOut `"$here\$t`"" -PassThru
    if (-not $p.WaitForExit(120000)) { $p.Kill(); Write-Host "FAIL $t : did not finish in 2 minutes"; $failed++; continue }
    if (-not (Test-Path $out)) { Write-Host "FAIL $t : wrote no results"; $failed++; continue }
    $lines = Get-Content $out -Encoding UTF8
    Write-Host "--- $t"
    $lines | Where-Object { $_ -ne "DONE" } | ForEach-Object { Write-Host $_ }
    $failed += ($lines | Where-Object { $_ -like "FAIL*" }).Count
    if ($lines -notcontains "DONE") { Write-Host "FAIL $t : stopped before the end"; $failed++ }
}

# 3. the kit copy against its master, where there is one
$master = Join-Path (Split-Path $root -Parent) "lib\Kit"
if (Test-Path "$master\Kit.ahk") {
    $diff = @()
    foreach ($f in Get-ChildItem $master -Filter *.ahk -File) {
        $copy = Join-Path "$root\lib\Kit" $f.Name
        if (-not (Test-Path $copy) -or (Get-FileHash $copy).Hash -ne (Get-FileHash $f.FullName).Hash) { $diff += $f.Name }
    }
    foreach ($f in Get-ChildItem "$root\lib\Kit" -Filter *.ahk -File) {
        if (-not (Test-Path (Join-Path $master $f.Name))) { $diff += "$($f.Name) (not in the master)" }
    }
    if ($diff) { Write-Host "FAIL kit copy differs from the master: $($diff -join ', ') - run Tools\Sync-Kit.ps1"; $failed++ }
    else { Write-Host "PASS kit copy is the master's" }
}

Write-Host ""
if ($failed) { Write-Host "$failed FAILED"; exit 1 }
Write-Host "ALL PASSED"; exit 0
