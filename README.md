# RCL ERP – mobile app

Android and iPhone app for the people at the sites.

**Version 3 (14-10-2026: "mobile UI purn wegla hawa … fkt app che all logics functions mobile madhe … premium"):** the app
has its **own phone screens** (the desktop web stays as it is), on the same servers and with the same access:
* **Sign-in** (animated, the Rachana logo) – the Portal's email and password; his sites; Mechanical opened with a ticket.
* **Home** – the site's picture, the site (change it), the diesel stock (total and each place), machinery working today and
  today's Log Book entries, the modules he may open, today's diesel work.
* **Entries** – Diesel Issue / Diesel Inward / Transfer of a day (only those he may see): a strip of days, search, a filter by
  place, a card per entry (its details on a tap), **New Entry** for those with Edit.
* **New Diesel Issue** – machinery, its way (KM / Hrs …, picked by itself when there is one), readings, litres with the stock
  after it, driver, remark and the **4 photos** (camera now, the place printed on each, sent at once – as on the web);
  Inward and Transfer as on the web. The server decides everything; its warnings come back as "Save anyway?".
* **Reports**, **Me** (role, site, version / update, My settings, the full web ERP, sign out).

**Version 3.1.4 (14-10-2026: "user la pn disayla haw tyan approval sathi kay pathwale ahe … pending … milale"):** Me → **Approvals** opens the web's Approvals page in the app: a user sees the changes he sent (waiting / approved – saved / rejected with the reason); the Super Admin approves or rejects there. Shown to the Super Admin and to a user who may change Log Book or diesel. The notifications themselves are the web's (browser / installed web app); this app has no push service of its own yet.

**Version 3.1.3 (14-10-2026: "bill entry change fkt super admin change kru shakel … user pn change kru shakel but approval tewach hoil jewa super admin approval deil"):** an entry of a submitted bill. The Super Admin (his Portal ticket says so) changes it on the phone too – Mechanical saves it, and the next bill of the vendor takes the difference. Anybody else: the save is refused as before, and the phone now asks "send it to the Super Admin?" with a reason (`Api.askApproval` → `sendChangeRequest`, the same as the web page); it is saved only when he approves it (Mechanical → Approvals). A Log Book entry or diesel issue of a bill can be opened again on the phone (the note under it says so). Tests: `session_test.dart` (sent with a reason / not sent / the Super Admin is not asked).

**Version 3.1.2 (14-10-2026: "super admin la pages … disle pahijet"):** the Super Admin signs in on the phone too and opens every
site's modules as Admin (the Portal lists them all for him); before, the app sent him to the Portal.

**Version 3.1.1 (14-10-2026: "ekach date madhe multiple entry … pratek entry seprate asawi … edit delete pn asaw"):**
* A water tanker's Log Book entry is a **card per trip** (Trip 1, Trip 2 …: challan, dispatch – unload, chainage, use for), each
  with **Change** / **Delete** (`tripsOfRow`, `deleteTrip`); an entry made before trip by trip is read as its trips (as the web).
* The tanker screen: a saved trip can be **changed** (its shift too) – `updateTankerTrip` (web update-105).
* The web's page is switched without eval (`window.rclGo`, web update-104) – the Admin's faults list no longer gets
  "Security policy … eval" from the app.

**Version 3.1 (14-10-2026: "log book war loading, errors, web UI nko … dashboard photo reading auto … user settings"):**
* **Log Book on the phone** (`lib/screens/logbook.dart`): the day's entries, the machinery still without one, a new entry
  in every way (Start from the last entry, Time with split timings and break, Trip, Day, Idle / Holiday / Breakdown, No
  reading with the estimate, a new meter, ½ day, the format's challan / particular / chainage, Item-wise BOQ pick or split,
  Debit to, opening diesel of a first entry), change and delete, and a water tanker trip by trip – the web's own actions.
* **Diesel Issue**: the dashboard photo fills the reading and the dispenser photo the litres (the AI, `getMeterReading`, as
  the web); an entry can be changed or deleted from its details.
* **My settings** (`lib/screens/settings.dart`): default site (the Portal's start), usual shift, usual diesel place, Log Book
  usual way, size of the text, mobile number, photo, password – the same settings as the web.
* Modules still on the web: ONE web view (`lib/web/web_host.dart`) loaded in the background and kept alive – a module opens
  at once (the web switches its page, `__rclAppGo`); its "page stopped" box and the opening film are not shown.
* Modules not yet made for the phone (Machinery, Logbook, Maintenance, Billing, Store, Administration, the reports) open their
  **web page inside the app** (`lib/web/web_page.dart` + `assets/web_bridge.js`: camera, location, Excel / CSV to the share
  sheet, print / PDF, Back, Logout). The One Click opening film is not shown in the app.
* 3D pictures: Microsoft Fluent Emoji (MIT, `assets/icons3d/LICENSE-fluentui-emoji.txt`). The Rachana logo is the picture the
  web ERP shows (fetched once by the build, `assets/brand/`).
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
| The Portal and Mechanical (sign-in, ticket, actions) | `lib/core/api.dart` |
| Person, sites, access, the site's lists | `lib/core/session.dart` |
| The 4 photos (camera, location, the printed band) | `lib/core/photo.dart` |
| Screens | `lib/screens/` (login, site_pick, shell, home, entries, forms, reports, me), `lib/main.dart` (opening) |
| The web pages still in the app | `lib/web/web_host.dart`, `assets/web_bridge.js`, `lib/web/print_view.dart`, `lib/web/files.dart` |
| Design | `lib/ui/theme.dart`, `lib/ui/brand.dart` (backgrounds, Rachana mark and logo), `lib/ui/widgets.dart` |
| Tests | `test/`, with pretend servers in `test/fake_server.dart` |
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
