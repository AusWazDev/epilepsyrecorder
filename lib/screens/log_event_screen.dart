import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../constants.dart';
import '../models/event_record.dart';
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

  late EventType _eventType;
  late DurationCategory _duration;
  late EventSeverity _severity;
  late Set<String> _selectedFeelings;
  late Set<String> _selectedTriggers;
  late bool _referralRequired;

  // Originals for change detection
  late EventType _origEventType;
  late DurationCategory _origDuration;
  late EventSeverity _origSeverity;
  late Set<String> _origFeelings;
  late Set<String> _origTriggers;
  late bool _origReferral;
  late String _origNotes;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _eventType         = e?.eventType        ?? EventType.seizure;
    _duration          = e?.duration         ?? DurationCategory.lt1;
    _severity          = e?.severity         ?? EventSeverity.mild;
    _selectedFeelings  = (e?.feelings        ?? []).toSet();
    _selectedTriggers  = (e?.triggers        ?? []).toSet();
    _referralRequired  = e?.referralRequired ?? false;
    _notesController.text = e?.notes        ?? '';

    // Store originals
    _origEventType = _eventType;
    _origDuration  = _duration;
    _origSeverity  = _severity;
    _origFeelings  = Set.from(_selectedFeelings);
    _origTriggers  = Set.from(_selectedTriggers);
    _origReferral  = _referralRequired;
    _origNotes     = _notesController.text.trim();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    if (_isNew) return true;
    return _eventType        != _origEventType ||
        _duration            != _origDuration  ||
        _severity            != _origSeverity  ||
        _referralRequired    != _origReferral  ||
        _notesController.text.trim() != _origNotes ||
        !_sameSet(_selectedFeelings, _origFeelings) ||
        !_sameSet(_selectedTriggers, _origTriggers);
  }

  bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  List<String> _buildChangeList() {
    final changes = <String>[];
    if (_eventType != _origEventType) {
      changes.add(
        'Event type: ${eventTypeLabel(_origEventType)} → ${eventTypeLabel(_eventType)}',
      );
    }
    if (_duration != _origDuration) {
      changes.add(
        'Duration: ${durationLabel(_origDuration)} → ${durationLabel(_duration)}',
      );
    }
    if (_severity != _origSeverity) {
      changes.add(
        'Severity: ${severityLabel(_origSeverity)} → ${severityLabel(_severity)}',
      );
    }
    if (_referralRequired != _origReferral) {
      changes.add(
        'Medical referral: ${_origReferral ? "Yes" : "No"} → ${_referralRequired ? "Yes" : "No"}',
      );
    }
    if (!_sameSet(_selectedFeelings, _origFeelings)) {
      changes.add('Feelings updated');
    }
    if (!_sameSet(_selectedTriggers, _origTriggers)) {
      changes.add('Triggers updated');
    }
    if (_notesController.text.trim() != _origNotes) {
      changes.add('Notes updated');
    }
    return changes;
  }

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
      eventType:        _eventType,
      duration:         _duration,
      severity:         _severity,
      feelings:         _selectedFeelings.toList(),
      triggers:         _selectedTriggers.toList(),
      referralRequired: _referralRequired,
      notes:            _notesController.text.trim(),
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
                        _SectionLabel('Event type'),
                        const SizedBox(height: 8),
                        _EventTypeGrid(
                          selected:   _eventType,
                          onSelected: (t) => setState(() => _eventType = t),
                        ),
                        const SizedBox(height: 20),

                        // ── DURATION ──
                        _SectionLabel('Duration'),
                        const SizedBox(height: 8),
                        _SelectionRow<DurationCategory>(
                          options:    DurationCategory.values,
                          selected:   _duration,
                          labelFor:   durationLabel,
                          onSelected: (d) => setState(() => _duration = d),
                        ),
                        const SizedBox(height: 20),

                        // ── SEVERITY ──
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

                        // ── FEELINGS ──
                        _SectionLabel('How are you feeling?'),
                        const SizedBox(height: 8),
                        _SelectionWrap(
                          options:  kFeelingsOptions,
                          selected: _selectedFeelings,
                          onToggle: (f) => setState(() {
                            _selectedFeelings.contains(f)
                                ? _selectedFeelings.remove(f)
                                : _selectedFeelings.add(f);
                          }),
                        ),
                        const SizedBox(height: 20),

                        // ── TRIGGERS ──
                        _SectionLabel('Possible triggers'),
                        const SizedBox(height: 8),
                        _SelectionWrap(
                          options:  kTriggerOptions,
                          selected: _selectedTriggers,
                          onToggle: (t) => setState(() {
                            _selectedTriggers.contains(t)
                                ? _selectedTriggers.remove(t)
                                : _selectedTriggers.add(t);
                          }),
                        ),
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
  final EventType selected;
  final ValueChanged<EventType> onSelected;

  const _EventTypeGrid({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 3.2,
      children: EventType.values.map((type) {
        final isSelected = selected == type;
        return _EventTypeButton(
          type: type,
          isSelected: isSelected,
          onTap: () => onSelected(type),
        );
      }).toList(),
    );
  }
}

class _EventTypeButton extends StatelessWidget {
  final EventType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _EventTypeButton({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _icon {
    switch (type) {
      case EventType.seizure:
        return Icons.monitor_heart_outlined;
      case EventType.absence:
        return Icons.access_time_outlined;
      case EventType.medication:
        return Icons.medication_outlined;
      case EventType.other:
        return Icons.edit_note_outlined;
    }
  }

  Color get _selectedColor {
    switch (type) {
      case EventType.seizure:
        return MERColours.alert;
      case EventType.absence:
        return MERColours.action;
      case EventType.medication:
        return MERColours.success;
      case EventType.other:
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
                eventTypeLabel(type),
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
  final T selected;
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
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _SelectionWrap({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
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
              option,
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
      }).toList(),
    );
  }
}