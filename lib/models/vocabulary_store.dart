import 'package:sqflite_common/sqlite_api.dart';

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

  /// Every entry, active and retired, in sort order.
  static List<VocabularyEntry> get eventTypes => _eventTypes;
  static List<VocabularyEntry> get triggers => _triggers;
  static List<VocabularyEntry> get observations => _observations;

  /// What a picker offers: active only, "Other" last.
  static List<VocabularyEntry> get offerableEventTypes => offerable(_eventTypes);
  static List<VocabularyEntry> get offerableTriggers => offerable(_triggers);
  static List<VocabularyEntry> get offerableObservations =>
      offerable(_observations);

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
