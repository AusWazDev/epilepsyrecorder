import 'package:flutter/material.dart';

import '../models/condition.dart';
import '../models/vocabulary.dart';
import '../models/vocabulary_store.dart';
import '../theme/mer_theme.dart';

/// Name what you track, and say which event types belong to each.
///
/// ## ⛔ THIS SCREEN EXISTS TO AVOID A MIGRATION
///
/// The `condition` table has existed since schema v8, empty, reaching nothing.
/// It was built that way deliberately: **assigning a condition to the 72
/// existing records is an assertion about someone's health invented by code**,
/// and three design reads rejected it on exactly that ground.
///
/// The way out is that a record's condition is DERIVED from its event type, not
/// stored on the record. So the user makes ONE statement about their own
/// vocabulary — *"Seizure / fit and Absence episode are my epilepsy"* — and
/// every record carrying those types attributes itself. No migration, no bulk
/// edit, and the statement is theirs and revisable.
///
/// ## ⛔ ONE CONDITION PER TYPE, AND IT FAILS VISIBLY
///
/// Each type has ONE condition, because a type is the name of a thing that
/// happened — if it belonged to two, an event of that type could be either,
/// which is not a type but an ambiguity. The edge case is a generic word:
/// "Headache" is plausible for epilepsy and migraine both. **The honest
/// handling is two types carrying the same word, one per condition**, because a
/// headache in a seizure cluster and a migraine headache are different clinical
/// events even when the word matches.
///
/// A user who tries to put one type under two conditions finds the second
/// choice REPLACES the first, and the screen says so before they tap. That is a
/// conversation, not a silent wrong answer.
///
/// ## ⚠️ NOTHING HERE TOUCHES THE CAPTURE PATH
///
/// Quick-record stays one tap and asks nothing. DATA-MODEL §5: *nothing at
/// capture time.* A record with no type has no condition, and that stays a real
/// answer rather than defaulting to whatever was named first.
class ConditionsScreen extends StatefulWidget {
  const ConditionsScreen({super.key, required this.store});

  /// ⛔ A STORE, NEVER A `Database`. `sqlite_single_writer_test` enforces it.
  final ConditionStore store;

  @override
  State<ConditionsScreen> createState() => _ConditionsScreenState();
}

class _ConditionsScreenState extends State<ConditionsScreen> {
  List<Condition> _conditions = const <Condition>[];
  bool _loaded = false;
  bool _adding = false;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await widget.store.load();
    if (!mounted) return;
    setState(() {
      _conditions = c;
      _loaded = true;
    });
  }

  Future<void> _add() async {
    final text = _nameController.text.trim();
    if (text.isEmpty) return;
    await widget.store.add(text);
    _nameController.clear();
    if (!mounted) return;
    setState(() => _adding = false);
    await _load();
  }

  Future<void> _assign(VocabularyEntry type, int? conditionId) async {
    try {
      await Vocabularies.setCondition(kEventTypeTable, type, conditionId);
      if (!mounted) return;
      setState(() {});
    } on VocabularyRuleError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('What you track', style: TextStyle(fontSize: 16)),
            Text('Medical Event Recorder',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              // viewPadding, not a constant: the system nav bar OVERLAYS the
              // window, so a fixed number leaves the last row underneath it.
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewPadding.bottom + 32),
              children: [
                const _Explainer(),
                if (!widget.store.canPersist)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'This needs the app database, which could not be opened '
                      'on this launch. Your records are unaffected.',
                      style: TextStyle(color: MERColours.textMuted),
                    ),
                  ),
                ..._conditionsSection(),
                ..._typesSection(),
              ],
            ),
    );
  }

  List<Widget> _conditionsSection() => <Widget>[
        _heading('Conditions',
            _conditions.isEmpty
                // ⛔ THE SHAPE, NOT A DIAGNOSIS. The hint below used to read
                // "Epilepsy, migraine, something else" — naming two conditions,
                // one of which the register has in the BLOCKED set. Naming the
                // shape is true; naming a diagnosis is a claim about what MER
                // serves, and it is the same claim being corrected in the store
                // listing.
                //
                // It belongs HERE rather than in the hint because a placeholder
                // vanishes the moment someone types. This blurb is visible
                // whether the field is focused or not.
                ? 'Nothing named yet. For things that happen in episodes — '
                    'they start, they stop. Most people only ever name one.'
                : 'The first one you named is your main one.'),
        for (final c in _conditions)
          _row(
            title: c.name,
            // The count is what tells a user whether their assignment worked,
            // without making them go and look at a picker.
            subtitle: () {
              final n = Vocabularies.allIn(kEventTypeTable)
                  .where((e) => e.conditionId == c.id)
                  .length;
              return n == 0
                  ? 'No event types yet — assign some below'
                  : '$n event ${n == 1 ? "type" : "types"}';
            }(),
          ),
        if (_adding)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      // Defers to the user's own word, the way the whole
                      // vocabulary does — renameEntry is is_seeded = 1 only,
                      // because a user's entry is theirs and MER does not
                      // relabel it. Deliberately NOT "whatever you call your
                      // episodes": this field takes a CONDITION, and that
                      // wording invites the event type instead, producing a
                      // condition named "Seizures" holding a type "Seizure".
                      hintText: 'The name you use for it',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                TextButton(onPressed: _add, child: const Text('Add')),
              ],
            ),
          )
        else if (widget.store.canPersist)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _adding = true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Name a condition'),
              ),
            ),
          ),
      ];

  List<Widget> _typesSection() {
    if (_conditions.isEmpty) return const <Widget>[];
    final types = Vocabularies.allIn(kEventTypeTable)
        .where((e) => e.isActive)
        .toList();
    return <Widget>[
      _heading('Event types',
          'Each type belongs to ONE condition. Choosing a second replaces the '
              'first — if a word fits both, make two types with that word.'),
      for (final t in types) _typeRow(t),
    ];
  }

  Widget _typeRow(VocabularyEntry t) => Container(
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: MERColours.border, width: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(t.label,
                  style: const TextStyle(
                      fontSize: 15, color: MERColours.textPrimary)),
            ),
            DropdownButton<int?>(
              value: _conditions.any((c) => c.id == t.conditionId)
                  ? t.conditionId
                  : null,
              underline: const SizedBox.shrink(),
              hint: const Text('Not set',
                  style: TextStyle(fontSize: 14, color: MERColours.textMuted)),
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Not set', style: TextStyle(fontSize: 14)),
                ),
                for (final c in _conditions)
                  DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text(c.name, style: const TextStyle(fontSize: 14)),
                  ),
              ],
              onChanged: widget.store.canPersist
                  ? (v) => _assign(t, v)
                  : null,
            ),
          ],
        ),
      );

  Widget _heading(String title, String blurb) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MERColours.textPrimary)),
            const SizedBox(height: 2),
            Text(blurb,
                style: const TextStyle(
                    fontSize: 12, color: MERColours.textMuted)),
          ],
        ),
      );

  Widget _row({required String title, required String subtitle}) => Container(
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: MERColours.border, width: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, color: MERColours.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: MERColours.textMuted)),
          ],
        ),
      );
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: MERColours.surface,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name what you track, and say which event types belong to each.',
              style: TextStyle(fontSize: 14, color: MERColours.textPrimary),
            ),
            SizedBox(height: 6),
            Text(
              'Your records follow their event type, so nothing you have '
              'already recorded is changed or reassigned by anything on this '
              'screen. Recording an event still takes one tap and never asks '
              'which condition it was.',
              style: TextStyle(fontSize: 13, color: MERColours.textMuted),
            ),
          ],
        ),
      );
}
