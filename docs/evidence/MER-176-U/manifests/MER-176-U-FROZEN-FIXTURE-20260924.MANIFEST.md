# Frozen fixture manifest: MER-176-U-FROZEN-FIXTURE-20260924

**Frozen 24 Sep 2026 ~20:05 AEST** (host clock sntp-correct from 19:48). Cloned from MER-176-U after (ii).

| Name | UDID | What it is |
|---|---|---|
| `MER-176-U-FROZEN-FIXTURE-20260924` | `427DB6D1-65C0-4B86-88E9-95DE770CD88E` | ⭐ **THE FROZEN FIXTURE.** 180b / 176d start from here |
| `MER-176-U` | `2E364C3F-DA09-4B82-9EAD-21EDE359692D` | The source device, in the same frozen state. Keep it shut down and do not boot it as the fixture |
| `MER-176-U-POSTINCIDENT-1737-NOT-FROZEN` | `8E484F3D-67D5-4B5A-BA9B-D3E8BD2040F2` | ⛔ **NOT the fixture.** Pre-(ii) rollback: markers still present |

App: 1.0.2 (3), Debug simulator build, unentitled Runner (variant U). Data container `6AF194C4-3D1E-406C-A2D2-9FD88700FF69`
(same UUID in the clone). App Group container `5AB1F785…`.

## ⛔ MUST MATCH on every check (a mismatch is a finding)

| Path (Data container) | sha256 |
|---|---|
| `Library/Preferences/au.com.notiva.medicaleventrecorder.plist` | `cf9c5eec210476d88162d27773b0d4e723c4d42834cf8ec6946d4f07272c943c` |
| `Library/Preferences/group.au.com.notiva.medicaleventrecorder.plist` | `d850600fc64685b73f68628bea45bd2d620107eac68ac75d477d5f6a32894f85` |
| `MER-176-U-FIXTURE-FROZEN.txt` (marker file, container root) | `f503e7f8e5d925f12066f46465c65f8d046a2e6f15458041f348d1e3deb4be0a` |
| App Group `5AB1F785…/Library/Preferences` | **EMPTY** (0 files) |

Content: 6 records in both suites, mirror == main. **No `flutter.mer_active_event` / `mer_active_event` in either suite.**
Swift records 1B14D71F / 54605897 / CBE84F1D and 38DBC0EA are `lt1` (abandoned). Host copies of the plists are in `../frozen/`.

## EXPECTED TO CHANGE on a boot or launch (a change here is NOT tampering)

- `Library/Preferences/group.awn.0be43e74.plist`: awesome_notifications lifecycle bookkeeping. Frozen at
  `f355e4b85c8e927c91f236e2da4d3ab109aeea62ff22b78b114f837c5d0923fd`; observed values f355e4b8… / 9b6288bf… / 22b11abb…
- `Library/Saved Application State/au.com.notiva.medicaleventrecorder.savedState/` (and contents)
- `Library/Caches/au.com.notiva.medicaleventrecorder/com.apple.metal/`: `functions.list`, `libraries.list`, dir mtime;
  `functions.data` / `libraries.data` ctime
- `Library/Preferences/` directory mtime
- `Library/Caches/io.sentry/`: **DELETED at the freeze** (14 files, 20:04:23). The Sentry SDK recreates it on the next launch
- `Library/Caches/SentryCrash/…/CrashState.json`, `Library/Caches/async.log`: written by the 20:01 foreground launch (classified then)
- **Anything else is UNCLASSIFIED.** Adjudicate it before proceeding, and do not fold it silently into either list.

⚠️ **Boot behaviour changed.** Earlier, booting triggered an unrequested background 1.0.2 launch via liveactivitiesd. The three
1.0.2 Live Activities were ended by the system (content source chronod) at 19:09–19:10 on 24 Sep. The 19:55 boot restored none and
launched nothing. So a boot of this state is EXPECTED not to launch the app. Still re-hash after every boot.

## Full-device manifests (this directory)

- `MER-176-U-source-manifest-prefreeze-clone.sha256` == `…-postfreeze-clone.sha256` (11107 files; the clone did not change the source)
  sha256 of the manifest: `afafae9715aad2f16b12bbc206fa331d3c3d3317c6a775508801115cebe633df`
- `MER-176-U-FROZEN-FIXTURE-20260924-clone-manifest.sha256` (11106 files): `3d8ac760700d651b4093be6f294a83a29cddc2f69b5b954ad2a193ae1331712f`
- Clone == source except `device.plist` (name/UDID) and `datacom.apple.modelcatalog/tokenStore/0C47801D-…`, a host
  boot-session token that `simctl clone` does not copy. This is the same pattern as the POSTINCIDENT clone.
