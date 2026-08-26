import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_record.dart';
import '../screens/event_wizard_screen.dart';
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

/// The date windows offered by the range filter.
///
/// Presets rather than a picker: the clinical case this exists for is "the last
/// three months, for my appointment", and a preset answers that in one tap
/// where a picker takes four. See the report for why no custom range was added.
enum _DateRange { all, days30, months3, months12 }

extension _DateRangeLabel on _DateRange {
  String get chipLabel {
    switch (this) {
      case _DateRange.all:      return 'All time';
      case _DateRange.days30:   return 'Last 30 days';
      case _DateRange.months3:  return 'Last 3 months';
      case _DateRange.months12: return 'Last 12 months';
    }
  }

  /// The inclusive lower bound, or null for [all].
  ///
  /// Anchored to the START of the day so "last 30 days" means 30 whole days,
  /// not 30 days minus the time of day — which would silently drop events
  /// recorded earlier this morning on the boundary day.
  DateTime? startFrom(DateTime now) {
    final midnight = DateTime(now.year, now.month, now.day);
    switch (this) {
      case _DateRange.all:      return null;
      case _DateRange.days30:   return midnight.subtract(const Duration(days: 29));
      case _DateRange.months3:  return DateTime(now.year, now.month - 3, now.day);
      case _DateRange.months12: return DateTime(now.year - 1, now.month, now.day);
    }
  }
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<EventRecord> _records;

  final DateFormat _uiTimeFmt = DateFormat('EEE d MMM yyyy, h:mm a');
  /// Row-level format. The date moved to the day header, so a row shows only
  /// the time — which is also what stopped "PM" wrapping onto its own line.
  final DateFormat _rowTimeFmt = DateFormat('h:mm a');
  /// Day-header format, used when the day is neither today nor yesterday.
  final DateFormat _dayHeaderFmt = DateFormat('EEE d MMM yyyy');
  final TextEditingController _searchController = TextEditingController();

  String _searchText      = '';
  bool   _referralOnly    = false;
  _DateRange _dateRange   = _DateRange.all;
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

    // Resolved once, not per record: DateTime.now() inside the predicate would
    // move the boundary while the list is being filtered.
    final from = _dateRange.startFrom(DateTime.now());

    return _records.where((r) {
      // Referral filter
      if (_referralOnly && !r.referralRequired) return false;

      // Event type filter — if none selected show all
      if (_selectedTypes.isNotEmpty && !_selectedTypes.contains(r.eventType)) {
        return false;
      }

      // ── DATE RANGE ──
      // Filters on `timestamp`, which the target data model maps to `logged_at`
      // — "never null, never editable". Deliberately NOT `occurred_at`: that
      // field is nullable and the migration leaves it NULL for every record
      // that exists today, so a filter written against it would match none of
      // them and would change meaning the day the expansion lands. Filtering on
      // the log time means this predicate keeps working, and keeps meaning the
      // same thing, across that migration.
      if (from != null && r.timestamp.isBefore(from)) return false;

      // Text search
      if (q.isEmpty) return true;

      final parsed = int.tryParse(q);
      if (parsed != null && RegExp(r'^\d+$').hasMatch(q)) {
        // THREE STATES. A measured record matches on its whole minutes, which
        // is the closest analogue of what the bucket ranges did — 187s is
        // "3 minutes" to a searcher. This is NOT new filtering: it keeps the
        // existing numeric search working for records that now carry a number
        // instead of a range. Without it the search would silently stop
        // matching every event captured from the notification.
        final secs = r.durationSeconds;
        if (secs != null) return secs ~/ 60 == parsed;

        // An UNKNOWN duration matches no numeric query. It is not zero and
        // not "any length" — the question is unanswerable for this record, so
        // excluding it is the only honest option. Including it in every
        // numeric search would be worse than excluding it from all.
        if (r.duration == null) return false;
        switch (r.duration!) {
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
        // Contributes NOTHING when unknown, rather than the word "Unknown" —
        // otherwise typing "unknown" surfaces these rows, a search feature
        // nobody asked for.
        if (r.duration != null) durationLabel(r.duration!),
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

  /// Whether any filter is narrowing the list.
  ///
  /// Derived from the filters themselves rather than by comparing counts: a
  /// count comparison would call an active filter "not narrowed" whenever it
  /// happened to exclude nothing, which is the same class of accidentally-true
  /// label this replaces.
  bool get _isNarrowed =>
      _searchText.trim().isNotEmpty ||
      _referralOnly ||
      _selectedTypes.isNotEmpty ||
      _dateRange != _DateRange.all;

  /// Sheet header. States what is actually being exported, and distinguishes a
  /// narrowed export from the whole set.
  String _exportSheetTitle() {
    final shown = _filteredRecords.length;
    final total = _records.length;
    final noun  = shown == 1 ? 'event' : 'events';
    return _isNarrowed
        ? 'Export $shown of $total $noun'
        : 'Export all $total $noun';
  }

  /// Flattens a newest-first list into day headers followed by their events.
  ///
  /// Input order is preserved exactly — this regroups, it never re-sorts. The
  /// CSV export is built separately by `buildCsv` from the record list and is
  /// oldest-first and ungrouped; nothing here touches it.
  List<_HistoryItem> _groupByDay(List<EventRecord> records) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final items = <_HistoryItem>[];
    DateTime? currentDay;

    for (var i = 0; i < records.length; i++) {
      final r   = records[i];
      final day = DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);

      if (currentDay == null || day != currentDay) {
        final label = day == today
            ? 'Today'
            : day == yesterday
                ? 'Yesterday'
                : _dayHeaderFmt.format(day);
        items.add(_HistoryItem.header(label));
        currentDay = day;
      }

      // Whether this is the last event of its day, so the divider can be
      // dropped there and each day reads as one cluster.
      final next = i + 1 < records.length ? records[i + 1] : null;
      final nextDay = next == null
          ? null
          : DateTime(next.timestamp.year, next.timestamp.month, next.timestamp.day);
      items.add(_HistoryItem.record(r, isLastOfDay: nextDay != day));
    }

    return items;
  }

  /// Removes every active filter in one action.
  void _clearFilters() {
    setState(() {
      _searchText = '';
      _searchController.clear();
      _referralOnly = false;
      _selectedTypes.clear();
      _dateRange = _DateRange.all;
    });
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
    // The SAME three-way routing as the Last Event card, so a record does not
    // open one way from Home and another from History:
    //   false  a partial          -> the guided wizard
    //   true   already completed  -> the single page
    //   null   predates it        -> the single page
    final result = await Navigator.of(context).push<EventRecord>(
      MaterialPageRoute(
        builder: (_) => wantsWizard(r)
            ? EventWizardScreen(existing: r)
            : LogEventScreen(
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
            tooltip:  'Export CSV',
            icon:     const Icon(Icons.ios_share),
            // The header said "Export N filtered events" unconditionally, which
            // was true only by coincidence — showExportOptions recomputes the
            // count from what it is handed, so it always reports 100% of the
            // export set and can never tell the user whether anything was
            // narrowed. It read correctly in a screenshot because a search
            // happened to be active at the time.
            //
            // The scope has to be decided HERE, where both numbers exist: the
            // filtered count and the total. Tooltips need hover or a long
            // press, so no touch user ever sees one — the sheet header is the
            // only place this gets read.
            onPressed: () => showExportOptions(
              context,
              shown,
              filenamePrefix: _isNarrowed
                  ? 'medical_event_recorder_filtered'
                  : 'medical_event_recorder_all',
              sheetTitle: _exportSheetTitle(),
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

            // ── DATE RANGE ──
            _DateRangeFilterChips(
              selected: _dateRange,
              onSelect: (r) => setState(() => _dateRange = r),
            ),
            const SizedBox(height: 8),

            // ── RESULTS COUNT + CLEAR ──
            // The count states the scope the same way the export header does,
            // so what the screen says and what the export says cannot drift.
            // "Clear filters" appears only while something is active: a filter
            // the user cannot tell is on is worse than no filter at all.
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shown.isEmpty
                          ? 'No events match'
                          : _isNarrowed
                              ? '${shown.length} of ${_records.length} '
                                '${_records.length == 1 ? "event" : "events"}'
                              : '${shown.length} '
                                '${shown.length == 1 ? "event" : "events"}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (_isNarrowed)
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                      label: const Text('Clear filters'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
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
                  : Builder(
                      builder: (_) {
                        // Flattened to headers-and-rows so the list stays LAZY.
                        // Grouping by nesting a ListView per day would need
                        // shrinkWrap, which builds every row up front — the
                        // opposite of what this screen needs as a diary grows.
                        // This builds a small index list instead and lets
                        // ListView.builder realise only what is on screen.
                        final items = _groupByDay(shown);
                        return ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (ctx, i) {
                            final item = items[i];
                            if (item.isHeader) {
                              return _DayHeader(label: item.header!);
                            }
                            final r = item.record!;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _EventListTile(
                                  record:   r,
                                  timeFmt:  _rowTimeFmt,
                                  onTap:    () => _editRecord(r),
                                  onDelete: () => _deleteAndPersist(r.id),
                                ),
                                if (!item.isLastOfDay)
                                  const Divider(height: 1, indent: 16),
                              ],
                            );
                          },
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
      // Absence reads as absence: the element is omitted, exactly as feelings,
      // triggers, referral and notes already are. The row reads "Mild" rather
      // than "< 1 minute · Mild" or "Unknown · Mild".
      // Three states: a number, a legacy bucket, or nothing. Absence still
      // reads as absence — the element is simply omitted.
      if (durationDisplay(r.duration, r.durationSeconds) != null)
        durationDisplay(r.duration, r.durationSeconds)!,
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
/* ===========================
   DAY GROUPING
   =========================== */

/// One entry in the flattened history list: either a day header or an event.
///
/// Exactly one of [header] and [record] is non-null, so a row can never be
/// silently neither.
class _HistoryItem {
  final String? header;
  final EventRecord? record;

  /// True when this is the last event of its day, so the trailing divider can
  /// be dropped and each day reads as a single cluster.
  final bool isLastOfDay;

  const _HistoryItem.header(this.header)
      : record = null,
        isLastOfDay = false;

  const _HistoryItem.record(this.record, {required this.isLastOfDay})
      : header = null;

  bool get isHeader => header != null;
}

class _DayHeader extends StatelessWidget {
  final String label;
  const _DayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize:      11,
          fontWeight:    FontWeight.w700,
          letterSpacing: 0.6,
          color:         MERColours.primary,
        ),
      ),
    );
  }
}

/* ===========================
   DATE RANGE FILTER CHIPS
   =========================== */

class _DateRangeFilterChips extends StatelessWidget {
  final _DateRange selected;
  final ValueChanged<_DateRange> onSelect;

  const _DateRangeFilterChips({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final range in _DateRange.values) ...[
            ChoiceChip(
              label: Text(range.chipLabel),
              selected: selected == range,
              // Single-select: the ranges are mutually exclusive, unlike the
              // type chips above, which are additive. Re-tapping the active
              // one returns to All rather than doing nothing, so the filter
              // can always be undone from where it was set.
              onSelected: (_) =>
                  onSelect(selected == range ? _DateRange.all : range),
              // NO labelStyle override. The theme sets labelStyle for the
              // unselected state and secondaryLabelStyle (white) for the
              // selected one; passing a labelStyle here overrides BOTH, which
              // left the selected chip rendering textPrimary on the dark blue
              // selectedColor — a checkmark with an invisible label. Caught on
              // the device, not in review.
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
