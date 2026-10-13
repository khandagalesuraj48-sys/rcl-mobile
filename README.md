# RCL ERP – mobile app

Android and iPhone app for the people at the sites.

**Version 2 (14-10-2026: "web warcha full access app war"):** the app shows the **whole web ERP** – every page, the ☰ menu,
the Dashboard, the same Edit / View / None access, the Store and every module of the site inside it – exactly as on the web.
Nothing of the work is written twice: the pages, checks and saves are the web's own (`/api/rpc`).
(Version 1 had its own Diesel Issue / Inward / Transfer screens – replaced.)

* **One sign-in:** the app's own sign-in screen (animated) takes the Portal's email and password, lists the person's sites
  and their modules, and opens the chosen site's ERP with a Portal ticket (`#sso=…`) – nothing else is typed. The Portal's
  sign-in is also given to the web view, so the web's "Change site" and its modules open without a sign-in.
* **What a phone's web view does not do by itself** – done by the app (`lib/web/web_shell.dart` + `assets/web_bridge.js`):
  * the **camera** for a photo (Diesel Issue …) and the **location** of an entry – Android asks once;
  * **Excel / CSV** made by the web – offered to open, send or keep (Android's share sheet);
  * **print** – the web's print window opens inside the app (with its Portrait / Landscape / Excel / Print), then
    Android's printing (a printer or Save as PDF);
  * a link to **another site** (photo full size, map, backup sheet) – opened outside the app;
  * the phone's **Back** – one step back in the ERP (the web's own Back); the web's **Logout** – the app's sign-out.
* **Update from inside the app** (asked 14-10-2026: "git release madhe apk theun de"): the newest **GitHub Release** of this
  repository.
  * The release carries the APK, and its notes carry the build number and the SHA-256.
  * The app downloads the APK and checks the fingerprint. Android then installs it only if it carries the same signature.
  * iPhone: App Store / TestFlight, later.

## Build
GitHub Actions (`.github/workflows/build.yml`) runs on every push:
* `flutter analyze` and the tests;
* pictures of the screens (saved in the branch `screens/<branch>`);
* an Android file for checking (artifact **android-apk**, debug-signed).

The first run makes the `android/` and `ios/` folders and saves them in the branch.

## Code
| Part | File |
|---|---|
| The Portal (sign-in, sites, ticket) | `lib/core/api.dart` |
| Person, sites, the site open | `lib/core/session.dart` |
| The web ERP in the app | `lib/web/web_shell.dart`, `assets/web_bridge.js`, `lib/web/print_view.dart`, `lib/web/files.dart` |
| The app's own screens | `lib/screens/` (sign-in, sites), `lib/main.dart` (opening) |
| Design | `lib/ui/theme.dart`, `lib/ui/brand.dart` (the moving green background, the RCL mark) |
| Tests | `test/`, with a pretend Portal in `test/fake_server.dart` |
| The web bridge in a real browser | `test_web/bridge.test.js` (a page built like the ERP), `test_web/real_erp.js` (the real ERP on the local test copy) – run by hand with Node + Chromium; a web view cannot run in Flutter's tests |

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
