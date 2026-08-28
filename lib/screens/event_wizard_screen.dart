import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/event_record.dart';
import '../models/vocabulary.dart';
import '../models/vocabulary_store.dart';
import '../theme/mer_theme.dart';

/// Guided detail entry: one section per screen, a summary before saving.
///
/// ## Why it exists
///
/// A quick-recorded event carries a timestamp and nothing else — no duration,
/// no type anyone chose. The single-page form can supply those, but it is a
/// dense screen at the moment someone is least able to work through one. This
/// is the calm path.
///
/// ## Nothing is gated
///
/// Skip is on every step including the first, Back works from every step after
/// it, and abandoning keeps whatever exists. Force-quitting mid-wizard lands the
/// user in a working app with a partial record, not back at step one.
///
/// ## It is downstream of capture, never in it
///
/// Nothing here runs on the capture path. `_quickRecord` and the notification
/// build a record and return; this screen is only ever reached by an explicit
/// tap afterwards.
class EventWizardScreen extends StatefulWidget {
  const EventWizardScreen({super.key, this.existing});

  /// Null for "Record with details" — nothing exists until the first Next.
  final EventRecord? existing;

  @override
  State<EventWizardScreen> createState() => _EventWizardScreenState();
}

/// Whether the duration step has an answer already, and whether that answer is
/// one this control can show.
///
/// THE TRAP THIS EXISTS FOR: a legacy record has a bucket and no seconds. To a
/// naive `duration != null` check it looks answered — and it is not answerable
/// in a minutes-and-seconds control, because "1-5 minutes" contains no number.
/// Skipping it would silently deny those records the one step that could give
/// them a real quantity.
enum DurationAnswer {
  /// Seconds present. The only case that skips.
  measured,

  /// A legacy range and no number. ASKS, with the range shown as context.
  bucketOnly,

  /// Nothing. Asks.
  none,
}

/// Whether [r] should open in the guided wizard rather than the single page.
///
/// ONE definition for all three entry points — the Last Event card, a History
/// row, and the notification tap — because three copies of `== false` scattered
/// across two files is exactly the drift a test cannot see.
///
/// TWO reasons to route here, and the second was added with the "Needs
/// details" filter:
///
///   1. `detailsCompleted == false` — a PARTIAL. Someone started and stopped.
///   2. [isIncomplete] — a duration, type or severity is still unset,
///      WHATEVER the flag says.
///
/// ⚠️ **THE SECOND EXISTS BECAUSE OF THE FILTERED LIST.** That list is what a
/// user works through to COMPLETE their history, and sending them from it into
/// the dense single page is sending them to the screen the guided flow was
/// built to replace, for the population it was built for.
///
/// It also fixes a gap the flag alone could not: a record can be
/// `detailsCompleted == true` with every field null — open the wizard, Skip to
/// end, Save — and that record would have routed to the form while appearing
/// in a list of incomplete ones.
///
/// `true` AND complete still opens the single page: stepping a finished record
/// through four screens to change one field would be worse than the form.
/// `null` and complete does too — it predates the concept and has nothing
/// missing.
bool wantsWizard(EventRecord r) =>
    r.detailsCompleted == false || isIncomplete(r);

DurationAnswer durationAnswerOf(EventRecord? r) {
  if (r?.durationSeconds != null) return DurationAnswer.measured;
  if (r?.duration != null) return DurationAnswer.bucketOnly;
  return DurationAnswer.none;
}

/// The first step carrying a question this record has not answered.
///
/// ## Why it exists
///
/// The "needs details" filter turns History into a WORK QUEUE, and a queue
/// that re-asks what is already recorded is the fastest way to make it feel
/// like a chore. A legacy record typically has feelings and triggers but no
/// type and no severity; walking it through all four steps would ask three
/// questions it already knows the answer to.
///
/// ## Only steps 0 and 1 are skippable, and the reason is not symmetry
///
/// Duration, type and severity have an ABSENT state — null means not asked.
/// Feelings and triggers do not: an empty list is an ANSWER, "nothing
/// beforehand" is data, and there is no way to tell it from "not asked". So
/// steps 2 and 3 can never be skipped, and a record with everything answerable
/// already answered opens on step 2 rather than jumping to the summary.
///
/// ⚠️ **THE LEGACY-DURATION TRAP, AND WHY IT HAS NO TWIN.** A record with a
/// bucket and no seconds LOOKS answered and is not answerable in a
/// minutes-and-seconds control — "1-5 minutes" contains no number — so only
/// [DurationAnswer.measured] skips. Type and severity have NO equivalent: both
/// are two-state, null or a value, and neither has a superseded representation
/// that the current control cannot express. A retired vocabulary entry is still
/// a real answer and still renders, so it does not re-ask. **Duration is the
/// only field where "has a value" and "has an answerable value" differ.**
int firstUnansweredStep(EventRecord? r) {
  if (durationAnswerOf(r) != DurationAnswer.measured) return 0;
  if (r?.eventType == null || r?.severity == null) return 1;
  return 2;
}

class _EventWizardScreenState extends State<EventWizardScreen> {
  static const _uuid = Uuid();

  int _step = 0;
  static const _lastStep = 3;

  /// The record as it stands. Null until the first Next on a NEW event — so
  /// opening the wizard and backing straight out leaves nothing, while
  /// answering something and stopping keeps it.
  EventRecord? _draft;

  final _minsController = TextEditingController();
  final _secsController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _timestamp;
  DurationCategory? _bucket;
  /// NULL until the user picks. ⚠️ **The pre-selection was the trap**, and it
  /// is the same shape as the legacy duration bucket: a highlighted chip LOOKS
  /// answered, so the one step that could get a real answer never asks
  /// insistently, and the record ships a value nobody chose. Starting at null
  /// means an unanswered step is visibly unanswered.
  String? _eventType;
  EventSeverity? _severity;
  bool? _rescueGiven;
  RescueResponse? _rescueHelped;
  bool? _rescueSecondDose;
  final Set<String> _feelings = {};
  final Set<String> _triggers = {};
  bool _referral = false;
  late String _id;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _id = e?.id ?? _uuid.v4();
    _timestamp = e?.timestamp ?? DateTime.now();
    _bucket = e?.duration;
    if (e?.durationSeconds != null) {
      _minsController.text = '${e!.durationSeconds! ~/ 60}';
      _secsController.text = '${e.durationSeconds! % 60}';
    }
    // Carried as-is, INCLUDING null. The `?? seizure` / `?? mild` here was the
    // defect at the surface the fix is for: it re-defaulted on the way in, so
    // even after the model stopped fabricating, the wizard started again.
    _eventType = e?.eventType;
    _severity = e?.severity;
    _rescueGiven = e?.rescueMedGiven;
    _rescueHelped = e?.rescueMedHelped;
    _rescueSecondDose = e?.rescueMedSecondDose;
    _feelings.addAll(e?.feelings ?? const []);
    _triggers.addAll(e?.triggers ?? const []);
    _referral = e?.referralRequired ?? false;
    _notesController.text = e?.notes ?? '';
    _draft = e;

    // Open on the FIRST step with something still unanswered.
    _step = firstUnansweredStep(e);
  }

  @override
  void dispose() {
    _addController.dispose();
    _minsController.dispose();
    _secsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int? get _enteredSeconds {
    final m = int.tryParse(_minsController.text.trim());
    final s = int.tryParse(_secsController.text.trim());
    if (m == null && s == null) return null;
    return (m ?? 0) * 60 + (s ?? 0);
  }

  /// What `detailsCompleted` becomes when the wizard CAPTURES rather than
  /// saves.
  ///
  /// ⛔ **PRESERVES WHAT THE RECORD ALREADY HAD. Capturing must not assert
  /// anything about work nobody did.**
  ///
  /// This was `false` unconditionally, and that made merely OPENING a legacy
  /// record and leaving rewrite it: `_onWillPop` captures whenever there is any
  /// input, and an existing record always has some, so backing out flipped
  /// `detailsCompleted` from NULL to false on a record the user only looked at.
  ///
  /// **NULL and false are different claims.** NULL means the record predates
  /// the wizard - neither complete nor incomplete, because the concept did not
  /// exist when it was written. False means someone started the flow and did
  /// not finish. Converting the first into the second is a quiet claim about
  /// history, triggered by a tap that changed nothing else.
  ///
  /// ⚠️ **THE BLAST RADIUS IS NARROWER THAN "every record that predates the
  /// wizard", and the first write-up of this said otherwise.** Reaching the
  /// wizard at all requires `wantsWizard`, so a NULL-flagged record is only
  /// exposed if it is ALSO incomplete - a complete one routes to the single
  /// page and is never at risk. Measured on the tablet, 27 Aug 2026:
  ///
  ///     records with detailsCompleted == NULL            70
  ///     of those, incomplete (so they reach the wizard)   0
  ///
  /// So the defect was real, reachable in principle, and had **no record on
  /// this device in the affected state** - which is also why it cannot be
  /// demonstrated there. It is proved instead by reverting the fix and
  /// watching `details_completed_capture_test` 1, 2 and 4 fail.
  ///
  /// The three cases, and why each is right:
  ///
  ///   NEW record (no `existing`)   false  - it genuinely IS a fresh partial,
  ///                                         and quick-record writes false too
  ///   EXISTING record              carried through UNCHANGED
  ///
  /// Carrying a `true` through unchanged is deliberate rather than an
  /// oversight. The flag records whether the flow was ever COMPLETED, and it
  /// was; if the user has since emptied a field, `isIncomplete` catches that on
  /// its own by reading the fields. Downgrading here would make the flag say
  /// something the fields already say better.
  ///
  /// Only [_finish] sets it true, and that is unchanged.
  bool? get _capturedCompletion =>
      widget.existing == null ? false : widget.existing!.detailsCompleted;

  EventRecord _build({bool completed = false}) => EventRecord(
        id: _id,
        timestamp: _timestamp,
        duration: _bucket,
        durationSeconds: _enteredSeconds,
        feelings: _feelings.toList(),
        triggers: _triggers.toList(),
        referralRequired: _referral,
        notes: _notesController.text.trim(),
        eventType: _eventType,
        severity: _severity,
        rescueMedGiven: _rescueGiven,
        rescueMedHelped: _rescueHelped,
        rescueMedSecondDose: _rescueSecondDose,
        detailsCompleted: completed ? true : _capturedCompletion,
      );

  /// Materialises the partial. The timestamp is the one fact that cannot be
  /// reconstructed later, so it is kept the moment the user answers anything.
  void _capture() => _draft = _build();

  /// ⛔ THE SAME GUARD `_onWillPop` ALREADY USES, AND IT BELONGED HERE TOO.
  ///
  /// `_capture()` ran unconditionally, so pressing Next through an untouched
  /// wizard MATERIALISED A RECORD. Two exits from the identical state gave
  /// opposite answers: backing out created nothing (guarded, and pinned by
  /// test 14), pressing Next created a junk row. Found on the device — the
  /// export went 72 -> 73 after navigation alone.
  ///
  /// ⚠️ THE PARTIAL-SAVE RULE IS UNAFFECTED, and this is the part worth being
  /// sure of. That rule exists because a moment cannot be reconstructed — but
  /// `_timestamp` is set in `initState`, not here, and `_build()` reads that
  /// field. Deferring the capture cannot move a record's timestamp. Someone who
  /// enters anything at all still gets `_hasAnyInput`, still gets captured, and
  /// still gets the moment they opened the screen.
  ///
  /// What it stops is the case the rule was never decided for: opening the
  /// wizard to see what is in it and tapping Next twice.
  void _next() {
    setState(() {
      if (_draft != null || _hasAnyInput) _capture();
      if (_step < _lastStep) _step++;
      else _step = _lastStep + 1; // summary
    });
  }

  void _back() => setState(() => _step--);

  void _finish() {
    Navigator.pop(context, _build(completed: true));
  }

  /// Every exit path returns the draft, so abandoning saves what exists.
  /// Whether anything at all has been supplied on this visit.
  ///
  /// Only consulted for a NEW record. For an existing one `_draft` is non-null
  /// from `initState`, so there is always something to update.
  bool get _hasAnyInput =>
      _enteredSeconds != null ||
      _eventType != null ||
      _severity != null ||
      _rescueGiven != null ||
      _rescueHelped != null ||
      _rescueSecondDose != null ||
      _feelings.isNotEmpty ||
      _triggers.isNotEmpty ||
      _referral ||
      _notesController.text.trim().isNotEmpty;

  Future<bool> _onWillPop() async {
    // ⚠️ CAPTURE THE CURRENT STEP BEFORE LEAVING.
    //
    // `_draft` was materialised only by Next and by Skip, so anything chosen
    // on the step being left — after the last Next — was DISCARDED. Found on
    // the tablet: select a type and a severity, back out, reopen, and both are
    // gone.
    //
    // Pre-existing, and the "needs details" queue makes it the PRIMARY path
    // rather than an edge: a user opens an incomplete record, answers the one
    // thing missing, and backs out. Losing it defeats the queue. It also made
    // Help's "whatever you have entered is kept if you back out" false.
    //
    // ⚠️ The condition is what keeps test 14 honest: opening the wizard on a
    // NEW event and closing it without touching anything must still create
    // NOTHING. `_draft` is null there and nothing has been entered, so nothing
    // is materialised.
    if (_draft != null || _hasAnyInput) _capture();
    Navigator.pop(context, _draft);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final onSummary = _step > _lastStep;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(onSummary ? 'Check and save' : 'Add details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                _step == 0 ? _onWillPop() : setState(() => _step--),
          ),
          actions: [
            if (!onSummary)
              TextButton(
                // EXPLICIT white. A bare TextButton takes its foreground from
                // colorScheme.primary — which is 0xFF0D4F82, the same colour as
                // the AppBar behind it. On the tablet this rendered navy on
                // navy: present, tappable, and completely invisible. AppBar's
                // `foregroundColor` does not reach it; buttons carry their own
                // ButtonStyle.
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () => setState(() {
                  // Same guard as _next. Skip is the FASTEST route through an
                  // untouched wizard, so leaving it unconditional would keep
                  // the defect on the shortest path to it.
                  if (_draft != null || _hasAnyInput) _capture();
                  _step = _lastStep + 1;
                }),
                // Jumps to the summary, not to the next step — so the label
                // says so. "Next" already advances without requiring an answer.
                child: const Text('Skip to end'),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            // STRETCH, not the default centre. Under centre alignment a Column
            // hands its children LOOSE width constraints, so the scroll view
            // shrink-wraps to its widest line and floats in the middle — which
            // is what the summary did on the tablet, indented 200px while the
            // footer beneath it ran full width. Steps carrying a full-width
            // child (the duration Row, the chip Wraps) hid the defect by
            // filling the width for their own reasons.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!onSummary)
                LinearProgressIndicator(
                  value: (_step + 1) / (_lastStep + 1),
                  minHeight: 3,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: onSummary ? _summary() : _stepBody(),
                ),
              ),
              _footer(onSummary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _durationStep();
      case 1:
        return _whatHappenedStep();
      case 2:
        return _beforehandStep();
      default:
        return _afterwardsStep();
    }
  }

  Widget _heading(String title, String hint) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(hint,
              style: const TextStyle(
                  fontSize: 14, color: MERColours.textMuted)),
          const SizedBox(height: 20),
        ],
      );

  Widget _durationStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('How long did it last?',
              'Leave both blank if you do not know — that is recorded as unknown, not as zero.'),
          if (durationAnswerOf(widget.existing) == DurationAnswer.bucketOnly)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Recorded as ${durationLabel(_bucket!)}',
                style: const TextStyle(
                    fontSize: 13, color: MERColours.textMuted),
              ),
            ),
          Row(
            children: [
              Expanded(child: _numField(_minsController, 'minutes')),
              const SizedBox(width: 12),
              Expanded(child: _numField(_secsController, 'seconds')),
            ],
          ),
        ],
      );

  Widget _numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(labelText: label, hintText: '--'),
      );

  Widget _whatHappenedStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('What happened?', 'Pick what best describes it.'),
          _vocabChips(
            table: kEventTypeTable,
            entries: Vocabularies.offerableEventTypes,
            isSel: (e) => _eventType != null && _eventType == e.value,
            onTap: (e) => setState(() => _eventType = e.value),
            addPrompt: 'Add an event type',
            // A type the vocabulary has never seen — restored from a backup
            // made on another device — must still show as selected rather than
            // silently reading as whatever chip happens to match.
            // Null contributes no orphan chip — there is nothing to show.
            orphanValue: _eventType,
          ),
          const SizedBox(height: 24),
          const Text('Compared with your other events',
              style: TextStyle(fontSize: 14, color: MERColours.textMuted)),
          const SizedBox(height: 10),
          _chips<EventSeverity>(
            EventSeverity.values,
            severityLabel,
            (s) => _severity != null && _severity == s,
            (s) => setState(() => _severity = s),
          ),
        ],
      );

  // Deliberately NOT "what caused this". Several sources warn that a recorded
  // trigger is often the event already starting — food cravings, thirst, light
  // sensitivity — and MER must not imply causation. See DATA-MODEL.md §10.
  Widget _beforehandStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('What was happening beforehand?',
              'Anything you noticed. This is not a cause — just what was going on.'),
          // ⚠️ THE ADD PROMPT MUST NOT REINTRODUCE CAUSATION. The heading
          // asks what was happening and the hint denies cause explicitly; an
          // affordance reading "add a trigger" would undo both in three words,
          // in the one place a user is about to type something they will see
          // again on every future record.
          //
          // "Add something else" matches the heading's grammar - it completes
          // "what was happening beforehand?" and claims nothing.
          _vocabMultiChips(
            table: kTriggerTable,
            entries: Vocabularies.offerableTriggers,
            selected: _triggers,
            addPrompt: 'Add something else',
          ),
        ],
      );

  Widget _afterwardsStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A QUESTION, like every other step, and the same words the single
          // page uses.
          //
          // ## The four wordings this has worn, so a fifth is not reached for
          //
          //  1. "How are you feeling?"  PRESENT TENSE. Someone logging live
          //     read it as RIGHT NOW and someone logging days later as THEN.
          //     One field, two meanings, nothing in the record saying which.
          //  2. "How did you feel afterwards?"  Correct, and what is here now.
          //  3. "Afterwards"  A noun, justified as fitting "a column of nouns"
          //     on the single page. THE COLUMN IS NOT NOUNS — it runs
          //     "What happened?", "Duration", "Severity", "Afterwards",
          //     "What was happening beforehand?", "Medical referral required?",
          //     "Notes (optional)". Three questions among seven, and the label
          //     directly below this one is a question. The reason was wrong, so
          //     the change it justified was wrong.
          //  4. Nothing at all (Option A).  Reversed the same day. It rested on
          //     two premises that did not hold: a per-step title in the AppBar
          //     (there is none — it reads "Add details" on every step) and a
          //     RadioGroup or Semantics label being duplicated (there is
          //     neither). Nothing was being duplicated, so what was removed was
          //     the only label the field had.
          //
          // The heading carries the temporal meaning rather than leaving it to
          // the hint, because Option A showed what happens when the hint is the
          // only thing saying it: remove one line and the meaning is gone.
          _heading('How did you feel afterwards?',
              'In the minutes and hours after it ended.'),
          _vocabMultiChips(
            table: kObservationTable,
            entries: Vocabularies.offerableObservations,
            selected: _feelings,
            addPrompt: 'Add how you felt',
          ),
          const SizedBox(height: 24),
          ..._rescueSection(),
          const SizedBox(height: 24),
          const Text('Medical referral required?',
              style: TextStyle(fontSize: 14, color: MERColours.textMuted)),
          const SizedBox(height: 10),
          _chips<bool>(
            const [false, true],
            (b) => b ? 'Yes' : 'No',
            (b) => _referral == b,
            (b) => setState(() => _referral = b),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _notesController,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Add any additional observations...',
            ),
          ),
        ],
      );

  /// Rescue medication: one question, and two more only once it is answered
  /// yes.
  ///
  /// ## Why the children are GATED rather than always shown
  ///
  /// "Did it help: yes" beside "given: no" is a contradiction a reviewer cannot
  /// resolve - neither half identifies itself as the wrong one - and the export
  /// carries it to a clinician who cannot ask what was meant. Preventing the
  /// impossible state beats recording it faithfully.
  ///
  /// ## Why they are CLEARED on no, with no confirmation
  ///
  /// A dialog defending fields the user is actively contradicting is friction
  /// on a form. If they meant to keep them they will set the parent back, and
  /// nothing is lost that a second tap does not restore.
  ///
  /// ⚠️ **The visibility test is [rescueChildrenVisible], NOT `_rescueGiven ==
  /// true`.** A record that arrives already carrying a child value renders it
  /// whatever the parent says - see that function for why hiding a stored value
  /// is the worse of the two failures.
  List<Widget> _rescueSection() {
    final showChildren = rescueChildrenVisible(_draftForVisibility());
    return <Widget>[
      const Text('Rescue medication given?',
          style: TextStyle(fontSize: 14, color: MERColours.textMuted)),
      const SizedBox(height: 10),
      _chips<bool>(
        const [false, true],
        (b) => b ? 'Yes' : 'No',
        (b) => _rescueGiven == b,
        (b) => setState(() {
          _rescueGiven = b;
          if (!b) {
            // CLEARED, not preserved-and-hidden. A hidden value still exports
            // and still backs up, so preserving it would put the contradiction
            // in the file while removing it from the screen - the worst of both.
            _rescueHelped = null;
            _rescueSecondDose = null;
          }
        }),
      ),
      if (showChildren) ...<Widget>[
        const SizedBox(height: 16),
        const Text('Did it help?',
            style: TextStyle(fontSize: 14, color: MERColours.textMuted)),
        const SizedBox(height: 10),
        _chips<RescueResponse>(
          RescueResponse.values,
          rescueResponseLabel,
          (r) => _rescueHelped == r,
          (r) => setState(() => _rescueHelped = r),
        ),
        const SizedBox(height: 16),
        const Text('Was a second dose needed?',
            style: TextStyle(fontSize: 14, color: MERColours.textMuted)),
        const SizedBox(height: 10),
        _chips<bool>(
          const [false, true],
          (b) => b ? 'Yes' : 'No',
          (b) => _rescueSecondDose == b,
          (b) => setState(() => _rescueSecondDose = b),
        ),
      ],
    ];
  }

  /// The three rescue values as they stand right now, for the visibility test.
  ///
  /// A throwaway record rather than three inline comparisons, so this screen and
  /// the single-page form ask the SAME function the same question. Two copies of
  /// a three-clause condition is how they drift.
  EventRecord _draftForVisibility() => EventRecord(
        id: '',
        timestamp: DateTime(2000),
        duration: null,
        feelings: const <String>[],
        referralRequired: false,
        notes: '',
        rescueMedGiven: _rescueGiven,
        rescueMedHelped: _rescueHelped,
        rescueMedSecondDose: _rescueSecondDose,
      );

  /// The table an inline "add your own" field is currently open for, or null.
  ///
  /// ONE field for the whole screen: two steps can each offer adding, and two
  /// simultaneously-open editors on a guided flow is exactly the derailment
  /// this shape exists to avoid.
  String? _addingIn;
  final _addController = TextEditingController();

  /// Adding is INLINE, not a dialog, and that is the whole design.
  ///
  /// A modal inside a guided flow is a second decision stacked on the one the
  /// user came to make — it traps focus, hides the step behind it, and turns
  /// Back into an ambiguous gesture. An inline field appears under the chips,
  /// leaves the question visible above it, and leaves Back, Skip and the
  /// system gesture meaning exactly what they meant a moment earlier.
  ///
  /// It is also the SEIZURE TRACKER pattern: type it once, and it is offered
  /// next time. No settings screen, no setup — which suits an app whose
  /// strength is having none.
  Widget _addRow(String table, String prompt, void Function(VocabularyEntry) onAdded) {
    if (_addingIn != table) {
      return ActionChip(
        avatar: const Icon(Icons.add, size: 18),
        label: Text(prompt),
        onPressed: () => setState(() {
          _addingIn = table;
          _addController.clear();
        }),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _addController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: prompt,
                // Says what happens next, because "it is offered next time" is
                // the whole point and is not obvious from a text field.
                helperText: 'Saved for next time.',
              ),
              onSubmitted: (_) => _commitAdd(table, onAdded),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() => _addingIn = null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _commitAdd(table, onAdded),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _commitAdd(
      String table, void Function(VocabularyEntry) onAdded) async {
    final entry = await Vocabularies.add(table, _addController.text);
    if (!mounted) return;
    setState(() {
      _addingIn = null;
      // Empty input closes the field and adds nothing, rather than creating a
      // blank vocabulary entry that can never be deleted.
      if (entry != null) onAdded(entry);
    });
  }

  /// Single-select chips over a vocabulary, plus the add affordance.
  ///
  /// [orphanValue] is rendered as its own selected chip when it matches no
  /// entry. That happens for real: a backup restored from another device can
  /// carry a type this device's vocabulary has never seen. Dropping it would
  /// silently reassign the record to whatever chip happened to be selected.
  Widget _vocabChips({
    required String table,
    required List<VocabularyEntry> entries,
    required bool Function(VocabularyEntry) isSel,
    required void Function(VocabularyEntry) onTap,
    required String addPrompt,
    String? orphanValue,
  }) {
    final known = entries.any((e) => e.value == orphanValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in entries)
              ChoiceChip(
                label: Text(e.label),
                selected: isSel(e),
                onSelected: (_) => onTap(e),
              ),
            if (orphanValue != null && !known)
              ChoiceChip(
                label: Text(eventTypeLabel(orphanValue)),
                selected: true,
                onSelected: (_) {},
              ),
            if (_addingIn != table)
              _addRow(table, addPrompt, (e) => onTap(e)),
          ],
        ),
        if (_addingIn == table) _addRow(table, addPrompt, (e) => onTap(e)),
      ],
    );
  }

  /// Multi-select chips over a vocabulary, plus the add affordance.
  ///
  /// Values already on the record that match no entry get their own selected
  /// chip, same rule as above.
  Widget _vocabMultiChips({
    required String table,
    required List<VocabularyEntry> entries,
    required Set<String> selected,
    required String addPrompt,
  }) {
    final known = entries.map((e) => e.value).toSet();
    final orphans = selected.where((v) => !known.contains(v)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in entries)
              FilterChip(
                // display, not label — the glyph belongs on a chip and nowhere
                // a record is rendered. See Vocabularies.displayFor.
                label: Text(e.display),
                selected: selected.contains(e.value),
                onSelected: (_) => setState(() => selected.contains(e.value)
                    ? selected.remove(e.value)
                    : selected.add(e.value)),
              ),
            for (final v in orphans)
              FilterChip(
                label: Text(Vocabularies.displayFor(table, v)),
                selected: true,
                onSelected: (_) => setState(() => selected.remove(v)),
              ),
            if (_addingIn != table)
              _addRow(table, addPrompt, (e) => selected.add(e.value)),
          ],
        ),
        if (_addingIn == table)
          _addRow(table, addPrompt, (e) => selected.add(e.value)),
      ],
    );
  }

  Widget _chips<T>(List<T> options, String Function(T) label,
          bool Function(T) isSel, void Function(T) onTap) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map((o) => ChoiceChip(
                  label: Text(label(o)),
                  selected: isSel(o),
                  onSelected: (_) => onTap(o),
                ))
            .toList(),
      );

  /// Reuses the edit screen's Confirm-changes shape: an ITEMISED list of what
  /// was entered, not "are you sure". For a new record everything is a change
  /// from nothing, so every answered field appears and unanswered ones stay
  /// silent — the same absence-reads-as-absence rule as the history row.
  Widget _summary() {
    final lines = <String>[];
    final d = durationDisplay(_bucket, _enteredSeconds);
    lines.add('Duration: ${d ?? 'not recorded'}');
    // Omitted when unanswered, like duration two lines up. A summary that said
    // "Event type: unknown" would read as a finding.
    final t = eventTypeDisplay(_eventType);
    if (t != null) lines.add('Event type: $t');
    final sev = severityDisplay(_severity);
    if (sev != null) lines.add('Severity: $sev');
    // ⛔ LABELS, NOT STORED VALUES. These lines joined the raw strings, so a
    // record holding the retired `😵 Confused` — or its mis-decoded twin, which
    // is what all three observation records on the device actually hold —
    // showed the user something different from the chip they had just tapped.
    //
    // `labelFor`, not `displayFor`: this is a Text widget in a style with no
    // emoji coverage, which is the exact combination that rendered mojibake in
    // History rows. The glyph belongs on a chip and nowhere a record is read.
    if (_triggers.isNotEmpty) {
      lines.add('Beforehand: ${_triggers.map(
            (v) => Vocabularies.labelFor(kTriggerTable, v),
          ).join(', ')}');
    }
    if (_feelings.isNotEmpty) {
      lines.add('Afterwards: ${_feelings.map(
            (v) => Vocabularies.labelFor(kObservationTable, v),
          ).join(', ')}');
    }
    // Only when ANSWERED, like type and severity above. "Rescue medication:
    // no" on every summary would crowd out the lines that carry information,
    // and unanswered is not the same as no.
    if (_rescueGiven != null) {
      lines.add('Rescue medication: ${_rescueGiven! ? 'given' : 'not given'}');
    }
    final helped = rescueResponseDisplay(_rescueHelped);
    if (helped != null) lines.add('Did it help: $helped');
    if (_rescueSecondDose != null) {
      lines.add('Second dose: ${_rescueSecondDose! ? 'yes' : 'no'}');
    }
    if (_referral) lines.add('Medical referral required');
    if (_notesController.text.trim().isNotEmpty) lines.add('Notes added');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // NOT "nothing is saved until you tap Save" — that would be false.
        // The partial is already kept; Save is what marks it finished.
        _heading('Check and save',
            'Save to finish. What you have entered is kept either way.'),
        ...lines.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('• $l', style: const TextStyle(fontSize: 15)),
            )),
      ],
    );
  }

  Widget _footer(bool onSummary) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Row(
          children: [
            if (_step > 0 && !onSummary)
              Expanded(
                child: OutlinedButton(
                  onPressed: _back,
                  child: const Text('Back'),
                ),
              ),
            if (_step > 0 && !onSummary) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: onSummary ? _finish : _next,
                child: Text(onSummary
                    ? 'Save'
                    : (_step == _lastStep ? 'Review' : 'Next')),
              ),
            ),
          ],
        ),
      );
}
