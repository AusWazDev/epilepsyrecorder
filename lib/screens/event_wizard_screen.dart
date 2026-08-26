import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../constants.dart';
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
/// Only an explicit FALSE routes here. `true` is already finished and stepping
/// it through four screens to change one field would be worse than the form;
/// `null` predates the wizard and is neither complete nor incomplete, so it
/// keeps the screen it has always opened in.
bool wantsWizard(EventRecord r) => r.detailsCompleted == false;

DurationAnswer durationAnswerOf(EventRecord? r) {
  if (r?.durationSeconds != null) return DurationAnswer.measured;
  if (r?.duration != null) return DurationAnswer.bucketOnly;
  return DurationAnswer.none;
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
  String _eventType = kTypeSeizure;
  EventSeverity _severity = EventSeverity.mild;
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
    _eventType = e?.eventType ?? kTypeSeizure;
    _severity = e?.severity ?? EventSeverity.mild;
    _feelings.addAll(e?.feelings ?? const []);
    _triggers.addAll(e?.triggers ?? const []);
    _referral = e?.referralRequired ?? false;
    _notesController.text = e?.notes ?? '';
    _draft = e;

    // A record that ALREADY has a measured duration must not be asked again.
    // Only `measured` skips — see [DurationAnswer].
    if (durationAnswerOf(e) == DurationAnswer.measured) _step = 1;
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
        detailsCompleted: completed,
      );

  /// Materialises the partial. The timestamp is the one fact that cannot be
  /// reconstructed later, so it is kept the moment the user answers anything.
  void _capture() => _draft = _build();

  void _next() {
    setState(() {
      _capture();
      if (_step < _lastStep) _step++;
      else _step = _lastStep + 1; // summary
    });
  }

  void _back() => setState(() => _step--);

  void _finish() {
    Navigator.pop(context, _build(completed: true));
  }

  /// Every exit path returns the draft, so abandoning saves what exists.
  Future<bool> _onWillPop() async {
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
                  _capture();
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
            isSel: (e) => _eventType == e.value,
            onTap: (e) => setState(() => _eventType = e.value),
            addPrompt: 'Add an event type',
            // A type the vocabulary has never seen — restored from a backup
            // made on another device — must still show as selected rather than
            // silently reading as whatever chip happens to match.
            orphanValue: _eventType,
          ),
          const SizedBox(height: 24),
          const Text('Compared with your other events',
              style: TextStyle(fontSize: 14, color: MERColours.textMuted)),
          const SizedBox(height: 10),
          _chips<EventSeverity>(
            EventSeverity.values,
            severityLabel,
            (s) => _severity == s,
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
          _multiChips(kTriggerOptions, _triggers),
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
                label: Text(e.label),
                selected: selected.contains(e.value),
                onSelected: (_) => setState(() => selected.contains(e.value)
                    ? selected.remove(e.value)
                    : selected.add(e.value)),
              ),
            for (final v in orphans)
              FilterChip(
                label: Text(Vocabularies.labelFor(table, v)),
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

  Widget _multiChips(List<String> options, Set<String> selected) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map((o) => FilterChip(
                  label: Text(o),
                  selected: selected.contains(o),
                  onSelected: (_) => setState(() =>
                      selected.contains(o) ? selected.remove(o) : selected.add(o)),
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
    lines.add('Event type: ${eventTypeLabel(_eventType)}');
    lines.add('Severity: ${severityLabel(_severity)}');
    if (_triggers.isNotEmpty) lines.add('Beforehand: ${_triggers.join(', ')}');
    if (_feelings.isNotEmpty) lines.add('Afterwards: ${_feelings.join(', ')}');
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
