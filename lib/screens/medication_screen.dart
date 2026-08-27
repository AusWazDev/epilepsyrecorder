import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/medication_note.dart';
import '../theme/mer_theme.dart';

/// The regular-medication stream: a list of DEVIATIONS, and a way to add one.
///
/// ## ⛔ WHY THIS IS NOT IN HISTORY
///
/// History is a list of EVENTS, and everything on it assumes that: the search
/// haystack, the five filters, the "Needs details" queue, the export scope
/// statement, and the row that reads "1m 45s · Mild". A medication note has no
/// duration, no severity, no observations and nothing to complete, so every one
/// of those would need a "unless it is a dose" clause — five places where a
/// wrong answer is silent.
///
/// **The streams meet in the EXPORT, on one timeline, which is where the model
/// always said they would.** A specialist reads them together; the app does not.
///
/// ## ⛔ AND WHY IT IS NOT ON THE HOME SCREEN
///
/// Home is the capture path. Nothing goes there that is not one tap from an
/// event, and a deviation is recorded hours later by definition — that is the
/// whole reason the stream is exceptions-only.
class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key, required this.store});

  /// ⛔ A STORE, NEVER A `Database`. `sqlite_single_writer_test` forbids a
  /// screen holding one, and it caught the first draft of this file doing
  /// exactly that. See [MedicationStore].
  final MedicationStore store;

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  static const _uuid = Uuid();
  List<MedicationNote> _notes = const <MedicationNote>[];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await widget.store.load();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loaded = true;
    });
  }

  Future<void> _add() async {
    if (!widget.store.canPersist) return;
    final result = await showModalBottomSheet<_Draft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RecordSheet(),
    );
    if (result == null) return;

    await widget.store.add(
      MedicationNote(
        id: _uuid.v4(),
        occurredAt: result.occurredAt,
        // ALWAYS now, never editable. When it was written down is a fact about
        // the writing, not about the deviation.
        loggedAt: DateTime.now(),
        kind: result.kind,
        notes: result.notes,
      ),
    );
    await _load();
  }

  Future<void> _delete(MedicationNote n) async {
    if (!widget.store.canPersist) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this note?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.store.remove(n.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy · HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Medication', style: TextStyle(fontSize: 16)),
            Text('Medical Event Recorder',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      floatingActionButton: !widget.store.canPersist
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Record a deviation'),
            ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const _Explainer(),
                if (!widget.store.canPersist)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Medication notes need the app database, which could not '
                      'be opened on this launch. Your events are unaffected.',
                      style: TextStyle(color: MERColours.textMuted),
                    ),
                  )
                else if (_notes.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Nothing recorded yet.\n\n'
                          'That is the normal state — this list is only for '
                          'doses you missed, took late, or changed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: MERColours.textMuted),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: _notes.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (_, i) {
                        final n = _notes[i];
                        return ListTile(
                          title: Text(fmt.format(n.occurredAt)),
                          subtitle: n.notes.isEmpty ? null : Text(n.notes),
                          leading: _KindChip(kind: n.kind),
                          trailing: IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(n),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        color: MERColours.surface,
        child: const Text(
          // THE COPY THAT KEEPS THE STREAM EXCEPTIONS-ONLY. Without it a user
          // reasonably assumes they are meant to log every dose, does it for a
          // fortnight, stops, and the list becomes misleading rather than empty.
          'Record only the doses you missed, took late, or changed. '
          'There is no need to log the ones you took as normal — '
          'the exceptions are what a specialist needs to see.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
      );
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind});
  final MedicationDeviation kind;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: MERColours.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          medicationDeviationLabel(kind),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MERColours.primary),
        ),
      );
}

class _Draft {
  const _Draft({required this.kind, required this.occurredAt, required this.notes});
  final MedicationDeviation kind;
  final DateTime occurredAt;
  final String notes;
}

class _RecordSheet extends StatefulWidget {
  const _RecordSheet();

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  MedicationDeviation? _kind;
  DateTime _when = DateTime.now();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (!mounted) return;
    setState(() => _when = DateTime(
        d.year, d.month, d.day, t?.hour ?? _when.hour, t?.minute ?? _when.minute));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy · HH:mm');
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Record a deviation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          const Text('What happened?',
              style: TextStyle(fontSize: 13, color: MERColours.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: MedicationDeviation.values
                .map((k) => ChoiceChip(
                      label: Text(medicationDeviationLabel(k)),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('When?',
              style: TextStyle(fontSize: 13, color: MERColours.textMuted)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickWhen,
            icon: const Icon(Icons.schedule),
            label: Text(fmt.format(_when)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              // NO DRUG-NAME FIELD, decided on burden grounds. Asking for a
              // name every time is a reason not to log at all.
              hintText: 'Which medication, and anything worth remembering',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  // DISABLED until a kind is chosen. It is the one field with
                  // no honest default: "missed" and "late" are different facts
                  // and neither may be guessed.
                  onPressed: _kind == null
                      ? null
                      : () => Navigator.pop(
                            context,
                            _Draft(
                              kind: _kind!,
                              occurredAt: _when,
                              notes: _notes.text.trim(),
                            ),
                          ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
