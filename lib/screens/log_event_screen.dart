import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/event_record.dart';
import '../models/vocabulary.dart';
import '../models/vocabulary_store.dart';
import '../widgets/occurred_at_field.dart';
import '../theme/mer_theme.dart';

class LogEventScreen extends StatefulWidget {
  final EventRecord? existing;
  final bool confirmOnSave;

  const LogEventScreen({
    super.key,
    this.existing,
    this.confirmOnSave = false,
  });

  @override
  State<LogEventScreen> createState() => _LogEventScreenState();
}

class _LogEventScreenState extends State<LogEventScreen> {
  final _uuid = const Uuid();
  final _notesController = TextEditingController();

  late String? _eventType;
  /// NULL = unknown. An unanswered duration now LOOKS unanswered — before
  /// this, every field carried a default and the user could not tell a default
  /// from an answer.
  /// The legacy BUCKET, shown but never edited. A record captured before
  /// duration was a quantity has a range and will never have a number; it is
  /// displayed as context so the user can see what was recorded, and it is
  /// never derived from, or overwritten by, what they type.
  DurationCategory? _duration;

  /// Null means NOT ASKED. Never defaulted to `now` on save.
  DateTime? _occurredAt;

  final _minsController = TextEditingController();
  final _secsController = TextEditingController();
  int? _origSeconds;
  DateTime? _origOccurredAt;
  late EventSeverity? _severity;
  late Set<String> _selectedFeelings;
  late Set<String> _selectedTriggers;
  late bool _referralRequired;

  // Originals for change detection
  late String? _origEventType;

  /// Which vocabulary an inline "add your own" field is open for, or null.
  ///
  /// One field for the whole form, for the same reason the wizard has one: two
  /// open editors on one screen is two half-finished decisions.
  String? _addingIn;
  final _addController = TextEditingController();

  bool? _rescueGiven;
  RescueResponse? _rescueHelped;
  bool? _rescueSecondDose;

  /// The three rescue values as they stand, for [rescueChildrenVisible].
  /// See the wizard's `_draftForVisibility` — one function, asked by both
  /// screens, rather than two copies of a three-clause condition.
  EventRecord _rescueDraft() => EventRecord(
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

  /// Values the beforehand chips offer for THIS record.
  ///
  /// Offerable entries plus anything the record already carries that is no
  /// longer offered - the same rule the observation list follows, so a value
  /// from another device keeps its chip rather than vanishing from a record
  /// that holds it.
  List<String> _triggerOptions() {
    final offered =
        Vocabularies.offerableTriggers.map((e) => e.value).toList();
    final extra =
        _selectedTriggers.where((v) => !offered.contains(v)).toList()..sort();
    return <String>[...offered, ...extra];
  }

  /// Values the observation chips offer for THIS record.
  ///
  /// Offerable entries, plus anything the record already carries that is no
  /// longer offered. A record holding the retired `😵 Confused` keeps its chip,
  /// selected — the alternative is a value silently dropped from a medical
  /// record because MER revised its own vocabulary afterwards.
  List<String> _observationOptions() {
    final offered =
        Vocabularies.offerableObservations.map((e) => e.value).toList();
    final extra =
        _selectedFeelings.where((v) => !offered.contains(v)).toList()..sort();
    return <String>[...offered, ...extra];
  }

  /// The inline add field. NOT a dialog — see the wizard's `_addRow` for why.
  Widget _inlineAdd(
      String table, String prompt, void Function(VocabularyEntry) onAdded) {
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
      _addController.clear();
      // Empty input closes the field and adds nothing, rather than creating a
      // blank entry that can never be deleted.
      if (entry != null) onAdded(entry);
    });
  }
  DurationCategory? _origDuration;
  late EventSeverity? _origSeverity;
  late Set<String> _origFeelings;
  late Set<String> _origTriggers;
  late bool _origReferral;
  bool? _origRescueGiven;
  RescueResponse? _origRescueHelped;
  bool? _origRescueSecondDose;
  late String _origNotes;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    // Carried as-is, INCLUDING null. `?? seizure` here would re-default at the
    // surface after the model stopped fabricating — see the wizard.
    _eventType         = e?.eventType;
    // No `?? lt1`. A record with no duration opens with nothing selected.
    _duration          = e?.duration;
    if (e?.durationSeconds != null) {
      _minsController.text = '${e!.durationSeconds! ~/ 60}';
      _secsController.text = '${e.durationSeconds! % 60}';
    }
    _occurredAt        = e?.occurredAt;
    _severity          = e?.severity;
    _selectedFeelings  = (e?.feelings        ?? []).toSet();
    _selectedTriggers  = (e?.triggers        ?? []).toSet();
    _referralRequired  = e?.referralRequired ?? false;
    _rescueGiven       = e?.rescueMedGiven;
    _rescueHelped      = e?.rescueMedHelped;
    _rescueSecondDose  = e?.rescueMedSecondDose;
    _notesController.text = e?.notes        ?? '';

    // Store originals
    _origEventType = _eventType;
    _origDuration  = _duration;
    _origSeconds   = _enteredSeconds;
    _origOccurredAt = _occurredAt;
    _origSeverity  = _severity;
    _origFeelings  = Set.from(_selectedFeelings);
    _origTriggers  = Set.from(_selectedTriggers);
    _origReferral  = _referralRequired;
    _origRescueGiven      = _rescueGiven;
    _origRescueHelped     = _rescueHelped;
    _origRescueSecondDose = _rescueSecondDose;
    _origNotes     = _notesController.text.trim();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _minsController.dispose();
    _secsController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    if (_isNew) return true;
    return _occurredAt       != _origOccurredAt ||
        _eventType           != _origEventType ||
        _enteredSeconds      != _origSeconds   ||
        _severity            != _origSeverity  ||
        _referralRequired    != _origReferral  ||
        _rescueGiven         != _origRescueGiven ||
        _rescueHelped        != _origRescueHelped ||
        _rescueSecondDose    != _origRescueSecondDose ||
        _notesController.text.trim() != _origNotes ||
        !_sameSet(_selectedFeelings, _origFeelings) ||
        !_sameSet(_selectedTriggers, _origTriggers);
  }

  static final DateFormat _whenFmt = DateFormat('d MMM yyyy · HH:mm');

  bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  List<String> _buildChangeList() {
    final changes = <String>[];
    if (_eventType != _origEventType) {
      changes.add(
        'Event type: ${eventTypeDisplay(_origEventType) ?? 'not recorded'} '
        '→ ${eventTypeDisplay(_eventType) ?? 'not recorded'}',
      );
    }
    // Named the same way the other lines are: what the FIELD held, not a
    // claim about the event. 'not recorded' is the vocabulary this list
    // already uses for absence.
    if (_occurredAt != _origOccurredAt) {
      String w(DateTime? d) =>
          d == null ? 'not recorded' : _whenFmt.format(d);
      changes.add('When it happened: ${w(_origOccurredAt)} '
          '→ ${w(_occurredAt)}');
    }
    if (_enteredSeconds != _origSeconds) {
      changes.add(
        'Duration: ${_durLabel(_origDuration, _origSeconds)} → ${_durLabel(_duration, _enteredSeconds)}',
      );
    }
    if (_severity != _origSeverity) {
      changes.add(
        // "not recorded" rather than "unknown": this is a CHANGE LOG, and it
        // is describing what the field held, not asserting a clinical value.
        'Severity: ${severityDisplay(_origSeverity) ?? 'not recorded'} '
        '→ ${severityDisplay(_severity) ?? 'not recorded'}',
      );
    }
    if (_referralRequired != _origReferral) {
      changes.add(
        'Medical referral: ${_origReferral ? "Yes" : "No"} → ${_referralRequired ? "Yes" : "No"}',
      );
    }
    if (!_sameSet(_selectedFeelings, _origFeelings)) {
      // "Afterwards", matching the section label and the wizard's summary
      // line. This was the FOURTH wording of one field and it survived the
      // trigger alignment because that pass looked for causal words, not for
      // every place the field is named.
      changes.add('Afterwards updated');
    }
    if (!_sameSet(_selectedTriggers, _origTriggers)) {
      changes.add('Beforehand updated');
    }
    if (_notesController.text.trim() != _origNotes) {
      changes.add('Notes updated');
    }
    return changes;
  }

  /// Change-log label. "not recorded" rather than "Unknown": the log is a
  /// sentence about what the user did, not a data cell.
  /// Reads the two fields as one quantity, or null when neither is filled.
  /// Blank is UNKNOWN, never zero — typing nothing must not assert 0 seconds.
  int? get _enteredSeconds {
    final m = int.tryParse(_minsController.text.trim());
    final s = int.tryParse(_secsController.text.trim());
    if (m == null && s == null) return null;
    return (m ?? 0) * 60 + (s ?? 0);
  }

  String _durLabel(DurationCategory? d, int? secs) =>
      durationDisplay(d, secs) ?? 'not recorded';

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save.')),
      );
      return;
    }

    if (widget.confirmOnSave && !_isNew) {
      final changes = _buildChangeList();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm changes'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                const Text('Save the following changes?'),
                const SizedBox(height: 12),
                for (final c in changes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $c'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    final record = EventRecord(
      id:               widget.existing?.id ?? _uuid.v4(),
      timestamp:        widget.existing?.timestamp ?? DateTime.now(),
      occurredAt:       _occurredAt,
      eventType:        _eventType,
      // The bucket is carried through UNCHANGED. Never derived from the
      // number, never cleared by it: what was recorded then and what the user
      // supplies now are different facts.
      duration:         _duration,
      durationSeconds:  _enteredSeconds,
      severity:         _severity,
      feelings:         _selectedFeelings.toList(),
      triggers:         _selectedTriggers.toList(),
      referralRequired: _referralRequired,
      rescueMedGiven:      _rescueGiven,
      rescueMedHelped:     _rescueHelped,
      rescueMedSecondDose: _rescueSecondDose,
      notes:            _notesController.text.trim(),
      // TRUE. Reaching Save here means the whole form was filled and
      // confirmed, so the record is no longer a partial and must not keep
      // routing back into the guided path. The field means "detail entry was
      // completed", not "the wizard specifically was used" — which is also
      // why the wizard sets it at _finish only, never on a Skip.
      detailsCompleted: true,
    );

    if (mounted) Navigator.pop(context, record);
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
appBar: AppBar(
          leading: IconButton(
            icon:      const Icon(Icons.arrow_back),
            onPressed: _cancel,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize:       MainAxisSize.min,
            children: [
              Text(
                _isNew ? 'Log new event' : 'Edit event',
                style: const TextStyle(
                  fontSize:   15,
                  fontWeight: FontWeight.w600,
                  color:      Colors.white,
                ),
              ),
              const Text(
                'Medical Event Recorder',
                style: TextStyle(
                  fontSize: 10,
                  color:    Colors.white54,
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

// ── EVENT TYPE ──
                        // SAME words as the wizard's step heading. One field, one wording,
                        // on whichever screen a record happens to open in.
                        _SectionLabel('What happened?'),
                        const SizedBox(height: 8),
                        _EventTypeGrid(
                          selected:   _eventType,
                          onSelected: (t) => setState(() => _eventType = t),
                          onAdd: Vocabularies.canPersist
                              ? () => setState(() => _addingIn = kEventTypeTable)
                              : null,
                        ),
                        if (_addingIn == kEventTypeTable)
                          _inlineAdd(kEventTypeTable, 'Add an event type',
                              (e) => _eventType = e.value),
                        const SizedBox(height: 20),

                        // ── DURATION ──
                        _SectionLabel('Duration'),
                        const SizedBox(height: 8),
                        // A legacy record's RANGE, shown as context. It is not
                        // editable and it is never converted: "1-5 minutes"
                        // contains no number, and inventing one would put a
                        // fabricated quantity in a medical record.
                        if (_duration != null && _enteredSeconds == null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Recorded as ${durationLabel(_duration!)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: MERColours.textMuted,
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: _DurationField(
                                controller: _minsController,
                                label: 'minutes',
                                onChanged: () => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DurationField(
                                controller: _secsController,
                                label: 'seconds',
                                onChanged: () => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // ⚠️ AFTER DURATION, NOT AT THE TOP — moved there on
                        // evidence. Placed above "What happened?" it pushed
                        // every other field down by its own height, and a
                        // widget test's tap on an observation chip started
                        // MISSING: the chip was still in the tree and no
                        // longer under the finger. That is what one more
                        // block at the top costs on a real screen too, and
                        // the common edit here is adding details to a quick
                        // record, not correcting a time.
                        //
                        // Beside duration is also where it belongs: these are
                        // the two questions about time, and "how long" reads
                        // oddly separated from "when".
                        OccurredAtField(
                          value: _occurredAt,
                          fallback: widget.existing?.timestamp ??
                              DateTime.now(),
                          onChanged: (v) =>
                              setState(() => _occurredAt = v),
                        ),

                        const SizedBox(height: 28),

                        _SectionLabel('Severity'),
                        const SizedBox(height: 8),
                        _SelectionRow<EventSeverity>(
                          options:    EventSeverity.values,
                          selected:   _severity,
                          labelFor:   severityLabel,
                          colorFor:   (s) {
                            switch (s) {
                              case EventSeverity.mild:
                                return MERColours.action;
                              case EventSeverity.moderate:
                                return MERColours.warning;
                              case EventSeverity.severe:
                                return MERColours.alert;
                            }
                          },
                          onSelected: (s) => setState(() => _severity = s),
                        ),
                        const SizedBox(height: 20),

                        // ── AFTERWARDS ──
                        // NOT "How are you feeling?" — present tense. Someone
                        // logging live read it as RIGHT NOW and someone logging
                        // days later read it as THEN, so one field meant two
                        // things and nothing in the record said which. It is the
                        // postictal state.
                        //
                        // ⚠️ THE "COLUMN OF NOUNS" ARGUMENT WAS FALSE, and it
                        // is the reason this label was briefly a noun. Enumerate
                        // the column and it reads: "What happened?", "Duration",
                        // "Severity", THIS, "What was happening beforehand?",
                        // "Medical referral required?", "Notes (optional)".
                        // Three of the seven are questions, and the one directly
                        // BELOW this is a question. A question here is not the
                        // odd one out.
                        //
                        // Word for word the wizard's step 4 heading, for the same
                        // reason the type label above matches its step 2.
                        // Matches the wizard. See the note there for why no
                        // person appears in this heading.
                        _SectionLabel('How were things afterwards?'),
                        const SizedBox(height: 4),
                        // "In the minutes and hours…", NOT "How you felt in
                        // the minutes and hours…". The longer form belonged to
                        // the noun heading, which had to carry "how you felt"
                        // in the hint because the noun could not. With the
                        // question restored above, that half is said twice —
                        // and THIS is a real instance of the redundancy the
                        // last two changes were reaching for and missing.
                        _SectionHint('In the minutes and hours after it ended.'),
                        const SizedBox(height: 8),
                        _SelectionWrap(
                          // Offerable entries PLUS anything this record already carries
                          // that is no longer offered — a retired legacy value keeps its
                          // chip, selected, rather than vanishing from the record.
                          options: _observationOptions(),
                          selected: _selectedFeelings,
                          // displayFor, not labelFor: the glyph belongs on a chip and
                          // nowhere a record is rendered.
                          labelFor: (v) =>
                              Vocabularies.displayFor(kObservationTable, v),
                          addLabel: 'Add something else',
                          onToggle: (f) => setState(() {
                            _selectedFeelings.contains(f)
                                ? _selectedFeelings.remove(f)
                                : _selectedFeelings.add(f);
                          }),
                          onAdd: Vocabularies.canPersist
                              ? () => setState(() => _addingIn = kObservationTable)
                              : null,
                        ),
                        if (_addingIn == kObservationTable)
                          _inlineAdd(kObservationTable, 'Add something else',
                              (e) => _selectedFeelings.add(e.value)),
                        const SizedBox(height: 20),

                        // ── BEFOREHAND ──
                        // Deliberately NOT "Possible triggers". Several sources warn
                        // that a recorded trigger is often the event already starting
                        // — food cravings, thirst, light sensitivity — and MER must
                        // not imply causation. See DATA-MODEL.md §10.
                        //
                        // The rule is about the FIELD, not the screen, so this is
                        // word-for-word the wizard's step heading: a record that opens
                        // here and one that opens there must not describe the same
                        // field differently. The hint is the wizard's, trimmed to its
                        // causation half — this is a dense form, not a guided step.
                        _SectionLabel('What was happening beforehand?'),
                        const SizedBox(height: 4),
                        _SectionHint('Not a cause — just what was going on.'),
                        const SizedBox(height: 8),
                        // The form CREATES as well as selects, because most
                        // records open here rather than in the wizard - a
                        // vocabulary a user can only extend from one screen is
                        // one they will not find.
                        _SelectionWrap(
                          options:  _triggerOptions(),
                          selected: _selectedTriggers,
                          labelFor: (v) =>
                              Vocabularies.displayFor(kTriggerTable, v),
                          onToggle: (t) => setState(() {
                            _selectedTriggers.contains(t)
                                ? _selectedTriggers.remove(t)
                                : _selectedTriggers.add(t);
                          }),
                          addLabel: 'Add something else',
                          onAdd: Vocabularies.canPersist
                              ? () => setState(() => _addingIn = kTriggerTable)
                              : null,
                        ),
                        if (_addingIn == kTriggerTable)
                          _inlineAdd(kTriggerTable, 'Add something else',
                              (e) => _selectedTriggers.add(e.value)),
                        const SizedBox(height: 20),

                        // ── RESCUE MEDICATION ──
                        //
                        // Word for word the wizard's step 4, same gate, same
                        // clearing rule. The two screens edit the same record
                        // and a user who learns one must not be surprised by
                        // the other.
                        _SectionLabel('Rescue medication given?'),
                        const SizedBox(height: 8),
                        _SelectionRow<bool>(
                          options:    const [false, true],
                          selected:   _rescueGiven,
                          labelFor:   (v) => v ? 'Yes' : 'No',
                          onSelected: (v) => setState(() {
                            _rescueGiven = v;
                            if (!v) {
                              _rescueHelped = null;
                              _rescueSecondDose = null;
                            }
                          }),
                        ),
                        if (rescueChildrenVisible(_rescueDraft())) ...[
                          const SizedBox(height: 20),
                          _SectionLabel('Did it help?'),
                          const SizedBox(height: 8),
                          _SelectionRow<RescueResponse>(
                            options:    RescueResponse.values,
                            selected:   _rescueHelped,
                            labelFor:   rescueResponseLabel,
                            onSelected: (v) =>
                                setState(() => _rescueHelped = v),
                          ),
                          const SizedBox(height: 20),
                          _SectionLabel('Was a second dose needed?'),
                          const SizedBox(height: 8),
                          _SelectionRow<bool>(
                            options:    const [false, true],
                            selected:   _rescueSecondDose,
                            labelFor:   (v) => v ? 'Yes' : 'No',
                            onSelected: (v) =>
                                setState(() => _rescueSecondDose = v),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // ── REFERRAL ──
                        _SectionLabel('Medical referral required?'),
                        const SizedBox(height: 8),
                        _SelectionRow<bool>(
                          options:    const [false, true],
                          selected:   _referralRequired,
                          labelFor:   (v) => v ? 'Yes' : 'No',
                          onSelected: (v) =>
                              setState(() => _referralRequired = v),
                        ),
                        const SizedBox(height: 20),
                        // ── NOTES ──
                        _SectionLabel('Notes (optional)'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _notesController,
                          maxLines: 4,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          decoration: const InputDecoration(
                            hintText: 'Add any additional observations...',
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── BUTTONS ──
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: _save,
                            child: Text(
                              _isNew ? 'Save event' : 'Save changes',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: _cancel,
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/* ===========================
   SECTION LABEL
   =========================== */

/// Mirrors [_SectionLabel] so the muted style lives in one place rather than
/// as an inline literal that drifts from the wizard's equivalent.
class _SectionHint extends StatelessWidget {
  final String text;
  const _SectionHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: MERColours.textMuted),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge,
    );
  }
}

/* ===========================
   EVENT TYPE GRID
   =========================== */

class _EventTypeGrid extends StatelessWidget {
  /// NULL means NOT ASKED, and NO TILE IS SELECTED. That is the visible half of
  /// the fix: an unanswered type looks unanswered rather than looking like
  /// someone chose "Seizure / fit".
  final String? selected;
  final ValueChanged<String> onSelected;

  /// Opens the inline "add a type" field. Null hides the add tile — which is
  /// what happens on a launch with no database, where an entry could not
  /// survive a restart.
  final VoidCallback? onAdd;

  const _EventTypeGrid({
    required this.selected,
    required this.onSelected,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final entries = Vocabularies.offerableEventTypes;
    // A type this device's vocabulary has never seen — from a backup made
    // elsewhere — still gets a tile, selected, rather than silently reading as
    // whichever tile happens to match.
    // Null is not an orphan — there is nothing to render a tile for.
    final orphan = (selected == null || entries.any((e) => e.value == selected))
        ? null
        : selected;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 3.2,
      children: <Widget>[
        for (final e in entries)
          _EventTypeButton(
            type: e.value,
            label: e.label,
            isSelected: selected == e.value,
            onTap: () => onSelected(e.value),
          ),
        if (orphan != null)
          _EventTypeButton(
            type: orphan,
            label: eventTypeLabel(orphan),
            isSelected: true,
            onTap: () {},
          ),
        if (onAdd != null)
          _EventTypeButton(
            type: '',
            label: 'Add your own',
            isSelected: false,
            onTap: onAdd!,
            icon: Icons.add,
          ),
      ],
    );
  }
}

class _EventTypeButton extends StatelessWidget {
  final String type;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const _EventTypeButton({
    required this.type,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  /// An icon per SEEDED type, and one neutral icon for everything else. A
  /// user-defined type gets no bespoke icon for the same reason it gets no
  /// bespoke colour — see `_EventTypeFilterChips._activeColor` in History.
  IconData get _icon {
    if (icon != null) return icon!;
    switch (type) {
      case kTypeSeizure:
        return Icons.monitor_heart_outlined;
      case kTypeAbsence:
        return Icons.access_time_outlined;
      case kTypeMedication:
        return Icons.medication_outlined;
      default:
        return Icons.edit_note_outlined;
    }
  }

  Color get _selectedColor {
    switch (type) {
      case kTypeSeizure:
        return MERColours.alert;
      case kTypeAbsence:
        return MERColours.action;
      case kTypeMedication:
        return MERColours.success;
      default:
        return MERColours.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _selectedColor.withOpacity(0.1)
              : MERColours.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _selectedColor : MERColours.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _icon,
              size: 18,
              color: isSelected ? _selectedColor : MERColours.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize:   12,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: isSelected
                      ? _selectedColor
                      : MERColours.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ===========================
   SINGLE SELECT ROW
   (Duration, Severity, Referral)
   =========================== */

class _SelectionRow<T> extends StatelessWidget {
  final List<T> options;
  /// Nullable so a group can show NOTHING selected. Non-null callers are
  /// unaffected: T is assignable to T?.
  final T? selected;
  final String Function(T) labelFor;
  final Color Function(T)? colorFor;
  final ValueChanged<T> onSelected;

  const _SelectionRow({
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
    this.colorFor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((option) {
        final isSelected = selected == option;
        final colour = colorFor != null
            ? colorFor!(option)
            : MERColours.primary;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colour
                      : MERColours.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? colour : MERColours.border,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Text(
                  labelFor(option),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : MERColours.textMuted,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/* ===========================
   MULTI SELECT WRAP
   (Feelings, Triggers)
   =========================== */

class _SelectionWrap extends StatelessWidget {
  /// The STORED VALUES, not the labels. For triggers the two are still the same
  /// string; for observations they differ, because a legacy value carries an
  /// emoji its label does not.
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  /// Resolves a value to what a person reads. Null means the value IS the
  /// label, which is how triggers still work.
  final String Function(String)? labelFor;

  /// Opens the inline "add your own" field. Null hides the pill — which is what
  /// happens with no database, where the entry could not survive a restart.
  final VoidCallback? onAdd;
  final String addLabel;

  const _SelectionWrap({
    required this.options,
    required this.selected,
    required this.onToggle,
    this.labelFor,
    this.onAdd,
    this.addLabel = 'Add your own',
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        ...options.map((option) {
        final isSelected = selected.contains(option);
        return GestureDetector(
          onTap: () => onToggle(option),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? MERColours.primary
                  : MERColours.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? MERColours.primary
                    : MERColours.border,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Text(
              labelFor?.call(option) ?? option,
              style: TextStyle(
                fontSize:   13,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: isSelected
                    ? Colors.white
                    : MERColours.textPrimary,
              ),
            ),
          ),
        );
        }),
        if (onAdd != null)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: MERColours.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MERColours.border, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 16, color: MERColours.primary),
                  const SizedBox(width: 6),
                  Text(addLabel,
                      style: const TextStyle(
                          fontSize: 13, color: MERColours.primary)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Minutes or seconds. Digits only, and BLANK MEANS UNKNOWN.
///
/// The app had no numeric input anywhere before this — the only two TextFields
/// are the History search and the Notes box, both free text. So the keyboard
/// type and the formatter are deliberate rather than inherited.
///
/// Deliberately NOT defaulted to 0. A zero typed by the widget rather than the
/// user is the same fabrication as the `lt1` this change exists to retire.
class _DurationField extends StatelessWidget {
  const _DurationField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.done,
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        labelText: label,
        hintText: '--',
      ),
    );
  }
}
