param()
$ErrorActionPreference = "Continue"

$sdkRoot     = "$env:LOCALAPPDATA\Android\Sdk"
$adb         = if (Get-Command adb      -ErrorAction SilentlyContinue) { "adb"      } else { "$sdkRoot\platform-tools\adb.exe" }
$emulatorExe = if (Get-Command emulator -ErrorAction SilentlyContinue) { "emulator" } else { "$sdkRoot\emulator\emulator.exe" }

$avdName   = "Medium_Phone_API_36.1"
$package   = "au.com.notiva.medicaleventrecorder"
$apk       = "C:\dev\epilepsyrecorder\build\app\outputs\flutter-apk\app-profile.apk"
$destPrefs = "/data/data/$package/shared_prefs/FlutterSharedPreferences.xml"

function Close-Shade {
    & $adb shell cmd statusbar collapse 2>&1 | Out-Null
    Start-Sleep -Seconds 1
}
function Open-Shade {
    & $adb shell cmd statusbar expand-notifications 2>&1 | Out-Null
    Start-Sleep -Seconds 1
}

Write-Host "[1] Killing any existing emulator..."
& $adb emu kill 2>&1 | Out-Null
Start-Sleep -Seconds 2

Write-Host "[2] Starting emulator (windowed)..."
$emuArgs = "-avd `"$avdName`" -noaudio -no-boot-anim -gpu swiftshader_indirect"
Start-Process -FilePath $emulatorExe -ArgumentList $emuArgs -PassThru | Out-Null

Write-Host "[3] Waiting for adb connection..."
$ok = $false
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 2
    if ((& $adb devices 2>&1) -match "emulator-\d+\s+device") { $ok = $true; break }
}
if (-not $ok) { throw "Emulator not connected after 120s" }
Write-Host "  Connected."

Write-Host "[4] Waiting for boot..."
$ok = $false
for ($i = 0; $i -lt 90; $i++) {
    Start-Sleep -Seconds 2
    $prop = (& $adb shell getprop sys.boot_completed 2>&1).Trim()
    if ($prop -eq "1") { $ok = $true; break }
    if ($i % 10 -eq 9) { Write-Host "  Booting... ($([int](($i+1)*2))s)" }
}
if (-not $ok) { throw "Boot did not complete after 180s" }
Write-Host "  Booted."
Start-Sleep -Seconds 3

Write-Host "[4b] Rooting adb daemon..."
& $adb root 2>&1 | Out-Null
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 1
    if ((& $adb devices 2>&1) -match "emulator-\d+\s+device") { break }
}

Write-Host "[4c] Unlocking screen..."
& $adb shell input keyevent KEYCODE_WAKEUP 2>&1 | Out-Null
Start-Sleep -Milliseconds 500
& $adb shell wm dismiss-keyguard 2>&1 | Out-Null
Start-Sleep -Seconds 1
Close-Shade
& $adb shell input keyevent KEYCODE_HOME 2>&1 | Out-Null
Start-Sleep -Seconds 1

Write-Host "[5] Installing APK..."
$r = & $adb install -r $apk 2>&1
Write-Host "  $r"
Start-Sleep -Seconds 2
& $adb shell pm grant $package android.permission.POST_NOTIFICATIONS 2>&1 | Out-Null
Write-Host "  POST_NOTIFICATIONS granted."

Write-Host "[6] Launching app (accept disclaimer if shown)..."
& $adb shell monkey -p $package -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
Start-Sleep -Seconds 5
Close-Shade
$tmpXml = "$env:TEMP\mer_ss4_dump.xml"
& $adb shell uiautomator dump /sdcard/window_dump.xml 2>&1 | Out-Null
& $adb pull /sdcard/window_dump.xml $tmpXml 2>&1 | Out-Null
if ((Test-Path $tmpXml) -and (Get-Content $tmpXml -Raw) -match "I Understand and Agree") {
    Write-Host "  Accepting disclaimer..."
    & $adb shell input tap 540 1200 2>&1 | Out-Null
    Start-Sleep -Seconds 3
}

Write-Host "[7] Injecting active event state..."
& $adb shell am force-stop $package
Start-Sleep -Seconds 2

$startIso  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.ffffff')
$eventJson = '{"id":"screenshot-event-001","startIso":"' + $startIso + '"}'

$prefsXml = (& $adb shell run-as $package cat $destPrefs 2>&1) -join "`n"

if ($prefsXml -match '</map>') {
    Write-Host "  Existing prefs found - patching..."
    $prefsXml = [regex]::Replace($prefsXml, '<string name="flutter\.mer_active_event">[^<]*</string>\s*', '')
    $prefsXml = [regex]::Replace($prefsXml, '<boolean name="flutter\.mer_open_latest_event"[^/]*/>\s*', '')
    $newEntry = '    <string name="flutter.mer_active_event">' + $eventJson + '</string>'
    $prefsXml = $prefsXml -replace '</map>', "$newEntry`n</map>"
} else {
    Write-Host "  No existing prefs - creating fresh..."
    $disc     = '<string name="flutter.disclaimerAcceptedVersion">1.0</string>'
    $evtEntry = '<string name="flutter.mer_active_event">' + $eventJson + '</string>'
    $prefsXml = "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>`n<map>`n    $disc`n    $evtEntry`n</map>"
}

$xmlBytes = [System.Text.Encoding]::UTF8.GetBytes(($prefsXml -replace "`r`n", "`n"))
$b64      = [Convert]::ToBase64String($xmlBytes)
$result   = & $adb shell "run-as $package sh -c 'echo $b64 | base64 -d > $destPrefs'" 2>&1
if ($result) { Write-Warning "  Inject warning: $result" } else { Write-Host "  Inject: OK" }

$verify = (& $adb shell "run-as $package cat $destPrefs" 2>&1) -join ''
if ($verify -match 'mer_active_event') {
    Write-Host "  Verified: mer_active_event present in prefs"
} else {
    Write-Warning "  WARNING: mer_active_event NOT found in prefs after inject"
    Write-Host "  Prefs snippet: $($verify.Substring(0, [Math]::Min(400, $verify.Length)))"
}

Write-Host "[8] Restarting app..."
& $adb shell monkey -p $package -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
Start-Sleep -Seconds 6
Close-Shade

Write-Host "[9] Opening notification shade..."
Open-Shade
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "============================================================"
Write-Host "  READY - Emulator notification shade is open."
Write-Host "  The notification should show the 'Event Ended' button."
Write-Host ""
Write-Host "  Use Windows Snipping Tool to capture the emulator screen."
Write-Host "  Save as: mer-gp-phone-4.png"
Write-Host "  Path: C:\dev\epilepsyrecorder\assets\screenshots\google_play_phone\"
Write-Host "============================================================"
Write-Host ""

Read-Host "Press Enter when done to shut down the emulator"

Write-Host "Shutting down emulator..."
& $adb emu kill 2>&1 | Out-Null
Write-Host "Done."
