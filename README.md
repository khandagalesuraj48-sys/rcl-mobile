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
* **Update from inside the app:** the Portal's `/api/app` gives the newest version.
  * Android: a 10-minute link to the APK kept in a private Supabase bucket. The fingerprint (SHA-256) is checked, then
    Android installs it only if it carries the same signature.
  * iPhone: the App Store / TestFlight page.

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
