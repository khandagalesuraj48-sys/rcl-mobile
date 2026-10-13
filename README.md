# RCL ERP – mobile app

Android and iPhone app for the people at the sites. First version (14-10-2026): **Diesel Issue, Diesel Inward, Diesel Transfer**
and a Home screen with the stock. Design 6 "Big Tiles".

* **One sign-in:** the Portal's email and password. Sites and access come from the Portal and from Mechanical (the same
  Edit / View / None as on the web; a tile only for what the person may open).
* **The same server rules** as the web app: the app calls Mechanical's own actions (`getInit`, `saveDieselIssue`,
  `getDieselIssues`, `saveInward`, `saveTransfer`, `getIssueBalance` …). Stock, closed month, bill lock, an active
  machinery and reading checks are decided by the server.
* A Mechanical sign-in that ended is renewed by itself with a new Portal ticket. A save carries its own number, so it is
  saved once even when it is sent again.
* **Update from inside the app** (asked 14-10-2026: "git release madhe apk theun de"): the newest **GitHub Release** of this
  repository.
  * The release carries the APK, and its notes carry the build number and the SHA-256.
  * The app downloads the APK and checks the fingerprint. Android then installs it only if it carries the same signature.
  * iPhone: App Store / TestFlight, later.

## Build
GitHub Actions (`.github/workflows/build.yml`) runs on every push:
* `flutter analyze` and the tests;
* pictures of the screens (artifact **screens**);
* an Android file for checking (artifact **android-apk**, debug-signed).

The first run makes the `android/` and `ios/` folders and saves them in the branch.

## Code
| Part | File |
|---|---|
| Servers | `lib/core/api.dart` |
| Person, site, access, lists | `lib/core/session.dart` |
| Screens | `lib/screens/` (home, entries, forms, me) |
| Design | `lib/ui/theme.dart` |
| Tests | `test/`, with a pretend server in `test/fake_server.dart` |

Fonts: Rubik and Noto Sans Devanagari (SIL Open Font License, `assets/fonts/OFL-*.txt`).

## Release (signed, a GitHub Release)
`.github/workflows/release.yml` is run by hand on `main` (Actions → release → Run workflow), after the owner says yes.
* **First time:** it makes the private bucket **app-keys** in the Portal's Supabase and the signing key, kept only there. A
  copy of that key should be kept offline: Android installs an update only when it carries the same key.
* **Every time:**
  1. the tests;
  2. the signed APK for every Android phone (ARM 32 + 64 bit), with build number 100 + run number;
  3. a check that the debug key was not used;
  4. a GitHub Release `v<version>-<build>` with the APK, its SHA-256 and the data line for the app.

  People install the first time from the release page; later updates come inside the app.
* **Needs two GitHub secrets:** `PORTAL_SUPABASE_URL` and `PORTAL_SUPABASE_KEY` (for the signing key only). They are never
  in a file and never in chat.
