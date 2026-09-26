# Tier A restore fix — the RED before the fix

**Measured 26 September 2026, Windows, Flutter 3.41.7.** Before any fix existed.

These are the raw runner logs of the two tests that drive the REAL `onRestore`
(`test/restore_vocabulary_guard_closed_test.dart` and
`test/restore_vocabulary_guard_open_test.dart`, shared harness in
`test/support/restore_vocabulary_contract.dart`), captured from the same file
content that was committed, less the `skip:` line added afterwards.

They were committed SKIPPED, not red: a suite expected to be red cannot detect a
new red. The fix's commit removes the skip.

## What the red shows

- **Guard closed, schema 1 backup:** 4 findings. No row for the custom event
  type, observation or trigger a restored record uses. No row for a value on a
  record already on the device (the D-1 repair case).
- **Guard open, current schema, with a condition:** 2 findings. No row for the
  custom type, so its assignment to the restored condition is dropped.

## The controls that passed in these same runs

The confirm dialog appeared; the "Restored" snackbar appeared; the failed-write
banner was NOT up, so `_persist()` landed; every record's type, observations and
triggers were unchanged; the fixture's retired row was absent and the custom type
absent before the restore. D-2 and D-3 held, trivially, because today nothing is
created at all.

## The green control, run once and reverted

With the four missing rows created in setUp (after the "before" controls), both
cases went GREEN, 0 findings. The file was then restored and `cmp` confirmed it
byte-identical. The guard-open case assigned the type with no change to the
assignment loop — evidence for claim (a), that the ordering alone fixes the
dropped assignment. Summary lines of those two runs are at the end.

---

## Raw log: guard_closed (red)

```
00:00 +0: loading C:/dev/epilepsyrecorder/test/restore_vocabulary_guard_closed_test.dart
00:00 +0: [schema 1, guard closed] a restore through the real onRestore recreates the list entries its records use
    >>> [schema 1, guard closed] START
    >>> [schema 1, guard closed] 1 pumping HomeScreen
    >>> [schema 1, guard closed] 2 tapping Restore from a backup
    >>> [schema 1, guard closed] 3 confirming
    >>> [schema 1, guard closed] 4 reading storage
    >>> [schema 1, guard closed] 5 DONE, 4 finding(s)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: empty
  Actual: [
            'MISSING: no event_type row for "Staring spell (my own word for it)"',
            'MISSING: no observation row for "Metallic taste before it starts"',
            'MISSING: no trigger_option row for "Strobe lights at the gym"',
            'MISSING: no observation row for "Left behind by an earlier restore"'
          ]

  MISSING: no event_type row for "Staring spell (my own word for it)"
  MISSING: no observation row for "Metallic taste before it starts"
  MISSING: no trigger_option row for "Strobe lights at the gym"
  MISSING: no observation row for "Left behind by an earlier restore"

When the exception was thrown, this was the stack:
#4      registerRestoreVocabularyCase.<anonymous closure>.<anonymous closure> (file:///C:/dev/epilepsyrecorder/test/support/restore_vocabulary_contract.dart:297:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///C:/dev/epilepsyrecorder/test/support/restore_vocabulary_contract.dart line 297
The test description was:
  a restore through the real onRestore recreates the list entries its records use
════════════════════════════════════════════════════════════════════════════════════════════════════
00:01 +0 -1: [schema 1, guard closed] a restore through the real onRestore recreates the list entries its records use [E]
  Test failed. See exception logs above.
  The test description was: a restore through the real onRestore recreates the list entries its records use
  
00:01 +0 -1: Some tests failed.

```

## Raw log: guard_open (red)

```
00:00 +0: loading C:/dev/epilepsyrecorder/test/restore_vocabulary_guard_open_test.dart
00:00 +0: [current schema, guard open] a restore through the real onRestore recreates the list entries its records use
    >>> [current schema, guard open] START
    >>> [current schema, guard open] 1 pumping HomeScreen
    >>> [current schema, guard open] 2 tapping Restore from a backup
    >>> [current schema, guard open] 3 confirming
    >>> [current schema, guard open] 4 reading storage
    >>> [current schema, guard open] 5 DONE, 2 finding(s)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: empty
  Actual: [
            'MISSING: no event_type row for "Staring spell (my own word for it)"',
            'ASSIGNMENT DROPPED: with no row, "Staring spell (my own word for it)" cannot be
assigned to "Epilepsy"'
          ]

  MISSING: no event_type row for "Staring spell (my own word for it)"
  ASSIGNMENT DROPPED: with no row, "Staring spell (my own word for it)" cannot be assigned to
"Epilepsy"

When the exception was thrown, this was the stack:
#4      registerRestoreVocabularyCase.<anonymous closure>.<anonymous closure> (file:///C:/dev/epilepsyrecorder/test/support/restore_vocabulary_contract.dart:297:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///C:/dev/epilepsyrecorder/test/support/restore_vocabulary_contract.dart line 297
The test description was:
  a restore through the real onRestore recreates the list entries its records use
════════════════════════════════════════════════════════════════════════════════════════════════════
00:01 +0 -1: [current schema, guard open] a restore through the real onRestore recreates the list entries its records use [E]
  Test failed. See exception logs above.
  The test description was: a restore through the real onRestore recreates the list entries its records use
  
00:01 +0 -1: Some tests failed.

```

## Green control summaries (fixture pre-seeded, reverted)

```
    >>> [schema 1, guard closed] 5 DONE, 0 finding(s)
00:01 +1: All tests passed!
    >>> [current schema, guard open] 5 DONE, 0 finding(s)
00:01 +1: All tests passed!
```
