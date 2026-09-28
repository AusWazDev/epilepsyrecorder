// Brief 217: reads the captured verdict back out of `schema_meta`.

import 'dart:convert';

import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/storage_migration.dart';

Future<String?> storedVerdict() async {
  final raw = await getMeta(StorageBoot.database!, kMetaRebuildVerdict);
  if (raw == null) return null;
  return (jsonDecode(raw) as Map<String, Object?>)['verdict'] as String?;
}
