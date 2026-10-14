/// Reports to Sentry whose rendering is built ONLY from categorical fields.
///
/// ⛔ **THE RULE (Brief MER-F4, 14 October 2026).** `disclaimer_screen.dart`
/// tells the user these reports "are designed not to include anything you have
/// recorded". A report on a path that handles raw record payloads (the legacy
/// mirror, the capture inbox) must therefore be unable to carry payload text
/// at all, not merely be written not to.
///
/// ⭐ **CONTENT-FREE BY CONSTRUCTION, NOT BY CARE.** A subclass holds enums,
/// counts and type names, and builds [categorical] from those alone. It has no
/// free-text field, so there is nothing for a caught exception's `toString()`
/// to be interpolated into. That is the defect this type exists to close: the
/// legacy mirror's decode failure was reported as
/// `StateError('Legacy mirror read INCOMPLETE — decode threw: $e …')`, and a
/// `FormatException`'s `toString()` quotes up to ~78 characters of the payload
/// it failed on. `beforeSend`'s sanitiser recognises `FormatException`, but the
/// text had already been baked into a `StateError`, which it does not.
///
/// ⚠️ **ADDING A FIELD IS THE RISK.** A `String` field taken from a caught
/// error, or from anything the payload produced, reopens exactly that path.
/// Type names (`describeThrowableType`) and counts are the permitted inputs.
library;

/// A report whose whole rendering is [categorical].
abstract class ContentFreeReport implements Exception {
  const ContentFreeReport();

  /// The full text sent to Sentry. Enums, counts and type names only.
  String get categorical;

  @override
  String toString() => categorical;
}

/// The TYPE of a caught throwable, never its text.
///
/// `FormatException` keeps `offset`, which locates a fault without quoting it;
/// its `message` and `source` are dropped. Everything else is its runtime type
/// name. ⚠️ Under `--obfuscate` that name is not human readable, but it is
/// still never user content.
String describeThrowableType(Object error) {
  if (error is FormatException) {
    return 'FormatException(offset: ${error.offset})';
  }
  return error.runtimeType.toString();
}

/// A capture-path error of a type this file does not recognise, reduced to its
/// type name. See `reportCaptureChannelError`.
class UncategorisedCaptureError extends ContentFreeReport {
  UncategorisedCaptureError(Object error) : type = describeThrowableType(error);

  /// From [describeThrowableType]: a type name, never the error's text.
  final String type;

  @override
  String get categorical =>
      'Capture path error of an unrecognised type: $type. '
      'Its text is withheld because this path handles record payloads.';
}
