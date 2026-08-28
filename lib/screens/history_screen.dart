import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_record.dart';
import '../models/vocabulary.dart';
import '../models/vocabulary_store.dart';
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

/// The filename prefix for an export, given whether the list is narrowed.
///
/// ## Why this is a named function and not two inline strings
///
/// The sheet header states the scope, and it is the last defence against
/// exporting a filtered set believing it to be complete. But **nobody reads the
/// sheet again afterwards.** The file outlives it: once it is attached to an
/// email, the filename is the only surviving statement of scope a clinician
/// ever sees.
///
/// So the two must not be able to disagree. A file called `_all_` holding a
/// filtered set is worse than no statement at all - it is a positive assertion
/// of completeness over an incomplete export, which is the exact failure the
/// header exists to prevent, displaced one artefact downstream.
///
/// Named so a test can call the REAL mapping rather than restate it. A test
/// that rewrites these two strings agrees with the source by construction and
/// would go on passing through precisely the change it is meant to catch.
String exportFilenamePrefix({required bool narrowed}) => narrowed
    ? 'medical_event_recorder_filtered'
    : 'medical_event_recorder_all';

/// The date windows offered by the range filter.
///
/// Presets rather than a picker: the clinical case this exists for is "the last
/// three months, for my appointment", and a preset answers that in one tap
/// where a picker takes four. See the report for why no custom range was added.
/// The filters this screen has, ENUMERATED.
///
/// ⚠️ **THE HAZARD THIS EXISTS TO CLOSE.** The filters used to live on the
/// screen, so a user could see one was on. They now live in a sheet, and the
/// only thing telling them is a badge and a line — both computed from
/// [_HistoryScreenState.activeFilters]. If a filter is ever added to the
/// PREDICATE and forgotten HERE, the screen shows a partial history while
/// claiming to be complete, and the export sheet says "Export all 74 events"
/// while exporting twelve. That is a partial clinical record sent to an
/// appointment.
///
/// The old `_isNarrowed` was four `||`s that someone had to remember to
/// extend. This is an enum, so `FilterKind.values` is a list a TEST can walk —
/// adding a case without wiring it fails, rather than shipping quietly.
///
/// NOT private, so the test can enumerate it. Nothing else in the app uses it.
enum FilterKind {
  search,
  eventType,
  referral,
  dateRange,

  /// Records with a duration, type or severity still unset. See [isIncomplete]
  /// for where the line falls, and why it is FIELD INSPECTION rather than
  /// `detailsCompleted` — the two answer different questions, and a
  /// wizard-completed record with fields skipped is exactly the one being
  /// hunted for.
  incomplete,
}

/// What each reads as on the applied-filters line. Short, because several
/// appear at once.
extension FilterKindLabel on FilterKind {
  String get lineLabel {
    switch (this) {
      case FilterKind.search:    return 'search';
      case FilterKind.eventType: return 'type';
      case FilterKind.referral:  return 'referral';
      case FilterKind.dateRange: return 'date';
      case FilterKind.incomplete: return 'needs details';
    }
  }
}

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
  bool   _incompleteOnly  = false;
  _DateRange _dateRange   = _DateRange.all;
  final Set<String> _selectedTypes = {};

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

      // Needs-details filter. Catch-all: ANY unset field qualifies, because a
      // record missing only its severity is still incomplete.
      if (_incompleteOnly && !isIncomplete(r)) return false;

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
        // Contribute NOTHING when unknown, the same rule duration already
        // follows below — otherwise typing "seizure" surfaces every record
        // nobody classified, which is the opposite of a search.
        eventTypeDisplay(r.eventType) ?? '',
        // Contributes NOTHING when unknown, rather than the word "Unknown" —
        // otherwise typing "unknown" surfaces these rows, a search feature
        // nobody asked for.
        if (r.duration != null) durationLabel(r.duration!),
        severityDisplay(r.severity) ?? '',
        // BOTH the stored values and their labels. Searching "confused"
        // must find a record whether it carries the legacy emoji string or
        // the revised plain one — the user typed a word, not a data format.
        r.feelings.join(' '),
        r.feelings
            .map((v) => Vocabularies.labelFor(kObservationTable, v))
            .join(' '),
        // BOTH, same as observations above — a renamed trigger must stay
        // findable by the word the user now sees AND by what the record holds.
        r.triggers.join(' '),
        r.triggers
            .map((v) => Vocabularies.labelFor(kTriggerTable, v))
            .join(' '),
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
  /// EVERY filter currently narrowing the list.
  ///
  /// ONE source for three consumers — the AppBar badge, the applied-filters
  /// line, and the export scope statement. They cannot disagree, because there
  /// is nothing for them to disagree about.
  ///
  /// A `switch` over [FilterKind] rather than a set of `||`s, and deliberately
  /// with NO `default` arm: adding a case to the enum fails to compile here
  /// until it is handled. That is the same compile-error-as-feature the
  /// nullable severity work relied on.
  Set<FilterKind> get activeFilters {
    final out = <FilterKind>{};
    for (final k in FilterKind.values) {
      final active = switch (k) {
        FilterKind.search => _searchText.trim().isNotEmpty,
        FilterKind.eventType => _selectedTypes.isNotEmpty,
        FilterKind.referral => _referralOnly,
        FilterKind.dateRange => _dateRange != _DateRange.all,
        FilterKind.incomplete => _incompleteOnly,
      };
      if (active) out.add(k);
    }
    return out;
  }

  bool get _isNarrowed => activeFilters.isNotEmpty;

  /// Sheet header. States what is actually being exported, and distinguishes a
  /// narrowed export from the whole set.
  ///
  /// ⚠️ THE NOUN AGREES WITH `total`, NOT `shown`. Both strings place it
  /// immediately after `total`, so it is the head of the "of N" phrase and
  /// agrees with that number: "Export 1 of 71 events". Agreeing with `shown`
  /// put a singular noun next to a plural number — "Export 1 of 71 event" —
  /// which is why this reads as a one-word change rather than a restructure.
  ///
  /// Reachable whenever exactly one record shows out of many, which the "Needs
  /// details" queue makes ordinary rather than rare: working the queue down
  /// ENDS at one, so the last export before it empties is the broken reading.
  String _exportSheetTitle() {
    final shown = _filteredRecords.length;
    final total = _records.length;
    final noun  = total == 1 ? 'event' : 'events';
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
  /// Every filter, in one scrolling sheet.
  ///
  /// ## Why a sheet and not a screen
  ///
  /// The filtered list stays visible behind it, which is what the user is
  /// judging — did that do what I meant. A full screen hides the answer.
  ///
  /// ## Immediate application, and what happens to the count
  ///
  /// No confirm: the list churning behind you is FEEDBACK, and with a count
  /// visible it is the fastest way to see a filter did nothing. A confirm step
  /// would add a tap to the common case (one filter) to help the rare one, and
  /// would create a "set but not applied" state — a second place to forget
  /// something is on, on a screen whose whole hazard is forgetting.
  ///
  /// ⚠️ **The count updates LIVE, and that is only safe because the banner is
  /// above the sheet.** A sheet at 0.75 of the height leaves the AppBar and the
  /// banner visible, so "12 of 74" changes where the user can see it change. A
  /// count that moved behind an opaque sheet and settled on close would be
  /// worse than one that never moved — the user would return to a number they
  /// did not watch arrive.
  ///
  /// ## Windows — A KNOWN COSMETIC COMPROMISE, CHOSEN RATHER THAN OVERLOOKED
  ///
  /// The same sheet, no special case, and it is **visually odd on a desktop**:
  /// a 560px-wide bottom sheet inside a 1550px window is a phone idiom in the
  /// wrong place. It is FUNCTIONALLY FINE — measured at 560x700, the sheet
  /// occupies 537px, every section is present, referral is reachable by
  /// scroll, and nothing overflows.
  ///
  /// ⚠️ **DO NOT "FIX" THIS WITH A DIALOG VARIANT WITHOUT REOPENING THE
  /// DECISION.** A desktop variant is the second code path that "no fork"
  /// exists to avoid: its own layout, its own tests, and its own behaviour to
  /// keep in step with this one every time a filter is added. The cost is
  /// permanent and recurring; the benefit is that a sheet looks less strange
  /// on a platform with no notification path, where History is already the
  /// larger part of what the app does.
  ///
  /// Fine beats optimal when optimal costs a fork. The oddity is the price and
  /// it was paid deliberately.
  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: MERColours.background,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          // StatefulBuilder so the sheet redraws its own controls, and
          // setState on the SCREEN so the list and the banner redraw too.
          // Both are needed: the sheet owns no state of its own.
          return StatefulBuilder(
            builder: (context, setSheetState) {
              void update(VoidCallback fn) {
                setState(fn);
                setSheetState(() {});
              }

              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Filters',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      if (_isNarrowed)
                        TextButton.icon(
                          onPressed: () => update(() {
                            _searchText = '';
                            _searchController.clear();
                            _referralOnly = false;
                            _incompleteOnly = false;
                            _selectedTypes.clear();
                            _dateRange = _DateRange.all;
                          }),
                          icon: const Icon(Icons.filter_alt_off_outlined,
                              size: 16),
                          label: const Text('Clear all'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── SEARCH ── first, because it is the one that narrows the
                  // export most easily without being noticed.
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20),
                      // The two field names were renamed and this was not. "feelings"
                      // is the AFTERWARDS step and "triggers" is BEFOREHAND —
                      // a word deliberately removed from the input because it
                      // asserts cause, and which must not survive in the one
                      // place telling the user what they can search.
                      hintText: 'Search notes, afterwards, beforehand, '
                          'severity…',
                      suffixIcon: _searchText.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => update(() {
                                _searchText = '';
                                _searchController.clear();
                              }),
                            )
                          : null,
                    ),
                    onChanged: (v) => update(() => _searchText = v),
                  ),
                  const SizedBox(height: 20),

                  // ── EVENT TYPE ── UNBOUNDED by design: user-defined types
                  // are coming. It is placed after search and before the two
                  // short controls so that a long vocabulary pushes only ITSELF
                  // down — the sheet scrolls, and referral and date stay
                  // reachable by scrolling rather than being unreachable.
                  // ── SHOW ONLY ──
                  // A CHIP, not a toggle, per the decision: filter VALUES are
                  // chips, filter MODES are toggles, and this is being treated
                  // as a value.
                  //
                  // ⚠️ It sits FIRST, above the type chips, because the type
                  // list is unbounded — a short control placed after it would
                  // be pushed further down the sheet with every type a user
                  // adds. The two short controls that could not scroll away
                  // are placed where they cannot.
                  //
                  // "Referral required only" is still a toggle below. That is
                  // not an inconsistency to tidy: referral is a MODE by the
                  // same rule. If it ever moves, it moves into this section.
                  const _SheetSectionLabel('Show only'),
                  const SizedBox(height: 8),
                  // ⚠️ WRAPPED. A direct child of the ListView is stretched to
                  // full width, and a full-width chip reads as a BUTTON — which
                  // is exactly the toggle-versus-chip distinction the decision
                  // turned on. Found on the tablet: it rendered as a bordered
                  // bar spanning the sheet. A Wrap sizes it to its content, the
                  // way every other chip row on this screen is sized, and takes
                  // a second chip without changing shape.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _NeedsDetailsChip(
                        selected: _incompleteOnly,
                        onToggle: () =>
                            update(() => _incompleteOnly = !_incompleteOnly),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const _SheetSectionLabel('Event type'),
                  const SizedBox(height: 8),
                  _EventTypeFilterChips(
                    selected: _selectedTypes,
                    onToggle: (type) => update(() =>
                        _selectedTypes.contains(type)
                            ? _selectedTypes.remove(type)
                            : _selectedTypes.add(type)),
                  ),
                  const SizedBox(height: 20),

                  const _SheetSectionLabel('Date range'),
                  const SizedBox(height: 8),
                  _DateRangeFilterChips(
                    selected: _dateRange,
                    onSelect: (r) => update(() => _dateRange = r),
                  ),
                  const SizedBox(height: 20),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _referralOnly,
                    title: const Text('Referral required only'),
                    subtitle: const Text(
                        'Show only events that required medical referral'),
                    onChanged: (v) => update(() => _referralOnly = v),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _searchText = '';
      _searchController.clear();
      _referralOnly = false;
      _incompleteOnly = false;
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
    // ⚠️ THIS IS THE COMPLETION ROUTE — the second entry point to the wizard,
    // and the reason the "needs details" filter is worth having. A queue that
    // surfaces records and offers nothing to do about them is a list of
    // complaints.
    //
    // ONE rule, `wantsWizard`, shared with the Last Event card and the
    // notification tap. That is the answer to "how do the two coexist without
    // a third rule appearing": there is no second rule to coexist with. A
    // path-specific key is exactly how a third appears.
    //
    //   detailsCompleted == false   a partial          -> the wizard
    //   isIncomplete                a gap in the three -> the wizard
    //   neither                     nothing to add     -> the single page
    //
    // The stale version of this comment described the three-way read on
    // `detailsCompleted` ALONE, which stopped being the rule when the filter
    // landed — a legacy record with a missing duration routed to the form
    // under that reading and routes to the wizard under this one.
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
          // ── FILTERS ──
          // The badge is the SUMMARY; the banner below the AppBar is the
          // detail. Placed before Export deliberately: the order of the two
          // actions is the order of the decision — narrow, then send.
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Filters',
                icon: const Icon(Icons.filter_list),
                onPressed: _openFilterSheet,
              ),
              if (activeFilters.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 8,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: MERColours.alert,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${activeFilters.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
            // ⛔ EVENTS ONLY, DELIBERATELY, and `notes` is left at its
            // default rather than omitted by accident.
            //
            // This export is SCOPED - it emits what the filters are showing,
            // and the sheet header says so. Medication notes are not filtered
            // by any of them, so including them would mean a file whose
            // scope statement is false: "Export 1 of 71 events" beside a file
            // containing every deviation ever recorded.
            //
            // The whole-record export lives in Your data and carries both.
            onPressed: () => showExportOptions(
              context,
              shown,
              filenamePrefix: exportFilenamePrefix(narrowed: _isNarrowed),
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

            // ⚠️ THE APPLIED-FILTERS BANNER. Safety work, not decoration.
            //
            // Hiding the controls in a sheet makes this screen better and makes the
            // FORGOTTEN-FILTER failure worse: someone who does not notice a filter is
            // on exports a partial history for an appointment and sends an incomplete
            // clinical record. This banner is what prevents that.
            //
            // Deliberately loud. It uses the ALERT colour, states the count in the
            // same breath as the filters, and carries its own Clear action. It is
            // ABSENT when nothing is active, so its PRESENCE is the signal — a
            // permanent strip that usually reads "no filters" is chrome, and chrome
            // is what gets skimmed.
            //
            // It sits ABOVE the list and BELOW the AppBar, the one band a bottom
            // sheet does not cover — so it stays readable while filters are being
            // changed. See _openFilterSheet.
            if (_isNarrowed) ...[
              _AppliedFiltersBanner(
                active: activeFilters,
                shown: shown.length,
                total: _records.length,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 10),
            ],

            // ── RESULTS COUNT ──
            // The QUIET count, and ONLY when nothing is filtered: "8 events".
            //
            // When a filter IS on, the banner above states the count in the same
            // sentence as the reason. Repeating it here would put the number twice on
            // one screen — once loud with its cause, once muted without it — and the
            // muted one is what a skimming eye lands on. That is exactly the reading
            // this redesign exists to prevent.
            //
            // "Clear filters" moved into the banner and the sheet, both of which only
            // exist when there is something to clear.
            if (!_isNarrowed)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  shown.isEmpty
                      ? 'No events yet'
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

/// ⚠️ **THE SAFETY CONTROL OF THIS REDESIGN.**
///
/// The filters moved into a sheet, which reclaims the screen and creates one
/// hazard: a user who does not know a filter is on reads a partial history as
/// their whole history, and exports it for an appointment.
///
/// Everything about this widget is chosen to make that hard:
///
///   * **ALERT colour, not muted.** The rest of the app uses this colour for
///     the seizure badge and destructive actions. Here it is doing the same
///     job — saying "this is not the whole picture".
///   * **It NAMES the filters**, so a user knows what to clear rather than
///     only that something is set.
///   * **The count is in the same sentence**, so "12 of 74" is read together
///     with the reason rather than in a separate muted line.
///   * **It is ABSENT when nothing is active.** A permanent strip reading "no
///     filters" is chrome, and chrome is skimmed. Presence is the signal.
///   * **Clear is inside it**, reachable without opening the sheet the user
///     has forgotten about.
/// A section heading inside the filter sheet. Its own widget so the four
/// sections cannot drift apart the way the four filter CONTROLS did — chips,
/// a Card, more chips and a bare TextField, no two sharing an implementation.
class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge,
      );
}

/// The "Needs details" chip.
///
/// Styled from `_DateRangeFilterChips` deliberately rather than freshly: the
/// old filter row had four controls with no two sharing an implementation, and
/// that is what the redesign set out to stop. A new control that invents a
/// fifth look would undo it.
class _NeedsDetailsChip extends StatelessWidget {
  const _NeedsDetailsChip({required this.selected, required this.onToggle});

  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? MERColours.primary : MERColours.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? MERColours.primary : MERColours.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 15, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              'Needs details',
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : MERColours.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppliedFiltersBanner extends StatelessWidget {
  const _AppliedFiltersBanner({
    required this.active,
    required this.shown,
    required this.total,
    required this.onClear,
  });

  final Set<FilterKind> active;
  final int shown;
  final int total;
  final VoidCallback onClear;

  /// "Filtered by search" / "Filtered by search and type" / "…, type and date".
  ///
  /// Enumerated from [FilterKind.values] rather than from `active` so the
  /// order is stable — a line whose words reorder as filters toggle is harder
  /// to read at a glance than one that always reads the same way.
  String get _reason {
    final names = <String>[
      for (final k in FilterKind.values)
        if (active.contains(k)) k.lineLabel,
    ];
    if (names.length == 1) return names.single;
    return '${names.take(names.length - 1).join(', ')} and ${names.last}';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: MERColours.alert.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: MERColours.alert, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.filter_alt, size: 18, color: MERColours.alert),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                // ONE sentence. The count and the cause are read together, so
                // "showing 12 of 74" can never be seen without "filtered by".
                'Showing $shown of $total — filtered by $_reason',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MERColours.alert,
                ),
              ),
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: MERColours.alert,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Clear'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTypeFilterChips extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _EventTypeFilterChips({
    required this.selected,
    required this.onToggle,
  });

  /// A colour per SEEDED type, and one neutral colour for everything else.
  ///
  /// User-defined types are not given a colour. Inventing a palette entry per
  /// new type would either repeat colours — making two types look like the same
  /// one — or drift away from the four the app's identity is built on. Neutral
  /// is the honest rendering of "MER has no opinion about this one".
  Color _activeColor(String value) {
    switch (value) {
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
    return Wrap(
      spacing:    6,
      runSpacing: 6,
      // OFFERABLE, not every row: a retired type must not keep appearing as a
      // filter. `offerable` also forces "Other" last.
      children: Vocabularies.offerableEventTypes.map((entry) {
        final type       = entry.value;
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
      // Omitted when not assessed, exactly as duration is above. A row that
      // said "Severity: unknown" would spend its one line on an absence.
      if (severityDisplay(r.severity) != null)
        severityDisplay(r.severity)!,
      // LABELS, not stored values. Found on the tablet: three records carry
      // the legacy `😵 Confused`, and the row rendered its emoji as MOJIBAKE
      // — the chips have an emoji-capable font and this text style does not.
      // Resolving through the vocabulary fixes it for free, because a legacy
      // entry's label is its value without the emoji. Same rule as the CSV.
      if (r.feelings.isNotEmpty)
        r.feelings
            .map((v) => Vocabularies.labelFor(kObservationTable, v))
            .join(', '),
      // "Beforehand", matching the form label and the wizard summary line.
      // The row is where a record is READ, so a causal word here asserts the
      // same thing the input label was changed to stop asserting.
      // Resolved through the vocabulary, exactly like observations two lines
      // up. Triggers became a vocabulary only last pass and nothing that
      // RENDERS them was updated, so a renamed entry would show its old stored
      // string here while the picker showed the new label.
      if (r.triggers.isNotEmpty)
        'Beforehand: ${r.triggers.map((v) => Vocabularies.labelFor(kTriggerTable, v)).join(', ')}',
      if (r.referralRequired)     'Referral: Yes',
      // WHAT IS MISSING, NAMED. A quick-record shows a timestamp and almost
      // nothing else; in a mixed list that reads as variation, but in a
      // FILTERED list of them every row differs only by time and the screen
      // reads as broken rather than as a work queue.
      //
      // Naming the gaps turns the list into something a user can ACT on:
      // which row to open, and what it will ask. It is PRESENTATION — the
      // fields are already null and the row already omits them — not
      // interpretation.
      //
      // Shown in a mixed list too, deliberately. A row that only explained
      // itself while a filter was on would make the filter the only way to
      // understand the list.
      if (isIncomplete(r))
        'Needs: ${missingFields(r).join(", ")}',
      if (notesShort.isNotEmpty)  'Notes: $notesShort',
    ];

    return ListTile(
      onTap:  onTap,
      title: Row(
        children: [
          Expanded(
            child: Text(timeFmt.format(r.timestamp)),
          ),
          // No badge at all when the type is unknown. A badge is a
          // CLASSIFICATION, and there is nothing to classify — a grey chip
          // reading "unknown" would assert that someone had considered it.
          if (r.eventType != null) _EventTypeBadge(type: r.eventType!),
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
  final String type;
  const _EventTypeBadge({required this.type});

  /// Seeded types keep their colours; everything else takes the neutral pair
  /// "Other" already used. See `_activeColor` for why no colour is invented.
  Color get _bg {
    switch (type) {
      case kTypeSeizure:
        return const Color(0xFFFAECE7);
      case kTypeAbsence:
        return const Color(0xFFEAF4FB);
      case kTypeMedication:
        return const Color(0xFFEAF3DE);
      default:
        return const Color(0xFFF1EFE8);
    }
  }

  Color get _fg {
    switch (type) {
      case kTypeSeizure:
        return const Color(0xFF993C1D);
      case kTypeAbsence:
        return const Color(0xFF185FA5);
      case kTypeMedication:
        return const Color(0xFF3B6D11);
      default:
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
