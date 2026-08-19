# Store Listing Copy — v1.1 revision

Paste-ready replacement copy for Apple App Store, Google Play and Microsoft Store.
Source: "Medical Event Recorder — Copy Revision" (claude.ai draft, 19 Aug 2026).

**Not applied anywhere.** These fields live in the store consoles and must be pasted
by hand. Use the same body text on all three so they cannot drift.

⚠️ Character limits below are from the source draft and were NOT verified against the
consoles. Confirm each in App Store Connect / Play Console / Partner Center before
pasting.

## Short fields

| Field | Limit (unverified) | Value |
|---|---|---|
| Name | 30 | Medical Event Recorder *(unchanged)* |
| Subtitle (Apple) | 30 | Private on-device event log |
| Short description (Play) | 80 | A private, on-device record of medical events. No account. No cloud. |

## Description (all three stores)

Medical Event Recorder is a private, on-device record of medical events — for
individuals and carers who need an accurate written record of what happened and when.

Record an event as it happens. Each entry is timestamped and structured: event
type, duration, how severe it felt, possible triggers, and any notes you want to
add.

Start and stop an event from the Lock Screen or notification shade, without unlocking
your phone.

Export your full record as a CSV file — open it in a spreadsheet, keep it as a backup,
or share it with whoever you choose.

WHAT IT RECORDS
• Date and time, captured automatically
• Event type
• Duration and severity
• How you were feeling
• Possible triggers
• Whether a medical referral is needed
• Free-text notes

PRIVACY
• Your event data is stored only on your device
• No cloud storage, no user account, no sign-in
• Nothing is shared unless you choose to export it
• Anonymous crash reports help fix faults; they contain no event data

Available on iPhone, iPad, Android and Windows.

Medical Event Recorder keeps a record. It does not interpret one. It is not a medical
device and is not intended to diagnose, monitor, predict, treat or prevent any
condition. Always consult a qualified healthcare professional.

## Keywords (Apple, 100 char limit — count before pasting)

event log,symptom,seizure,diary,carer,timestamp,csv,export,offline,private,record,epilepsy

## Rationale for the changes

| Current | Replacement | Reason |
|---|---|---|
| "helps you **track** seizures, absences and other medical events" | "a private, on-device **record** of medical events" | *Track* invites reading as *monitor*, a trigger verb in AU and EU |
| "Designed for individuals and carers **managing epilepsy**" | "for individuals and carers who need an accurate written record" | *Managing* a serious condition invokes a self-management framing whose carve-out excludes serious conditions |
| "**nothing is sent to the cloud or any third party**" | split into event data vs anonymous crash reports | Unqualified version is contradicted by the App Store privacy declaration (Diagnostics / Crash Data) |
| "share with your **doctor** or carer" | "share with whoever you choose" | Keeps the export a user action rather than a clinical workflow |
| *(no disclaimer)* | closing disclaimer paragraph | Intended purpose is established publicly; the public copy should carry the limits |

## Outstanding

- **"or enter it afterwards" deliberately removed.** There is no date or time
  picker in the app, so an event logged later is timestamped to the moment of
  logging, not the moment it occurred. Reinstate that wording only once an
  `occurredAt` field separate from the record timestamp exists.
- **Play and Microsoft Store listings never audited.** Only the Apple listing was
  reviewed when this was drafted. Both may contain phrasing not covered here.
- **Naming epilepsy in keywords** is not itself a claim, but it establishes the target
  condition as a serious one. Raise with the regulatory adviser specifically.
- **Jurisdiction analysis unverified.** Copy is drafted defensively to the broadest
  verb set rather than per-market. EU MDR is the tightest regime MER is exposed to;
  MDCG 2019-11 is the applicable guidance and has not been checked against current
  sources.
