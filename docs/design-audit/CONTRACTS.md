# Contracts — the shared-structure index

**Created 20 September 2026.** ⭐ **This is an INDEX POINTING AT TESTS, not a description.**
⛔ **It cannot drift without something going red** — every row marked TESTED names a file, and
that file fails when the invariant is violated.

⚠️ **NOTHING HERE IS DUPLICATED FROM ELSEWHERE.** `ARCHITECTURE.md` says what the app IS,
`DATA-MODEL.md` says what the schema IS, the register says what was DECIDED and why. **This says
only what must remain TRUE and what checks it.** One provenance claim in this repo already
needed correcting in four files because it was duplicated prose; this index does not repeat a
rule's reasoning, it points at it.

## ⛔ The three outcomes, and none is a lesser form

| outcome | what it means |
|---|---|
| **TESTED — behaviour** | a test drives the app and fails when the invariant breaks |
| **TESTED — source scan** | a test reads the source and fails when the invariant breaks. ⭐ **Real enforcement** — it is how the `exportScope` count guard, the save-location label pair and the `.visible` manifest work, and it catches things no behavioural test can see |
| **CONVENTION, not enforced** | ⛔ **no available instrument can check it.** Carries a date and the reason. ⚠️ **Not "nobody got round to it"** — that is a gap, and gaps get built |

---

## The fourteen

| # | structure | invariant — what must remain TRUE | outcome | checked by |
|---|---|---|---|---|
| **1** | home banner chain | Only ADVISORY content may occupy the exclusive chain; anything describing data at risk, or an event in progress, stacks above it | **TESTED — source scan** | `sweep_contracts_test` |
| **2** | `.visible` readers | Only History's list may exclude hidden records; every site that filters carries its classification — render · integrity · reconciling · **routing** | **TESTED — source scan** | `visible_manifest_test` |
| **3** | `FilterKind` | Membership of `activeFilters` is restricted to states the user SET and can CLEAR | **TESTED — source scan** | `sweep_contracts_test` |
| **4** | `HiddenView` | The default withholds hidden records; every state is reachable from Filters and every hidden record restorable from `only`; a non-default view joins `activeFilters`, a record's `hidden` flag never does | **CONVENTION**, 20 Sep 2026 | verified by hand — see note A |
| **5** | `_HomeMenuAction` | No data-out path appears in the overflow; export and backup live behind *Your data* | **CONVENTION**, 20 Sep 2026 | note B |
| **6** | type scale | No widget specifies a font size or weight numerically; every one resolves through `MERType` | **TESTED — source scan** | `type_system_test` |
| **7** | colour tokens | No widget names a colour directly; every colour resolves to a token | **TESTED — source scan** | `colour_system_test` test 12 — ⭐ **was already enforced; see note G** |
| **8** | spacing scale | Every screen's horizontal body inset is 0, 16 or 24; 24 is reserved to the walkthrough | **CONVENTION**, 20 Sep 2026 | note C — **coverage 2 of 12** |
| **9** | CSV columns | Any change to the column set, or to what a cell holds for the same stored state, bumps the shape marker | **TESTED — source scan** (column set only) | `sweep_contracts_test` ⚠️ **half the rule is convention — note D** |
| **10** | Help rows | Help never describes behaviour the app does not have | **CONVENTION**, 20 Sep 2026 | note E |
| **11** | SQLite migrations | Every step is additive, non-destructive and independently guarded, so a database at any version walks forward correctly in one open | **TESTED — source scan** | `migration_contract_test` |
| **12** | backup envelope keys | A restore is never partially applied, and existing records always win | **TESTED — behaviour** (that clause) · **CONVENTION** (the key set) | `restore_outcomes_test` · note F |
| **13** | save-location copy | Both sheets render the same label on the same platform, and no label promises an affordance the platform lacks | **TESTED — source scan** | `save_location_label_test` |
| **14** | export scope | Every completeness claim reads `ExportScope`; a clearability claim must not | **TESTED — behaviour + source scan** | `show_hidden_scope_test` |

---

## The convention notes

⭐ **Each names the DISTINCTION it guards and the MISREADING it prevents. None asserts
compliance** — a label that says "this holds" is the defect these notes exist to avoid.

### A — `#4` HiddenView

**Verified by hand on 20 September 2026 and found to hold on all four clauses.** ⛔ **Not tested,
because the fourth clause is the only interesting one and it is already covered from the other
side:** `sweep_contracts_test` asserts `activeFilters` never reads a record's `hidden` flag,
which is the same distinction seen from `#3`.

⚠️ **THE MISREADING IT GUARDS: a record's `hidden` FLAG and a `HiddenView` the user SELECTED are
two different objects wearing the same word.** The view is clearable from the Filters sheet; the
flag is not. ⭐ **Anyone "simplifying" these into one concept removes the distinction that makes
the banner's claim true.**

### B — `#5` menu actions

⛔ **No instrument can tell a data-out path from a navigation item.** *Your data*, *History* and
*Export CSV* are all `PopupMenuItem`s; only a reader knows which one produces a file.

⚠️ **THE MISREADING IT GUARDS:** the menu once held Export CSV, Back up now and Restore as three
of six flat items with no grouping — **and nothing distinguished the file that CAN be read back
from the one that cannot**, so someone wanting to preserve their history could pick the wrong
one. ⭐ **The grouping is the safety property, not tidiness.**

### C — `#8` spacing scale — ⛔ COVERAGE IS 2 OF 12

**Enforced, by render measurement:** `event_wizard` · `log_event` — both put the body padding on
the scroll host, so the viewport frame excludes it and the inset is readable.

⛔ **NOT enforced, and named so the figure cannot be read as a rule:** `home` · `history` ·
`disclaimer` · `help` · `your_data` · `about` · `conditions` · `vocabulary` · `medication` ·
`walkthrough`.

⚠️ **THE REASON, AND IT IS A REAL LIMIT RATHER THAN AN OMISSION: "a screen's horizontal body
inset" is not a readable property.** It is a structural fact about WHICH `Padding` is the body's,
and both available instruments get it wrong — a source parse mistakes an inner card's padding
for the body's, and a render measure returns the SUM of every inset down to the content. ⭐ **A
screen whose body `Padding` wraps its `Scrollable` reads 14 from the render while its source says
16, and both numbers are honest about different things.**

### D — `#9` the half that cannot be checked

**The column SET is pinned to the marker.** ⛔ **What a cell HOLDS for the same column is not.**
⚠️ **THE MISREADING IT GUARDS: a green test here does NOT mean the marker is correct** — it means
the columns have not changed since the marker was pinned. A change to a cell's value convention
still requires a bump, and nothing will tell you.

### E — `#10` Help rows — the mechanism was costed and NOT taken

⭐ **The claims register was costed, as the brief required.** `_HelpRow` is a named-parameter
widget, so the mechanism is **~30 lines**: one required `claim:` parameter, plus a source scan
asserting no row omits it.

⛔ **THE COST IS NOT THE MECHANISM. IT IS THE 28 JUDGEMENTS** — each row read against the code to
decide whether it makes a behavioural claim and, if so, what makes that claim true. ⭐ **Those
judgements ARE the audit**, and doing them inside a batched close-out would produce 28 hasty
answers and a green test asserting they were considered.

⚠️ **RECOMMENDED AS ITS OWN PASS, attached to the Help accessibility audit already in the
queue.** ⛔ **Until then this is a convention, and two defects this week were exactly this
class** — *"Show hidden brings it back"* and *"deleting asks you to confirm first"*, both
describing behaviour the app did not have. **In a capture tool, a user believing a record is
recoverable when it is not is the worst copy defect available.**

### G — `#7` colour was ALREADY enforced, and the sweep got it wrong

⛔ **Brief 60 reported this structure as unenforced and as a third instance of the `backupShare`
class. That was FALSE.** `colour_system_test` test 12 has scanned `lib/` for colour literals the
whole time, and is stronger than the scan built to replace it — chromatic literals fail outright,
neutral ones are allowlisted **with their measured contrast**, and a **stale** allowlist entry
fails too.

⚠️ **THE MISREADING IT GUARDS, and it is about searching rather than about colour: a test named
for the RULE it enforces is invisible to a search keyed on what it SCANS.** ⭐ Test 12 is called
*"rule 2 is enforced over lib/, not described"* — it contains neither the phrase that was searched
for nor a literal `Color(0x`, because it builds its pattern from a variable. **Enumerate what is
there; do not search for what you expect to find.**

### F — `#12` the envelope key SET

**Tested:** that a restore is never partially applied, and that existing records always win.

⛔ **Not tested: that the key set is append-only.** ⚠️ **THE MISREADING IT GUARDS: `schemaVersion`
in the envelope looks like it makes this safe and does not.** It lets a reader DETECT a shape it
does not know; it does not stop a key being renamed or removed, and a backup file outlives the
build that wrote it. ⭐ **The honest position is that compatibility rests on nobody renaming a
key, and the version field would only tell you afterwards.**
