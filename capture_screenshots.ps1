param()
$ErrorActionPreference = "Continue"

$sdkRoot     = "$env:LOCALAPPDATA\Android\Sdk"
$adb         = if (Get-Command adb       -ErrorAction SilentlyContinue) { "adb"       } else { "$sdkRoot\platform-tools\adb.exe" }
$emulatorExe = if (Get-Command emulator  -ErrorAction SilentlyContinue) { "emulator"  } else { "$sdkRoot\emulator\emulator.exe" }

$avdName   = "Medium_Phone_API_36.1"
$package   = "au.com.notiva.medicaleventrecorder"
$apk       = "C:\dev\epilepsyrecorder\build\app\outputs\flutter-apk\app-profile.apk"
$outputDir = "C:\dev\epilepsyrecorder\assets\screenshots\google_play_phone"
$tmpXml    = "$env:TEMP\mer_ui_dump.xml"

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

function Get-UIDump {
    & $adb shell uiautomator dump /sdcard/window_dump.xml 2>&1 | Out-Null
    & $adb pull /sdcard/window_dump.xml $tmpXml 2>&1 | Out-Null
    if (Test-Path $tmpXml) { return (Get-Content $tmpXml -Raw -Encoding UTF8) }
    return ""
}

function Get-ElementCenter($xml, $text) {
    $escaped = [regex]::Escape($text)
    # uiautomator dump is often one long line — we can't rely on per-line splitting.
    # Instead match the text/content-desc attribute then find bounds on the SAME node
    # ([^>]*? won't cross a > so it stays within the opening tag).
    # Try clickable=true first to prefer interactive elements over label containers.
    foreach ($pattern in @(
        '(?:text|content-desc)="' + $escaped + '"[^>]*?clickable="true"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        '(?:text|content-desc)="' + $escaped + '"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
    )) {
        if ($xml -match $pattern) {
            $x = [int](([int]$Matches[1] + [int]$Matches[3]) / 2)
            $y = [int](([int]$Matches[2] + [int]$Matches[4]) / 2)
            return @{ x = $x; y = $y }
        }
    }
    return $null
}

function Tap-Text($labels, $maxWait = 10) {
    $elapsed = 0
    while ($elapsed -lt $maxWait) {
        $xml = Get-UIDump
        foreach ($label in $labels) {
            $center = Get-ElementCenter $xml $label
            if ($center) {
                & $adb shell input tap $center.x $center.y
                Write-Host "  Tapped '$label' @ ($($center.x),$($center.y))"
                return $true
            }
        }
        Start-Sleep -Seconds 1
        $elapsed++
    }
    Write-Warning "  Not found after ${maxWait}s: $($labels -join ' / ')"
    return $false
}

function Tap-Coord($x, $y, $desc) {
    & $adb shell input tap $x $y
    Write-Host "  Coord tap ($x,$y) [$desc]"
}

function Take-Screenshot($name) {
    Start-Sleep -Seconds 2
    & $adb shell screencap /sdcard/ss_tmp.png 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500
    & $adb pull /sdcard/ss_tmp.png "$outputDir\$name.png" 2>&1 | Out-Null
    if (Test-Path "$outputDir\$name.png") {
        $kb = [int]((Get-Item "$outputDir\$name.png").Length / 1024)
        Write-Host "  Saved: $name.png (${kb} KB)"
    } else {
        Write-Warning "  FAILED: $name.png not saved"
    }
}

# Use the statusbar service command - reliable on API 23+, no gesture ambiguity
function Open-Shade {
    & $adb shell cmd statusbar expand-notifications 2>&1 | Out-Null
    Start-Sleep -Seconds 1
}

function Close-Shade {
    & $adb shell cmd statusbar collapse 2>&1 | Out-Null
    Start-Sleep -Seconds 1
}

# ── 1. Kill any leftover emulator
Write-Host "[1/9] Killing any existing emulator..."
& $adb emu kill 2>&1 | Out-Null
Start-Sleep -Seconds 2

# ── 2. Start headless
Write-Host "[2/9] Starting emulator (headless)..."
$emuArgs = "-avd `"$avdName`" -no-window -noaudio -no-boot-anim -gpu swiftshader_indirect"
Start-Process -FilePath $emulatorExe -ArgumentList $emuArgs -PassThru | Out-Null

# ── 3. Wait for adb connection
Write-Host "[3/9] Waiting for adb connection..."
$ok = $false
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 2
    if ((& $adb devices 2>&1) -match "emulator-\d+\s+device") { $ok = $true; break }
}
if (-not $ok) { throw "Emulator not connected after 120s" }
Write-Host "  Connected."

# ── 4. Wait for full boot
Write-Host "[4/9] Waiting for boot..."
$ok = $false
for ($i = 0; $i -lt 90; $i++) {
    Start-Sleep -Seconds 2
    $prop = (& $adb shell getprop sys.boot_completed 2>&1).Trim()
    if ($prop -eq "1") { $ok = $true; break }
    if ($i % 10 -eq 9) {
        $secs = $i * 2 + 2
        Write-Host "  Booting... (${secs}s)"
    }
}
if (-not $ok) { throw "Boot did not complete after 180s" }
Write-Host "  Booted."
Start-Sleep -Seconds 3

# ── 4b. Restart adb daemon as root, then set SELinux to permissive so
#        shell commands can write to /data/data/<package>/shared_prefs/.
Write-Host "[4b] Rooting adb daemon..."
& $adb root 2>&1 | Out-Null
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 1
    if ((& $adb devices 2>&1) -match "emulator-\d+\s+device") { break }
}
& $adb shell setenforce 0 2>&1 | Out-Null   # permissive — allows root to write app data dirs
Write-Host "  SELinux: $(& $adb shell getenforce 2>&1)"

# ── 4c. Unlock + collapse any notification shade
Write-Host "[4c] Unlocking screen..."
& $adb shell input keyevent KEYCODE_WAKEUP 2>&1 | Out-Null
Start-Sleep -Milliseconds 500
& $adb shell wm dismiss-keyguard 2>&1 | Out-Null
Start-Sleep -Seconds 1
Close-Shade                                              # collapse shade BEFORE anything else
& $adb shell input keyevent KEYCODE_HOME 2>&1 | Out-Null
Start-Sleep -Seconds 1

# ── 5. Install APK
Write-Host "[5/9] Installing APK..."
$r = & $adb install -r $apk 2>&1
Write-Host "  $r"
Start-Sleep -Seconds 2

# Grant notification permission before launch so no dialog appears
Write-Host "  Granting POST_NOTIFICATIONS permission..."
& $adb shell pm grant $package android.permission.POST_NOTIFICATIONS 2>&1 | Out-Null

# ── 6. Launch app
Write-Host "[6/9] Launching app..."
& $adb shell monkey -p $package -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
Start-Sleep -Seconds 4
Close-Shade                                              # collapse in case init opened it

# ── 7. Disclaimer check (no notification permission dialog — granted via pm)
Write-Host "[7/9] Checking disclaimer..."
for ($i = 0; $i -lt 10; $i++) {
    $xml = Get-UIDump
    if ($xml -match "I Understand and Agree") {
        Write-Host "  Accepting disclaimer..."
        Tap-Text @("I Understand and Agree") 3 | Out-Null
        Start-Sleep -Seconds 2
        # Verify it dismissed; if still visible, use coordinate fallback
        $xml2 = Get-UIDump
        if ($xml2 -match "I Understand and Agree") {
            Write-Host "  Still visible - coord tap disclaimer button"
            Tap-Coord 540 2160 "I Understand and Agree"
            Start-Sleep -Seconds 2
        }
        Start-Sleep -Seconds 1
        break
    }
    Start-Sleep -Seconds 1
}
Close-Shade
Start-Sleep -Seconds 3                                   # let notification init complete and home screen settle

# ── SCREENSHOT 1: Home screen
Write-Host ""
Write-Host "[8/9] Screenshot 1 of 5: Home screen"
Take-Screenshot "mer-gp-phone-1"

# ── SCREENSHOT 2: Log Event form
Write-Host "  Screenshot 2 of 5: Log Event form"
# adb input tap does not reliably trigger Flutter navigation for this button.
# Instead: force-stop, inject a dummy event record + mer_open_latest_event flag,
# restart — initState reads the flag and auto-navigates to the Log Event form.
& $adb shell am force-stop $package
Start-Sleep -Seconds 1

$dummyEvt  = '[{"id":"ss-event-001","timestamp":"2026-05-07T04:50:00.000000","duration":"oneToFive","feelings":["😴 Tired and weary","🤕 Experiencing a headache"],"referralRequired":false,"notes":"Happened at work. Felt dizzy beforehand.","eventType":"seizure","severity":"moderate","triggers":["Stress","Poor sleep"]}]'
$tmpPrefs2 = "$env:TEMP\mer_prefs_ss2.xml"
$prefsXml2 = (& $adb shell run-as $package cat /data/data/$package/shared_prefs/FlutterSharedPreferences.xml 2>&1) -join "`n"
if ($prefsXml2 -match '</map>') {
    $prefsXml2 = [regex]::Replace($prefsXml2, '<string name="flutter\.epilepsy_event_records_v1">[^<]*</string>\s*', '')
    $prefsXml2 = [regex]::Replace($prefsXml2, '<boolean name="flutter\.mer_open_latest_event"[^/]*/>\s*', '')
    $evtEntry  = "    <string name=""flutter.epilepsy_event_records_v1"">$dummyEvt</string>"
    $flagEntry = '    <boolean name="flutter.mer_open_latest_event" value="true" />'
    $prefsXml2 = $prefsXml2 -replace '</map>', "$evtEntry`n$flagEntry`n</map>"
} else {
    $disc      = '<string name="flutter.disclaimerAcceptedVersion">1.0</string>'
    $prefsXml2 = "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>`n<map>`n    $disc`n    <string name=""flutter.epilepsy_event_records_v1"">$dummyEvt</string>`n    <boolean name=""flutter.mer_open_latest_event"" value=""true"" />`n</map>"
}
$destPrefs  = "/data/data/$package/shared_prefs/FlutterSharedPreferences.xml"
$xmlBytes2  = [System.Text.Encoding]::UTF8.GetBytes(($prefsXml2 -replace "`r`n", "`n"))
$b64prefs2  = [Convert]::ToBase64String($xmlBytes2)
$ir2 = & $adb shell "run-as $package sh -c 'echo $b64prefs2 | base64 -d > $destPrefs'" 2>&1
if ($ir2) { Write-Warning "  inject: $ir2" } else { Write-Host "  Prefs injected OK" }
$v2 = (& $adb shell "run-as $package cat $destPrefs" 2>&1) -join ''
if ($v2 -match 'epilepsy_event_records_v1') { Write-Host "  Verified: event record present" } else { Write-Warning "  WARN: event record NOT found in prefs after inject" }

& $adb shell monkey -p $package -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
Start-Sleep -Seconds 5
Close-Shade
Take-Screenshot "mer-gp-phone-2"
& $adb shell input keyevent KEYCODE_BACK
Start-Sleep -Seconds 2
Close-Shade

# ── SCREENSHOT 3: Shade - Log Event Now
Write-Host "  Screenshot 3 of 5: Notification shade (Log Event Now)"
Open-Shade
Start-Sleep -Seconds 1
Take-Screenshot "mer-gp-phone-3"

Close-Shade
Start-Sleep -Seconds 1

# ── SCREENSHOT 4: Shade - Event Ended
# SilentAction taps are blocked on API 36 via adb. Instead: force-stop, inject
# flutter.mer_active_event into SharedPreferences, restart. _restoreNotification()
# sees the key and calls _showActive() which posts the "Event Ended" notification.
Write-Host "  Screenshot 4 of 5: Notification shade (Event Ended)"
& $adb shell am force-stop $package
Start-Sleep -Seconds 1

$startIso  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.ffffff')
$eventJson = '{"id":"screenshot-event-001","startIso":"' + $startIso + '"}'
$tmpPrefs  = "$env:TEMP\mer_prefs_snap.xml"
$prefsXml  = (& $adb shell run-as $package cat /data/data/$package/shared_prefs/FlutterSharedPreferences.xml 2>&1) -join "`n"
if ($prefsXml -match '</map>') {
    $prefsXml = [regex]::Replace($prefsXml, '<string name="flutter\.mer_active_event">[^<]*</string>\s*', '')
    $newEntry = "    <string name=""flutter.mer_active_event"">$eventJson</string>"
    $prefsXml = $prefsXml -replace '</map>', "$newEntry`n</map>"
} else {
    $prefsXml = "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>`n<map>`n    <string name=""flutter.mer_active_event"">$eventJson</string>`n</map>"
}
$xmlBytes4 = [System.Text.Encoding]::UTF8.GetBytes(($prefsXml -replace "`r`n", "`n"))
$b64prefs4 = [Convert]::ToBase64String($xmlBytes4)
& $adb shell "run-as $package sh -c 'echo $b64prefs4 | base64 -d > $destPrefs'" 2>&1 | Out-Null

& $adb shell monkey -p $package -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
Start-Sleep -Seconds 4
Close-Shade

Open-Shade
Start-Sleep -Seconds 2
Take-Screenshot "mer-gp-phone-4"
Close-Shade
Start-Sleep -Seconds 1

# ── SCREENSHOT 5: History screen
Write-Host "  Screenshot 5 of 5: History screen"
# Bring app to foreground cleanly
& $adb shell input keyevent KEYCODE_HOME 2>&1 | Out-Null
Start-Sleep -Seconds 1
& $adb shell monkey -p $package -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
Start-Sleep -Seconds 2
Close-Shade

# Open overflow menu — AppBar center y = status_bar(63) + appbar_half(42) = 105; x near right edge
Tap-Coord 1048 105 "overflow menu"
Start-Sleep -Seconds 1
# History is the first popup item; popup anchors at AppBar bottom y=147, first item center at 147+63=210
Tap-Coord 950 210 "History popup item"
Start-Sleep -Seconds 2
Take-Screenshot "mer-gp-phone-5"

# ── Done
Write-Host ""
Write-Host "[9/9] Shutting down emulator..."
& $adb emu kill 2>&1 | Out-Null

Write-Host ""
Write-Host "=== DONE ==="
Write-Host "Output: $outputDir"
Write-Host ""
Get-ChildItem $outputDir -Filter "*.png" -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
    $kb = [int]($_.Length / 1024)
    Write-Host "  $($_.Name)  (${kb} KB)"
}
Write-Host ""
Write-Host "Upload to: Google Play Console > App content > Store listing > Phone screenshots"
