# Google Play Submission Checklist — Medical Event Recorder

**Created 14 October 2026 (Brief LP-MER2, CR-47).** Until this date the repo had no Google Play
submission document (Brief LP-MER, CR-45).

Complete every item before submitting a build for review in the Play Console.
Do not submit until all boxes are checked.

⛔ **Every step below already existed in the repo's records, and each one names its source.**
Nothing here was invented for this checklist. Anything a Play release plausibly needs that
has no source in the repo is listed at the end, under "Unsourced, for the developer to
confirm", and is NOT a step until the developer confirms it.

---

## 1. Version

- [ ] **The next version code is read from `docs/BUILD-LEDGER.md`, not remembered and not
  inferred from `pubspec.yaml`.** Take the highest code in the table, add one, write the row,
  PUSH it, and only then build. The push is the allocation. Two builds must never share a
  version code.
  *Source: `docs/BUILD-LEDGER.md`, the rule block ("TWO BUILDS MUST NEVER SHARE A VERSION
  CODE", "THE PUSH IS THE ALLOCATION"), Brief 66, amended 21 September 2026.*
- [ ] **The row's commit is read from git at build time, with the tree clean,** and the row is
  corrected from that read after the build. A row whose commit was not corrected after its
  build is incomplete.
  *Source: `docs/BUILD-LEDGER.md`, the rule block (Brief 65 B-3) and the row 62 note.*
- [ ] **If the previous code under this version name never shipped, the name stays and only the
  code advances.**
  *Source: `docs/BUILD-LEDGER.md`, the row 62 note ("VERSION NAME STAYS 1.1.1").*
- [ ] **`applicationId` in `android/app/build.gradle.kts` matches the Google Play package
  `au.com.notiva.medicaleventrecorder` exactly.**
  *Source: the repo `CLAUDE.md`, "Package / Bundle IDs", "Before every build".*

## 2. Build

- [ ] **Built with `flutter build appbundle --release`.**
  *Source: the repo `CLAUDE.md`, "Build Commands".*
- [ ] **The ledger row's artefact column is filled from the AAB itself:** size, md5, signing
  key, and `versionCode` / `versionName` read from the bundle.
  *Source: `docs/BUILD-LEDGER.md`, rows 63 and 64, which record exactly these.*
- [ ] **No signing key is staged or committed** (`*.jks`, `*.keystore`).
  *Source: the repo `CLAUDE.md`, "Git Workflow".*

## 3. Store listing

- [ ] Store listing copy. Before submitting to any store, ask the developer for the current MER
  store listing pack (claude.ai project doc claude/MER-store-listing-pack.md). Apply every field
  marked APPROVED or REMOVE for that store, and only those. If a field is marked REMOVE and its
  replacement is DRAFT or absent, STOP and report. Do not delete a required field with nothing
  to put in it. REMOVE means replace, not blank. A field marked CHECK FIRST is applied
  only if its named check has been reported. Never write or reword listing copy here (D2: copy
  is decided by the chat half and lives in the pack, not here). Report which fields changed.
  *Source: CR-45 (Brief LP-MER, `3f08baf`), the same text as the Windows and iOS checklists.*

## 4. Submission

- [ ] **The developer uploads and submits, signed in to the Play Console.** The CLI does not
  upload: no Play credentials exist on the Windows machine, and none are to be created.
  *Source: Change Register, "No Play upload credentials on this machine, and none to be
  created — 30 September 2026 (Windows)" (Brief 274).*
- [ ] **The review screen's warnings and errors are read and recorded.** For 1.1.1 (64) it
  showed 1 warning and 0 errors: *"no deobfuscation file associated with this App Bundle"*.
  That warning is explained, not a defect, while the release build has
  `isMinifyEnabled = false`: there is nothing to deobfuscate.
  *Source: Change Register, "Android 1.1.1 (64) SUBMITTED TO PLAY PRODUCTION — 30 September
  2026" (Brief 278), and the CLI check beneath it.*
- [ ] **Know before submitting:** a release is withdrawable while in review ("Remove changes"),
  and NOT once rolled out. With managed publishing OFF, approval and publication are one
  event, and there is no manual go-live gate.
  *Source: the same Register entry (Brief 278).*

## 5. After submission

- [ ] **What the Play Console shows is recorded in the build's ledger row, "went where",
  dated, from a console read.** A Play Console upload leaves no trace in the repo, so nothing
  records it unless someone writes it down. Row 64 read *"Not uploaded"* for two days while 64
  was in review.
  *Source: `docs/BUILD-LEDGER.md`, row 64's annotation (Brief 313); Change Register, 30
  September 2026 ("A Play Console upload leaves no trace in the repo"; "The next record of
  either must come from the Play Console, not from the absence of news").*

---

## Unsourced, for the developer to confirm

These are NOT steps. No record in the repo establishes them as part of a Play submission.
Each is listed with what the records DO say, so the developer can confirm or discard it.

- **Data safety matches the app.** The repo holds no record of MER's own Play Data safety
  answers or of a check against them. The only Data safety text in the repo is about other
  apps (`docs/claude-ai-project-instructions.md`, the "only in the category" market-claim
  note). S30's App Privacy answer is SoundFind's, on the App Store, not MER's.
- **An Android device test of the AAB before upload.** Done for 63 and 64 (the Teclast P30,
  derived from the AAB with bundletool; `docs/BUILD-LEDGER.md` rows 63 and 64, Brief 237),
  but recorded as what happened, not as a rule. No Android device test checklist exists.
- **Track and rollout.** 64 went to the production track at full rollout, with no staged
  percentage (Brief 278). That records one release; no rule chooses the track or rollout.
- **Managed publishing.** Recorded as OFF for 64 (Brief 278); whether it should stay off is
  not decided anywhere.
- **The Play "DEX code optimisation" warning, Obfuscation 1%, "Fix by Feb 2027".**
  `docs/RELEASE-1.1.2.md` item 21, a relayed console read, not verified from the repo.
  Whether it must be checked or fixed before a given submission is not decided.
- **"Quick checks" in the Play Console.** Completed before 64's submission with nothing
  raised (Brief 278); recorded as what happened, not as a rule.
- **Release notes ("What's new") and screenshots.** No record covers them for Play. The
  listing-pack step covers listing copy only as far as the pack does.
- **Verifying the AAB's signature.** `tool/verify_release_signing.sh` has iOS and MSIX modes
  and no Android mode. Rows 63 and 64 record "BedLin upload key", but no verification step.

---

## Sign-off

Before submitting for review — confirm:
> "I have completed every item on this checklist, and I have decided each unsourced item
> above or deliberately left it."
