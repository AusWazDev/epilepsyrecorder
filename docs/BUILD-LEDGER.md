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
