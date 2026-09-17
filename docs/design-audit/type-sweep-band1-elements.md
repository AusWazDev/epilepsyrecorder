# Type sweep — band 1, element identity

**Read 17 September 2026 against source at `a0cfc7f`+.** Companion to `type-sweep-band1.md`, which carries the measurements and their qualifiers. This file adds ONE column: what each site RENDERS AS.

## ⛔ HOW THIS WAS PRODUCED, AND WHAT THAT MEANS FOR TRUSTING IT

- **The size, weight and colour are MEASURED** — re-extracted from source by the same balanced-paren scan as the companion file, not copied from it.
- **The element class is ADJUDICATED BY HAND**, by reading the widget each `TextStyle` is attached to. A first pass using proximity cues placed 35 of 122 and was discarded: rules good enough to place the rest would have been guessing, which is the proximity-method trap this corpus already has a name for.
- **The two are JOINED ON `file:line` and the join is checked.** An unclassified site or a stale key fails the run, so the adjudication cannot silently drift from the measurement.

⚠️ **`other` is 31 of 122 sites and that is a RESULT, not a gap.** A pass returning no `other` would be a pass that guessed. What lands there is listed with its reason, and three distinct things are mixed in it — see the note under that table.

## The finding: element class → set of steps

| element class | sites | distinct sizes | distinct (size, weight) |
|---|---|---|---|
| **app-bar title** | 10 | 13 / 15 / 16 | 3 |
| **app-bar subtitle** | 10 | 10 / 11 | 2 |
| **section heading** | 7 | 11 / 12 / 13 / 15 / 15.5 / 16 | 6 |
| **field label** | 8 | 13 / 14 | 3 |
| **body prose** | 15 | 12 / 12.5 / 13 / 13.5 / 14 / 15 / 16 | 7 |
| **hint or helper** | 10 | 10 / 11 / 12 / 13 / 14 | 5 |
| **metadata or timestamp** | 5 | 11 / 12 / 13 / 15 | 5 |
| **badge or count** | 6 | 10 / 11 / 12 / 14 | 4 |
| **button label** | 11 | 11 / 12 / 13 / 14 / 15 / 16 | 9 |
| **list-tile primary** | 4 | 14 / 15 | 2 |
| **list-tile secondary** | 5 | 11 / 12 | 2 |
| **other** | 31 | 9 / 10 / 11 / 12 / 13 / 14 / 15 / 16 | 18 |

---

### app-bar title — 10 sites

| size | weight | colour token | site | note |
|---|---|---|---|---|
| 13 | `w600` | `onPrimary` | `screens/disclaimer_screen.dart:38` | lockup inside AppBar.title |
| 13 | `w600` | `onPrimary` | `screens/home_screen.dart:962` | lockup inside AppBar.title |
| 15 | `w600` | `onPrimary` | `screens/about_screen.dart:23` |  |
| 15 | `w600` | `onPrimary` | `screens/help_screen.dart:82` |  |
| 15 | `w600` | `onPrimary` | `screens/history_screen.dart:969` |  |
| 15 | `w600` | `onPrimary` | `screens/log_event_screen.dart:541` |  |
| 15 | `w600` | `onPrimary` | `screens/your_data_screen.dart:44` |  |
| 16 | `w400` | `(inherit)` | `screens/conditions_screen.dart:109` |  |
| 16 | `w400` | `(inherit)` | `screens/medication_screen.dart:123` |  |
| 16 | `w400` | `(inherit)` | `screens/vocabulary_screen.dart:190` |  |

---

### app-bar subtitle — 10 sites

| size | weight | colour token | site | note |
|---|---|---|---|---|
| 10 | `w400` | `onPrimaryMuted` | `screens/about_screen.dart:31` |  |
| 10 | `w400` | `onPrimaryMuted` | `screens/disclaimer_screen.dart:46` |  |
| 10 | `w400` | `onPrimaryMuted` | `screens/help_screen.dart:90` |  |
| 10 | `w400` | `onPrimaryMuted` | `screens/history_screen.dart:977` |  |
| 10 | `w400` | `onPrimaryMuted` | `screens/home_screen.dart:970` |  |
| 10 | `w400` | `onPrimaryMuted` | `screens/log_event_screen.dart:549` |  |
| 10 | `w400` | `onPrimaryMuted` | `screens/your_data_screen.dart:52` |  |
| 11 | `w400` | `onPrimaryMuted` | `screens/conditions_screen.dart:111` |  |
| 11 | `w400` | `onPrimaryMuted` | `screens/medication_screen.dart:125` |  |
| 11 | `w400` | `onPrimaryMuted` | `screens/vocabulary_screen.dart:192` |  |

---

### section heading — 7 sites

| size | weight | colour token | site | note |
|---|---|---|---|---|
| 11 | `w700` | `primary` | `screens/history_screen.dart:1769` | day header, uppercase |
| 12 | `w600` | `onSurfaceMuted` | `screens/event_wizard_screen.dart:850` | condition group name over grouped chips |
| 13 | `w600` | `onSurfaceMuted` | `models/event_record.dart:1645` | export sheet header |
| 15 | `w600` | `onSurface` | `screens/conditions_screen.dart:270` |  |
| 15 | `w600` | `onSurface` | `screens/vocabulary_screen.dart:321` |  |
| 15.5 | `w700` | `onSurface` | `screens/your_data_screen.dart:213` | card title |
| 16 | `w700` | `(inherit)` | `services/backup_service.dart:262` | bottom-sheet header |

---

### field label — 8 sites

| size | weight | colour token | site | note |
|---|---|---|---|---|
| 13 | `w400` | `onSurfaceMuted` | `screens/medication_screen.dart:318` | above a chip group |
| 13 | `w400` | `onSurfaceMuted` | `screens/medication_screen.dart:332` | above a control |
| 13 | `w600` | `onSurface` | `widgets/occurred_at_field.dart:104` |  |
| 14 | `w400` | `onSurfaceMuted` | `screens/event_wizard_screen.dart:537` | above a chip group |
| 14 | `w400` | `onSurfaceMuted` | `screens/event_wizard_screen.dart:643` | above a chip group |
| 14 | `w400` | `onSurfaceMuted` | `screens/event_wizard_screen.dart:688` | above a chip group |
| 14 | `w400` | `onSurfaceMuted` | `screens/event_wizard_screen.dart:708` | above a chip group |
| 14 | `w400` | `onSurfaceMuted` | `screens/event_wizard_screen.dart:718` | above a chip group |

---

### body prose — 15 sites

| size | weight | colour token | site | note |
|---|---|---|---|---|
| 12 | `w400` | `iconColor.withValues(alpha: 0.85)` | `screens/home_screen.dart:1789` | card body |
| 12.5 | `w400` | `onSurfaceMuted` | `screens/your_data_screen.dart:140` | footnote paragraph |
| 13 | `w400` | `onSurfaceMuted` | `screens/conditions_screen.dart:324` | explainer, second paragraph |
| 13 | `w400` | `cautionOnContainer` | `screens/home_screen.dart:1520` | banner body |
| 13 | `w400` | `cautionOnContainer` | `screens/home_screen.dart:1641` | banner body |
| 13 | `w400` | `positiveOnContainer` | `screens/home_screen.dart:1722` | banner body |
| 13 | `w400` | `(inherit)` | `screens/medication_screen.dart:209` | explainer |
| 13 | `w400` | `onSurfaceMuted` | `screens/vocabulary_screen.dart:500` | explainer, second paragraph |
| 13 | `w400` | `onSurfaceMuted` | `screens/your_data_screen.dart:226` | card body paragraphs |
| 13 | `w400` | `(inherit)` | `services/backup_service.dart:274` | sheet body |
| 13.5 | `w400` | `onSurfaceMuted` | `screens/your_data_screen.dart:72` | intro paragraph |
| 14 | `w400` | `onSurface` | `screens/conditions_screen.dart:316` | explainer, first paragraph |
| 14 | `w400` | `onSurface` | `screens/vocabulary_screen.dart:493` | explainer, first paragraph |
| 15 | `w400` | `(inherit)` | `screens/event_wizard_screen.dart:1106` | summary bullet lines |
| 16 | `w400` | `(inherit)` | `screens/walkthrough_screen.dart:277` | step paragraphs |

---

### hint or helper — 10 sites

| size | weight | colour token | site | note |
|---|---|---|---|---|
| 10 | `w400` | `onSurfaceMuted.withOpacity(0.7)` | `screens/home_screen.dart:2016` | italic, the only italic in band 1 |
| 11 | `w400` | `onSurfaceMuted` | `screens/home_screen.dart:1236` | under the primary action |
| 11 | `w400` | `onSurfaceMuted` | `widgets/occurred_at_field.dart:124` |  |
| 12 | `w400` | `onSurfaceMuted` | `screens/conditions_screen.dart:276` | blurb under a section heading |
| 12 | `w400` | `onSurfaceMuted` | `screens/vocabulary_screen.dart:329` | blurb, carries the hidden count |
| 13 | `w400` | `onSurfaceMuted` | `screens/event_wizard_screen.dart:474` | states what is currently stored |
| 13 | `w400` | `onSurfaceMuted` | `screens/log_event_screen.dart:598` | states what is currently stored |
| 13 | `w400` | `onSurfaceMuted` | `screens/log_event_screen.dart:888` | the shared _SectionHint |
| 14 | `w400` | `onSurfaceMuted` | `screens/conditions_screen.dart:244` | DropdownButton hint |
| 14 | `w400` | `onSurfaceMuted` | `screens/event_wizard_screen.dart:458` | hint under a step heading |

---

### metadata or timestamp — 5 sites

| size | weight | colour token | site | note |
|---|---|---|---|---|
| 11 | `w400` | `onPrimaryMuted` | `main.dart:193` | version on the splash |
| 12 | `w400` | `criticalOnContainer` | `screens/home_screen.dart:1412` | started-at and elapsed |
| 13 | `w400` | `onPrimaryMuted` | `screens/about_screen.dart:94` | version in the hero card |
| 13 | `w500` | `onSurface` | `screens/home_screen.dart:2007` | last event time |
| 15 | `w400` | `onSurface` | `widgets/occurred_at_field.dart:111` | the formatted value |

---

### badge or count — 6 sites

| size | weight | colour token | site | note |
|---|---|---|---|---|
| 10 | `w700` | `onFill` | `screens/history_screen.dart:1013` | filter badge, on a filled circle |
| 11 | `w500` | `_fg` | `screens/history_screen.dart:1724` | event-type badge on a row |
| 12 | `w600` | `primary` | `screens/medication_screen.dart:227` | deviation-kind badge |
| 14 | `w400` | `onSurface` | `screens/vocabulary_screen.dart:252` | selection count in the bottom bar |
| 14 | `w400` | `onSurfaceMuted` | `screens/vocabulary_screen.dart:372` | count of retired entries |
| 14 | `w400` | `onSurfaceMuted` | `widgets/bounded_chip_wrap.dart:178` | count of hidden chips |

---

### button label — 11 sites

| size | weight | colour token | site | note |
|---|---|---|---|---|
| 11 | `w400` | `(inherit)` | `screens/home_screen.dart:1824` | TextButton textStyle |
| 11 | `w500` | `primary` | `screens/home_screen.dart:2053` | inline action with an icon |
| 11 | `w500` | `onPrimary` | `screens/home_screen.dart:2087` | inline action with an icon |
| 12 | `w600` | `(inherit)` | `screens/home_screen.dart:1810` | TextButton textStyle |
| 13 | `w400` | `primary` | `screens/log_event_screen.dart:1273` | add-chip |
| 13 | `w600` | `(inherit)` | `screens/home_screen.dart:1435` | FilledButton textStyle — End |
| 14 | `w400` | `link` | `screens/vocabulary_screen.dart:377` | Show / Hide, link-coloured |
| 14 | `w400` | `link` | `widgets/bounded_chip_wrap.dart:183` | Show all / Show fewer, link-coloured |
| 14 | `w600` | `(inherit)` | `screens/home_screen.dart:1261` | ElevatedButton textStyle — Record Event |
| 15 | `w400` | `(inherit)` | `screens/log_event_screen.dart:847` | FilledButton, full width |
| 16 | `w400` | `(inherit)` | `screens/disclaimer_screen.dart:341` | FilledButton, full width |

---

### list-tile primary — 4 sites

| size | weight | colour token | site | note |
|---|---|---|---|---|
| 14 | `w600` | `(inherit)` | `screens/help_screen.dart:576` | SwitchListTile title |
| 15 | `w400` | `onSurface` | `screens/conditions_screen.dart:235` | type label beside a dropdown |
| 15 | `w400` | `onSurface` | `screens/conditions_screen.dart:292` |  |
| 15 | `w400` | `visible ? onSurface : onSurfaceMuted` | `screens/vocabulary_screen.dart:408` | entry name, colour varies by state |

---

### list-tile secondary — 5 sites

| size | weight | colour token | site | note |
|---|---|---|---|---|
| 11 | `w400` | `onSurfaceMuted` | `screens/vocabulary_screen.dart:420` |  |
| 11 | `w400` | `onSurfaceMuted` | `screens/vocabulary_screen.dart:425` |  |
| 12 | `w400` | `onSurfaceMuted` | `screens/conditions_screen.dart:296` |  |
| 12 | `w400` | `onSurfaceMuted` | `screens/help_screen.dart:585` | SwitchListTile subtitle |
| 12 | `w400` | `onSurfaceMuted` | `screens/history_screen.dart:1620` | the needs-details gap line |

---

### other — 31 sites

| size | weight | colour token | site | note |
|---|---|---|---|---|
| 9 | `w400` | `onSurfaceMuted` | `screens/home_screen.dart:1927` | stat caption under a number — not a form label |
| 10 | `w400` | `onPrimaryMuted` | `main.dart:171` | splash tagline, letter-spaced |
| 11 | `w400` | `onPrimaryMuted` | `screens/about_screen.dart:102` | brand tagline, letter-spaced |
| 11 | `w400` | `onSurfaceMuted` | `theme/mer_theme.dart:263` | THEME DEFAULT — bodySmall |
| 11 | `w600` | `onSurfaceMuted` | `theme/mer_theme.dart:264` | THEME DEFAULT — labelLarge |
| 12 | `isSelected` | `(inherit)` | `screens/history_screen.dart:1423` | chip label — selectable |
| 12 | `isSelected` | `(inherit)` | `screens/log_event_screen.dart:1047` | selection tile label — weight varies by state |
| 12 | `selected ? w600 : w400` | `selected ? onPrimary : onSurface` | `screens/history_screen.dart:1250` | chip label — selectable, weight varies by state |
| 13 | `isSelected` | `(inherit)` | `screens/log_event_screen.dart:1137` | chip label — selectable |
| 13 | `isSelected` | `(inherit)` | `screens/log_event_screen.dart:1239` | chip label — selectable |
| 13 | `w400` | `onSurfaceMuted` | `theme/mer_theme.dart:262` | THEME DEFAULT — bodyMedium |
| 13 | `w400` | `onSurfaceMuted` | `theme/mer_theme.dart:339` | THEME DEFAULT — input labelStyle |
| 13 | `w400` | `onSurfaceMuted` | `theme/mer_theme.dart:343` | THEME DEFAULT — input hintStyle |
| 13 | `w400` | `(inherit)` | `theme/mer_theme.dart:364` | THEME DEFAULT — chip labelStyle |
| 13 | `w500` | `onSurface` | `theme/mer_theme.dart:260` | THEME DEFAULT — titleSmall |
| 13 | `w600` | `infoOnContainer` | `screens/history_screen.dart:1341` | applied-filters banner sentence |
| 13 | `w600` | `Colors.white` | `theme/mer_theme.dart:373` | THEME DEFAULT — chip secondaryLabelStyle |
| 13 | `w700` | `iconColor` | `screens/home_screen.dart:1781` | card title — settings nudge |
| 14 | `w400` | `(inherit)` | `screens/conditions_screen.dart:248` | DropdownMenuItem child — menu, not list |
| 14 | `w400` | `(inherit)` | `screens/conditions_screen.dart:253` | DropdownMenuItem child |
| 14 | `w500` | `(inherit)` | `theme/mer_theme.dart:317` | THEME DEFAULT — outlinedButton textStyle |
| 14 | `w600` | `cautionOnContainer` | `screens/home_screen.dart:1500` | banner title — unsaved events |
| 14 | `w600` | `cautionOnContainer` | `screens/home_screen.dart:1627` | banner title — storage fallback |
| 14 | `w600` | `positiveOnContainer` | `screens/home_screen.dart:1687` | banner title — backup reminder |
| 14 | `w600` | `(inherit)` | `theme/mer_theme.dart:286` | THEME DEFAULT — elevatedButton textStyle |
| 14 | `w600` | `(inherit)` | `theme/mer_theme.dart:302` | THEME DEFAULT — filledButton textStyle |
| 14 | `w700` | `criticalOnContainer` | `screens/home_screen.dart:1404` | banner title — active event |
| 15 | `w400` | `onSurface` | `theme/mer_theme.dart:261` | THEME DEFAULT — bodyLarge |
| 15 | `w500` | `onSurface` | `theme/mer_theme.dart:259` | THEME DEFAULT — titleMedium |
| 16 | `w600` | `onPrimary` | `main.dart:160` | splash wordmark — a full-screen brand lockup, not an app bar |
| 16 | `w600` | `Colors.white` | `theme/mer_theme.dart:249` | THEME DEFAULT — appBarTheme.titleTextStyle |

⚠️ **THREE DISTINCT THINGS ARE IN HERE and the specification should probably separate them.**

1. **Theme defaults (14).** `mer_theme.dart` entries have NO element — they are what an unstyled widget inherits. They are in the 122 because the sweep counts `TextStyle` declarations, and that is the right denominator for *how many settings exist*; it is the wrong one for *how many elements need a step*. ⭐ **11% of band 1 is not a site at all.**
2. **Selectable labels (6)** — chips and selection tiles whose WEIGHT changes with state. They are the only sites in band 1 where one element has two settings by design, so a single step cannot describe them.
3. **Banner and card titles (5)**, plus a splash lockup, a stat caption and two dropdown-menu items. These are genuine elements that none of the eleven offered classes fits.

