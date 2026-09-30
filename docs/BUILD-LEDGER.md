# Build ledger

**Created 21 September 2026 (AEST), Brief 66 Part A.**

⭐ **THIS IS A RECORD, NOT A GUARANTEE.** It enforces nothing. A ledger can be forgotten, and if
it is, the next build takes a code from memory again — which is the failure it exists to answer.
A proposed enforcement is at the end of this file; **it is proposed, not built.**

---

## Why it exists

⛔ **`Two builds must never share a version code` was a convention with no ledger.**

There is no way to read the next unused code. The obvious sources are both wrong:

| source | why it is wrong |
|---|---|
| `pubspec.yaml` git history | records codes that were **SET IN A COMMIT**, not codes that were **BUILT**. Code **59** was built and installed and appears nowhere in it |
| the installed build on a device | records the code of **one** artefact, and says nothing about codes used for builds that went elsewhere or nowhere |

⚠️ **AND THE RULE HAS ALREADY BEEN BROKEN, TWICE, AND EACH TIME IT WAS NOTICED AND WRITTEN DOWN
WITHOUT A LEDGER RESULTING:**

> `captures/INDEX.md`, 8 September 2026 — *"`versionCode 53` — ⛔ **UNCHANGED from the previous
> install, so the version string cannot tell the two builds apart.**"*
>
> `captures/INDEX.md`, 11 September 2026 — *"`versionCode 53` — ⛔ **unchanged again**, so the
> version string cannot tell this build from the 8 September one"*

⭐ **Three builds carried code 53, from at least two different commits, onto the same device.**
Each time the ambiguity was recorded in the capture index — the right observation, filed where
nothing would act on it. **The observation was never the missing piece; a place to put it was.**

🔴 **AND THE RULE ITSELF IS NOT IN THIS REPOSITORY.** Checked 21 September 2026 over **527
tracked files**: zero hits for the rule in any form. It lives only in the briefs. The one related
mention in the repo is a passing clause inside a comment about **MSIX packaging** — *"on Android,
two builds sharing a version is how a pre-migration state was read as a completed migration"* —
which records the CONSEQUENCE, under a different subject, where nobody setting an Android version
code would look. ⚠️ *Control on that null: the same search finds `escape clause` 3× in
`WORKING-AGREEMENT.md` and a known-absent phrase 0×.*

---

## ⛔ Where this ledger's knowledge begins

**Complete records begin at code 58, 20 September 2026.** Those were made in a session that
recorded them as they happened.

**Two earlier entries are backfilled** because they are independently evidenced in
`captures/INDEX.md` with commits, dates and install evidence.

⛔ **EVERYTHING BEFORE THAT IS NOT ESTABLISHED AND IS NOT GUESSED AT.** Codes 1–57 were *set* in
commits; whether each was built, and where any artefact went, is recorded nowhere. **They are
absent from the table below rather than reconstructed** — a ledger that quietly guesses at its
own history is worse than one that starts today and says so.

⚠️ **CONSEQUENCE, STATED: this ledger cannot answer "has code 42 ever been built?"** It can
answer that question from 58 onward. For anything earlier the honest answer is *unknown*, and the
safe behaviour is to take a code above the highest ever recorded anywhere.

---

## The ledger

| code | name | built from | date (AEST) | artefact | went where | superseded |
|---|---|---|---|---|---|---|
| 3 | 1.0.2 | ⛔ **NOT RECORDED** — the commit Play's build came from was never written down. The Android-relevant candidates carrying `1.0.2+3` are `192ae40` (6 May 04:37, the iOS submission), `4d1514a` and `0468e6f` (6 May, CR-43 Android notification changes); HEAD on 10 May was `2d171ca` (7 May, screenshots only), whose `lib/` and `android/` are `0468e6f`'s. **Unresolved** | 10 May 2026 (submitted) | release AAB, Play App Signing (almost certainly Google-generated key, Brief 245). ⚠️ A 51,795,210 B AAB dated 10 May sat in `build/` (Brief 220 listing) and has since been overwritten; no hash exists | **Google Play production**, live 13 May 2026 (backfilled from the Change Register) | — |
| 3 | 1.0.2 | ⛔ **TEST-ONLY REBUILD, NEVER DISTRIBUTED** (Brief 247, 29 Sep 2026). Built from `2d171ca` in a separate worktree, as the most probable tree of Play's 10 May build. **Shares code 3 deliberately, by chat's decision:** it stands in for Play's 1.0.2 in the 1.0.2 → 64 upgrade test, and a different code would make it not what it stands in for. Distinguished from the row above by hash. Toolchain: Flutter 3.41.7 / Dart 3.11.5 (NOT Play's engine, which is unrecorded), JDK 21, Gradle 8.13, AGP 8.11.1, Kotlin 2.2.20. `pubspec.lock` moved only `matcher` and `test_api` (test-only) | 29 Sep 2026 | release AAB, 51,796,969 B, md5 `0e9bfdf677dc43b559764a7399163c3b`, BedLin upload key `b2b46bd5…ee752f5`, `versionCode=3 versionName=1.0.2`, minSdk 24, targetSdk 36, no `allowBackup` attribute (defaults true, as 1.0.2 did). Device splits derived with bundletool 1.18.3 for the Teclast: set sha256 `11681d931c5bcbafa23bbff991030b2ffdee03f51756ac1ba276605811e5abaa`; `base-master` md5 `661ddcad08d218c2606a140ec83cca42` · `base-arm64_v8a` md5 `beee8794bdc7ca93fcd99731f3d194c0` · `base-en` md5 `593948c56e7a159e91d5bf6bd072adb5` · `base-tvdpi` md5 `bbda60eb4da27ed19dc75307f7f4b246`. Durable copy: `OneDrive\Projects\App Dev\MER builds\3-rebuild-TEST-ONLY\` | Teclast P30 only | — |
| 5 (**iOS**) | 1.0.3 | `4c18dd7` (4 June 2026, the TestFlight 1.0.3 (4) commit) in a separate worktree (`~/dev/mer-103-rig-worktree`), **written after the build, not allocated before it** (Briefs 263 and 264, 29 Sep 2026). ⭐ **THE 1.0.2-EQUIVALENT MIGRATION RIG, NOT A RELEASE.** `4c18dd7` predates `824cd16` (App Group on Runner/Release) and is not its ancestor. Changes from `4c18dd7`: the `pubspec.yaml` version line `1.0.3+4` → `1.0.3+5` (the ONLY source change), and `pubspec.lock` moved `matcher` 0.12.18 → 0.12.19 and `test_api` 0.7.9 → 0.7.10 because the current `flutter_test` pins them; the dependency graph puts neither in the release closure, and the resulting lock is byte-identical to shipped 1.0.2's (`192ae40`). Podfile.lock unchanged. ⚠️ **Built with the CURRENT SDK** (Flutter 3.41.7 / engine `59aa584fdf`, Xcode 26.3 17C529, iphoneos26.2), which matches what shipped 1.0.2's binary records. ⛔ **`4c18dd7` NEVER SHIPPED AS +5, nor with these package versions** | 29 Sep 2026, 22:03–22:08 (archive and export) | App Store IPA, 9,030,414 B, sha256 `a5bd84a252c503f17df56c7f1e971f6a85e5de30e7e215d1d00f5425f701e3df`; archive manifest (91 files) sha256 `3c85b6a00c267736eb0558841e00ac97faf1cf1b0c5649aac8fbf63d00b9841d`. Signed `Apple Distribution: NOTIVA (B7LWF6Z674)`, `get-task-allow` false; profiles Runner `c05df5d0-3e4a-463d-98dc-4017e8f5e739`, MERWidget `6a42b885-2a1f-455c-a8e4-f7b5713297ac`. ⭐ **APPARATUS CONTROL, read from the exported IPA's signatures (re-read 30 Sep 2026 with a plist parser, positive control: row 64 iOS's Runner shows the group): Runner carries ZERO `application-groups`; MERWidget carries `group.au.com.notiva.medicaleventrecorder`. This held even though Runner's profile `c05df5d0` GRANTS the group, so signing did not attach it.** That asymmetry is what shipped 1.0.2 looked like and is what makes the rig valid. dSYM UUIDs: Runner `281D6120-20B7-34C6-8D26-F714C3DFEC70`, MERWidget `74F47205-D5BD-3C52-BAF4-C09A02636232`, App `5CCF6C4B-AEE0-3035-A457-3E023F678A3B`, Flutter `4C4C44B2-5555-3144-A163-48D7137E0BCF`. ⚠️ **MERWidget carries 1.0.1 (2)** against the app's 1.0.3 (5); Apple warned 90473 on upload. Not a blocker; queued for 1.1.2. Durable copy: `~/dev/_artefacts/MER-1.0.3-5-ios-rig-b264-2026-09-29/` | **App Store Connect**, uploaded 29 Sep 2026 23:13–23:14 by altool with the API key (Brief 268), Delivery UUID `f74fccb2-06e3-4708-a7ef-9e2bf32b7c45`; at 23:18:06 `VALID`, internal and external `MISSING_EXPORT_COMPLIANCE` (no `ITSAppUsesNonExemptEncryption`; not resolved, a separate decision). Not distributed to any tester. ⚠️ **Its dSYMs reached Sentry UNINTENTIONALLY** (Brief 264): `4c18dd7` still has the "Upload dSYMs to Sentry" build phase later removed by `4cc50d3` | ⛔ **CODE 5 WAS ALREADY USED ON iOS BY A DIFFERENT ARTEFACT**: MER 1.1.0 (5) on Paula's iPhone 8 (Sentry `release_name` `au.com.notiva.medicaleventrecorder@1.1.0+5`, read from the 29 Sep baseline copy), source commit not recorded here and never in App Store Connect (Brief 267: builds 1–4 only). The row-53 class, across version strings |
| 53 | 1.1.0 | `97dfde0` | 8 Sep 2026 | release APK, real keystore | Teclast P30 | ⛔ code REUSED below |
| 53 | 1.1.0 | `c4220f2` | 11 Sep 2026 | release APK, 73,440,186 B, md5 `c80f4ca27289` | Teclast P30 | — |
| 58 | 1.1.0 | the tree that became `4ccce33` | 20 Sep 2026 | release APK | Teclast P30 | ✅ by 59, same day |
| **59** | 1.1.0 | ⛔ **NOT RECOVERABLE** — an uncommitted tree between `c4d5d0a` and `d8e0a1d` | 20 Sep 2026 | release APK | Teclast P30 | ✅ **by 60, same day — defect found ON THE DEVICE** |
| 60 | 1.1.0 | the tree that became `d8e0a1d` | 20 Sep 2026 | release APK | Teclast P30 | ✅ **by 62 on the device, 21 Sep 2026** |
| 61 | 1.1.1 | `f00a54d` ✅ **exact, tree clean** | 20 Sep 2026 | release APK, 73,718,998 B, md5 `9cba274a030d8ace6c09489e5a8addd7` | ⛔ **nowhere** — on disk only, not installed | — |
| **62** | 1.1.1 | `616c16d` ✅ **exact, tree clean, READ FROM GIT AT BUILD TIME** | 21 Sep 2026 | release APK, 73,702,682 B, md5 `d46aa4f22ff97a9d8ba933267286947e` | Teclast P30 — **current**, installed 21 Sep 2026, read back from the device as `versionCode=62 versionName=1.1.1` (was 60 / 1.1.0). ✅ **CONFIRMED BY HASH 28 Sep 2026 (Brief 224):** the installed `base.apk` pulled from the Teclast is 73,702,682 B, md5 `d46aa4f22ff97a9d8ba933267286947e`, sha256 `83af0a2f…7497920`, lastUpdateTime 2026-09-21 17:09:30, installer none (sideload via `com.android.shell`) | — |
| 62 | 1.1.1 | ⛔ **NOT RECORDED — found on disk 28 Sep 2026 (Brief 220), source commit unknown** | 24 Sep 2026 (file date) | release APK, 73,718,814 B, md5 `1b26f38be62d5f98670fb2d9823cc32b`, read back as `versionCode=62`, BedLin key | ⛔ **unknown**, except: ✅ **NOT the Teclast's install** (28 Sep 2026, Brief 224: the installed APK hashes to the row above, and the package has not been updated since 21 Sep) | ⛔ **a SECOND code-62 artefact**, the row-53 class; it differs from the row above in size |
| 63 | 1.1.1 | `ffa3a19` ✅ **exact, tree clean, READ FROM GIT AT BUILD TIME** (allocated against parent `6f3e7cd`) | 28 Sep 2026 | release **AAB**, 58,415,269 B, md5 `7626d085285ff3c0811af07a3c59c952`, BedLin upload key, `versionCode=63 versionName=1.1.1`, minSdk 24, targetSdk 36 | Not uploaded (Brief 220). ✅ **Teclast P30, 28 Sep 2026 22:52 AEST (Brief 231), installed IN PLACE over 62** (`install-multiple -r`; firstInstallTime 25 Aug and uid 10226 unchanged, data kept). ⭐ **Not the AAB itself: DERIVED FROM IT**, with bundletool 1.18.3 (Google's GitHub release, `bundletool-all-1.18.3.jar`, sha256 `a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29`, matching the release's published digest): `build-apks --device-spec` for THIS device (arm64-v8a, 213 dpi → tvdpi, en-US, API 35), so only the splits Play would serve it. Set `mer63-teclast.apks` 41,902,451 B, sha256 `657cb3f7…baabf456`. Splits installed: `base-master` 19,948,996 B md5 `819856b0f21bcea2b3b5978a7944dba0` · `base-arm64_v8a` 21,799,728 B md5 `561cfe599d115d0b6d643b75d220d65d` · `base-en` 41,306 B md5 `c16adcc622cc4e777dd7744163756282` · `base-tvdpi` 111,490 B md5 `9edf901bc9b94e86d04463636c220283`; all `versionCode=63`. ⚠️ **THE ONE DIFFERENCE FROM A PLAY INSTALL: SIGNED WITH THE UPLOAD KEY** (BedLin, `b2b46bd5…`), where Play would re-sign with its app-signing key if enrolled. Keystore passwords were passed to bundletool by file, not on the command line | ⛔ **by 64** — 63 carries the Android restore decoding defect (Brief 234 F) and cannot ship |
| 64 | 1.1.1 | `4da1751` ✅ **exact, tree clean, READ FROM GIT AT BUILD TIME** (allocated against parent `38bd6a0`). ⭐ **The only behavioural change from 63 is `38bd6a0`**, restore decodes UTF-8; `storage_boot` and `storage_migration` differ from 63 in comments only | 28 Sep 2026 | release **AAB**, 58,414,270 B, md5 `600dbf27d7bb97556a5fe93b9a709730`, BedLin upload key, `versionCode=64 versionName=1.1.1`, minSdk 24, targetSdk 36, `allowBackup=false` | Not uploaded. ✅ **Teclast P30, 28 Sep 2026 23:55 AEST (Brief 237), installed IN PLACE over 63** (`install-multiple -r`; firstInstallTime 25 Aug and uid 10226 unchanged, data kept). **Derived from the AAB** exactly as row 63: bundletool 1.18.3 (sha256 `a099cfa1…`), `build-apks --device-spec` for this device; set `mer64-teclast.apks` 41,902,451 B, sha256 `6b14cf79bc48584036b8fc6aae7b977da54c1c3b16efc31ee5f0e8b1d353ae3b`. Splits: `base-master` 19,948,996 B md5 `312aa70e40fae8d8f6b88cf5de263b35` · `base-arm64_v8a` 21,799,728 B md5 `f4401f225c7a1b02aa396119c1ae9cd7` · `base-en` 41,306 B md5 `e5953035553d3f528f06b670bdef779d` · `base-tvdpi` 111,490 B md5 `e1d3af9c0d84e38637e85c50e98ca489`; all `versionCode=64`. ⚠️ **Signed with the upload key, not Play's app-signing key** — the same one difference as 63. Keystore passwords by file, not on the command line. ✅ **RE-CONFIRMED FROM THE ARTEFACT, 29 Sep 2026 (Brief 239)**, decoded from the AAB itself (md5 `600dbf27…`), not from source: `allowBackup=false`; `dataExtractionRules=@xml/data_extraction_rules`; `root`, `file`, `database`, `sharedpref`, `external` excluded in both `cloud-backup` and `device-transfer`; no `hasFragileUserData`; minSdk 24, targetSdk 36; BedLin key `b2b46bd5…ee752f5` on the AAB and all four splits. ⭐ **The full decoded manifest differs from 63's in ONE line, `versionCode` 63 → 64, and the rules file is identical.** ⚠️ **NO DURABLE COPY OF THIS AAB:** it exists in `build/` (gitignored, overwritten by the next build) and in a session scratchpad. Copy it somewhere lasting and re-hash it against `600dbf27…` before any upload. ✅ **DURABLE COPY MADE 29 Sep 2026 (Brief 241A), copied from `build/` and re-hashed AFTER the copy:** `OneDrive\Projects\App Dev\MER builds\64\medical_event_recorder_1.1.1+64.aab` (58,414,270 B, md5 `600dbf27d7bb97556a5fe93b9a709730`) and `…\64\teclast-splits\` holding `mer64-teclast.apks` (sha256 `6b14cf79…`), the four splits (md5s as above, all matching) and `teclast-spec.json`. ⚠️ Local copy verified; the OneDrive CLOUD upload was not verified from here | — |
| 64 (**iOS**) | 1.1.1 | `65a9dcf` ✅ **exact, tree clean, level with origin, READ FROM GIT AT BUILD TIME** (Brief 261, 29 Sep 2026); `lib/`, `ios/` and `pubspec` identical to `af842ef`, so the only `ios/` change since the Android 64's `4da1751` is `4cc50d3` (Sentry build phase removed). ⚠️ **Written after the build, not allocated before it.** Release configuration, `flutter build ipa --release` | 29 Sep 2026, 21:39–21:44 | ⭐ **RELEASE CANDIDATE.** App Store IPA, 10,327,408 B, sha256 `ca9ff189b9d3f232a17e98937a914b4b3b3df45e80018ac6a03a720d79f026df`; archive manifest (96 files) sha256 `0eb0c145f2d731fd97b6a9f953aa6ddeb8a597de8d00d81bf2f99abc8f407d53`. Signed `Apple Distribution: NOTIVA (B7LWF6Z674)`, `get-task-allow` false, `ITSAppUsesNonExemptEncryption` false. Profiles: Runner `c05df5d0-3e4a-463d-98dc-4017e8f5e739` (iOS Team Store, created 29 Sep 2026, grants the App Group), MERWidget `6a42b885-2a1f-455c-a8e4-f7b5713297ac` (created 5 May 2026). **Both Runner and MERWidget carry `group.au.com.notiva.medicaleventrecorder`** (Blocker 2 closed from the binary). dSYM UUIDs: Runner `1961C066-3566-3566-AFED-8705D9D5A031`, MERWidget `BAA4472E-A354-34C6-A2F5-9EA77D6EED44`, App `5C46B4A2-354B-3C9B-BA0D-91D3B16676B4`, Flutter `4C4C44B2-5555-3144-A163-48D7137E0BCF`; `tool/upload_dsyms.sh --check` 4/4. ⚠️ **MERWidget carries 1.0.1 (2)** against the app's 1.1.1 (64); Apple warned 90473 on upload. Not a blocker; queued for 1.1.2. Durable copy: `~/dev/_artefacts/MER-1.1.1-64-ios-release-b261-2026-09-29/` | **App Store Connect**, uploaded 29 Sep 2026 23:14–23:15 by altool with the API key (Brief 268), Delivery UUID `b68f00cc-661c-496f-b91d-f456001d043d`; at 23:18:06 `VALID`, internal `READY_FOR_BETA_TESTING`, external `READY_FOR_BETA_SUBMISSION`. Not distributed to any tester, not submitted for review. ⚠️ **dSYMs NOT uploaded to Sentry** (a separate decision) | — |
| 65 (**iOS**) | 1.1.1 | `1b4e723` ✅ **exact, tree clean, level with origin, READ FROM GIT AT BUILD TIME** (Brief 301, 30 Sep 2026): `git rev-parse HEAD` and `git status --porcelain` were read immediately before `flutter clean` and again after the export, and both reads gave `1b4e723990c785e70a6132768a9e057f636c39ed` with an empty status, **so no drift**. Allocated and pushed BEFORE the build (Brief 300, decision 4 of 30 Sep) naming its PARENT `bf5a2ae`, the in-app copy correction; corrected here from the build-time read, per the procedure. The only change from 64's source is `lib/` user-facing copy (5 files; `main.dart` in a doc comment only) plus the version line. No storage, migration, schema or capture path. Release configuration, `flutter clean` then `caffeinate -dimsu flutter build ipa --release --export-options-plist=ExportOptions.used.plist` (the same export options as 64) | 30 Sep 2026, 16:32–16:39 | App Store IPA, 10,327,955 B, sha256 `3ec87d145ed9d078b18f01a9945b73b2763a17f374ea0353bc9fd682f611544b`; archive manifest (96 files) sha256 `19eb17d83ce59f3da41ce867b703240a1e7e3256eae2a8f595adc95eb32d6c3a`. Read FROM THE IPA: signed `Apple Distribution: NOTIVA (B7LWF6Z674)`, `get-task-allow` false, `ITSAppUsesNonExemptEncryption` false; profiles Runner `c05df5d0-3e4a-463d-98dc-4017e8f5e739`, MERWidget `6a42b885-2a1f-455c-a8e4-f7b5713297ac`; both carry `group.au.com.notiva.medicaleventrecorder`; entitlement plists of Runner and MERWidget **identical to 64's** by `diff`. dSYM UUIDs: Runner `9A37288D-2522-38F2-BF3C-77874E7C5F65`, MERWidget `BAA4472E-A354-34C6-A2F5-9EA77D6EED44`, App `BAB9D3FA-FCBD-375D-99A0-17AA63CC4B43`, Flutter `4C4C44B2-5555-3144-A163-48D7137E0BCF`; `tool/upload_dsyms.sh --check` 4/4. ⭐ **The corrected copy is in the binary**: UTF-16LE search of `App.framework/App` finds *"It is Delete App that removes the data, not Offload"* once in 65 and zero times in 64, with the old *"It is Delete App that destroys it"* the reverse, an unchanged string present in both, and a nonsense control absent from both. ⚠️ **MERWidget carries 1.0.1 (2)** against the app's 1.1.1 (65); queued for 1.1.2. Full suite at `1b4e723`: 1,072 passed, 6 failed, the two known Mac-only `checklist_citations_test` cases and four `a11y_batch_render_comparison` cases, which Brief 302 showed fail identically at `65a9dcf`, `bf5a2ae` and `1b4e723` (a host baseline issue, owned by 1.1.2). Durable copy: `~/dev/_artefacts/MER-1.1.1-65-ios-release-b301-2026-09-30/` | **App Store Connect**, uploaded 30 Sep 2026 17:34:53 AEST (ASC `uploadedDate` 2026-09-30T00:34:52-07:00) by **Transporter** (TransporterApp 1.4.5-14526, ContentDelivery 27.0.5 (3.26)), run by the developer; Delivery UUID `40456417-5d33-41e7-84dd-b6d09531f779`; `UPLOAD SUCCEEDED`, 0 errors, 2 warnings; at completion `PROCESSING`. ⭐ **The uploaded binary IS the verified IPA, not a re-export:** Transporter sends the file itself, and the delivery log's source path (`~/dev/_artefacts/MER-1.1.1-65-ios-release-b301-2026-09-30/ipa/Medical Event Recorder.ipa`) and byte count (10,327,955) are this row's artefact (sha256 `3ec87d14…544b`). **Independent hash of the same file, taken by Apple's own tooling:** MD5 `d1b47ea80be31234b9880c3d49b5d285` (composite `5b3b3ff27a5efd17f33918bbb4168eca-2-5242880`), both recomputed from the durable copy on 30 Sep 2026 and matching. ⚠️ Apple's validator raised 90473 again (2 warnings: MERWidget `CFBundleShortVersionString` 1.0.1 vs 1.1.1, `CFBundleVersion` 2 vs 65), as it did for rows 5 and 64. Known, and on the 1.1.2 list. ⚠️ **OBSERVATION, NOT EXPLAINED:** the `buildUpload` record `40456417-…` has `createdDate` 2026-09-29T23:39:17-07:00 (30 Sep 16:39:17 AEST), about 56 minutes before the Transporter run and within a minute of this row's export finishing (16:39:39); it was already `AWAITING_UPLOAD` when Transporter first queried at 17:32:47. What created it is not established. Not submitted for review, not attached to a version, export compliance not answered here. dSYMs NOT uploaded to Sentry | — |

### ⭐ Row 59 is the reason this file exists

**It is the row that was missing.** Code 59 was bumped, built, installed on the tablet, found
defective *on the device* — a checkmark superimposed on a type glyph, invisible to every test —
and superseded by 60 within the same pass, **all before any commit.** So:

- it appears **nowhere** in `pubspec.yaml`'s history;
- its source tree is **not recoverable from git**, because it was never committed;
- and "highest code in git history" would have handed it back out as unused.

⛔ **A build that reached a device and whose source state cannot be reconstructed is the worst
case this ledger records, and it is four days old.**

### ⭐ Row 62 is the first row written under the amended rule

⛔ **THE PUSH IS THE ALLOCATION, and this row was pushed BEFORE `flutter build` was invoked.**
Rows 53–61 were all written after their builds, which is the ordering the amendment of 21 September
reversed. ⚠️ **So this row exists in a state none of the others ever occupied: allocated, pushed,
and not yet built.** That is the intended cost recorded in `DECISIONS.md` — a pushed row with no
build still spends the code — and it is preferable to two hosts silently taking 62 at once.

⚠️ **VERSION NAME STAYS 1.1.1.** 61 carried 1.1.1 and went nowhere; the release has not shipped, so
the name has nothing to move past. ⛔ **Only the CODE advances, because only the code must never
repeat.**

⚠️ **AND THE ONE THING THE NEW ORDERING CANNOT DO, FOUND ON ITS FIRST OUTING.** When the row was
written, the commit that would carry it **did not yet exist**, so it necessarily named its PARENT,
`8e75804`. The build then came from `616c16d` — the allocation commit itself, because that is the
commit holding the `1.1.1+62` bump.

⛔ **So the row was written with a commit it was always going to be wrong about, and it was
corrected after the build from a git read at build time.** That is not a defect in the amendment; it
is the shape of writing a record before the thing it records. **The build-time read is what makes
the row true, and Brief 65 B-3 already required it** — what is new is that the pre-build row now has
a placeholder value in the interval, which a reader fetching mid-build would see.

⭐ **Recorded because the alternative is worse in both directions:** naming no commit until after the
build leaves the pushed row unable to say what it allocated against, and naming the parent silently
leaves a wrong hash that nothing re-derives.

### ⚠️ On "built from", and why three rows are hedged

**Only row 61 names a commit that is exactly what was built.** Brief 65 B-3 required the commit
to be read from git *at build time*, and that pass committed first and built second, with the
tree clean — so `f00a54d` is the artefact's source state, not an approximation of it.

⭐ **Rows 58 and 60 say "the tree that became" deliberately.** In both, the build was made before
the commit, from a working tree that also held changes the commit later swept up. The `lib/`
content matched what was committed; the tree as a whole did not. **That distinction is invisible
afterwards, which is why it is written down now rather than tidied into a commit hash.**

### ⚠️ The first iOS rows, and what they do not settle

*Added 30 September 2026, Brief 275.* **Until this date every row was Android.** The two rows marked
**iOS** record `CFBundleVersion`, iOS's build number, in the code column. ⛔ **This file does not say
whether "two builds must never share a version code" spans platforms.** iOS 64 now sits beside
Android 64, from different commits, and the table records both without deciding whether that is a
collision. ⭐ **Within iOS alone it is decided, and it failed:** build number 5 was used by 1.1.0 (5)
on Paula's iPhone before the rig took it. Apple accepted the rig anyway, so App Store Connect is not
a check on this rule either; it knows only the builds uploaded to it.

⚠️ **Both iOS rows were written AFTER their builds**, against the push-is-the-allocation rule above.
Recorded, not repaired.

#### ⭐ DECISIONS, 30 September 2026 (Brief 277)

*The paragraph above says this file does not settle the platform question. That was true when it
was written and is left as written; these decisions settle it.*

1. **The version-code rule does NOT span platforms.** Android's `versionCode` and iOS's
   `CFBundleVersion` are separate namespaces, enforced by separate stores. Global uniqueness would
   buy nothing.

2. ⭐ **THE RULE THAT DOES SPAN PLATFORMS: when the same code appears on two platforms, it means the
   SAME SOURCE.** Identical `lib/`, `pubspec.yaml` and `pubspec.lock`; only platform directories may
   differ. **This is the rule going forward**, not an observation about two rows. iOS 64 and
   Android 64 satisfy it: `git diff 4da1751 65a9dcf -- lib pubspec.yaml pubspec.lock` is empty
   (re-checked 30 Sep 2026; the same command over `ios/` shows `4cc50d3`'s 15 deleted lines, so it
   can see a difference), as Brief 259 C5 found.

3. **The iOS code-5 reuse stands, uncorrected.** It collides with nothing that enforces uniqueness:
   App Store Connect never saw 1.1.0 (5). ⚠️ **ITS CAUSE: the rig's build number was chosen without
   consulting this ledger, because the ledger had no iOS rows.** This file is the fix.

4. ⛔ **From now on, iOS build numbers are allocated from this ledger the way Android's are:** read
   the highest iOS code here, add one, write the row, push it, and only then build.

---

## The rule, and where it now reads its answer

> ⛔ **TWO BUILDS MUST NEVER SHARE A VERSION CODE.**
>
> ⭐ **The next unused code is READ FROM THIS FILE, not remembered and not inferred from
> `pubspec.yaml`.** Take the highest code in the table above, add one, **write the row, PUSH
> it, and only then build.**
>
> ⛔ **THE PUSH IS THE ALLOCATION.** Not the build, not the commit — the moment the row
> reaches `origin`. ⚠️ **AMENDED 21 September 2026**, hours after this file was created. It
> read: *"add the row **before** the build rather than after"* — correct for one host and
> insufficient for two, because a row that is written and not pushed is a code that looks
> free to every other clone.
>
> ⚠️ **A code is USED the moment an artefact is produced with it** — not when it is committed,
> not when it is installed. A build that is superseded five minutes later has still used its
> code, and row 59 is what that looks like.
>
> 🔴 **WITH MORE THAN ONE HOST BUILDING, THE PUSHED ROW IS WHAT SPENDS THE CODE.** ⛔ **An
> unpushed row is invisible to every other clone**, so two hosts reading this table can both
> see the same highest code and both take it. ⭐ Row 59 is the single-host version of that
> failure — a code spent with nothing recording it — and a second machine does not add a new
> failure mode, it adds a second hand to the existing one.
>
> ⚠️ **AMENDED 21 September 2026. This clause read:** *"AND WITH MORE THAN ONE HOST BUILDING,
> THE ROW IS WRITTEN AND PUSHED BEFORE THE NEXT CODE IS ALLOCATED"* — which described the
> same sequence while still treating allocation as something the build does.
>
> ⭐ **ADDED 21 September 2026, from row 62, the first row written under the amended rule.
> A ROW PUSHED BEFORE ITS BUILD NAMES ITS PARENT COMMIT, because the allocation commit does
> not exist when the row is written. IT IS CORRECTED FROM THE BUILD-TIME GIT READ AFTERWARDS,
> AND THAT CORRECTION IS PART OF THE PROCEDURE, NOT A REPAIR.** ⚠️ **This is the shape of
> writing a record before the thing it records — not a defect in the ordering.** ⛔ **So a row
> whose commit has not been corrected after its build is INCOMPLETE, not merely untidy**, and
> Brief 65 B-3's build-time read is what closes it.
>
> ⚠️ See `docs/WORKING-AGREEMENT.md` §2B rule (h), which carries the same obligation from the
> session's side rather than the ledger's.

⚠️ **STATED IN THIS REPOSITORY FOR THE FIRST TIME, 21 September 2026.** Brief 66 asked that the
existing rule be annotated to point here rather than restated. **There was no existing rule in
the repo to annotate** — the search above found zero occurrences across 527 tracked files. So
this is the first statement of it, placed with the ledger it depends on. ⛔ **If a second copy
appears elsewhere later, that copy should point here rather than restate this.**

---

## ⚠️ What this file does NOT do

⛔ **It does not enforce anything.** Nothing reads it, nothing fails when it is stale, and a build
made without adding a row succeeds exactly as before. **Do not read the existence of this file as
a guarantee that every build since 20 September is in it.**

### A cheap enforcement, PROPOSED and not built

Brief 66 Part A asks for a proposal and an explicit stop, so this is a proposal.

**A pre-build check: the code about to be built must be ABSENT from this ledger.**

- read `version:` from `pubspec.yaml`, parse the codes out of this file's table, and fail if the
  code already appears;
- it would have caught **53's second and third builds** outright;
- it would **not** have caught 59, because 59 was genuinely unused when it was built. ⭐ **59's
  problem was never a collision — it was that nothing recorded the code as spent afterwards.**
  Catching that needs a check on the other side: a build that writes its own row.

⚠️ **So the honest scope of the proposal: a pre-build collision check is cheap and catches the 53
class. The 59 class needs the build to record itself, which is a bigger change and a separate
decision.** ⛔ **Neither is built here.**
