// Brief 321 · one site per file, because the harness depends on
// SharedPreferences (one prefs-dependent test per process).
//
// ⛔ CONSTRUCTS A STATE THE APP DOES NOT CURRENTLY PRODUCE (as at 1 Oct 2026):
// the screen below the pushed one is removed while the pushed one survives.
// Basis: Brief 319's sweep found no route removal in lib/ that does this. It
// exists anyway to hold the line if a future route removal makes it
// reachable. Full statement in support/route_removed_write_contract.dart.

import 'package:flutter_test/flutter_test.dart';

import 'support/restore_vocabulary_contract.dart' show seedPrefs;
import 'support/route_removed_write_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  seedPrefs();
  registerRouteRemovedWriteCase(WriteSite.historyEditRecord);
}
