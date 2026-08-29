import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import 'condition.dart';
import 'vocabulary.dart';

/// The loaded vocabularies for this launch.
///
/// ## Why an in-memory holder rather than a query per render
///
/// Two vocabularies of a dozen rows each are read on every History row, every
/// chip and every CSV line. They change only when someone adds or hides an
/// entry, which is rare and always goes through this class — so the cache
/// cannot go stale without this file knowing.
///
/// ## Why it works with NO DATABASE AT ALL
///
/// `StorageBoot` falls back to shared_preferences when SQLite cannot be opened,
/// and widget tests construct screens without booting anything. In both cases
/// there is no `Database` — and the app must still render its chips. So the
/// seeded lists are the default state, and [load] only ever REPLACES them with
/// what the database holds.
///
/// That is why [eventTypes] and [observations] are never empty and never null:
/// a screen built in a test, on a fallback launch, or before boot completes,
/// gets exactly the vocabulary MER ships with.
class Vocabularies {
  Vocabularies._();

  static List<VocabularyEntry> _eventTypes = _fromSeeds(kSeedEventTypes);
  static List<VocabularyEntry> _observations = <VocabularyEntry>[
    ..._fromSeeds(kSeedObservations),
    ..._fromSeeds(kLegacyObservations, idBase: 1000, sortBase: 1000),
    ..._fromSeeds(mangledLegacyObservations(), idBase: 2000, sortBase: 2000),
  ];

  static List<VocabularyEntry> _triggers = _fromSeeds(kSeedTriggers);

  static Database? _db;

  /// Condition names by id, cached with the vocabularies.
  ///
  /// ⛔ **THIS LIVES HERE SO THE CSV DOES NOT NEED A PARAMETER.** `buildCsv`
  /// already reads this class statically three times for labels, and it takes
  /// no database — so a fourth static read is the SAME mechanism, not a new
  /// dependency. The alternative, threading `conditions:` down through
  /// `showExportOptions`, is the shape that has already failed twice in this
  /// exact call chain: a `notes:` parameter accepted and never forwarded, found
  /// only by diffing a device export, and the same mistake repeated in
  /// `showBackupOptions` weeks later.
  static Map<int, String> _conditionNames = const <int, String>{};

  /// Every entry, active and retired, in sort order.
  static List<VocabularyEntry> get eventTypes => _eventTypes;
  static List<VocabularyEntry> get triggers => _triggers;
  static List<VocabularyEntry> get observations => _observations;

  /// What a picker offers: active only, "Other" last.
  static List<VocabularyEntry> get offerableEventTypes =>
      offerable(kEventTypeTable, _eventTypes);
  static List<VocabularyEntry> get offerableTriggers =>
      offerable(kTriggerTable, _triggers, usage: usageFor(kTriggerTable));
  static List<VocabularyEntry> get offerableObservations =>
      offerable(kObservationTable, _observations,
          usage: usageFor(kObservationTable));

  /// True when mutations will persist. False on a fallback launch and in
  /// widget tests — the UI uses this to hide "add your own" rather than offer
  /// something that silently would not survive a restart.
  static bool get canPersist => _db != null;

  static List<VocabularyEntry> _fromSeeds(
    List<VocabularySeed> seeds, {
    int idBase = 0,
    int sortBase = 0,
  }) {
    var i = 0;
    return seeds.map((s) {
      final n = i++;
      return VocabularyEntry(
        id: idBase + n + 1,
        value: s.value,
        label: s.label,
        isSeeded: true,
        isActive: s.isActive,
        isProtected: s.isProtected,
        sortOrder: sortBase + n,
        // Carried, or the no-database fallback renders a glyph-less picker while
        // the database path renders glyphs — two different apps depending on
        // whether SQLite opened.
        emoji: s.emoji,
      );
    }).toList();
  }

  /// Reads both vocabularies from [db].
  ///
  /// NEVER throws and never leaves the lists empty: a database that cannot be
  /// read leaves the seeded defaults in place, which is a working app with the
  /// shipped vocabulary rather than a screen of blank chips.
  /// How many records carry each value, keyed by TABLE then value.
  ///
  /// ⛔ **KEYED BY TABLE, AND THAT IS NOT TIDINESS.** Since the migraine pass a
  /// value can exist in BOTH vocabularies — `Tired` is a prodrome symptom and a
  /// postdrome one, so it is seeded in each. A single map keyed by value alone
  /// would add its beforehand count to its afterwards count, and an entry used
  /// fifty times afterwards would lead the beforehand list having never been
  /// used there once.
  static Map<String, Map<String, int>> _usage =
      const <String, Map<String, int>>{};

  static Map<String, int> usageFor(String table) =>
      _usage[table] ?? const <String, int>{};

  /// Counts values across the record set.
  ///
  /// Reads `feelings_json` and `triggers_json`, which remain AUTHORITATIVE —
  /// `event_observation` and `event_trigger` are additive mirrors and are not
  /// the read path, so counting from them would be counting a copy.
  static Future<Map<String, Map<String, int>>> _countUsage(Database db) async {
    final obs = <String, int>{};
    final trg = <String, int>{};
    List<Map<String, Object?>> rows;
    try {
      rows = await db.query('event',
          columns: <String>['feelings_json', 'triggers_json']);
    } catch (_) {
      // A picker must never fail to render because a count could not be taken.
      return const <String, Map<String, int>>{};
    }
    void tally(Object? raw, Map<String, int> into) {
      if (raw is! String || raw.isEmpty) return;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) return;
        for (final v in decoded) {
          final s = v.toString();
          into[s] = (into[s] ?? 0) + 1;
        }
      } catch (_) {
        // One record with unparseable JSON must not cost the whole ordering.
        // The same tolerance `EventRecord.fromMap` applies to a bad timestamp.
      }
    }
    for (final r in rows) {
      tally(r['feelings_json'], obs);
      tally(r['triggers_json'], trg);
    }
    return <String, Map<String, int>>{
      kObservationTable: obs,
      kTriggerTable: trg,
    };
  }

  static Future<void> load(Database? db) async {
    _db = db;
    if (db == null) return;
    try {
      final types = await loadVocabulary(db, kEventTypeTable);
      final obs = await loadVocabulary(db, kObservationTable);
      // Only replace on a NON-EMPTY read. An empty table means the seed did not
      // run — a bug — and rendering nothing would turn that bug into an app with
      // no chips at all.
      if (types.isNotEmpty) _eventTypes = types;
      final trg = await loadVocabulary(db, kTriggerTable);
      if (trg.isNotEmpty) _triggers = trg;
      if (obs.isNotEmpty) _observations = obs;
      // REPLACED unconditionally, unlike the vocabularies above. An empty
      // vocabulary means the seed did not run, which is a bug; an empty
      // condition table is the NORMAL state — nothing is seeded and most users
      // will never name one. Keeping a stale name here would be worse than
      // holding none.
      // AFTER the vocabularies, because an ordering over a list that failed
      // to load would be an ordering over nothing.
      _usage = await _countUsage(db);
      _conditionNames = <int, String>{
        for (final c in await loadConditions(db)) c.id: c.name,
      };
    } catch (_) {
      // Defaults stand.
    }
  }

  /// Test seam.
  static void debugSet({
    List<VocabularyEntry>? eventTypes,
    List<VocabularyEntry>? observations,
    List<VocabularyEntry>? triggers,
    Database? db,
  }) {
    if (eventTypes != null) _eventTypes = eventTypes;
    if (triggers != null) _triggers = triggers;
    if (observations != null) _observations = observations;
    _db = db;
  }

  /// Restores the shipped state. Used by tests so one test's additions cannot
  /// leak into the next.
  static void debugReset() {
    _eventTypes = _fromSeeds(kSeedEventTypes);
    _triggers = _fromSeeds(kSeedTriggers);
    _observations = <VocabularyEntry>[
      ..._fromSeeds(kSeedObservations),
      ..._fromSeeds(kLegacyObservations, idBase: 1000, sortBase: 1000),
      // The mangled twins too, so a test that renders a corrupted legacy value
      // without a database resolves it the same way the app does.
      ..._fromSeeds(mangledLegacyObservations(),
          idBase: 2000, sortBase: 2000),
    ];
    _conditionNames = const <int, String>{};
    _db = null;
  }

  /// Adds a user entry to [table] and refreshes the cache.
  ///
  /// Works with no database: the entry is added in memory so the flow the user
  /// is in completes normally. It will not survive a restart, which is why
  /// [canPersist] gates the UI that offers it.
  static Future<VocabularyEntry?> add(String table, String typed) async {
    final text = typed.trim();
    if (text.isEmpty) return null;

    final db = _db;
    if (db == null) {
      final list = table == kEventTypeTable
          ? _eventTypes
          : table == kTriggerTable
              ? _triggers
              : _observations;
      for (final e in list) {
        if (e.label.toLowerCase() == text.toLowerCase()) return e;
      }
      final entry = VocabularyEntry(
        id: -DateTime.now().microsecondsSinceEpoch,
        value: text,
        label: text,
        isSeeded: false,
        isActive: true,
        isProtected: false,
        sortOrder: 500,
      );
      if (table == kEventTypeTable) {
        _eventTypes = <VocabularyEntry>[..._eventTypes, entry];
      } else if (table == kTriggerTable) {
        _triggers = <VocabularyEntry>[..._triggers, entry];
      } else {
        _observations = <VocabularyEntry>[..._observations, entry];
      }
      return entry;
    }

    final entry = await addUserEntry(db, table, text);
    await load(db);
    return entry;
  }

  /// The label for a stored value, in whichever vocabulary [table] names.
  ///
  /// NO GLYPH. This is what a RECORD shows — History rows, the CSV, the search
  /// haystack, the wizard summary. Use [displayFor] for a picker.
  static String labelFor(String table, String value) => labelForValue(
      _listFor(table), value);

  static List<VocabularyEntry> _listFor(String table) =>
      table == kEventTypeTable
          ? _eventTypes
          : table == kTriggerTable
              ? _triggers
              : _observations;

  /// Hides or shows an entry, and refreshes the cache.
  ///
  /// ## THE COLUMN EXISTED FOR THREE SCHEMA VERSIONS AND NOTHING REACHED IT
  ///
  /// `is_active` has been on every vocabulary row since v2, `setActive` has
  /// been written and tested since the vocabulary landed, and no screen has
  /// ever called it. Every field became user-extensible and none could be
  /// un-extended, so two entries added while testing are permanent on the
  /// device. This is the method that closes that.
  ///
  /// ## IT IS NOT A DELETE, AND THE DIFFERENCE IS THE WHOLE DESIGN
  ///
  /// The row stays. Records that reference it keep resolving through
  /// [labelFor] and [displayFor], History keeps rendering it, the CSV keeps
  /// exporting it, and a picker holding it on an existing record keeps showing
  /// its chip. See [kWhyNoDelete].
  ///
  /// Rethrows [VocabularyRuleError] from the model's `setActive` so the caller
  /// can show the reason a protected entry refused, rather than failing
  /// silently.
  static Future<VocabularyEntry?> setVisible(
    String table,
    VocabularyEntry entry,
    bool visible,
  ) async {
    final db = _db;
    if (db == null) {
      // Mirrors [add]: the flow completes in memory so a fallback launch is not
      // a broken screen. It will not survive a restart, and `canPersist` gates
      // the UI that offers it.
      if (!visible && entry.isProtected) {
        throw const VocabularyRuleError(
          'Medication is recorded separately from events, and a future version '
          'of MER moves it out of this list. Hiding it now would leave records '
          'that move cannot identify.',
        );
      }
      if (visible && isShippedHidden(table, entry.value)) {
        throw const VocabularyRuleError(
          'This entry was replaced by a newer version of the same wording. It '
          'still shows on records that already use it, but offering it again '
          'would store an older format in new records.',
        );
      }
      final updated = entry.copyWith(isActive: visible);
      List<VocabularyEntry> swap(List<VocabularyEntry> list) => list
          .map((e) => e.id == entry.id ? updated : e)
          .toList();
      if (table == kEventTypeTable) {
        _eventTypes = swap(_eventTypes);
      } else if (table == kTriggerTable) {
        _triggers = swap(_triggers);
      } else {
        _observations = swap(_observations);
      }
      return updated;
    }

    final updated = await setActive(db, table, entry, visible);
    await load(db);
    return updated;
  }

  /// Assigns an event type to a condition, or clears it, and refreshes.
  ///
  /// See [setConditionFor] for why one type belongs to exactly one condition
  /// and why that constraint is enforced by the column rather than by a throw.
  static Future<VocabularyEntry?> setCondition(
    String table,
    VocabularyEntry entry,
    int? conditionId,
  ) async {
    final db = _db;
    if (db == null) {
      // Mirrors `add` and `setVisible`: the flow completes in memory so a
      // fallback launch is not a broken screen, and does not survive a restart.
      if (table != kEventTypeTable) {
        throw const VocabularyRuleError(
          'Only event types belong to a condition. Observations and what was '
          'happening beforehand are shared across every condition you track, '
          'so you never have to set them up twice.',
        );
      }
      final updated = entry.copyWith(conditionId: conditionId);
      _eventTypes =
          _eventTypes.map((e) => e.id == entry.id ? updated : e).toList();
      return updated;
    }
    final updated = await setConditionFor(db, table, entry, conditionId);
    await load(db);
    return updated;
  }

  /// ⛔ THE DERIVATION. A record's condition is a FUNCTION OF ITS TYPE.
  ///
  /// This is what makes multi-condition possible without a migration. The
  /// alternative — storing `condition_id` on every event — needs someone to
  /// decide what the 72 existing records belong to, and **a migration deciding
  /// that is an assertion about the user's health that nobody made.** Three
  /// design reads rejected exactly that.
  ///
  /// Deriving asks the user for ONE statement instead — "these types are my
  /// epilepsy" — and 71 records attribute themselves from it. The statement is
  /// theirs, about their own vocabulary, and it is revisable.
  ///
  /// ⚠️ **NULL IS A REAL ANSWER AND MUST STAY ONE.** A record with no type
  /// (the quick-record path writes none) has no condition, and a type nobody
  /// has assigned has no condition. Both mean NOT YET SAID — the same rule as
  /// `occurredAt`, `detailsCompleted` and duration at creation. Do not default
  /// either to the primary condition: that would invent the attribution this
  /// whole design exists to avoid.
  static int? conditionIdForEventType(String? eventTypeValue) {
    if (eventTypeValue == null) return null;
    for (final e in _eventTypes) {
      if (e.value == eventTypeValue) return e.conditionId;
    }
    return null;
  }

  /// The condition NAME a record with this event type belongs to, or null.
  ///
  /// ⛔ **THE EXPORT'S DERIVATION, AND IT READS NO DATABASE.** A record's
  /// condition is a function of its type — pass 1's decision, and this is what
  /// carries it into the artefact a specialist reads. Nothing writes
  /// `event.condition_id`; it stays NULL on every row.
  ///
  /// ⚠️ **`EventRecord` DELIBERATELY DOES NOT GAIN A `conditionId` FIELD.** It
  /// would be null on every record forever, since nothing populates the column
  /// — and a field that exists and is always null is the shape that has bitten
  /// twice this month: `setActive` sat unreachable for three schema versions
  /// and `renameEntry` still is. Deriving needs no field.
  ///
  /// Returns null for: no type (the quick-record path writes none), a type
  /// nobody has assigned, and a type assigned to a condition that no longer
  /// exists. All three mean NOT YET SAID and none is an error.
  static String? conditionNameForEventType(String? eventTypeValue) {
    final id = conditionIdForEventType(eventTypeValue);
    if (id == null) return null;
    return _conditionNames[id];
  }

  /// Event types grouped by condition, for a PICKER.
  ///
  /// ⛔ **GROUPED, NOT FILTERED, AND THE DIFFERENCE IS LOAD-BEARING.** There is
  /// no condition context at capture — DATA-MODEL §5: *nothing at capture
  /// time* — so a picker filtered to one condition would make a second
  /// condition unrecordable from the main flow. Grouping is what "types do not
  /// mix" actually asks for: a migraine type sits under its own heading rather
  /// than among the seizure types, and every type stays reachable.
  ///
  /// Filtering by condition is meaningful in HISTORY, where the user is asking
  /// a question about a subset. It is not meaningful while recording.
  ///
  /// Returns null-keyed entries LAST — unassigned types are not a condition,
  /// and with one condition (or none) that group is the whole list, so the
  /// picker looks exactly as it does today.
  static Map<int?, List<VocabularyEntry>> offerableEventTypesByCondition() {
    final out = <int?, List<VocabularyEntry>>{};
    for (final e in offerableEventTypes) {
      out.putIfAbsent(e.conditionId, () => <VocabularyEntry>[]).add(e);
    }
    final keys = out.keys.where((k) => k != null).toList()
      ..sort((a, b) => a!.compareTo(b!));
    return <int?, List<VocabularyEntry>>{
      for (final k in keys) k: out[k]!,
      if (out.containsKey(null)) null: out[null]!,
    };
  }

  /// Every entry in [table], hidden ones included, in picker order.
  ///
  /// The management screen needs this and no other caller does: a picker shows
  /// [offerable], which is exactly the list this one is NOT.
  static List<VocabularyEntry> allIn(String table) => _listFor(table);

  /// What a PICKER shows: the glyph and the label.
  ///
  /// Two functions rather than one, because the difference is the whole point.
  /// A chip can afford a glyph — it is rendered by a widget with emoji
  /// coverage, and the glyph helps someone scanning a grid just after an event.
  /// A History row cannot: that text style mangled the emoji into `ð..µ` on the
  /// tablet, and a CSV must not carry one at all per DATA-MODEL.md §6.
  ///
  /// Falls back to the raw value when nothing matches, exactly as [labelFor]
  /// does — a record from another device's vocabulary shows its own string
  /// rather than a wrong one.
  static String displayFor(String table, String value) {
    final list = _listFor(table);
    for (final e in list) {
      if (e.value == value) return e.display;
    }
    return value;
  }
}
