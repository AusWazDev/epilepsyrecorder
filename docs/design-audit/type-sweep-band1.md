# Type sweep — band 1, raw rows

**Generated 17 September 2026 from source at `3595093`, by a script, not transcribed.** Regenerate rather than edit: this file is a measurement, and a hand-corrected measurement is no longer one.

## ⛔ SCOPE AND ITS QUALIFIERS — read these before using any figure

The qualifiers are part of the result. Dropped, these numbers read as drift, which is exactly how `AUDIT.md` §13(bg)'s sweeps 2 and 4 were nearly misread.

- **Inline `TextStyle(...)` declarations only.** Styles inherited from `MERTheme`'s `textTheme` without a local override are NOT here, because they carry no site-level setting to record.
- **Literal `fontSize` only.** A site whose size is an expression cannot be placed on a numeric band; those are in the last two tables.
- **34 `.dart` files under `lib/`**, walked recursively. Nothing under `test/`, `ios/`, `android/` or `windows/`.
- **OCCURRENCES, not lines.** A line can carry more than one declaration and a reformat moves line counts without changing what was measured. ⚠️ In the sibling records-field sweep the line count moved 35 → 37 while occurrences held at 37; that is why this unit is stated.
- **Comments stripped before matching**, and bodies extracted with balanced parentheses, so a `TextStyle` inside a nested constructor is captured whole rather than truncated at the first `)`.
- **Band 1 is `fontSize` 9..16 inclusive.** The band boundary is not a design decision — it is where the measured sizes have no gap wider than one point. 16 → 18 is the first break.

### Denominator, every declaration in exactly one bucket

| bucket | count |
|---|---|
| band 1 (literal size 9..16) | **122** |
| out of band (literal size 18..28) | 11 |
| colour-only (no size, no weight) | 6 |
| size-less but weighted | 5 |
| **total `TextStyle(` occurrences** | **144** |

⭐ **Nothing is silently outside the check.** The four buckets sum to the total, and a residual would fail the run rather than be dropped.

---

## Band 1 — 122 sites

Sorted by size, then weight, then file, then line.

| size | weight | colour token | owning symbol | site |
|---|---|---|---|---|
| 9 | `w400` | `onSurfaceMuted` | `_StatCell.Text / Text` | `screens/home_screen.dart:1927` |
| 10 | `w400` | `onPrimaryMuted` | `_SplashLoadingScreen.Text / Text` | `main.dart:171` |
| 10 | `w400` | `onPrimaryMuted` | `AboutScreen.Text / Text` | `screens/about_screen.dart:31` |
| 10 | `w400` | `onPrimaryMuted` | `DisclaimerScreen.Text / Text` | `screens/disclaimer_screen.dart:46` |
| 10 | `w400` | `onPrimaryMuted` | `_HelpScreenState.Text / Text` | `screens/help_screen.dart:90` |
| 10 | `w400` | `onPrimaryMuted` | `_HistoryScreenState.Text / Text` | `screens/history_screen.dart:670` |
| 10 | `w400` | `onPrimaryMuted` | `_HomeScreenState.Text / Text` | `screens/home_screen.dart:970` |
| 10 | `w400` | `onSurfaceMuted.withOpacity(0.7)` | `_LastEventCard.Text / Text` | `screens/home_screen.dart:2016` |
| 10 | `w400` | `onPrimaryMuted` | `_LogEventScreenState.Text / Text` | `screens/log_event_screen.dart:549` |
| 10 | `w400` | `onPrimaryMuted` | `YourDataScreen.Text / Text` | `screens/your_data_screen.dart:52` |
| 10 | `w700` | `onFill` | `_HistoryScreenState.BoxConstraints / Text` | `screens/history_screen.dart:706` |
| 11 | `w400` | `onPrimaryMuted` | `_SplashLoadingScreen.Text / Text` | `main.dart:193` |
| 11 | `w400` | `onPrimaryMuted` | `AboutScreen.Text / Text` | `screens/about_screen.dart:102` |
| 11 | `w400` | `onPrimaryMuted` | `_ConditionsScreenState.Text / Text` | `screens/conditions_screen.dart:111` |
| 11 | `w400` | `onSurfaceMuted` | `_HomeScreenState.SizedBox / Text` | `screens/home_screen.dart:1236` |
| 11 | `w400` | `(inherit)` | `_SettingsNudgeCard.TextButton` | `screens/home_screen.dart:1824` |
| 11 | `w400` | `onPrimaryMuted` | `_MedicationScreenState.Text / Text` | `screens/medication_screen.dart:125` |
| 11 | `w400` | `onPrimaryMuted` | `_VocabularyScreenState.Text / Text` | `screens/vocabulary_screen.dart:192` |
| 11 | `w400` | `onSurfaceMuted` | `_VocabularyScreenState.Text / Text` | `screens/vocabulary_screen.dart:420` |
| 11 | `w400` | `onSurfaceMuted` | `_VocabularyScreenState.TextStyle / Text` | `screens/vocabulary_screen.dart:425` |
| 11 | `w400` | `onSurfaceMuted` | `MERTheme.light` | `theme/mer_theme.dart:263` |
| 11 | `w400` | `onSurfaceMuted` | `OccurredAtField.Text` | `widgets/occurred_at_field.dart:124` |
| 11 | `w500` | `_fg` | `_EventTypeBadge.eventTypeLabel` | `screens/history_screen.dart:1373` |
| 11 | `w500` | `primary` | `_LastEventCard.Text / Text` | `screens/home_screen.dart:2053` |
| 11 | `w500` | `onPrimary` | `_LastEventCard.Text / Text` | `screens/home_screen.dart:2087` |
| 11 | `w600` | `onSurfaceMuted` | `MERTheme.light` | `theme/mer_theme.dart:264` |
| 11 | `w700` | `primary` | `_DayHeader.Padding / Text` | `screens/history_screen.dart:1418` |
| 12 | `isSelected` | `(inherit)` | `_EventTypeFilterChips.eventTypeLabel / Text` | `screens/history_screen.dart:1082` |
| 12 | `isSelected` | `(inherit)` | `_EventTypeButton.Expanded / Text` | `screens/log_event_screen.dart:1047` |
| 12 | `selected ? w600 : w400` | `selected ? onPrimary : onSurface` | `_NeedsDetailsChip.Text / Text` | `screens/history_screen.dart:935` |
| 12 | `w400` | `onSurfaceMuted` | `_ConditionsScreenState.Text / Text` | `screens/conditions_screen.dart:276` |
| 12 | `w400` | `onSurfaceMuted` | `_ConditionsScreenState.Text / Text` | `screens/conditions_screen.dart:296` |
| 12 | `w400` | `onSurfaceMuted` | `_StandingSwitch.Padding` | `screens/help_screen.dart:571` |
| 12 | `w400` | `onSurfaceMuted` | `_EventListTile.Text / Text` | `screens/history_screen.dart:1279` |
| 12 | `w400` | `criticalOnContainer` | `_ActiveEventBannerState.Text / Text` | `screens/home_screen.dart:1412` |
| 12 | `w400` | `iconColor.withValues(alpha: 0.85)` | `_SettingsNudgeCard.Text / Text` | `screens/home_screen.dart:1789` |
| 12 | `w400` | `onSurfaceMuted` | `_VocabularyScreenState.TextStyle / Text` | `screens/vocabulary_screen.dart:329` |
| 12 | `w600` | `onSurfaceMuted` | `_EventWizardScreenState.Padding / Text` | `screens/event_wizard_screen.dart:850` |
| 12 | `w600` | `(inherit)` | `_SettingsNudgeCard.TextButton` | `screens/home_screen.dart:1810` |
| 12 | `w600` | `primary` | `_KindChip.medicationDeviationLabel / Text` | `screens/medication_screen.dart:227` |
| 12.5 | `w400` | `onSurfaceMuted` | `YourDataScreen.Padding / Text` | `screens/your_data_screen.dart:140` |
| 13 | `isSelected` | `(inherit)` | `_SelectionRow.labelFor / Text` | `screens/log_event_screen.dart:1137` |
| 13 | `isSelected` | `(inherit)` | `_SelectionWrap.isSelected / Text` | `screens/log_event_screen.dart:1239` |
| 13 | `w400` | `onPrimaryMuted` | `AboutScreen.Text / Text` | `screens/about_screen.dart:94` |
| 13 | `w400` | `onSurfaceMuted` | `_Explainer.Text / Text` | `screens/conditions_screen.dart:324` |
| 13 | `w400` | `onSurfaceMuted` | `_EventWizardScreenState.Padding / Text` | `screens/event_wizard_screen.dart:474` |
| 13 | `w400` | `cautionOnContainer` | `_FailedWriteBanner.Text / Text` | `screens/home_screen.dart:1520` |
| 13 | `w400` | `cautionOnContainer` | `_StorageFallbackBanner.Text / Text` | `screens/home_screen.dart:1641` |
| 13 | `w400` | `positiveOnContainer` | `_BackupReminderBanner.Text / Text` | `screens/home_screen.dart:1722` |
| 13 | `w400` | `onSurfaceMuted` | `_LogEventScreenState.Padding / Text` | `screens/log_event_screen.dart:598` |
| 13 | `w400` | `onSurfaceMuted` | `_SectionHint.Text / Text` | `screens/log_event_screen.dart:888` |
| 13 | `w400` | `primary` | `_SelectionWrap.Text / Text` | `screens/log_event_screen.dart:1273` |
| 13 | `w400` | `(inherit)` | `_Explainer.build` | `screens/medication_screen.dart:209` |
| 13 | `w400` | `onSurfaceMuted` | `_RecordSheetState.Text / Text` | `screens/medication_screen.dart:318` |
| 13 | `w400` | `onSurfaceMuted` | `_RecordSheetState.Text / Text` | `screens/medication_screen.dart:332` |
| 13 | `w400` | `onSurfaceMuted` | `_Explainer.Text / Text` | `screens/vocabulary_screen.dart:500` |
| 13 | `w400` | `onSurfaceMuted` | `_DataCard.Text / Text` | `screens/your_data_screen.dart:226` |
| 13 | `w400` | `(inherit)` | `(top level).Padding / Text` | `services/backup_service.dart:274` |
| 13 | `w400` | `onSurfaceMuted` | `MERTheme.light` | `theme/mer_theme.dart:262` |
| 13 | `w400` | `onSurfaceMuted` | `MERTheme.light / BorderSide` | `theme/mer_theme.dart:339` |
| 13 | `w400` | `onSurfaceMuted` | `MERTheme.light` | `theme/mer_theme.dart:343` |
| 13 | `w400` | `(inherit)` | `MERTheme.light` | `theme/mer_theme.dart:364` |
| 13 | `w500` | `onSurface` | `_LastEventCard.Text / Text` | `screens/home_screen.dart:2007` |
| 13 | `w500` | `onSurface` | `MERTheme.light / TextTheme` | `theme/mer_theme.dart:260` |
| 13 | `w600` | `onSurfaceMuted` | `EventStore.Expanded / Text` | `models/event_record.dart:1607` |
| 13 | `w600` | `onPrimary` | `DisclaimerScreen.Text / Text` | `screens/disclaimer_screen.dart:38` |
| 13 | `w600` | `infoOnContainer` | `_AppliedFiltersBanner.Expanded / Text` | `screens/history_screen.dart:1000` |
| 13 | `w600` | `onPrimary` | `_HomeScreenState.Text / Text` | `screens/home_screen.dart:962` |
| 13 | `w600` | `(inherit)` | `_ActiveEventBannerState.FilledButton / FilledButton` | `screens/home_screen.dart:1435` |
| 13 | `w600` | `Colors.white` | `MERTheme.light` | `theme/mer_theme.dart:373` |
| 13 | `w600` | `onSurface` | `OccurredAtField.Text / Text` | `widgets/occurred_at_field.dart:104` |
| 13 | `w700` | `iconColor` | `_SettingsNudgeCard.Text / Text` | `screens/home_screen.dart:1781` |
| 13.5 | `w400` | `onSurfaceMuted` | `YourDataScreen.Padding / Text` | `screens/your_data_screen.dart:72` |
| 14 | `w400` | `onSurfaceMuted` | `_ConditionsScreenState.Expanded / Text` | `screens/conditions_screen.dart:244` |
| 14 | `w400` | `(inherit)` | `_ConditionsScreenState.Expanded / Text` | `screens/conditions_screen.dart:248` |
| 14 | `w400` | `(inherit)` | `_ConditionsScreenState.for / Text` | `screens/conditions_screen.dart:253` |
| 14 | `w400` | `onSurface` | `_Explainer.Text / Text` | `screens/conditions_screen.dart:316` |
| 14 | `w400` | `onSurfaceMuted` | `_EventWizardScreenState.Text / Text` | `screens/event_wizard_screen.dart:458` |
| 14 | `w400` | `onSurfaceMuted` | `_EventWizardScreenState.Text / Text` | `screens/event_wizard_screen.dart:537` |
| 14 | `w400` | `onSurfaceMuted` | `_EventWizardScreenState.Text / Text` | `screens/event_wizard_screen.dart:643` |
| 14 | `w400` | `onSurfaceMuted` | `_EventWizardScreenState.Text / Text` | `screens/event_wizard_screen.dart:688` |
| 14 | `w400` | `onSurfaceMuted` | `_EventWizardScreenState.Text / Text` | `screens/event_wizard_screen.dart:708` |
| 14 | `w400` | `onSurfaceMuted` | `_EventWizardScreenState.Text / Text` | `screens/event_wizard_screen.dart:718` |
| 14 | `w400` | `onSurface` | `_VocabularyScreenState.Expanded / Text` | `screens/vocabulary_screen.dart:252` |
| 14 | `w400` | `onSurfaceMuted` | `_VocabularyScreenState.Expanded / Text` | `screens/vocabulary_screen.dart:372` |
| 14 | `w400` | `link` | `_VocabularyScreenState.Text / Text` | `screens/vocabulary_screen.dart:377` |
| 14 | `w400` | `onSurface` | `_Explainer.Text / Text` | `screens/vocabulary_screen.dart:493` |
| 14 | `w400` | `onSurfaceMuted` | `_BoundedChipWrapState.Expanded / Text` | `widgets/bounded_chip_wrap.dart:178` |
| 14 | `w400` | `link` | `_BoundedChipWrapState.TextStyle / Text` | `widgets/bounded_chip_wrap.dart:183` |
| 14 | `w500` | `(inherit)` | `MERTheme.light / RoundedRectangleBorder` | `theme/mer_theme.dart:317` |
| 14 | `w600` | `(inherit)` | `_StandingSwitch.Padding / Text` | `screens/help_screen.dart:562` |
| 14 | `w600` | `(inherit)` | `_HomeScreenState.SizedBox / RoundedRectangleBorder` | `screens/home_screen.dart:1261` |
| 14 | `w600` | `cautionOnContainer` | `_FailedWriteBanner.Expanded / Text` | `screens/home_screen.dart:1500` |
| 14 | `w600` | `cautionOnContainer` | `_StorageFallbackBanner.Expanded / Text` | `screens/home_screen.dart:1627` |
| 14 | `w600` | `positiveOnContainer` | `_BackupReminderBanner.Expanded / Text` | `screens/home_screen.dart:1687` |
| 14 | `w600` | `(inherit)` | `MERTheme.light / RoundedRectangleBorder` | `theme/mer_theme.dart:286` |
| 14 | `w600` | `(inherit)` | `MERTheme.light / RoundedRectangleBorder` | `theme/mer_theme.dart:302` |
| 14 | `w700` | `criticalOnContainer` | `_ActiveEventBannerState.Text / Text` | `screens/home_screen.dart:1404` |
| 15 | `w400` | `onSurface` | `_ConditionsScreenState.Expanded / Text` | `screens/conditions_screen.dart:235` |
| 15 | `w400` | `onSurface` | `_ConditionsScreenState.Text / Text` | `screens/conditions_screen.dart:292` |
| 15 | `w400` | `(inherit)` | `_EventWizardScreenState.Padding / Text` | `screens/event_wizard_screen.dart:1106` |
| 15 | `w400` | `(inherit)` | `_LogEventScreenState.SizedBox / Text` | `screens/log_event_screen.dart:847` |
| 15 | `w400` | `visible ? onSurface : onSurfaceMuted` | `_VocabularyScreenState.Text / Text` | `screens/vocabulary_screen.dart:408` |
| 15 | `w400` | `onSurface` | `MERTheme.light / TextTheme` | `theme/mer_theme.dart:261` |
| 15 | `w400` | `onSurface` | `OccurredAtField.Text / Text` | `widgets/occurred_at_field.dart:111` |
| 15 | `w500` | `onSurface` | `MERTheme.light / TextTheme` | `theme/mer_theme.dart:259` |
| 15 | `w600` | `onPrimary` | `AboutScreen.Text / Text` | `screens/about_screen.dart:23` |
| 15 | `w600` | `onSurface` | `_ConditionsScreenState.Text / Text` | `screens/conditions_screen.dart:270` |
| 15 | `w600` | `onPrimary` | `_HelpScreenState.Text / Text` | `screens/help_screen.dart:82` |
| 15 | `w600` | `onPrimary` | `_HistoryScreenState.Text / Text` | `screens/history_screen.dart:662` |
| 15 | `w600` | `onPrimary` | `_LogEventScreenState.Text / Text` | `screens/log_event_screen.dart:541` |
| 15 | `w600` | `onSurface` | `_VocabularyScreenState.Text / Text` | `screens/vocabulary_screen.dart:321` |
| 15 | `w600` | `onPrimary` | `YourDataScreen.Text / Text` | `screens/your_data_screen.dart:44` |
| 15.5 | `w700` | `onSurface` | `_DataCard.Expanded / Text` | `screens/your_data_screen.dart:213` |
| 16 | `w400` | `(inherit)` | `_ConditionsScreenState.Text / Text` | `screens/conditions_screen.dart:109` |
| 16 | `w400` | `(inherit)` | `DisclaimerScreen.SafeArea / Text` | `screens/disclaimer_screen.dart:341` |
| 16 | `w400` | `(inherit)` | `_MedicationScreenState.Text / Text` | `screens/medication_screen.dart:123` |
| 16 | `w400` | `(inherit)` | `_VocabularyScreenState.Text / Text` | `screens/vocabulary_screen.dart:190` |
| 16 | `w400` | `(inherit)` | `_StepPage.SizedBox / Text` | `screens/walkthrough_screen.dart:277` |
| 16 | `w600` | `onPrimary` | `_SplashLoadingScreen.Text / Text` | `main.dart:160` |
| 16 | `w600` | `Colors.white` | `MERTheme.light / AppBarTheme` | `theme/mer_theme.dart:249` |
| 16 | `w700` | `(inherit)` | `(top level).Padding / Text` | `services/backup_service.dart:262` |

---

## Colour-only declarations — 6

⛔ **A `TextStyle` carrying only a colour has nothing to be proximate to**, so no size-based method can place it. This is a CLASS the specification must name, not a set of cases a sweep failed on.

| colour token | owning symbol | site | source |
|---|---|---|---|
| `onSurfaceMuted` | `_ConditionsScreenState.Padding / Text` | `screens/conditions_screen.dart:130` | `style: TextStyle(color: MERColours.onSurfaceMuted),` |
| `onSurfaceMuted` | `_MedicationScreenState.Padding / Text` | `screens/medication_screen.dart:147` | `style: TextStyle(color: MERColours.onSurfaceMuted),` |
| `onSurfaceMuted` | `_MedicationScreenState.Expanded / Text` | `screens/medication_screen.dart:160` | `style: TextStyle(color: MERColours.onSurfaceMuted),` |
| `onPrimary` | `_VocabularyScreenState.if / Text` | `screens/vocabulary_screen.dart:202` | `style: const TextStyle(color: MERColours.onPrimary)),` |
| `onSurfaceMuted` | `_VocabularyScreenState.Padding / Text` | `screens/vocabulary_screen.dart:224` | `style: TextStyle(color: MERColours.onSurfaceMuted),` |
| `Colors.white` | `MERTheme.light / SnackBarThemeData` | `theme/mer_theme.dart:392` | `contentTextStyle: const TextStyle(color: Colors.white),` |

---

## Size-less but weighted — 5

Neither band 1 (no literal size) nor colour-only (they carry a weight). ⚠️ **The two `TextSpan` sites are a different shape again** — a weight applied inside a rich-text run rather than to a whole `Text`.

| weight | colour token | owning symbol | site |
|---|---|---|---|
| `w500` | `(inherit)` | `EventStore.ListTile / Text` | `models/event_record.dart:1639` |
| `w500` | `(inherit)` | `EventStore.ListTile / Text` | `models/event_record.dart:1681` |
| `w500` | `onSurfaceMuted` | `EventStore.ListTile / Text` | `models/event_record.dart:1720` |
| `w700` | `(inherit)` | `DisclaimerScreen.TextSpan / TextSpan` | `screens/disclaimer_screen.dart:206` |
| `w700` | `(inherit)` | `DisclaimerScreen.TextSpan / TextSpan` | `screens/disclaimer_screen.dart:271` |

---

## Out of band, for completeness — 11

Not part of the specification question this file was cut for, listed so the denominator above can be checked rather than taken.

| size | weight | colour token | owning symbol | site |
|---|---|---|---|---|
| 18 | `w400` | `onSurfaceMuted` | `_DisclaimerBullet.Text / Text` | `screens/disclaimer_screen.dart:366` |
| 18 | `w600` | `(inherit)` | `_HistoryScreenState.Expanded / Text` | `screens/history_screen.dart:428` |
| 18 | `w600` | `(inherit)` | `_RecordSheetState.Text / Text` | `screens/medication_screen.dart:315` |
| 18 | `w600` | `onSurface` | `MERTheme.light / TextTheme` | `theme/mer_theme.dart:258` |
| 18 | `w700` | `onPrimary` | `AboutScreen.Text / Text` | `screens/about_screen.dart:85` |
| 20 | `w600` | `(inherit)` | `_EventWizardScreenState.Text / Text` | `screens/event_wizard_screen.dart:454` |
| 20 | `w600` | `valueColor ?? primary` | `_StatCell.Text / Text` | `screens/home_screen.dart:1917` |
| 24 | `w600` | `(inherit)` | `_StepPage.Text / Text` | `screens/walkthrough_screen.dart:271` |
| 26 | `w700` | `onCapture` | `_HomeScreenState.SizedBox / Text` | `screens/home_screen.dart:1212` |
| 28 | `w600` | `onSurface` | `MERTheme.light / TextTheme` | `theme/mer_theme.dart:257` |
| 28 | `w800` | `onPrimary` | `_SplashLoadingScreen.Text / Text` | `main.dart:148` |
