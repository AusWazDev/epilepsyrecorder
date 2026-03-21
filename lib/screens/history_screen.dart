import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_record.dart';
import '../screens/log_event_screen.dart';
import '../theme/mer_theme.dart';

class HistoryScreen extends StatefulWidget {
  final List<EventRecord> records;
  final Future<void> Function(List<EventRecord> updated) onRecordsChanged;
  final Future<void> Function(
    EventRecord existing, {
    required bool confirmOnSave,
  }) onEdit;

  const HistoryScreen({
    super.key,
    required this.records,
    required this.onRecordsChanged,
    required this.onEdit,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<EventRecord> _records;

  final DateFormat _uiTimeFmt = DateFormat('EEE d MMM yyyy, h:mm a');
  final TextEditingController _searchController = TextEditingController();

  String _searchText      = '';
  bool   _referralOnly    = false;
  final Set<EventType> _selectedTypes = {};

  @override
  void initState() {
    super.initState();
    _records = List<EventRecord>.from(widget.records);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── FILTERING ──
  List<EventRecord> get _filteredRecords {
    final q = _searchText.trim().toLowerCase();

    return _records.where((r) {
      // Referral filter
      if (_referralOnly && !r.referralRequired) return false;

      // Event type filter — if none selected show all
      if (_selectedTypes.isNotEmpty && !_selectedTypes.contains(r.eventType)) {
        return false;
      }

      // Text search
      if (q.isEmpty) return true;

      final parsed = int.tryParse(q);
      if (parsed != null && RegExp(r'^\d+$').hasMatch(q)) {
        switch (r.duration) {
          case DurationCategory.lt1:
            return parsed < 1;
          case DurationCategory.oneToFive:
            return parsed >= 1 && parsed <= 5;
          case DurationCategory.gt5:
            return parsed > 5;
        }
      }

      final haystack = [
        eventTypeLabel(r.eventType),
        durationLabel(r.duration),
        severityLabel(r.severity),
        r.feelings.join(' '),
        r.triggers.join(' '),
        'referral: ${r.referralRequired ? "yes" : "no"}',
        r.notes,
        _uiTimeFmt.format(r.timestamp),
      ].join(' ').toLowerCase();

      return haystack.contains(q);
    }).toList();
  }

  // ── DELETE ──
  Future<void> _deleteAndPersist(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this event?'),
        content: const Text(
          'This action cannot be undone.\n\n'
          'Are you sure you want to delete this event?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _records.removeWhere((r) => r.id == id));
    await widget.onRecordsChanged(_records);
  }

  // ── EDIT ──
  Future<void> _editRecord(EventRecord r) async {
    final result = await Navigator.of(context).push<EventRecord>(
      MaterialPageRoute(
        builder: (_) => LogEventScreen(
          existing:      r,
          confirmOnSave: true,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      final index = _records.indexWhere((e) => e.id == result.id);
      if (index != -1) _records[index] = result;
      _records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });

    await widget.onRecordsChanged(_records);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _filteredRecords;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:       MainAxisSize.min,
          children: [
            Text(
              'History',
              style: TextStyle(
                fontSize:   15,
                fontWeight: FontWeight.w600,
                color:      Colors.white,
              ),
            ),
            Text(
              'Medical Event Recorder',
              style: TextStyle(
                fontSize: 10,
                color:    Colors.white54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip:  'Export CSV (filtered)',
            icon:     const Icon(Icons.ios_share),
            onPressed: () => showExportOptions(
              context,
              shown,
              filenamePrefix: 'medical_event_recorder_filtered',
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── SEARCH ──
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon:    const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchText = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                hintText: 'Search notes, feelings, severity, triggers…',
              ),
              onChanged: (v) => setState(() => _searchText = v),
            ),
            const SizedBox(height: 10),

            // ── EVENT TYPE CHIPS ──
            _EventTypeFilterChips(
              selected: _selectedTypes,
              onToggle: (type) {
                setState(() {
                  _selectedTypes.contains(type)
                      ? _selectedTypes.remove(type)
                      : _selectedTypes.add(type);
                });
              },
            ),
            const SizedBox(height: 8),

            // ── REFERRAL TOGGLE ──
            Card(
              child: SwitchListTile(
                dense: true,
                title: Text(
                  'Referral required only',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Show only events that required medical referral',
                ),
                value:     _referralOnly,
                onChanged: (v) => setState(() => _referralOnly = v),
              ),
            ),
            const SizedBox(height: 8),

            // ── RESULTS COUNT ──
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                shown.isEmpty
                    ? 'No events match'
                    : '${shown.length} '
                      '${shown.length == 1 ? "event" : "events"}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

            // ── LIST ──
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text(
                        _records.isEmpty
                            ? 'No events yet.\n'
                              'Tap "Record Event" to get started.'
                            : 'No events match your search\n'
                              'or filters.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      itemCount:        shown.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final r = shown[i];
                        return _EventListTile(
                          record:   r,
                          timeFmt:  _uiTimeFmt,
                          onTap:    () => _editRecord(r),
                          onDelete: () => _deleteAndPersist(r.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ===========================
   EVENT TYPE FILTER CHIPS
   =========================== */

class _EventTypeFilterChips extends StatelessWidget {
  final Set<EventType> selected;
  final ValueChanged<EventType> onToggle;

  const _EventTypeFilterChips({
    required this.selected,
    required this.onToggle,
  });

  Color _activeColor(EventType t) {
    switch (t) {
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
    return Wrap(
      spacing:    6,
      runSpacing: 6,
      children: EventType.values.map((type) {
        final isSelected = selected.contains(type);
        final colour     = _activeColor(type);
        return GestureDetector(
          onTap: () => onToggle(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical:   6,
            ),
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
              eventTypeLabel(type),
              style: TextStyle(
                fontSize:   12,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: isSelected
                    ? Colors.white
                    : MERColours.textMuted,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/* ===========================
   EVENT LIST TILE
   =========================== */

class _EventListTile extends StatelessWidget {
  final EventRecord record;
  final DateFormat  timeFmt;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EventListTile({
    required this.record,
    required this.timeFmt,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r          = record;
    final notesShort = r.notes.trim().isEmpty
        ? ''
        : (r.notes.trim().length > 60
            ? '${r.notes.trim().substring(0, 60)}…'
            : r.notes.trim());

    final parts = <String>[
      durationLabel(r.duration),
      severityLabel(r.severity),
      if (r.feelings.isNotEmpty)  r.feelings.join(', '),
      if (r.triggers.isNotEmpty)  'Triggers: ${r.triggers.join(', ')}',
      if (r.referralRequired)     'Referral: Yes',
      if (notesShort.isNotEmpty)  'Notes: $notesShort',
    ];

    return ListTile(
      onTap:  onTap,
      title: Row(
        children: [
          Expanded(
            child: Text(timeFmt.format(r.timestamp)),
          ),
          _EventTypeBadge(type: r.eventType),
        ],
      ),
      subtitle: Text(
        parts.join(' · '),
        maxLines:  2,
        overflow:  TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon:      const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }
}

/* ===========================
   EVENT TYPE BADGE
   =========================== */

class _EventTypeBadge extends StatelessWidget {
  final EventType type;
  const _EventTypeBadge({required this.type});

  Color get _bg {
    switch (type) {
      case EventType.seizure:
        return const Color(0xFFFAECE7);
      case EventType.absence:
        return const Color(0xFFEAF4FB);
      case EventType.medication:
        return const Color(0xFFEAF3DE);
      case EventType.other:
        return const Color(0xFFF1EFE8);
    }
  }

  Color get _fg {
    switch (type) {
      case EventType.seizure:
        return const Color(0xFF993C1D);
      case EventType.absence:
        return const Color(0xFF185FA5);
      case EventType.medication:
        return const Color(0xFF3B6D11);
      case EventType.other:
        return const Color(0xFF5F5E5A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical:   3,
      ),
      decoration: BoxDecoration(
        color:        _bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _fg.withOpacity(0.4),
          width: 0.5,
        ),
      ),
      child: Text(
        eventTypeLabel(type),
        style: TextStyle(
          fontSize:   11,
          fontWeight: FontWeight.w500,
          color:      _fg,
        ),
      ),
    );
  }
}