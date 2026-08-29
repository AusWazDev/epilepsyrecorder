import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/mer_theme.dart';

/// "When it happened", for a record written after the fact.
///
/// ## ⛔ ONE IMPLEMENTATION, TWO CALLERS — the same reason `duration_format`
/// has its own file
///
/// The wizard and the single-page form both need this, and two copies of a
/// date-and-time affordance is drift a test cannot see: both would look
/// reasonable and they would diverge on the first change to either. The
/// formatter, the future guard and the wording live here once.
///
/// ## ⛔ NULL IS "NOT ASKED", NOT "IT HAPPENED NOW"
///
/// [value] is null on every record written before this existed, and stays null
/// for anyone who records events as they happen — which is most of them, and is
/// the whole timer-driven path. A caller must never substitute `DateTime.now()`
/// for null when SAVING: that would assert a time nobody stated. Reading is
/// where the fallback belongs, through `EventRecord.whenHappened`.
///
/// ## ⚠️ THE FUTURE GUARD, AND WHY IT IS NOT INHERITED
///
/// This is modelled on `medication_screen._pickWhen`, which has a defect this
/// deliberately does not copy: `lastDate: DateTime.now()` bounds the DATE and
/// nothing bounds the CLOCK, so picking today plus a later hour yields a time
/// that has not happened yet. Here that is refused and said out loud, rather
/// than silently clamped — a clamp is how a wrong time becomes a plausible one.
class OccurredAtField extends StatelessWidget {
  const OccurredAtField({
    super.key,
    required this.value,
    required this.fallback,
    required this.onChanged,
  });

  /// The stated occurrence time, or null when nobody has said.
  final DateTime? value;

  /// What the record's time resolves to while [value] is null — the log time.
  /// Shown so the row states a real time in both states rather than a blank.
  final DateTime fallback;

  /// Null clears the field back to NOT ASKED.
  final ValueChanged<DateTime?> onChanged;

  static final DateFormat _fmt = DateFormat('d MMM yyyy · HH:mm');

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final start = value ?? fallback;

    final d = await showDatePicker(
      context: context,
      initialDate: start.isAfter(now) ? now : start,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (d == null || !context.mounted) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (!context.mounted) return;

    final chosen = DateTime(
      d.year,
      d.month,
      d.day,
      t?.hour ?? start.hour,
      t?.minute ?? start.minute,
    );

    // ⛔ REFUSED, NOT CLAMPED. Silently moving the value to `now` would store a
    // time the user did not choose and show it back as though they had.
    if (chosen.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('That time has not happened yet. Nothing was changed.'),
      ));
      return;
    }
    onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final isSet = value != null;
    return Container(
      decoration: BoxDecoration(
        color: MERColours.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('When it happened',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MERColours.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  _fmt.format(value ?? fallback),
                  style: const TextStyle(
                      fontSize: 15, color: MERColours.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  // Both states say what the value MEANS, because the same
                  // date can be either "this is when it happened" or "this is
                  // just when it was written down" and they are not the same
                  // claim about a medical record.
                  isSet
                      ? 'Recorded later than this.'
                      : 'The time this was recorded. Change it if it happened '
                          'earlier.',
                  style: const TextStyle(
                      fontSize: 11, color: MERColours.textMuted),
                ),
              ],
            ),
          ),
          if (isSet)
            TextButton(
              // Back to NOT ASKED. Deliberately not "Now" — it does not set the
              // field to the current time, it removes the statement.
              onPressed: () => onChanged(null),
              child: const Text('Clear'),
            ),
          TextButton(
            onPressed: () => _pick(context),
            child: Text(isSet ? 'Change' : 'Set'),
          ),
        ],
      ),
    );
  }
}
