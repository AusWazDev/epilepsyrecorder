// Brief 135R · the clobber contract, against the FALLBACK (prefs) store.
//
// ⭐ The assertion is not here. It lives once, in
// `support/history_clobber_contract.dart`, and is run against each store —
// the structural insurance against the two `save` implementations diverging
// later, which is the risk the whole change exists to remove.
//
// ⛔ ONE PREFS-DEPENDENT TEST PER PROCESS (CLAUDE.md), which is why the sqlite
// case is a SEPARATE FILE rather than a second case in this one. The reason,
// measured rather than assumed, is in the support file's header.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';

import 'support/history_clobber_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  seedPrefs();

  /// Ids in the PREFS payload, read back from storage — not from any widget.
  Future<List<String>> prefsIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(kEventStorageKey);
    if (raw == null || raw.isEmpty) return <String>[];
    return [
      for (final e in (jsonDecode(raw) as List).whereType<Map>()) '${e['id']}'
    ];
  }

  registerClobberContract(StoreCase(
    'prefs',
    () async {
      StorageBoot.debugSet(); // null store -> the prefs fallback
    },
    prefsIds,
    () async {},
  ));
}
