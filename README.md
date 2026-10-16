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

**Version 3.1.11 (16-10-2026, with Mechanical update-118: "jewa t entry sent verification krel tyala pn samajayla haw konti entry
verification madhe aahe ani konte approval zale aahet … tyach reminder pn to pathau shakel"):**
* **My entries in verification** (`lib/screens/verify.dart`): on Home (all pages – waiting, sent back, approved today) and on the
  Diesel Issue / Inward / Transfer forms and the Log Book (that page's): Waiting / Sent back / Approved / Not saved; tap → each
  entry (at whom it waits, since when) with **Remind**, and **Remind all waiting**. The approver is told at once.
* The approver's phone: a notification for each reminder (`alertsFrom`: open app – the live tick; closed – Android every ~15 min).

**Version 3.1.10 (16-10-2026, with Mechanical update-117 – every site its own diesel places, set by the Super Admin in the
Portal: 18B's Camp Pump and the dispensers MH12ZE1739 / MH12WJ1381):** the app already takes the site's places from Mechanical
(every place list, the stock tiles on Home); now the Marathi word under each place on Home is its own (pump / dispenser / store –
`placeMr`, lib/core/kinds.dart) – before, every place other than the Dispenser said "store".

**Version 3.1.9 (16-10-2026: "vehicle select kel ki auto tyach km km+hrs trip je kay asel te auto select … perfect kam karyla haw"):**
the Log Book entry picks "Measured by" by itself, as the web does: the way of the machinery's last entry, else its Asset Master
unit, else its first way (`Machine.logWay`). It can still be changed (Idle, Holiday, Breakdown, a day on Time). Diesel Issue: by
itself since 3.1.8.

**Version 3.1.8 (15-10-2026: "number plate cha photo … auto number detect hoil manual pn krta yeil"; "km aahe hrs aahe ki km+hrs aahe he pn auto select asaw"; "eka khali ek ashi list … jyala jo access aahe tyala tech disel"; "jr revert zal tr mahesh la continue push notification jatil"):**
* Diesel Issue: **"Photo of the number plate"** – the phone reads it (Google ML Kit, on the phone: no internet, nothing paid) and
  picks the machinery of the Asset Master on site that day (`lib/core/plate.dart`: two lines, letters the camera mixes up, one
  letter wrong). Several alike → he picks among them; none → he is told and picks as before.
* Diesel Issue: KM / Hrs / KM + Hrs **by itself** from the Asset Master (`Machine.dieselWay`); only "Meter not working".
* The save button says **"Send to verification"** when the Super Admin's rule applies to him (Mechanical update-116, getInit
  "flow"); else "Save …".
* **Entries**: a list one under the other of the pages he may open – 1. Diesel Issue 2. Diesel Inward 3. Transfer 4. Log Book.
* **Reports**: every report of the web he may open (Dashboard, the diesel reports, Bill Summary, Vendor Ledger / Outstanding).
* **Notifications** on the phone (`lib/core/alerts.dart`): something new waits for him to approve (once); an entry of his sent
  back with a question (again every 30 minutes until he answers). Also with the app closed: Android asks about every 15 minutes
  (an Android alarm). The phone asks to allow notifications once.

**Version 3.1.7 (15-10-2026: verification of every work – Mechanical update-114; a machinery that left the site – update-115; "app madhe live sync haway … app refresh kraychi kahich garaj nahi"):**
* An entry of a work the Super Admin put under verification comes back "Sent for verification to … – VF-00001": shown in green,
  the form is emptied (an edit is closed) – nothing is saved until it is approved (`Api.isSent`, code `sent`, never sent again).
* **Approvals** in Me for everybody (the web's Approvals page in the app: approve one or several, the Super Admin's rules), with
  the number waiting for him – also on the Me tab.
* **Live**: while the app is on the screen it asks Mechanical every 15 s what changed (`Session.liveTick`, the web's "sync"):
  Home, Entries and the Log Book load again by themselves; a new machinery (Asset Master) or stock comes in; the Approvals count.
  Nothing is asked in the background.
* **No network**: a NEW diesel entry or Log Book entry that got no answer may be **kept on the phone**; it is sent by itself when
  the network is back – with the save number of the first try, so it is saved once. Me → **Waiting on this phone** shows them; one
  the server refuses stays there with its words until it is deleted. (`Session.keepEntry` / `sendKept`.)
* The machinery picker offers only the machinery **on the site on the entry's date** (from Active From until the day before
  Inactive From – as the server); the Home count too.

**Version 3.1.6 (15-10-2026: "app madhe mala language change ha option hawa aahe all site user sathi hindi marathi english … purn app tyach language madhe asel error suggestions pn tyach language madhe"):** Me → My settings → **App language**: मराठी / हिंदी / English. The whole app is shown in it – titles, buttons, hints, messages, the servers' errors – and the web pages inside the app too. It is kept with his account: the same on the web and at all his sites (Mechanical update-112), and on the phone for the next start (the sign-in screen too). Not chosen yet: the app as before (English with the Marathi line). The code stays English: `lib/core/lang.dart` turns what is shown from `assets/i18n/web_<lang>.json` (the web's words, the server's messages) and `assets/i18n/app_<lang>.json` (the app's own); `lib/ui/t.dart` is the app's `Text` (every screen imports material without its Text), `MrLine` the Marathi second line; strings given to Flutter's own widgets (hints, labels, tooltips, the bottom menu) go through `tr()`, two-language messages through `bi()`. Photos' printed stamps stay English.

**Version 3.1.5 (15-10-2026: "super admin new user banwel test password dila … user la first time swatacha pn banwaycha asel tr to app madhun pn banau shakel"):** the first sign-in with the password the Super Admin gave (a new user, or a one-time password) no longer sends the person to the web: the same screen asks for the given password and his new password twice (English + Marathi), the Portal checks it and its rules, and the app opens. Opened again before it is set: the same screen; "Back to sign in" signs out.

**Version 3.1.4 (14-10-2026: "user la pn disayla haw tyan approval sathi kay pathwale ahe … pending … milale"):** Me → **Approvals** opens the web's Approvals page in the app: a user sees the changes he sent (waiting / approved – saved / rejected with the reason); the Super Admin approves or rejects there. Shown to the Super Admin and to a user who may change Log Book or diesel. The notifications themselves are the web's (browser / installed web app); this app has no push service of its own yet. **Day / Night by the time** (asked the same day): a new diesel issue, transfer, Log Book entry or water-tanker trip starts with Day (8 AM – 8 PM) or Night, by the site's hours (web → Settings → Rules of the site); "My usual shift" still wins (its empty choice is now "Automatic"); the shift can be changed by hand.

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
