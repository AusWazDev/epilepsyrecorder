# Windows Store Submission Checklist — Medical Event Recorder

Complete every item before uploading a package to Partner Center.
Do not submit until all boxes are checked. No exceptions.

---

## 1. Package Integrity

- [ ] `AppxManifest.xml` extracted and read — identity name (`Notiva.MedicalEventRecorder`), publisher CN (`520D1E31-3542-4059-8124-5366ECCA4994`), version, display name all correct
- [ ] Package version incremented from last submission
- [ ] Architecture matches declaration (x64; Arm64 added in v1.0.1)
- [ ] Build completed cleanly — `flutter build windows --release` then `dart run msix:create` then manual signtool signing

## 2. Signing Verification

- [ ] MSIX signed with real store certificate (not `CN=Msix Testing`)
- [ ] Verify: `signtool verify /pa /v build\windows\x64\runner\Release\medical_event_recorder.msix` — shows Notiva CN
- [ ] `sign_msix: false` confirmed in `pubspec.yaml` (signing is manual via PowerShell)

## 3. Visual Assets — open every file and eyeball it

- [ ] App icon displays correctly in the installer and taskbar
- [ ] Start menu tile shows MER branding — not a default placeholder
- [ ] No generic/white-background tiles
- [ ] **Check Store listing icon in Partner Center preview AND on the live Store page** — v1.0.0 icon was flagged as substandard quality after publication. Investigate source asset resolution and Partner Center store listing image upload before resubmitting.

## 4. Install and Smoke Test

- [ ] MSIX installed on a real Windows machine
- [ ] App launches without errors
- [ ] Disclaimer screen appears on first launch (or home screen if already accepted)
- [ ] Record Event flow works end to end — fill in details, save, appears in history
- [ ] CSV export works
- [ ] About screen shows correct version, Privacy Policy link loads, Terms of Service link loads
- [ ] Quick Log Notification section is NOT visible on Windows (DEF-37)
- [ ] App name, icon, and publisher correct in Apps & Features — shows "Notiva"
- [ ] No crash or console error on launch

## 5. Store Listing Review

- [ ] Screenshots match current app UI
- [ ] Description and short description proofread
- [ ] Age rating complete
- [ ] Privacy policy URL loads: notiva.com.au/medical-event-recorder/privacy/
- [ ] Terms of Service URL loads: notiva.com.au/medical-event-recorder/terms/
- [ ] Submission options complete (runFullTrust declared and approved)
- [ ] Chapter 3 tax status confirmed in Partner Center payout settings

## 6. Partner Center Upload

- [ ] Package shows "Validated" after upload — no errors
- [ ] No unexpected warnings in validation report
- [ ] All submission sections show "Complete" before clicking Submit

---

## Sign-off

Before clicking Submit / Resubmit — confirm:
> "I have completed every item on this checklist. The app has been installed and tested as a real user would experience it."
