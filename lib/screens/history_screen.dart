import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_record.dart';
import '../widgets/section_label.dart';
import '../models/vocabulary.dart';
import '../models/vocabulary_store.dart';
import '../screens/event_wizard_screen.dart';
import '../screens/log_event_screen.dart';
import '../theme/mer_theme.dart';
import '../theme/mer_type.dart';

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
/// What an export will contain, and the complete set it is drawn from.
///
/// ## ⛔ ONE PAIR, TWO CONSUMERS, STRUCTURALLY UNABLE TO DISAGREE
///
/// The sheet title and the filename both state the export's scope, and until
/// 17 September 2026 each DERIVED THAT SEPARATELY — the title from a count
/// comparison, the filename from `activeFilters`. Two derivations of one claim
/// can drift, and this one had a live divergence waiting: with records hidden
/// and no filter set, `activeFilters` is empty, so the filename said `_all`
/// over a file that omitted them.
///
/// ⚠️ A BOOLEAN CANNOT CARRY THIS. The title needs BOTH numbers —
/// *Export 15 of 20 events* — and a predicate throws away the half it needs.
/// That is why this is a pair rather than the `narrowed` flag it replaces.
///
/// ⭐ [isComplete] is the ONE question both consumers ask, so "the file is
/// named `_all`" and "the title says *all*" are now the same fact rather than
/// two facts that agree.
class ExportScope {
  const ExportScope({required this.willExport, required this.total});

  /// How many records the file will actually contain.
  final int willExport;

  /// The complete set, hidden records included. This is deliberately NOT the
  /// visible population: the file leaves the app, so its scope statement is a
  /// completeness claim about everything the app holds.
  final int total;

  /// ⛔ THE ONLY PREDICATE EITHER CONSUMER MAY USE.
  bool get isComplete => willExport == total;
}

/// The export sheet's header, given what that export will contain.
///
/// ⛔ A TOP-LEVEL FUNCTION OF THE PAIR, beside [exportFilenamePrefix], and
/// that pairing is the point. The two are the app's only scope statements, they
/// answer the same question, and a test can now hold BOTH to the SAME input and
/// assert they cannot disagree — which is impossible while one is a private
/// method reading screen state and the other is a pure function.
///
/// ⚠️ THE NOUN AGREES WITH `total`, NOT `willExport`. Both strings place it
/// immediately after `total`, so it is the head of the "of N" phrase and agrees
/// with that number: *Export 1 of 71 events*. Agreeing with `willExport` put a
/// singular noun next to a plural number — *Export 1 of 71 event*.
String exportSheetTitle(ExportScope scope) {
  final noun = scope.total == 1 ? 'event' : 'events';
  // ⛔ `isComplete`, NOT a narrowed-ness flag. The old predicate asked whether
  // the user had adjusted anything; this asks whether the file is complete.
  // They diverge in BOTH directions now: a record hidden with no filter set
  // makes an UNADJUSTED export incomplete, and *Show hidden* with no other
  // filter makes an ADJUSTED one complete.
  return scope.isComplete
      ? 'Export all ${scope.total} $noun'
      : 'Export ${scope.willExport} of ${scope.total} $noun';
}

/// The filename prefix for an export, given what that export will contain.
///
/// ⚠️ TAKES THE SCOPE, NOT A `narrowed` FLAG. A flag read from
/// `activeFilters` answers *did the user adjust something*, and that is a
/// different question from *is this file complete* — they came apart the
/// moment a widening toggle joined that set, and they were already apart for a
/// record hidden with no filter on.
String exportFilenamePrefix(ExportScope scope) => scope.isComplete
    ? 'medical_event_recorder_all'
    : 'medical_event_recorder_filtered';

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

  /// ⛔ THE ONE WIDENING MEMBER, AND THE ONLY REASON IT BELONGS IN THIS SET
  /// IS THAT THE USER TURNS IT ON.
  ///
  /// Hiding a record must NEVER join `activeFilters`: the badge and the banner
  /// are CLEARABILITY claims — `filter_sheet_test.dart:148`, *"so the user
  /// knows what to clear"* — and a hidden record is not clearable from
  /// there. Revealing one is. **The state is not a filter; the choice to see it
  /// is.**
  ///
  /// ⚠️ It WIDENS, so it must not fold into [FilterKindLabel.lineLabel]'s
  /// "filtered by" list — see [FilterKindLabel.narrows]. A widening toggle in
  /// a narrowing sentence asserts the user narrowed by something that widened.
  showHidden,
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
      case FilterKind.showHidden: return 'hidden shown';
    }
  }

  /// Whether this kind REDUCES what is shown.
  ///
  /// ⛔ The applied-filters sentence is built from the narrowing members
  /// only. `showHidden` is an adjustment the user made and can clear — so it
  /// belongs in `activeFilters`, the badge and Clear-all — but it is not
  /// something they filtered BY, and a sentence saying so would be a category
  /// error in the one place the user reads to understand the list.
  ///
  /// ⭐ No `default` arm, deliberately: a kind added to the enum fails to
  /// compile here until someone decides which way it cuts.
  bool get narrows {
    switch (this) {
      case FilterKind.search:
      case FilterKind.eventType:
      case FilterKind.referral:
      case FilterKind.dateRange:
      case FilterKind.incomplete:
        return true;
      case FilterKind.showHidden:
        return false;
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
  /// Reveals hidden records. FALSE is the default and Clear-all returns here.
  bool   _showHidden      = false;
  _DateRange _dateRange   = _DateRange.all;
  final Set<String> _selectedTypes = {};

  @override
  void initState() {
    super.initState();
    _records = List<EventRecord>.from(widget.records);
  }

  @override
  void dispose() {
    // ⛔ THE UNDO BELONGS TO THIS SCREEN, so it must not outlive it.
    //
    // `ScaffoldMessenger` sits ABOVE the Navigator in `MaterialApp`, so a
    // SnackBar shown here SURVIVES a pop and stays on screen over Home — with
    // an Undo whose closure targets a disposed State. That is worse than a
    // missed undo: it is a live control that does nothing.
    //
    // ⚠️ Clearing it costs the fast path for a user who hides and
    // immediately leaves. It is not data loss: the record is hidden, not
    // deleted, and *Show hidden* reaches it from the filter sheet at any time.
    // The SnackBar is the QUICK reversal; the filter is the DURABLE one.
    //
    // ⛔ THE BAR'S OWN CONTROLLER, NOT `removeCurrentSnackBar()`. Two reasons,
    // and the first is that the messenger call DOES NOT WORK HERE — measured:
    // with it, `HistoryScreen` was gone from the tree and the bar was still up
    // with a live Undo. The second is that "current" is whatever bar happens to
    // be showing, which need not be the one this screen put there.
    // ⛔ NOT CLOSED HERE — SEE THE `PopScope` IN `build`.
    //
    // Two attempts failed before the right hook was found, and both are worth
    // recording because the second looked correct:
    //
    //   `_messenger?.removeCurrentSnackBar()`  did nothing. Measured: History
    //       gone from the tree, bar still up with a live Undo.
    //   `_undoBar?.close()`, even guarded on `_messenger!.mounted`, threw
    //       `'mounted': is not true` on a WHOLE-TREE teardown. The assert is
    //       inside a DEFERRED closure, so a check at call time cannot help.
    //
    // ⭐ And the guard was answering the wrong question anyway. The condition
    // that matters is *the user navigated away from History*, not *this State
    // was disposed* — a test tearing the tree down is not navigation.
    _searchController.dispose();
    super.dispose();
  }

  /// The controller for the undo bar THIS screen last showed.
  ///
  /// Held so `dispose` can close that exact bar rather than whatever is
  /// current, and so a second hide can close the first one by identity.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _undoBar;


  // ── FILTERING ──
  List<EventRecord> get _filteredRecords {
    final q = _searchText.trim().toLowerCase();

    // Resolved once, not per record: DateTime.now() inside the predicate would
    // move the boundary while the list is being filtered.
    final from = _dateRange.startFrom(DateTime.now());

    // ⛔ THE ONE SEAM. Hiding composes with the user's filters HERE and
    // nowhere else, and `_records` itself stays complete because `:149` is
    // written back through `onRecordsChanged`.
    return _scopePopulation.where((r) {
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
      // ⛔ NOW `whenHappened`, AND THE OLD REASONING IS WHY THIS IS SAFE.
      //
      // This filtered on `timestamp` (logged_at) because `occurred_at` was
      // null on every record that existed, so a filter written against it
      // would have matched none of them. That is still true of every record
      // written before 29 Aug 2026 — which is exactly why the COALESCE costs
      // nothing: `occurredAt ?? timestamp` is `timestamp` for all of them, so
      // this predicate returns an identical result set for the entire existing
      // history and only differs for records that state an occurrence time.
      //
      // The change is required, not cosmetic. "Show me last month" filtering
      // on the log time returns records by when they were TYPED, which for a
      // condition recorded after the fact is the wrong month.
      if (from != null && r.whenHappened.isBefore(from)) return false;

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
        // Searchable by WHEN IT HAPPENED, matching what the row displays.
        _uiTimeFmt.format(r.whenHappened),
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
        FilterKind.showHidden => _showHidden,
      };
      if (active) out.add(k);
    }
    return out;
  }

  bool get _isNarrowed => activeFilters.isNotEmpty;

  /// The population the current view is drawn from, before the user's
  /// narrowing filters are applied.
  ///
  /// ⚠️ NOT unconditionally `_records.visible`. That is right whenever
  /// *Show hidden* is off — the overwhelming case, and the one the banner's
  /// denominator rule was written for — but with the toggle ON the view is
  /// drawn from the complete set, and a denominator of the visible population
  /// would render **"Showing 20 of 15"**.
  ///
  /// ⭐ The property that holds in BOTH states is *what this view is drawn
  /// from*, and it coincides with the visible population exactly when nothing
  /// is being revealed.
  List<EventRecord> get _scopePopulation =>
      _showHidden ? _records : _records.visible;

  /// How many records are being WITHHELD from the view right now.
  ///
  /// Zero while *Show hidden* is on, because nothing is being withheld then —
  /// the records are still flagged, but saying "5 events hidden" beside five
  /// visible rows would be false.
  int get _hiddenWithheld =>
      _showHidden ? 0 : _records.length - _records.visible.length;

  /// ⛔ THE PAIR BOTH SCOPE STATEMENTS READ. See [ExportScope].
  ExportScope get exportScope => ExportScope(
        willExport: _filteredRecords.length,
        total: _records.length,
      );

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

  /// The empty-state message, ALL FOUR CASES, including the two that are
  /// unchanged.
  ///
  /// ⛔ THE MATRIX IS WRITTEN OUT RATHER THAN THE NEW CASE BEING ADDED TO
  /// A TERNARY, so the next reader sees the whole decision instead of
  /// inferring it from one new branch sitting beside two old ones nobody
  /// re-read.
  ///
  ///     records   filters   anything visible   message
  ///     -------   -------   ----------------   -------
  ///     none      —         —                  No events yet — UNCHANGED
  ///     some      yes       none               no match — UNCHANGED, AND IT WINS
  ///     some      no        none, all hidden   No events to show. N hidden.
  ///     some      yes       none, hidden exist no match · N hidden.
  ///
  /// ## ⭐ WHY THE FILTERS MESSAGE WINS WHEN BOTH APPLY
  ///
  /// Filters are what the user SET and what they can CLEAR. Leading with
  /// the hidden count would name the thing they did not do and cannot act
  /// on from here, ahead of the thing they did.
  ///
  /// ## ⛔ WHY THE THIRD ROW EXISTS AT ALL
  ///
  /// Without it a user with everything hidden sees a screen INDISTINGUISHABLE
  /// FROM A FRESH INSTALL — the Help screen's Windows section, exactly: a
  /// user who finds nothing cannot tell whether it is missing or absent.
  ///
  /// ⚠️ A STATE, NOT A PLACE. D6's register throughout — *"22 hidden"*,
  /// *"Nothing is deleted"*. There is no bin and no destination screen, so
  /// the copy names no place to go to.
  String _emptyStateMessage() {
    // 1. Nothing has ever been recorded.
    if (_records.isEmpty) {
      return 'No events yet.\n'
          'Tap "Record event" to get started.';
    }

    final withheld = _hiddenWithheld;
    final noun = withheld == 1 ? 'event' : 'events';

    // 2 and 4. Filters are set. The filters message WINS, and the hidden
    // count is appended only when records are actually being withheld.
    if (_isNarrowed) {
      const base = 'No events match your search\nor filters.';
      return withheld == 0 ? base : '$base\n$withheld $noun hidden.';
    }

    // 3. No filters, and everything there is has been hidden.
    if (withheld > 0) {
      return 'No events to show.\n$withheld $noun hidden.';
    }

    // ⚠️ UNREACHABLE, AND NAMED RATHER THAN FOLDED INTO A BRANCH ABOVE.
    // Records exist, no filter is set and nothing is withheld, so the list
    // cannot be empty. Returning the fresh-install copy here would be a
    // false claim if it were ever reached; this says what happened.
    return 'No events to show.';
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
      // Grouped under the day it HAPPENED, or a backdated record would sit
      // under the heading for the day it was typed.
      final w = r.whenHappened;
      final day = DateTime(w.year, w.month, w.day);

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
          : DateTime(next.whenHappened.year, next.whenHappened.month,
              next.whenHappened.day);
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
      backgroundColor: MERColours.surfaceSunken,
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
                                fontSize: MERType.heading,
                fontWeight: MERType.emphasis)),
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
                            // Same reset as `_clearFilters`, same reason.
                            _showHidden = false;
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
                              // ⛔ NAMED 9 Sep 2026 — AUDIT.md §13(z).
                              // "Clear search", not "Clear": this sheet also
                              // carries filter chips, and a bare "Clear" beside
                              // them would not say what it clears.
                              tooltip: 'Clear search',
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

                  // ⛔ A TOGGLE, NOT A CHIP, by this sheet's own rule stated
                  // above: filter VALUES are chips, filter MODES are toggles.
                  // This changes which population is shown, so it is a mode.
                  //
                  // ⚠️ PLACED LAST, AFTER the referral switch, for two
                  // reasons. It is the only WIDENING control here, so grouping
                  // it with the narrowing chips would suggest it belongs to
                  // them; and `filter_sheet_test` taps the referral switch as
                  // `find.byType(Switch).first`, which this must not displace.
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _showHidden,
                    title: const Text('Show hidden'),
                    subtitle: const Text(
                        'Include events you have hidden from this list'),
                    onChanged: (v) => update(() => _showHidden = v),
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
      // ⛔ THE DEFAULT IS HIDDEN-HIDDEN, so Clear-all must return here.
      // Omitting this line is the INERT-CONTROL defect: the banner and badge
      // would keep reporting an adjustment the clear control did not clear,
      // and the control would visibly do nothing. Guarded by a test.
      _showHidden = false;
    });
  }

  // ── DELETE ──
  /// Hides one record, with an Undo. ⛔ NO CONFIRMATION, DELIBERATELY.
  ///
  /// ## ⭐ WHY THE DIALOG WENT
  ///
  /// It said *"This action cannot be undone"*, and once hiding replaced
  /// deletion **that sentence became false**. C2's own test is *did the user
  /// come here to do this thing* — a reversible act does not earn a
  /// destructive dialog, and this app already has the precedent: vocabulary's
  /// hide warns about nothing, because nothing is destroyed.
  ///
  /// ⚠️ THE TRADE ONLY HOLDS BECAUSE THE REVEAL SHIPPED FIRST (`a0cfc7f`).
  /// Without *Show hidden* this would be deletion with a four-second window,
  /// and a reversible-action argument applied to an irreversible one is how a
  /// false safety claim reaches medical copy.
  ///
  /// ## ⛔ REPLACED IN PLACE, NEVER REMOVED AND RE-INSERTED
  ///
  /// The record keeps its INDEX, and `ordinal` is the index at save time — so
  /// position survives without anything having to restore it. `§13(ch)`'s
  /// delete-then-reinsert shape is what this avoids.
  ///
  /// ⭐ AND UNDO RESTORES THE ORIGINAL OBJECT, not a rebuilt one. Nothing is
  /// reconstructed on the way back, so there is no second opportunity to drop
  /// a field — §13(cj) failure mode (b) does not apply to this path at all.
  Future<void> _hideAndPersist(String id) async {
    final index = _records.indexWhere((r) => r.id == id);
    if (index < 0) return;
    final original = _records[index];
    if (original.hidden) return;

    // The moment of the TAP. Hiding is a change the user made, and their
    // most recent intent is what the field records.
    setState(() =>
        _records[index] = original.withHidden(true, at: DateTime.now()));
    await widget.onRecordsChanged(_records);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    // ⛔ REPLACE, DO NOT QUEUE. Two hides in quick succession would otherwise
    // stack two identical "Event hidden" bars, and the first one's Undo would
    // refer to a record the user can no longer tell apart from the second.
    // Only the most recent action is undoable, and only one bar says so.
    _undoBar?.close();
    _undoBar = messenger.showSnackBar(SnackBar(
      // D6's register: a STATE, never a place. There is no bin and nowhere to
      // go, and "Nothing is deleted" is the sentence the removed dialog used
      // to be answering.
      content: const Text('Event hidden. Nothing is deleted.'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => _unhide(original),
      ),
    ));
    // Cleared when the bar goes for ANY reason — timeout, swipe, the action —
    // so `dispose` never closes a controller that is already finished and a
    // later hide never closes a stale one.
    _undoBar?.closed.then((_) {
      if (mounted) _undoBar = null;
    });
  }

  /// Restores [original] — the exact object captured before the hide — to
  /// whatever position its id now occupies.
  ///
  /// ⚠️ Re-located by id rather than by the old index: an edit elsewhere
  /// could have re-sorted the list while the SnackBar was up, and writing to a
  /// stale index would overwrite a different record.
  Future<void> _unhide(EventRecord original) async {
    final i = _records.indexWhere((r) => r.id == original.id);
    if (i < 0) return;
    setState(() => _records[i] = original);
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
      // Sorted on the same value the rows display and group by. A list that
      // sorts on one time and prints another is the defect the CSV had.
      _records.sort((a, b) => b.whenHappened.compareTo(a.whenHappened));
    });

    await widget.onRecordsChanged(_records);
  }

  @override
  Widget build(BuildContext context) {
    // ⛔ THE UNDO BELONGS TO THIS SCREEN AND MUST NOT OUTLIVE IT ON SCREEN.
    //
    // `ScaffoldMessenger` sits ABOVE the Navigator in `MaterialApp`, so a bar
    // shown here SURVIVES a pop and sits over Home carrying an Undo whose
    // closure targets a disposed State — a live control that silently does
    // nothing, which is worse than a missed undo.
    //
    // ⚠️ Closing it costs the fast path for a user who hides and leaves
    // immediately. That is not data loss: the record is hidden, not deleted,
    // and *Show hidden* reaches it from the filter sheet at any time. The bar
    // is the QUICK reversal; the filter is the DURABLE one.
    //
    // ⭐ `canPop: true` — this does not gate the pop, it only reacts to one,
    // unlike the form's `PopScope` which guards an unsaved draft.
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _undoBar?.close();
      },
      child: _buildHistory(context),
    );
  }

  Widget _buildHistory(BuildContext context) {
    final shown = _filteredRecords;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:       MainAxisSize.min,
          children: [
            Text(
              'History',
              style: MERType.subheadOnPrimary,
            ),
            Text(
              'Medical Event Recorder',
              style: MERType.microOnPrimaryMuted,
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
                        color: MERColours.infoOnContainer,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${activeFilters.length}',
                        textAlign: TextAlign.center,
                        style: MERType.captionStrongOnFill.copyWith(height: 1),
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
            onPressed: () {
              // ⛔ ONE SCOPE, READ ONCE, FEEDING BOTH STATEMENTS. Two reads
              // would be two derivations again, which is the defect this
              // consolidation removes rather than a style preference.
              final scope = exportScope;
              showExportOptions(
                context,
                shown,
                filenamePrefix: exportFilenamePrefix(scope),
                sheetTitle: exportSheetTitle(scope),
              );
            },
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
                // ⛔ THE SCOPE POPULATION, NOT `_records.length`. The banner
                // is a CLEARABILITY claim, so its denominator must describe
                // what the clear control returns the user to — never the
                // complete set, which clearing cannot reach. The sheet title
                // beside it is a COMPLETENESS claim and uses the complete set:
                // the two differing is correct, not a gap.
                total: _scopePopulation.length,
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
                        _emptyStateMessage(),
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
                                  onDelete: () => _hideAndPersist(r.id),
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

  // ⭐ DELEGATES to the one implementation. See `SectionLabel`.
  @override
  Widget build(BuildContext context) => SectionLabel(text);
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
            color: selected ? MERColours.primary : MERColours.outline,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 15, color: MERColours.onPrimary),
              const SizedBox(width: 6),
            ],
            Text(
              'Needs details',
              style: TextStyle(
                fontSize: MERType.caption,
                fontWeight: selected ? MERType.emphasis : MERType.regular,
                color: selected ? MERColours.onPrimary : MERColours.onSurface,
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

  /// "filtered by search" / "filtered by search and type" /
  /// "filtered by type · hidden shown" / "hidden shown".
  ///
  /// Enumerated from [FilterKind.values] rather than from `active` so the
  /// order is stable — a line whose words reorder as filters toggle is harder
  /// to read at a glance than one that always reads the same way.
  ///
  /// ## ⛔ THE WIDENING TOGGLE IS APPENDED, NEVER FOLDED IN
  ///
  /// `activeFilters` is ONE set answering ONE question — *what can I clear* —
  /// and this sentence answers a different one: *what did I do*. Folding a
  /// widening toggle into the "filtered by" list would assert the user narrowed
  /// by something that widened, in the one place they read to understand why
  /// the list is short.
  ///
  /// ⭐ Split on [FilterKindLabel.narrows], so the two halves cannot drift:
  /// a kind added to the enum must declare which way it cuts before this
  /// compiles.
  String get _reason {
    final narrowing = <String>[
      for (final k in FilterKind.values)
        if (k.narrows && active.contains(k)) k.lineLabel,
    ];
    final widening = <String>[
      for (final k in FilterKind.values)
        if (!k.narrows && active.contains(k)) k.lineLabel,
    ];

    final parts = <String>[];
    if (narrowing.isNotEmpty) {
      final list = narrowing.length == 1
          ? narrowing.single
          : '${narrowing.take(narrowing.length - 1).join(', ')} '
              'and ${narrowing.last}';
      parts.add('filtered by $list');
    }
    parts.addAll(widening);
    return parts.join(' · ');
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
          // ⭐ A TOKEN, NOT A COMPOSITE. This was `alert` at 10% alpha,
          // which is an untokened colour nothing can assert. A banner whose
          // job is to say a filter is on is informational.
          color: MERColours.infoContainer,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: MERColours.infoAccent, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.filter_alt, size: 18, color: MERColours.infoAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                // ONE sentence. The count and the cause are read together, so
                // "showing 12 of 74" can never be seen without "filtered by".
                'Showing $shown of $total — $_reason',
                style: MERType.bodyStrongInfoOnContainer,
              ),
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: MERColours.infoOnContainer,
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
        return MERColours.identitySeizureOn;
      case kTypeAbsence:
        return MERColours.identityAbsenceOn;
      case kTypeMedication:
        return MERColours.identityMedicationOn;
      default:
        return MERColours.identityOtherOn;
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
                color: isSelected ? colour : MERColours.outline,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Text(
              eventTypeLabel(type),
              style: TextStyle(
                fontSize:   MERType.caption,
                fontWeight: isSelected
                    ? MERType.emphasis
                    : MERType.regular,
                color: isSelected
                    ? MERColours.onFill
                    : MERColours.onSurfaceMuted,
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
      // ⛔ THE GAP LINE IS NO LONGER IN `parts`. IT MOVED TO ITS OWN LINE
      // BELOW - see the `subtitle` builder. `parts` is now CONTENT ONLY.
      //
      // Why, recorded 7 Sep 2026. For a timestamp-only record every branch
      // in this list is false, so the gap line was the ONLY element and
      // `parts.join` rendered the row's entire description of the event as a
      // list of what it lacked. That is the output of the primary action -
      // one tap, nothing gated - presented as an incomplete thing awaiting
      // repair. Wording alone could not reach it: the register would change
      // and the content would not.
      if (notesShort.isNotEmpty)  'Notes: $notesShort',
    ];

    return ListTile(
      onTap:  onTap,
      // ⭐ THE TIME IS FIXED, THE BADGE IS FLEXIBLE. 11 Sep 2026 (AUDIT.md
      // §13(bx)). This was `Expanded(time)` beside a bare badge, and at 200%
      // text scale the badge — which could not shrink — pushed the row 66.5 px
      // past its edge on every typed event. The time is the row's identifier
      // (§13(bz)) and is laid out first at its own width; the badge, a
      // CLASSIFICATION, takes what is left and ellipsises when that is not
      // enough. `spaceBetween` puts the leftover in the middle, so at 1.0 the
      // time still sits left and the badge still sits right, in exactly the
      // same place — test/a11y_batch_render_comparison_test.dart holds that
      // against a baseline from the unpatched code.
      //
      // ⛔ NOT two `Flexible`s. That caps each child at HALF the row whether
      // or not the other needs it; in the harness font, where "10:30 AM" alone
      // is 124 of the row's 243 px at 375, it trimmed the badge at the
      // DEFAULT size, and the render comparison caught it.
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(timeFmt.format(r.whenHappened)),
          // No badge at all when the type is unknown. A badge is a
          // CLASSIFICATION, and there is nothing to classify — a grey chip
          // reading "unknown" would assert that someone had considered it.
          if (r.eventType != null)
            Flexible(child: _EventTypeBadge(type: r.eventType!)),
        ],
      ),
      // ⛔ CONTENT FIRST, THE GAP LINE DEMOTED BENEATH IT. 7 Sep 2026.
      //
      // The gap list is METADATA ABOUT THE ROW, not a description of the
      // event, so it renders smaller and in `textMuted` on its own line.
      // The row now says what IS known first, and what is still open after.
      //
      // ✅ THE WORK-QUEUE CASE SURVIVES UNCHANGED, which is the property the
      // counter-argument at the top of `parts` defends: in a filtered list of
      // quick-records the gap line is still present on every row, still names
      // which fields the row will ask for, and is still the thing that makes
      // the list actionable. Only its PROMINENCE changed.
      //
      // ⚠️ THE maxLines BUDGET IS UNCHANGED AT TWO TEXT LINES: content takes
      // 2 when there is no gap line and 1 when there is.
      //
      // ⛔ ROW HEIGHTS, MEASURED ON THE DEVICE AT 430 AND NOT INFERRED FROM
      // THE BUDGET. This comment first claimed an incomplete row is never
      // taller than a complete one, and that timestamp-only rows get slightly
      // SHORTER. BOTH WERE FALSE - they were read off the maxLines budget
      // rather than off a screen. Measured from the divider positions in the
      // 430x932 capture of 7 Sep 2026:
      //
      //   complete row                        73 px  ->  73 px   unchanged
      //   PARTIAL row (content + gap line)    73 px  ->  77 px   +4 px
      //   timestamp-only row (gap line only)         unchanged   (day-header
      //                                               boundaries align at y=331)
      //
      // So a partial row IS taller, by 4 px, because `ListTile`'s subtitle
      // area absorbs most of a 12 px second line. Cumulative effect in the
      // default view: one row boundary drops below the fold. Negligible, but
      // it is a real cost and it is not zero.
      subtitle: Builder(builder: (_) {
        final content = parts.join(' · ');
        final gaps = isIncomplete(r)
            // ⭐ "Add details:", not "Needs:". Changed 7 Sep 2026.
            //
            // The row names the ACTION and the screen it opens carries the
            // SAME WORD: tapping an incomplete row routes to the wizard,
            // whose app bar reads 'Add details' (event_wizard_screen.dart).
            // "Needs" stated a deficiency and the destination stated an
            // action; they now agree.
            //
            // ⚠️ THE FIELD LIST IS UNCHANGED, and so is `missingFields`.
            // This is a change of REGISTER, not of content - the row still
            // enumerates exactly which fields the wizard will ask for, which
            // is what makes a filtered list of quick-records actionable.
            //
            // ⚠️ Three other registers for this same concept are LEFT
            // ALONE and are a separate decision: the filter chip and its
            // label say "Needs details" / "needs details", and the Last
            // Event card says "Tap edit to update details". Only the row was
            // in scope here.
            ? 'Add details: ${missingFields(r).join(", ")}'
            : null;
        if (gaps == null) {
          return Text(
            content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Omitted entirely when empty. An empty Text would spend a line
            // on nothing, which is what a timestamp-only record would get.
            if (content.isNotEmpty)
              Text(
                content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            // ⭐ NO maxLines, 11 Sep 2026 (AUDIT.md §13(bw)). `maxLines: 1`
            // clipped "Add details: duration, type, severity" at 375 wide at
            // the DEFAULT text size — the row's whole job is to name which
            // fields are open, and an ellipsis hid the names. The string is
            // at most three field names, so letting it wrap is bounded: a
            // second line at 375, and the "maxLines budget" comment above
            // now describes the content line only.
            Text(
              gaps,
              style: MERType.captionOnSurfaceMuted,
            ),
          ],
        );
      }),
      trailing: IconButton(
        // ⛔ NAMED 9 Sep 2026 — AUDIT.md §13(z). It announced NOTHING on every
        // row.
        //
        // ⚠️ IT IS NO LONGER THE ONE IRREVERSIBLE CONTROL IN THE APP, and
        // that claim is retired rather than moved: §13(ax) described a delete
        // leaving no row, no flag and no log. This now HIDES — the row stays,
        // the flag is what changed, and *Show hidden* reveals it. The reset in
        // About is the destructive control, and it keeps its confirmation.
        //
        // "Hide this event" rather than a bare "Hide", because this one
        // repeats per row. Measured: the row's own content IS the
        // semantics node immediately BEFORE this button in traversal order, so
        // forward navigation supplies context — but TalkBack's next-control
        // gesture and VoiceOver's rotor set to buttons SKIP it, leaving
        // "Delete, Delete, Delete".
        //
        // ⚠️ AND IT IS DELIBERATELY NOT DYNAMIC. A tooltip is VISIBLE on hover
        // and long-press, so 'Delete ${time}' would surface record data into a
        // newly-visible element — in an app whose whole property is that
        // nothing leaves the device unless the user sends it. §13(ad) also
        // shows seven byte-identical rows, so a timestamp would not
        // disambiguate. Which-record identification stays UNSOLVED.
        // ⛔ NOT `destructive`, AND NOT A TOKEN CHANGE. `destructive` is
        // reserved for the one control that destroys, which is now the reset
        // alone — C2: the destructive control is the only red one. Hiding is
        // reversible, so it takes the ordinary muted control colour already in
        // the palette rather than a new value.
        tooltip:   'Hide this event',
        color:     MERColours.onSurfaceMuted,
        icon:      const Icon(Icons.visibility_off_outlined),
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
        return MERColours.identitySeizureContainer;
      case kTypeAbsence:
        return MERColours.identityAbsenceContainer;
      case kTypeMedication:
        return MERColours.identityMedicationContainer;
      default:
        return MERColours.identityOtherContainer;
    }
  }

  Color get _fg {
    switch (type) {
      case kTypeSeizure:
        return MERColours.identitySeizureOn;
      case kTypeAbsence:
        return MERColours.identityAbsenceOn;
      case kTypeMedication:
        return MERColours.identityMedicationOn;
      default:
        return MERColours.identityOtherOn;
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
        // One line, ellipsised, 11 Sep 2026 (§13(bx)): the badge now sits in
        // a `Flexible`, so when its slot is narrower than its label it must
        // trim rather than wrap into a two-line pill.
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: MERType.captionStrongInherit.copyWith(color: _fg),
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
        style: MERType.bodyStrongPrimary.copyWith(letterSpacing: 0.6),
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
