import 'package:flutter/material.dart';

import '../models/vocabulary.dart';
import '../models/vocabulary_store.dart';
import '../theme/mer_theme.dart';

/// Hide and show the entries the three pickers offer.
///
/// ## ⛔ WHY THIS SCREEN EXISTS, AND WHY IT IS ONE SCREEN
///
/// `is_active` has been on every vocabulary row since schema v2 and `setActive`
/// has been written and tested since the vocabulary landed. **No screen ever
/// called it.** Meanwhile every field in turn became user-extensible — event
/// types, then observations, then the beforehand field — so a list could grow
/// and never shrink. Two entries added while testing (`Cluster headache`,
/// `Jaw ache`) are permanent on the device, and a third was one tap away. The
/// gap grew with use, which is the worst shape for a gap to have.
///
/// ## ⛔ HIDE IS NOT DELETE, AND THAT IS THE ENTIRE DESIGN
///
/// The row stays. See [kWhyNoDelete] — the delete function does not exist, and
/// this screen must not become the thing that reintroduces it. What hiding
/// changes is exactly one thing: whether [offerable] returns the entry. Records
/// that already reference it are untouched, resolve through the same
/// [Vocabularies.labelFor] they always did, and keep their chip in a picker
/// because every picker adds back values the record already holds.
///
/// ## ⛔ AND WHY UNHIDE IS WHAT FORCED A SCREEN
///
/// A long-press on a chip was the cheap option and it can only ever do half the
/// job: **a picker does not render hidden entries, so there is nowhere in a
/// picker to un-hide from.** Unhide needs a list of everything, which is a
/// screen; and once that screen exists, putting hide anywhere else makes two
/// affordances for one operation. One mechanism, one home.
///
/// Hidden entries stay **in place, in sort order**, greyed. Not exiled to a
/// separate section at the bottom — a user looking for the thing they hid looks
/// where it used to be.
class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _Section {
  const _Section(this.table, this.title, this.blurb);
  final String table;
  final String title;
  final String blurb;
}

/// The three vocabularies this screen manages, and the words the app already
/// uses for them.
///
/// ⚠️ **`condition` IS DELIBERATELY ABSENT.** It is not a [VocabularyEntry] —
/// different table shape (`name`, no value/label split, no glyph, no seeding),
/// a different store, and **no picker anywhere in the app**. Hiding an entry
/// from a picker that does not exist, in a table holding zero rows, would be a
/// fourth variation on this mechanism built to manage nothing. When conditions
/// gets a picker it can join this screen; until then it has nothing to hide.
const List<_Section> _kSections = <_Section>[
  _Section(
      kEventTypeTable, 'Event types', 'Offered when you record what happened.'),
  _Section(kTriggerTable, 'What was happening beforehand',
      'Offered on the beforehand step. Not causes.'),
  _Section(kObservationTable, 'How you felt afterwards',
      'Offered on the afterwards step.'),
];

class _VocabularyScreenState extends State<VocabularyScreen> {
  Future<void> _setVisible(
      String table, VocabularyEntry e, bool visible) async {
    try {
      await Vocabularies.setVisible(table, e, visible);
      if (!mounted) return;
      setState(() {});
    } on VocabularyRuleError catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err.message)));
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
            Text('Your lists', style: TextStyle(fontSize: 16)),
            Text('Medical Event Recorder',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      body: ListView(
        // ⚠️ viewPadding, not a fixed number. The system navigation bar
        // OVERLAYS the window rather than shrinking it, so a constant bottom
        // padding leaves the last row underneath it — which is exactly how the
        // Medication sheet's Save button became unreachable in landscape. Same
        // fix, lifted rather than re-derived.
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom + 32),
        children: [
          const _Explainer(),
          if (!Vocabularies.canPersist)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Your lists need the app database, which could not be opened '
                'on this launch. Changes here will not be kept. Your records '
                'are unaffected.',
                style: TextStyle(color: MERColours.textMuted),
              ),
            ),
          for (final s in _kSections) ..._section(s),
        ],
      ),
    );
  }

  List<Widget> _section(_Section s) {
    final entries = Vocabularies.allIn(s.table);
    // ⚠️ Counts only what the USER hid. Observations ship 22 inactive rows —
    // the retired set and their mis-decoded twins — and "22 hidden" over a list
    // nobody has touched reads as though the user did that.
    final hidden = entries
        .where((e) => !e.isActive && !isShippedHidden(s.table, e.value))
        .length;
    return <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MERColours.textPrimary)),
            const SizedBox(height: 2),
            Text(
              hidden == 0 ? s.blurb : '${s.blurb}  $hidden hidden.',
              style:
                  const TextStyle(fontSize: 12, color: MERColours.textMuted),
            ),
          ],
        ),
      ),
      for (final e in entries) _row(s.table, e),
    ];
  }

  Widget _row(String table, VocabularyEntry e) {
    final visible = e.isActive;
    // ⛔ RETIRED BY MER, NOT BY THE USER. Showing one of these would put a
    // pre-revision value back in the picker, and its glyph is inside the
    // stored value — so the next record written with it carries an emoji into
    // feelings_json, the CSV and every backup. See [isShippedHidden].
    final retired = !visible && isShippedHidden(table, e.value);
    return Container(
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: MERColours.border, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // The glyph belongs here for the same reason it belongs on a
                  // chip: this screen IS the picker's contents.
                  e.display,
                  style: TextStyle(
                    fontSize: 15,
                    color:
                        visible ? MERColours.textPrimary : MERColours.textMuted,
                  ),
                ),
                if (!visible)
                  Text(
                      retired
                          ? 'Replaced by newer wording — still shown on records '
                              'that use it'
                          : 'Hidden — still shown on records that use it',
                      style: const TextStyle(
                          fontSize: 11, color: MERColours.textMuted)),
                if (visible && e.isProtected)
                  const Text('Cannot be hidden',
                      style:
                          TextStyle(fontSize: 11, color: MERColours.textMuted)),
              ],
            ),
          ),
          if (retired || (e.isProtected && visible))
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.lock_outline,
                  size: 18, color: MERColours.textMuted),
            )
          else
            TextButton(
              onPressed: () => _setVisible(table, e, !visible),
              child: Text(visible ? 'Hide' : 'Show'),
            ),
        ],
      ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: MERColours.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hiding stops an entry being offered when you record something new.',
            style: TextStyle(fontSize: 14, color: MERColours.textPrimary),
          ),
          SizedBox(height: 6),
          Text(
            'Nothing is deleted. Records that already use a hidden entry keep '
            'showing it, and it still appears in your exports. You can show it '
            'again at any time.',
            style: TextStyle(fontSize: 13, color: MERColours.textMuted),
          ),
        ],
      ),
    );
  }
}
