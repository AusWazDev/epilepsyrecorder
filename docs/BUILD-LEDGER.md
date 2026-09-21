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
| 60 | 1.1.0 | the tree that became `d8e0a1d` | 20 Sep 2026 | release APK | Teclast P30 — **current** | — |
| 61 | 1.1.1 | `f00a54d` ✅ **exact, tree clean** | 20 Sep 2026 | release APK, 73,718,998 B, md5 `9cba274a030d8ace6c09489e5a8addd7` | ⛔ **nowhere** — on disk only, not installed | — |

### ⭐ Row 59 is the reason this file exists

**It is the row that was missing.** Code 59 was bumped, built, installed on the tablet, found
defective *on the device* — a checkmark superimposed on a type glyph, invisible to every test —
and superseded by 60 within the same pass, **all before any commit.** So:

- it appears **nowhere** in `pubspec.yaml`'s history;
- its source tree is **not recoverable from git**, because it was never committed;
- and "highest code in git history" would have handed it back out as unused.

⛔ **A build that reached a device and whose source state cannot be reconstructed is the worst
case this ledger records, and it is four days old.**

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
> `pubspec.yaml`.** Take the highest code in the table above, add one, and add the row **before**
> the build rather than after.
>
> ⚠️ **A code is USED the moment an artefact is produced with it** — not when it is committed,
> not when it is installed. A build that is superseded five minutes later has still used its
> code, and row 59 is what that looks like.

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
