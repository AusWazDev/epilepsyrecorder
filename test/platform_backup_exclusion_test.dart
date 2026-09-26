import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract #25 — PLATFORM BACKUP AND TRANSFER ARE OFF ON ANDROID.
///
/// ⛔ **HOW IT GOT HERE: A MANIFEST ATTRIBUTE NOBODY TESTED.** Until 26 September
/// 2026 `android:allowBackup` was simply absent, and the platform default is
/// `true`, so the SQLite database, Sentry's INSTALLATION file, the pre-migration
/// plaintext backup and SharedPreferences were all in scope for Google's cloud
/// backup and for device-to-device transfer.
///
/// ⛔ **WHY TWO THINGS ARE CHECKED, NOT ONE.** `allowBackup="false"` stops cloud
/// backup. It does NOT stop device-to-device transfer for an app targeting
/// Android 12 or later: AOSP's `BackupEligibilityRules.isAppBackupAllowed`
/// force-allows transfer (`IGNORE_ALLOW_BACKUP_IN_D2D`, enabled since target S).
/// Only the `<device-transfer>` section of `dataExtractionRules` governs that
/// path, and `FullBackup` copies EVERYTHING when the section is missing.
///
/// ⭐ **A RULES FILE THAT EXISTS BUT EXCLUDES NOTHING READS AS PROTECTION.** So
/// this checks the CONTENT of each section, and it strips XML comments first: a
/// commented-out section must not count.
///
/// ⚠️ **WHAT THIS CANNOT SEE.** It reads the source manifest, not the merged one
/// a build produces. A library could in principle override the attribute at
/// merge time; the merged release manifest had no backup attributes at all
/// when checked on 26 September 2026. It says nothing about iOS, whose
/// exclusion is set at runtime.

const _manifestPath = 'android/app/src/main/AndroidManifest.xml';
const _rulesPath = 'android/app/src/main/res/xml/data_extraction_rules.xml';
const _rulesRef = '@xml/data_extraction_rules';

/// Every domain MER's data can live in. Excluded, with no path, in each section.
const _domains = <String>['root', 'file', 'database', 'sharedpref', 'external'];
const _sections = <String>['cloud-backup', 'device-transfer'];

String _stripComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

/// Every reason the manifest fails the contract. Empty means it holds.
List<String> manifestProblems(String manifest) {
  final m = RegExp(r'<application\b[^>]*>', dotAll: true)
      .firstMatch(_stripComments(manifest));
  if (m == null) return ['no <application> element'];
  final tag = m.group(0)!;
  final problems = <String>[];
  if (!RegExp(r'android:allowBackup\s*=\s*"false"').hasMatch(tag)) {
    problems.add('android:allowBackup is not "false"');
  }
  if (!RegExp('android:dataExtractionRules\\s*=\\s*"${RegExp.escape(_rulesRef)}"')
      .hasMatch(tag)) {
    problems.add('android:dataExtractionRules does not point at $_rulesRef');
  }
  return problems;
}

/// Every reason the rules file fails the contract. Empty means it holds.
List<String> rulesProblems(String rules) {
  final xml = _stripComments(rules);
  final problems = <String>[];
  for (final section in _sections) {
    final body = RegExp('<$section>(.*?)</$section>', dotAll: true)
        .firstMatch(xml)
        ?.group(1);
    if (body == null) {
      problems.add('<$section> section is missing');
      continue;
    }
    if (RegExp(r'<include\b').hasMatch(body)) {
      // An <include> turns the section into an allow-list, which is a
      // different policy and would need its own review.
      problems.add('<$section> contains an <include>');
    }
    for (final domain in _domains) {
      // No path attribute: a path narrows the exclusion to part of the domain.
      final whole = RegExp('<exclude\\s+domain="$domain"\\s*/>');
      if (!whole.hasMatch(body)) {
        problems.add('<$section> does not exclude the whole "$domain" domain');
      }
    }
  }
  return problems;
}

void main() {
  // Read at registration, not in setUpAll: the negative controls below are
  // built FROM these contents when the tests are declared.
  final manifest = File(_manifestPath).readAsStringSync();
  final rules = File(_rulesPath).readAsStringSync();

  test('CONTROL: both files were really read', () {
    expect(manifest, contains('<application'),
        reason: 'the manifest read is empty or wrong, so every check below '
            'would be testing nothing');
    expect(rules, contains('<data-extraction-rules>'),
        reason: 'the rules file read is empty or wrong');
  });

  test('#25 the manifest turns platform backup off, and names the rules file',
      () {
    expect(manifestProblems(manifest), isEmpty);
  });

  test('#25 each section of the rules file excludes every domain, whole', () {
    expect(rulesProblems(rules), isEmpty);
  });

  // ⭐ THE CHECKERS CAN FAIL, AND EACH FAILURE NAMES ITS CAUSE. Every fault is
  // applied to a copy of the REAL file, and the control asserts the fault was
  // actually applied before reading the verdict, so a substitution that
  // silently did nothing cannot pass as a live control.
  //
  // ⛔ APPLIED TO THE COMMENT-STRIPPED TEXT. The rules file's own header
  // comment names `<device-transfer>`, so a fault regex run on the raw file
  // would begin INSIDE the comment and run on to the real closing tag. That
  // fault would pass for the wrong reason. Stripped, each fault hits exactly
  // the element it names.
  final manifestBody = _stripComments(manifest);
  final rulesBody = _stripComments(rules);

  group('NEGATIVE CONTROLS, one fault each', () {
    void fault(String name, String original, String Function(String) mangle,
        List<String> Function(String) check, String expected) {
      test(name, () {
        final mangled = mangle(original);
        expect(mangled, isNot(original), reason: 'the fault was not applied');
        expect(check(mangled), contains(expected));
      });
    }

    fault(
        'allowBackup removed',
        manifestBody,
        (s) => s.replaceFirst('android:allowBackup="false"', ''),
        manifestProblems,
        'android:allowBackup is not "false"');
    fault(
        'allowBackup set true',
        manifestBody,
        (s) => s.replaceFirst(
            'android:allowBackup="false"', 'android:allowBackup="true"'),
        manifestProblems,
        'android:allowBackup is not "false"');
    fault(
        'dataExtractionRules removed',
        manifestBody,
        (s) => s.replaceFirst(
            'android:dataExtractionRules="$_rulesRef"', ''),
        manifestProblems,
        'android:dataExtractionRules does not point at $_rulesRef');
    fault(
        'the device-transfer section removed',
        rulesBody,
        (s) => s.replaceFirst(
            RegExp(r'<device-transfer>.*?</device-transfer>', dotAll: true),
            ''),
        rulesProblems,
        '<device-transfer> section is missing');
    fault(
        'the device-transfer section present but EMPTY',
        rulesBody,
        (s) => s.replaceFirst(
            RegExp(r'<device-transfer>.*?</device-transfer>', dotAll: true),
            '<device-transfer></device-transfer>'),
        rulesProblems,
        '<device-transfer> does not exclude the whole "file" domain');
    fault(
        'the device-transfer section COMMENTED OUT',
        rulesBody,
        (s) => s.replaceFirstMapped(
            RegExp(r'<device-transfer>.*?</device-transfer>', dotAll: true),
            (m) => '<!-- ${m[0]} -->'),
        rulesProblems,
        '<device-transfer> section is missing');
    fault(
        'one domain narrowed to a path',
        rulesBody,
        (s) => s.replaceFirst('<exclude domain="database" />',
            '<exclude domain="database" path="mer_events.db" />'),
        rulesProblems,
        '<cloud-backup> does not exclude the whole "database" domain');
    fault(
        'the cloud-backup section removed',
        rulesBody,
        (s) => s.replaceFirst(
            RegExp(r'<cloud-backup>.*?</cloud-backup>', dotAll: true), ''),
        rulesProblems,
        '<cloud-backup> section is missing');
  });
}
