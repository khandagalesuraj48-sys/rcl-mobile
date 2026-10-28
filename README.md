# RCL ERP – mobile app

Android and iPhone app for the people at the sites. (The Windows computer app of 3.19.0 is no longer built – since 3.37.0,
asked 25-10-2026; computers use the web ERP.)

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

**Version 3.53.0 (28-10-2026 – "jewde active aahet own rachana vehicle te mala import karaych aahe as it is jas asel tr"; then "aple
app madhe powerful Claude AI aahe so import kartana full scan duplicate sagle kahi find krun import kasel name correction …", with
Mechanical update-173; "he admin la fkt nahi user la pn disu de", update-174):** **Maintenance** has, for everyone with Maintenance
Edit (not only the Admin), **"Import the old log book (Excel or PDF)"** (a person whose Maintenance is under verification: his import is
sent, said as sent): his **Excel** (a sheet a
machinery, read as the web reads it – a bill = the rows of one date and party, a merged date the row's above, a reading on the bill's
first row, each line as it is with its GST % from its GST Amount, a ₹0 line kept as FOC), a **PDF or a photo of a page read by the AI**
row by row (2 pages a call, one page when its answer was cut; each machinery's table a sheet), or **"Download the format (Excel)"** (a
sheet for each Own machinery on the site, its number in row 3, the heading). A card a sheet with its machinery (the **Own** ones on the
site today; it can be changed or set to "– not imported –"), rows, bills, the file's total and the total as it will be kept, **the lines
that do not add up** (Qty × Rate ≠ Amount, Amount + GST ≠ Amount With GST, an odd GST %); **the names written in more than one way**
(Party Name, Particulars, Uom – the AI's list, nothing ticked: he ticks, or types another name); **Check** (nothing saved – each mistake
with its row), then **Import** (asked first; one machinery all of it or nothing; **a bill already there** – the same machinery and date,
its lines or its total to ₹1, whatever its party is called – is left out **and listed**). The same server actions as the web
(readMaintLog, maintImportNames, checkMaintImport, importMaint). Then (28-10-2026, Mechanical update-175): **every Own machinery** –
on the site now or not (marked "not on the site now") – and its bills before its Active From; the names' list goes once all is imported;
the **Maintenance Log Book "Start to end"** (from its first bill, no limit of days) and the bills **"Start to end"** (every bill – each can
be changed or deleted, also an old one); **"Fetch outward (Store)"** – the Store's Issue is not built yet: said so, then the log book start
to end. The web's help and words taken again.

**Version 3.52.0 (27-10-2026 – "pdf print keli ki gst raw madhe ka dakhawat aahe heading madhe aahet gst tr", with Mechanical
update-172):** the car's **Maintenance Log Book** (screen, Excel, PDF) shows no GST row: a bill saved before 3.51.0 with its taxes as lines
of their own ("CGST @ 9%", "SGST @ 9%", "GST 18%" or "IGST 18%" – one rate) has them on its items – by the tax's % when that makes the
bill's tax, else in the items' proportion – each item its CGST / SGST in the heading's columns; the bill's total stays what was saved.
A line's name is written without its kind after it ("Oil filter", not "Oil filter (Warranty)") – Paid by is its own column. "By work /
part" (the server's) has no CGST / SGST work either. The web's help and words taken again.

**Version 3.51.0 (27-10-2026 – "gst row madhe nko heading madhe ghe 9 9 18 … koni paid kel insurance claim aahe nahi service ch
bill ahe ka as sagle hawa entry krtana pn ani log print madhe pn", with Mechanical update-171):** each line of a maintenance bill
has its **GST %** (one number – CGST and SGST are half each) – the card shows its GST ₹ and its amount with GST, the bill total is
with GST; no tax lines any more. Each line says **Paid by**: RCL, Insurance, Warranty, FOC or Service Plan – a line paid by the
insurance turns the insurance claim on by itself and "Paid by the insurance" is those lines with their GST (not typed). The
**Maintenance Log Book** has the GST rates in its heading (CGST 9% · SGST 9% … for each rate), then "GST 18%" (or GST Amount when
there are several rates), Amount With GST, and on every line **Paid by · Insurance claim (Yes / No) · Service (Yes / No)** · Total;
the tax lines of the bills of before go into their CGST / SGST column. A bill with GST or lines paid by the insurance can be
changed only by this version (the server asks an older app to update).

**Version 3.50.0 (27-10-2026 – "mala log book as hawa aahe ya format madhe … party name … jr direct bill marle tr party ch name yeil",
with Mechanical update-170):** Maintenance is at **every site**, for every machinery (when the page is given): a bill's **Party
name** (the garage / shop of a direct bill), its **Current reading** (KM / Hrs), each line its **Uom** (Nos, Ltr, Kg … offered).
The **Maintenance Log Book** is in his format (Roller No-03): Sr No · Date · Party Name · Current Reading · Particulars · Qty · Uom ·
Basic Rate · Amount · GST Amount · Amount With GST · Total – a row a line, the tax lines in GST Amount, the insurance's part its own
row; at a site on fuel cards the fills follow, then "by work / part". The RCL Store's material comes in when the Store has its Issue.

**Version 3.49.0 (27-10-2026 – "kahi material warranty madhe aste kahi paid aste kahi discount deun aste tr sagle kahi yeyla hawa
… type pn krta yayla hawa", with Mechanical update-168):** a maintenance bill keeps EVERY line of the garage's bill: each line is a
card with its work / part, its **kind** (Paid / Warranty / FOC / Service Plan), **Qty, Rate, Disc %** and **₹** – a Paid line's ₹
is worked out from Qty × Rate − Disc % (and can be typed), a free line is ₹ 0 with its worth shown in green. Under the lines: the
bill total, what the free lines are worth, and an **insurance claim** (the company, the claim no., what the insurance paid) – the
car's cost is **what we paid**. "Read the bill (AI)" puts the car from the bill's number, every line with its kind and the
insurance; the list, the bill's sheet, Change and the car's Maintenance Log Book show we paid / the bill / the insurance / the free
worth, as the web. A bill with free lines or an insurance part can be changed only by this version (the server asks an older app
to update).

**Version 3.48.0 (27-10-2026 – "Claude API lawaychi aahe … all app madhla AI perfect chalayla hawa", with Mechanical
update-167):** the server's AI is **Claude** when the Admin puts its key (ANTHROPIC_API_KEY) in Vercel – the assistant, the
meter / pump photos and the maintenance bills go to Claude through the same server actions (the app's conversation is the same;
the server puts it into Claude's words). In the app only the words changed: "Test the AI service" names the service ("Service:
Claude") and, when no model answers, says to look at the key and the credit in Claude Console; no key on the server names
ANTHROPIC_API_KEY; the web's help for the new messages (no credit left, a key not accepted) and its Marathi / Hindi words taken
again. The photos the PHONE reads itself (ML Kit, 3.28.0) are not changed.

**Version 3.47.0 (27-10-2026 – "fuel card number / details takayla option nahiye te baanaw", with Mechanical update-166):** a fuel
card's **details** – Bank / company, Name on the card, **Expiry** (month / year, typed as 08/2029), Customer / Account ID – in the card's
form (Fuel Cards → a card → Change card, or + Card); the tile shows its bank / company and a mark **"Expires 31-10-2026"** (amber –
within 30 days of its last good day) or **"Expired 08/2026"** (red), also on the Dashboard's cards; its sheet shows every detail. The
number stays **only its last 4 digits** (his choice) – the server refuses a whole card number typed into any box. `FuelCard.issuer`
/ `holder` / `expiry` / `custId` / `expDays` (the server's days to its last good day), `cardExpNote`.

**Version 3.46.0 (27-10-2026 – step 2 of HO, the Maintenance Log Book, with Mechanical update-165):** at a site on fuel cards the page
**Maintenance** (its own screens, `screens/maintenance.dart`; access: the Portal's page "Maintenance" – Edit / View, blank = none):
the bills of the dates (and of one car) with their total; **one bill of a car** – date, car, garage, bill number, KM, **Service** (its
KM is needed), remark, its **lines** (each work / part with its ₹, a discount a minus line, the words typed before offered) and its
**files** (PDF / photos, up to 10 – the Log Book's attachment box, sent with `maintFile`); **"Read the bill (AI)"** reads the last
file added (`readMaintBill`) and fills the empty boxes and the bill's date (blue – the person checks every value; lines typed already
are replaced only when he says so; the bill's vehicle not this car is told). The same bill number of the same garage for the car is
asked first ("Saved before?"). A bill opens with its lines and files (`getMaintFiles`), Change, Delete. **The car's Maintenance Log
Book** (`report_defs.dart` `kMaintLog`, the server's `maintLog`): every fill (its card or Cash) and bill by date, fuel / maintenance /
all costs, KM of its Log Book, ₹ per KM, the last service – on the screen, Excel and PDF (no fuel to choose: the car has its own).
Entries, the start page and Help list it only at a site on fuel cards. Every other site exactly as before.

**Version 3.45.0 (27-10-2026 – "ho madhe diesel stock hot nahi ek card dilelel aahet … card cha opening balance takel nantr apli
system auto amount debit dakhwel", with Mechanical update-164):** a site on **fuel cards** (HO – the Super Admin, Portal → Sites →
Diesel places → "Fuel cards – no stock"; Mechanical tells it in `getInit` as `fuelMode: 'card'`) keeps **no diesel stock**: Home shows
every Active card's balance (opening + payments onto it − the fills paid by it; a card short of money in red) in place of the stock;
Entries has Diesel Issue and **Fuel Cards** – no Inward, no Transfer, no "Multiple entries" / Excel; a **Diesel Issue** is paid by one
of the car's cards (its balance shown, the balance after the fill – short is still saved, in red) or **Cash**, with its **Amount (₹)**
and rate (₹ read from the dispenser photo); no Register photo. The page **Fuel Cards** (its own screen, `screens/fuel_cards.dart`):
the cards (name, kind, last 4 digits only, opening balance and date, cars – none = every car, Active), the payments / recharges onto
a card with receipt photos, a card's statement. The **Dashboard** at such a site: the cards' balances and each car – KM, fuel and ₹
(by card / cash), average, last fill (`getCardDash`); Reports → Overview's cost is the ₹ of the fills; no stock reports. The
assistant: a fill is made in its form; the stock question gives the cards. `Session.cardSite` / `cards` / `card` / `payFor` / `kCash`,
`FuelCard`. Every other site (VTR, 18B) exactly as before. The web's help and words taken again.

**Version 3.44.0 (26-10-2026 – "petrol cng he field banaw ani ha electric ha pn thew future madhe ya gadya pn yenar aahet", with
Mechanical update-163):** **fuel** – every machinery has one (Asset Master → **Fuel**: Diesel / Petrol / CNG / Electric; none =
Diesel – also "Multiple machinery", the Excel import, its card and details) and every diesel place holds one (the Super Admin, Portal
→ Sites → Diesel places; Mechanical tells them in `getInit` as `placeFuels`). A **Diesel Issue** offers only the places of the
machinery's fuel (both "Multiple entries" too; a site with more than one fuel always shows "Fuel from"); an **Electric** machinery
gets no fuel (a red line); a **Transfer**'s To is of the From's fuel (also its grid rows); CNG in **kg** ("Kg", the stock, the
balances, the cards). The Excel checks: "runs on Petrol – not at DIESEL CARD", "From Petrol, To Diesel – not the same fuel". **Never
added together:** Home shows the first fuel in big and the others under it; the lists' day totals per fuel; the **Dashboard** and
every **report** of a site with more than one fuel have a **Fuel** choice – one fuel at a time, in its own words and unit (`FuelScope`
in `ui/t.dart` turns "Diesel" into its name and the litres into kg for CNG; `fuelDoc` does the same for a report's print and Excel);
the Daily report shows each fuel's stock, received and issued one after another; Reports → Overview's diesel figures (consumed,
cost, the trend) are Diesel's only. The assistant's diesel entry takes a place of the
machinery's fuel. A site whose places are all Diesel (VTR, 18B) looks exactly as before. `core/fuel.dart`; `Session.placeFuels` /
`placeFuel` / `siteFuels` / `multiFuel` / `fuelPlaces` / `fuelProblem` / `transferTos`; `Machine.fuel`. The web's help taken again.

**Version 3.43.0 (26-10-2026 – "user wise konala konte source cha access deycha … jya user la jyacha access asel to tyach madhun
issue kru shakel same transfer la pn … inward la nko", with Mechanical update-162):** his **diesel sources** – the places the Super
Admin gave him in the Portal (Users & Access → Pages → Diesel sources; Mechanical tells them in `getInit` / `sync` as `user.dsrc`).
A **Diesel Issue** (one entry, "Multiple entries" – both kinds, an Excel file) and the **From of a Diesel Transfer** (one entry,
"Multiple entries", an Excel file) offer only them; given some, the Issue shows its source even when there is one (he sees where the
diesel comes from); none given: a red line says so. The **To** of a transfer, **Diesel Inward**, the lists and reports: every place
(as before). Nothing chosen for him / an Admin: every place, as before. A change in the Portal reaches the open app at the next sync.
The assistant's diesel entry takes his own source when he names none. Mechanical refuses another source whatever the app sends (its
message has its help). `Session.dsrc` / `mySources(page)` / `ownSources(page)`; the import checks (`issueProblems`,
`transferProblems`: "… – not your diesel source"). The web's help taken again (`assets/help/web_help.json` – also the help rules of
Mechanical updates 157, 158 and 161 that had not been taken yet; `test/fixtures/help/web_fix.json` from the web's own rules).

**Version 3.42.0 (26-10-2026 – "mala app war pratek gostich realtime notification jayla haw app band aso ki chalu app updet pasun te
sagle kahi"):** the notifications come AT ONCE through Google Firebase (FCM), whether the app is open or closed (Android): a call –
its ringtone with **Answer** (the app opens at the call's site and answers) and **Decline** (said to the caller); answered on another
device – the ring stops; a missed call; verification and approvals (waiting for you, the next level, approved / rejected, sent back,
answered, sent again, a reminder – pressed: Approvals at that site); and every phone with the app is told **"RCL ERP <version> is
ready"** when a version is released (the topic `rcl-app-update` – `release.yml` → `tool/fcm_topic.sh`, the GitHub secret
`FCM_SERVICE_ACCOUNT_JSON`). Shown in the app's language. `core/push.dart` (what each message shows – tested without the plugins;
the phone given to Mechanical at a site once a day – `fcmSave`, Mechanical update-161 keeps it at the first site so every site
reaches it; taken off FIRST at Sign out – `fcmOff`), `core/push_fcm.dart` (Firebase: start, the open app's messages, pressed
notifications), `main.dart` (`pushInBackground`, `pushActionInBackground` – the app closed), `alerts.dart` (the call / missed /
update channels; an approval uses the SAME number as the 15-minute check, which stays – one thing is never told twice). A pressed
notification waits in `ScanLink` like a QR code: after the sign-in, the fingerprint, at its site (another of his sites opened by
itself). While the app is open: the open site's ring on the app's own ring screen (asked at once), a new version on Home's Update.
Firebase's settings (`android/app/google-services.json`) are written by the build from the GitHub secret `GOOGLE_SERVICES_JSON`
(never in git – `.gitignore`); without them the app is built as before (the Gradle plugin `com.google.gms.google-services` 4.5.0 is
applied only when the file is there); a release checks the file is for `in.rachana.rcl.rcl_mobile` and that the APK carries it.
`USE_FULL_SCREEN_INTENT` (the ring on a locked phone). iPhone: not yet (needs the Apple account's push key).

**Version 3.41.0 (25-10-2026 – "google scanner mobile scanner madhun jari scann kel adhi app kade jaw app nasel tr browser kade ok
ani complete process zal shiway madhech cut hou naye"):** the QR code of "Scan with Mobile" (Log Book attachments on the computer,
Mechanical update-160: `…/scan?cap=<code>&site=<site>`) opens in THIS app whoever reads it – the phone's camera, Google Lens or the
app's own Scan; without the app on the phone it opens in the browser, as before. Android App Links: `AndroidManifest.xml` (an
`autoVerify` intent filter for `https://oneclicksolution-erp.vercel.app/scan`, Flutter's own deep links off – also in
`tool/patch_platforms.py`) with the web's `/.well-known/assetlinks.json` (this app's package and its signing fingerprint); the
links are read with `app_links` (`main.dart`: the link the app was opened with and every later one). `core/scan_link.dart` keeps
the code until it can be opened and `screens/scan_link_layer.dart` opens it over every screen: after the sign-in (signed out),
after the fingerprint (locked), at the QR code's site – another of HIS sites is opened by itself (the screens of the site before
are closed), a site not given to him is said – then the photos screen (`CaptureScreen`, the server checks the person, the site
and the code as before). The same link twice is opened once. Not cut midway: the app's own camera, gallery and file box (entry
photos, Scan with Mobile, the plate, a photo in a call's chat, an Excel file, his photo – `AppLock.whileOutside`) are not "away" – the lock asks again only after 10 minutes there (1 minute for another app).
iPhone: the link opens in the browser for now (Universal Links need the Apple team – not done).

**Version 3.40.0 (25-10-2026 – the app icon, "1 banaw"):** the app's icon is option 1 of the six shown – the navy of the approved
design (#0B3A66 → #022646 → #06111C) with the white rounded tile and the red / dark R in its middle (as on the start screen); the old
green fuel-pump icon is gone. The R is traced from the logo picture into sharp shapes and drawn at every size. Android: the legacy
icons (`mipmap-*/ic_launcher.png`, rounded), the adaptive icon's front (`drawable-*/ic_launcher_foreground.png`, the tile and the R) on
a navy gradient (`drawable/ic_launcher_background_navy.xml`, `mipmap-anydpi-v26/ic_launcher.xml`); iPhone: every size of
`AppIcon.appiconset` (square, no see-through – iOS rounds it). The sources for `flutter_launcher_icons`: `assets/icon/icon.png`,
`icon_fg.png`, `icon_bg.png` (not in the app's assets).

**Version 3.39.0 (25-10-2026 – "aple app madhe new screen ali aahe tri pn old screen diste … old screen purn pn remove kr"):** the
old green screen is gone. **The app lock** (the fingerprint / face / PIN not given, or wrong) and **"No connection"** are on the
approved design of the opening (`screens/splash.dart`: `SplashScene` – the navy, the PQC road, the mark and RCL ERP at the top – with
their own card at the bottom: `SplashPanel`, the red `SplashButton`); what they do is as before (Unlock asks the phone again, the
phone's answer shown in the card; Try again). **Which site** is on the navy of the design (`SplashBackdrop`). The old moving green
background (`Backdrop` in `ui/brand.dart`) is removed. On a screen too short for both (a phone held across) the words at the top give
way and the card scrolls – its button always on the screen. **Faster opening** ("app opening slow zal aahe new screen ale pasun …
ultra fast"): (1) with the sign-in kept on the phone, the Portal's "is he still signed in" and the kept site's first lists (getInit)
are asked **at the same time** (`Session.start`, `Api.callOnce`) – one wait instead of two; the site's answer is used only when the
Portal says he still has that site at that address (else dropped, asked the normal way; a refused one is asked again with the
renewal); the language is read meanwhile; (2) the still part of the opening screen is drawn **once** (a `RepaintBoundary`) – only the
bar is drawn again while it moves; the photo's fade is in the picture itself (its own alpha, `pqc_road.webp`), no mask on every frame;
(3) the kept site and the site's address are written to the phone's safe only when they change. Tests: `splash_test.dart` (the card
on 4 sizes), `session_test.dart` (asked at once; signed out → dropped; a site no longer given → Which site; a refused answer → asked
again); pictures `58_lock.png`, `0_no_network.png`, `2_sites.png`.

**Version 3.38.0 (25-10-2026, with Mechanical's update-159 – asked at 18B: "/ nko … jyach tyach seprate ale gel transfer"; "jo
stock point asel tithun transfer asel trch"):** with one stock point chosen, Dashboard → Day-wise diesel stock and its stock cards,
and Reports → Daily Inward & Issue show a **"Received from" and a "Sent to" column (line) for EACH other stock point** – never
"A / B" together (at 18B: CAMP PUMP, DISPENSER - MH12ZE-1739, DISPENSER - MH12WJ-1381); every column always, 0 when nothing moved.
The server's answer carries `tinBy` / `toutBy` (Ltr by the other stock point) and `others`; `tin` / `tout` stay the totals (an older
answer: the site's places, 0). VTR (two places) reads as before. The Transfer list's filter is **"From (stock point)"**: only the
transfers sent FROM it (the server's `getTransfers`, and the day list of the Transfer page). `core/dash.dart` (`peersOf`, `byPeer`,
`locationCards`, `ledgerTable`, `ledgerHelp`), `core/report_defs.dart` (`kDailyReport`), `screens/entries.dart`,
`screens/entry_more.dart`; tests in `dash_test.dart`, `reports_test.dart`.

**Version 3.37.0 (25-10-2026 – the approved "RCL ERP Premium Splash Screen"):** the app's first screen (while the kept sign-in is
checked and the site is opened) is the approved design – dark navy, the photo of the PQC road (finished concrete on the left, the
paving on the right), the Rachana mark on its white tile, **RCL ERP** (RCL red, ERP white) with its red line, INTEGRATED
CONSTRUCTION MANAGEMENT, and at the bottom "Preparing your workspace..." with its bar. The bar is the **real** opening
(`Session.boot`: the kept sign-in read 15 %, the sites from the Portal 40 %, the site opened 50 %, its sign-in 70 %, its lists 100 % –
100 % only when the app is open), moving smoothly between the steps (at once with "less motion"). The logo, the words and the bar
are drawn by the app (sharp on every screen); only the road is a picture (`assets/splash/pqc_road.webp`, 852 × 990, 196 KB, shown
as soon as it is read – the screen never waits for it). Sizes follow the design's width, so a small phone, a large one and a tablet look
the same, clear of the status bar and the navigation bar. The phone's own launch moment is the same navy
(Android `launch_background`, Android 12+ `values-v31` without an icon, iPhone `LaunchScreen`), so no white or green flash. Fonts:
Montserrat 400 / 800 (Latin letters only, OFL). Nothing of the sign-in, the access, the screens after it or the servers changes.
`screens/splash.dart`, `core/session.dart` (`boot`), `main.dart` (`Gate`); tests in `splash_test.dart` (the steps, the figure, every
screen size; pictures `00_splash*.png`). **No Windows app any more** (asked 25-10-2026: "app fkt android ios sathi"): the
Windows jobs of `build.yml` and `release.yml` are switched off (`if: false`) – a release is Android only; computers use the web ERP.

**Version 3.36.0 (24-10-2026, with Mechanical's update-156 – "Concurrent Updates साठी Version Checks आणि Conflict Detection"):**
every edit screen sends the version of the entry it opened, as the web page does – Diesel Issue (since update-145) and now Inward,
Transfer, Payments, Asset Master (one, many at once, delete, delete many), Vendor BOQ (change, delete) and Vendor Master (change,
delete): an entry someone else changed after it was opened is refused with who changed it; nothing is saved (`forms.dart`,
`entries.dart`, `bill_money.dart`, `machine_form.dart`, `machinery.dart`, `boq.dart`, `vendors.dart`; test `version156_test.dart`).

**Version 3.35.0 (24-10-2026, with Mechanical's update-155 – "Smart Cache … Smart Data Sync … User B ला सक्रिय Screen वर शक्यतो 2
सेकंदांत Update … API Calls आणि Egress कमी करणे"):** the app keeps the last answer of each question **in memory only** (never on the
phone's storage) with its fingerprint; asked again, the server answers "the same" (a few bytes), only the parts that changed, or the
whole answer – the app rebuilds it and checks it against the server's SHA-256, and asks whole again on any mismatch (`core/answers.dart`,
the same pieces and patch as the web page's; `Api._rpc`). Emptied at sign-out, at another site and at a new sign-in; a refusal drops
it. **Live sync as the web:** Home and Entries every 2 seconds (was 15), Reports and Me every 5, after 5 minutes without a touch every
15, nothing in the background and at once when the app comes back, a tab is chosen or the screen is touched after a quiet spell
(`Session.liveGap`, `touch`, `showing`). **A tab that is not seen does not load:** Home and Entries load after others' changes only
when they are on the screen (and only for what they show) – else the moment they are seen again (`ui/live.dart`, `appRoutes`).
**What the screens keep** (a day's Entries and Log Book, the pending list – now kept per site) is emptied at sign-out and at
another site (`Session.memoryClears`). **No answer at all:** a question and a numbered save are sent again (as before); a change
without a number only when the server said it did not start it (busy, another save running). **Android:** the 15-minute alarm does
not fetch the Approvals list while the app is open and asking (`live_at`). Tests: `answers_test.dart` (replays what Mechanical's own
`server/delta.js` answers – `test/fixtures/answers155.json`).

**Version 3.34.0 (24-10-2026, with Mechanical's update-153 – "Universal Smart Attachment … PDFs supported … multi-entry linking, no
duplicate uploads … up to 10 per entry (configurable)" and the photo correction):** a Log Book entry (new or changed) has
**Attachments – photos or PDF**: 📷 Camera, 🖼 Gallery, 📄 PDF; each photo is made ready on the phone (upright, at most 1600 px, a JPEG
of a few hundred KB) and ✎ corrects it before it is sent – ⟲ ⟳, straighten, the four corners (a cut, or a photo taken at an angle
made straight), ✂ a suggested cut of the paper (shown – used on "Use this"), Whole photo, Reset, Original quality, Use the original
file. Only one copy of a photo is ever sent; the same file twice in one entry is refused. The files are sent when the entry is saved
(`uploadAttachment` – the server keeps each file once under its SHA-256) and the entry keeps their fingerprints; a change sends the
whole list with what it had when opened (`attWas` – changed by someone else meanwhile → refused, nothing lost). The entry card shows
📎 n and its details open the files. **Scan with Mobile:** the web's QR code read by the app's scanner opens the capture screen –
the same person, the same site – and the photos taken there show on the computer, which saves them with the entry (`capClaim`,
`capAdd`). **Bills:** View / Print of a saved bill ends with the annex of its Log Book's files AS SUBMITTED (each file once, with its
entries and fingerprint); RCL Drive → **Files**: one ZIP of them, each checked against its SHA-256, with `FINGERPRINTS.txt`.
Administration → Rules of this site: the number of attachments of one entry (1 to 20, 10 unless set). `core/attach.dart`,
`screens/attach_box.dart` (`AttachStrip`, `AttViewer`, `AttEditor`, `CaptureScreen`), `logbook.dart`, `label_scan.dart`,
`bill.dart` (`billAttHtml`), `bill_print.dart` (`billFilesZip`), `bill_drive.dart`, `admin.dart`, the print style `.bill-att`; tests in
`attach_test.dart` and `screens_test.dart`.

**Version 3.33.0 (24-10-2026, with Mechanical's update-152 – "Once a Logbook Entry has been approved, or it is included in a submitted
Machinery Bill: ONLY SUPER ADMIN CAN …"):** an entry approved in verification is marked **✔ Approved** (Log Book list, its details, Edit
Log Book) and locked like a billed one: anybody else's change or delete is refused by the server and offered to the Super Admin
("An approved entry – send it to the Super Admin?", with the reason); Edit Log Book shows it read-only. **The Super Admin's** save of
a locked entry (approved or billed) asks **"Locked entry – give the reason"** (the server's SA_REASON) and goes again with it, as a
new save – the reason is kept with the entry's history. **Bills:** only the Super Admin has Delete (RCL Drive); a deleted bill is
kept, shown **Deleted** (who, when, why; "DELETED" across its papers) and its entries stay locked. `api.dart` (`crApproved`,
`saReason`, `askReason`, the reason sent as the 4th part of the call), `main.dart` (`askReasonBox`), `log_edit.dart` (`apLock`, the
lock texts as the web's), `logbook.dart`, `entries.dart`, `bill_drive.dart`, `bill_print.dart`, the print style `.deleted`; tests in
`session_test.dart`, `log_edit_test.dart`.

**Version 3.32.0 (24-10-2026, with Mechanical's update-151 – "bill final zalyawar nantar kuni logbook photo badalla tari june bill
badalta kama naye, karan te arthik purawa asto"):** a saved bill's Log Book is shown **as it was submitted** – the evidence the
server kept with the bill (its entries, its machinery as it was, its BOQ / diesel / rates and Idle choice), never the Log Book of
today: RCL Drive → View / Print and Log Book, Bill Summary, the Vendor Ledger and the print after Submit. On top: "Log Book as
submitted with RA Bill … Evidence check ✔" (or "EVIDENCE CHECK FAILED … Tell the Super Admin"); the Log Book print of such a bill
asks no diesel rate (the bill's own). A bill submitted before has no evidence: its Log Book is today's, and the paper says so, with
how many entries changed after it was saved. `bill.dart` (`evNoteHtml`), `bill_print.dart` (`SavedLog`, `savedBillLog`,
`savedBillLogSheets`), `log_print.dart` (`printLogBook`: `fixed`, `machines`, `note`), `lb_print.dart` (`note`), the print style
`.ev-note`; tests in `bill_test.dart` (the web's own note texts as the fixture `test/fixtures/bill/web_ev_notes.json`) and
`log_edit_test.dart`.

**Version 3.31.8 (24-10-2026, with Mechanical's update-150 – "asset sathi qr … owner wise machine wise sigle or bulk mdhe print kru
shako a4 page war multiple jastit jast 6 to 8 qr"; his answer: 8, 2 × 4):** Asset Master ⋮ → **QR labels** chooses which labels:
an **Owner** (all its machinery ticked), **Find**, a ticked list (**Tick all shown** / **Untick all shown**; one machinery or many,
of any owners), "n ticked – p pages"; **8 labels on an A4 page (2 × 4)** – the code bigger (50 mm) on the left, the customer, the
number and name · type on its right – exactly the web's sheet. `machinery.dart` (`_QrPick`), `more_imports.dart`
(`qrLabelsHtml`, `kQrPerPage`, `qrSub`); tests in `more_imports_test.dart` (the web's own sheet as the fixture
`test/fixtures/qr/web_labels150.json`), `screens_test.dart`.

**Version 3.31.7 (24-10-2026, with Mechanical's update-149 – "log book mdhun ekadi entry debit to keli jate tr tyach wegle record
rahaw … filter import export print rate change … app mdhe"):** Reports → Financial → **Log Book Debit Statement**: the Log Book
entries charged to a party ("Debit to") – a summary, one line per party, then every entry party by party (date, shift, machinery,
measured by, quantity, work, its Debit Note, rate, amount); filters: dates, a party, one machinery (blank = all). **Change rates**:
the rate of one entry, or "Rate for all shown" → "Put on all shown", then save (an entry in a Debit Note keeps its rate). **Import
party + rate (Excel)**: Date, Shift, Machinery, Debit to, Rate – each line is a saved entry (a blank Debit to keeps its party).
Both ask first and go to the server's `saveLogDebits` (all or nothing, every check of a Log Book change); Excel and Print as every
report. Log Book View access: the statement only. `report_defs.dart` (`ldebit`), `report_screen.dart` (`_ldRates`, `_ldImport`,
`ldImportRows`, `kLdCols`), `home.dart`; tests in `reports_test.dart`, `screens_test.dart`.

**Version 3.31.6 (24-10-2026, with Mechanical's update-148 – "details mdhe attachment disayla haw"):** Approvals → Details shows the
entry's **photos / bill copies themselves** (small; pressed – full size, as the photos of a saved fill), named (Dashboard, Dispenser
litres, Bill copy …) – no longer a table of their file names. `approval_details.dart` (`_Pic`); test in `screens_test.dart`.

**Version 3.31.5 (23-10-2026, with Mechanical's update-147 – "approval detna details madhe sagle bghta yaw ki entry mdhe ky ahe fkt
diesel nhi sagle approval mdhe … bulk approval asel tri"):** Approvals – **"Details"** on every request opens the entry in full
under its card (the server's `approvalDetails`: who sent it and what it does, every field with its name, its rows as a table that
scrolls sideways, the machinery with its name, photos / bill copies counted, for a change of a saved entry what is saved now);
**"Details of all"** opens every one; several ticked → **each one in full** in the question before Approve / Send back / Reject.
Asked once per version of the request (decided or corrected → asked again). Only reads – the server decides who may see it.
`lib/screens/approval_details.dart`, `approvals.dart`; test in `screens_test.dart` (fake server `approvalDetails`).

**Version 3.31.4 (23-10-2026, "app madhun baher al ki updet hoych band hot nantr app prt chalu krun prt sagle 0 pasun start hot tr as nko
… background la app updet chaluch asel ani complte al ki konte hi screen war aso mi install karaychi as ek pop up eil"):** Android –
Update hands the download to **Android's own Download Manager** (`android/…/UpdateKit.kt`, channel `rcl/update`): it goes on when
the app is left or closed and after the network comes back; pressed again while it goes, it is **not started again from 0**. Its
progress is in the phone's notifications and in the box "Updating" (it may be closed – "Keep working"). When it is there and its
fingerprint (SHA-256) is the release's: **"Update … is ready – Install?" over whatever screen of the app is open**; the app away:
the notification "update ready – tap to install" (`UpdateDoneReceiver`) opens the app, which asks. "Later": asked again when the
app is opened again. Installed: its file goes. A phone whose Download Manager cannot be used: the download inside the app, as
before. `lib/core/update.dart` (`startBgUpdate`, `updateWatch`; `main.dart` – when the app opens and comes back);
`test/update_bg_test.dart`. The file path `external-files-path` (filepaths.xml), the receiver in the manifest
(`tool/patch_platforms.py` the same). The Windows app and the iPhone: as before.

**Version 3.31.3 (23-10-2026, "jewa user landscap madhe rotate krto tewa pn ha box rotate hoyla hawa … fkt box ha rotate hoyla
hawa"):** the live reading of a photo (Dashboard, Hour meter, Dispenser litres – `lib/screens/scan.dart`) with the phone held
**sideways**: the screen stays upright on the phone (as a camera app's), the **box turns with the phone** and lies across the
meter as the person sees it (as wide as the long side); the digits are read the way they stand; the photo is kept as the person
saw it (turned upright before its band). How the phone is held comes from its accelerometer (`sensors_plus`; flat or between two
ways the box stays as it was); the rules and their tests: `lib/core/scan_rules.dart` (`turnOf`, `guideFor`, `guideOnScreen`,
`readTurn`, `uprightTurn`), `test/scan_rules_test.dart`. Upright: exactly as before. iPhone: `NSMotionUsageDescription` in
`Info.plist`. No server change.

**Version 3.31.2 (23-10-2026, with Mechanical update-143 – "1 day madhe multiple entry ghet nahi … multiple entry hou de; jar same data
bharat asel tr te duplicate hoil ani jr same data nasel tr duplicate honar nahi"):** a new Log Book entry for a date and shift that
is **already saved** is no longer refused – the server adds it to that entry as its next work (`lib/screens/logbook.dart`, `addTo`
of getLogRowPrefill). The form says so ("This day is already saved – this entry is added to it as work 2"); its Start is the saved
Close; the diesel of the shift is shown as already on the saved entry; no ½ day and no Split on such a work (one work per row); the
same work as the saved last one is refused on a machinery that is not on hours only. The same work twice is refused by the server
("already in the saved entry of this shift"). The assistant says it too. The prefill is asked with `{add: 1}` and such a row is
sent with `add: 1`: the server adds only rows so marked (an older app is refused as before). The web's help
(`assets/help/web_help.json`) taken again from the web page (`tool/web_help.js`), with its fixture
(`test/fixtures/help/web_fix.json`); the assistant's fixture (`test/fixtures/ai/web_ai.json`) made again from update-143's page –
the only change is `{add: 1}` on its 27 prefill calls. **With Mechanical update-144** ("ase error nko n yeyla" – his JCB in Edit
Log Book: Bucket by Time 14:00 – 18:00, "+ work in this shift" Breaker by Time 09:00 – 13:00): Edit Log Book (`lib/core/log_edit.dart`)
no longer says "the rows of this shift are all by Time" for a machinery on hours – the shift is sent as ONE entry by Time, its times
the rows' times in the order of the shift (`timeSpans`), its rows in that order; two rows at the same time are red ("is at the same
time as row N … a machinery does one work at a time"). The web's help taken again (+1 rule).

**Version 3.31.1 (20-10-2026, "AIK N OK AHE SAGLE FKT COLOUR THODE DIM DISAT AAHE APP THODI ENHANCE KR"):** the same colours a
little brighter and fuller (`lib/ui/theme.dart`): the greens and the gold stronger, the cream page lighter, the soft tiles
fuller, the grey words darker; gold words (View All, Forgot password?) in a deeper gold that is easy to read; the green of the
opening, lock and site screens the same family. Nothing else changes.

**Version 3.31.0 (20-10-2026, with his picture of the five screens and his two photos: "HE BGH SAME AS IT IS HAW AAHE MALA SAME"
– "TAS DARK EKDAM NKO"):** **the new look** of every screen.
* Colours (`lib/ui/theme.dart`): a forest green that is not too dark, a warm cream page, gold for the + and the links; every chip the
  same pill. One spacing for every screen (`Sp`): the page's edge 16, a name and its box 8, one part and the next 16, chips 10 –
  the Marathi word on the same line as the English one; a thin line under a page's bar when the page goes under it.
* **Sign in**: his photo (an excavator under the bridge) with the Rachana logo, RCL ERP and English / मराठी / हिंदी; Welcome Back,
  the email and the password, Remember me (the email kept on this phone), Forgot password?, "Build • Manage • Move Forward".
* **Home**: ≡ (every module he may open, Call, Approvals, My settings, Help & Support), RCL ERP, search, the bell (approvals, missed
  calls, entries kept on the phone, a new version), the robot; his photo (an excavator loading a tipper) with "Good Morning,
  Sujit 👋"; the site and Scan; the green stock card – the change since the start of the day (the Dashboard's opening) and the
  stock of each place in one bar; the four tiles; Modules (View All); no Rachana logo at the bottom any more.
* **The bar at the bottom**: green and rounded, the chosen tab in a pill (Reports gold), the gold **+** – a new entry (Diesel Issue,
  Inward, Transfer, Log Book entry, a tanker trip, Breakdown, Store – only the ones he may add).
* **Back**: one step back, to where he came from – a diesel page goes back to the Entries list; the tab he came from; on Home a
  second Back leaves the app.
* **The robot (Ask)** at the top right of every page (the red dot of the daily summary on it).
* **Your Entries**: All · Diesel · Machinery · Log Book · Store; each page a card with what it is for (Breakdown, Tanker Trips and
  Store there too).
* **Reports**: This Month / Last Month; Overview – Diesel Consumed (issued), Diesel Cost (the inward bills), Machinery Running
  (machinery that worked), Breakdowns (begun), each against the same number of days just before; the diesel issued in the last 7
  months; Quick Reports. Diesel · Machinery · Financial – his reports. The server's own answers (getDashboard, logDashboard,
  getBreakdowns) – nothing new on the server.
* **Me**: the green top with his photo (✏️ – My settings) and the robot, RCL ERP and his role; App Version; My Settings; Approvals;
  Help & Support (ask the app, the guides of the pages); Sign out.
* **A half-filled entry kept** (`lib/core/draft.dart`): what is typed in a new Diesel Issue / Inward / Transfer or a new Log Book
  entry stays on the phone; the form opened again brings it back ("Half-filled entry brought back" – Start new). Saved, kept for
  the network or sent for verification: gone.

**Version 3.30.0 (20-10-2026, with his photo of a dashboard "7087.0" that 3.29.0 read as 70820: "HE BGH AS HOTE BARYA PAIKI FAST
AAHE HE BUT AJUN PN PERFECT NAHI"):** **the seven-segment reader** (`lib/core/seven.dart`). An LED / LCD display's digits are read
by their 7 segments and its decimal point. ML Kit only finds where the number is and counts its digits; it reads such digits badly
(a "7." became a "2") and loses the point.
* How the reader works:
  * a few thresholds (also the one between a glowing LED's core and its glow) and a few slants (italic digits);
  * a tilted picture is straightened;
  * a digit counts only when its segments are clearly on or off – printed digits are not taken, ML Kit's reading stays;
  * the reading most of those looks agree on, with ML Kit's count of digits, is the one taken.
* Where it is used: in the live reading (in the background, every look) and on a photo read afterwards.
* A clear segment reading counts as sure: 2 agreeing looks take the photo.
* A reading with a point also fits a machinery whose records were always kept without it (7087.0 → 70870).

**Version 3.29.0 (20-10-2026: "ocr kadhi kadhi kam krte tr kadhi kadhi krt nahi kadhi kahi chukich reading ghete … point nantrch
number show nahi kt dispeser litre cha photo ghetla ki te pn auto ani perfect yet nahiye he sagle adchani fix kr ani ha jya gadich 2
engine yet tith 2 reading takayla lahtat ek km ani ek hrs tr ase 2 photo weg wegle gheta yawet"):**
* **The live reading** (`lib/screens/scan.dart`, its rules in `lib/core/scan_rules.dart`). The Dashboard, Hour meter and Dispenser
  litres photos are taken with the app's own camera:
  * a box on the screen – only the text inside it is read;
  * the phone reads about three times a second; every other look is on a softer copy, so the segments of LED / LCD digits join;
  * the reading is shown big as it is read;
  * the photo is taken **by itself** when the same number was seen again and again – twice when it fits the last reading or
    litres × rate = amount agreed, else three times. One wrong look is never taken;
  * the round button takes the photo at any time; the light is for a dark cabin or the night;
  * the phone's camera app is used as before when the camera cannot be opened in the app.
* **The rules** (`lib/core/ocr_read.dart`):
  * the digit after the point is kept, also when the reader gives it apart (45173.4, not 45173);
  * digits read apart (45 173) or as letters (D, Q → 0; G, b → 6; g, q → 9; T → 7);
  * a dispenser's points not seen (472500 / 5000 / 9450 → ₹ 4725.00 = 50.00 L × ₹ 94.50 – two decimals as a display shows);
  * a tanker bill in KL read as it is.
* **The Hour meter photo** (with Mechanical update-139): a machinery measured by **KM and Hrs** has a 5th photo. The Dashboard photo
  gives the KM, the Hour meter photo gives the Hrs. A machinery with one reading keeps the 4 photos.

**Version 3.28.0 (20-10-2026: "ata aplela app madhe ocr jodaych aahe mhanje google gemini api nahi ani te ocr khup fast asawi";
his choices: the Diesel Issue photos and the Diesel Inward bill; the web keeps its Gemini):** **the phone reads the photos itself**
(Google ML Kit text recognition, on the phone – no internet, nothing paid, no Gemini; `lib/core/ocr.dart`, the rules in
`lib/core/ocr_read.dart`):
* **Diesel Issue – Dashboard photo → KM / Hrs:** the number that fits the machinery's last reading (not below it, not more than it
  can run since then – the server's own rule); the tenth digit in another colour is understood. No last reading: one clear long
  number only. **Dispenser photo → Litres:** litres × rate = amount picks the litres; else the number by Litre / Volume / Qty.
* **Diesel Inward – bill copy (camera or gallery) → Bill No., Litres, Rate** (litres × rate = amount; a tanker's KL and ₹ per KL
  become litres). A line under the copies says what was read.
* Only empty boxes are filled (or ones the phone filled); a filled box is blue – "check it"; a number that does not fit is not
  put. The computer app (Windows) has no such reader: there the Diesel Issue photos are read by the server's AI, as on the web.

**Version 3.27.0 (20-10-2026: "ॲप उघडायला Fingerprint / Face lock … KR PERFECT"; his choices: for everyone, on by itself, asked
again after a minute away):** **the app lock** (`lib/core/applock.dart`, `lib/core/lock_gate.dart`, `lib/screens/lock.dart`):
* The app opens with a kept sign-in → **"RCL ERP is locked"** and the phone's own box at once: **fingerprint / face – or the phone's
  PIN / pattern** (Android BiometricPrompt; iPhone Face ID / Touch ID; the computer app Windows Hello). Nothing of the ERP is seen
  before. Not him / cancelled → still locked, **Unlock** asks again.
* **More than a minute away** (another app, the screen off) → locked again when the app comes back (also over a call's green bar;
  the call itself goes on). A password typed just now is not asked again. It cannot be switched off.
* A phone with **no screen lock** at all is not stopped (the work at the sites goes on): a red line asks to set a PIN / pattern /
  fingerprint. The fingerprint / face never leaves the phone – nothing goes to the server.
* Android 7 or newer (local_auth); the app's Android window is a FragmentActivity with the AppCompat themes.

**Version 3.26.0 (19-10-2026, with Mechanical update-137: "JR SAMAJ EK USER APP WAR AAHE ANI EK USER WEB WAR TRI SUDHA CONNECT HOYLA HAW
TE PN PROPER" – "SAGLE KAHI KARTA YAW", Android first):** **calls between the app and the web** (the web's screen share, spoken by the
app – the same server actions rtcUsers / rtcSend / rtcMissed / rtcWa and the heartbeat "sync" {r}; `lib/core/rtc.dart`):
* **Home → the call button** (a number on it = missed calls): who is at the app now (as the web's list), missed calls with **Call
  back**; **Voice call · Video call · My screen** → **Call** (one person; the web joins the app's call, the app joins a web call of up
  to 3).
* **A call comes in** (from the web or another phone, while the app is open): its own screen over the app, the phone's ringtone –
  **Accept · Decline · Reply** (the web's three short replies). Answered on his other device → it stops here.
* **The call:** the other's screen or back camera big (pinch to zoom), the faces in a row (his and mine – "You"), the time and the way
  (direct / relay), the page he is on; **Mute · Camera** (front / back, light) **· Screen** (the phone's own screen – Android asks
  "Start now") **· Chat** (text and photos) **· More** (speaker / earpiece, low data) **· End**. **Back keeps the call on** – a green bar
  on top of the app goes back to it; the notification "Call is on" keeps the voice (and the screen) going while another app is open.
* The pictures as on the web (update-136): a screen sharp, a camera smooth, the voice first; low data by itself on a poor network.
* Not yet: the ring while the app is closed (Firebase – the next step); the iPhone and the computer app have no calls yet.

**Version 3.25.0 (19-10-2026, with Mechanical update-134: "super admin user ni kelelI konti hi entry mg ti save aso approval
madhe aso ki retuen aso ki reject aso konti hi entry delet kru shakel … single date or ya period wise"):**
* **Diesel Issue ⋮ → Delete entries – Super Admin** (the Super Admin only): a date or From – To, who entered it, a machinery → the
  saved entries and the ones waiting for verification / returned / rejected, each with a tick → **Delete ticked** (all together or
  none; one of a submitted RA Bill or a closed month cannot be ticked – it says why). **Deleted entries** are kept whole → **Bring
  back ticked** (the same entry, its ID; checked again). The same server actions as the web (superDelList / superDelete /
  superRestore).

**Version 3.24.0 (19-10-2026, with Mechanical update-133: "jewa app la update detos n tya madhe kay new ale he 3 language madhe
dakhaw … next time update pasun", "je boq bantat je amendment bante tya warti work order number date he sagle yeu de … proper
amendment watayla haw"):**
* **The update question shows what is new** in the update in English, मराठी and हिंदी (the release's notes between
  `<!-- rcl-new -->` and `<!-- /rcl-new -->`, written by the release; shown as written, whatever language is chosen). A phone still
  on 3.23.0 shows only the name for the update to 3.24.0 – from 3.24.0 on, every update says what is new.
* **Vendor BOQ → Print:** the work order number and date on top. **An amendment prints as an amendment letter**: To the vendor
  (address, contact), Subject, Reference (the work order of the BOQ), "with effect from", Annexure-I with each machinery's earlier
  rate (till the day before) and the new rate, the vendor's details, all versions, "For and on behalf of …", accepted by the vendor.

**Version 3.23.0 (19-10-2026, with Mechanical update-132: "mala disayla haw old kay hot nantr amendment zali kadhi … boq period wise
ani vehicle wise"):**
* **Vendor BOQ → a vendor → "Rate history – machinery-wise":** for each machinery, period by period (from – to), the rate, which
  BOQ or amendment gave it (with the work order), and what changed ("Changed – was …"); the old rate ends the day before an
  amendment starts – exactly the rates the bills take.
* **Make amendment** from any date on or after the BOQ start – also after the BOQ ends (that machinery goes on at the new rate; the
  others stay as they are). Keep only the machinery whose rate changes.

**Version 3.22.1 (19-10-2026, with Mechanical update-131: "send any way he option nko aahe chukicha data approval sathi gelach nahi
pahije … user correct krel tya nantr … send hou shakel"):**
* **No "Send again anyway":** an entry going for approval with a reading that does not fit is a mistake – said in full (the row,
  the fill before or after it and its date); it is corrected first ("Open & correct"), then sent. Nothing wrong goes for approval.

**Version 3.22.0 (19-10-2026, with Mechanical update-130: "jy entry pathwale hote te mala open krun edit pn krta yaw kay kuth
chukley te pn samjayla haw"):**
* **Open & correct:** his own Rejected or Returned **Diesel Issue** entry (One entry, Multiple entries by date or by machinery)
  opens in the app's own form it was made in, as it was sent: on top why it came back and what is wrong now; the wrong rows
  marked with the reason. He corrects it and presses **Send again (VF-…)**: he writes what he corrected; it goes to
  verification again – the same request, from level 1 – and is saved when approved. Still wrong: marked again, nothing sent.
  The photos sent with one entry stay with it. **Stop correcting** leaves it as it was. "Send again" (as it was) stays too.
* **Approvals:** a corrected entry shows **Corrected by …** with what changed (before → after); its steps list the changes.

**Version 3.21.1 (19-10-2026, with Mechanical update-128: "ata user prt tya entry krt basnar nahi … jyana return zaley tith tyana
option asel send to approval or verification data loss nko"):**
* **Send again:** an entry of his that was Rejected, or Returned (approved, but the save refused it), shows why it was not saved
  and a **Send again** button (in "My entries in verification" and in Approvals); **Send all again (n)** sends all of them. He
  writes why; the entry goes to verification again exactly as it was sent (the same lines and photos), from level 1 – nothing is
  typed again. Mechanical checks it as a save first: one that would be refused again is told and stays as it is (nothing lost).
* **Warnings, not mistakes** (with Mechanical update-129): when the save only has warnings (e.g. a KM / Hrs reading lower than
  the last one), they are listed – "Please check – warnings, not mistakes" – and **Send again anyway** sends the entry with them
  confirmed (as "Save anyway" on the web); Cancel changes nothing. A mistake is said in full and is never passed.

**Version 3.21.0 (19-10-2026, with Mechanical update-126: "dashbord war opening closing received je numbers … kuth hi click kel ki
tyanchi entryies open hotil ek mast motha dialogbox … fkt show hotil"):**
* **Every number of the Diesel dashboard can be tapped:** Opening stock, Received, Issued, Closing stock, Stock now, Issued
  today, Machines fuelled, Issue entries, Average per entry. A tap opens a big sheet with the entries behind that number. It is
  only shown; nothing can be changed there. The big number on the sheet is the number on the card.
  * Opening / Closing stock: each diesel place, with Opening + Received + From another place − Sent − Issued = Closing.
  * Stock now: each place, with its tank size and how full it is.
  * Received: the Diesel Inward entries of the dates. An opening stock entered on or before the start date is part of the
    opening, as the server counts it.
  * Issued / Issue entries / Average: the Diesel Issue entries of the dates. Issued today: today's entries. Machines fuelled:
    machine by machine.
* The rules are in `numDetail` (`lib/core/dash.dart`), the same as the web's box (`kdBuild`). The sheet is `_numSheet` in
  `lib/screens/dashboard.dart`.
* The same server actions as the pages (getInwards, getDieselIssues), so the same access: a person without that page is told
  so in the sheet.

**Version 3.20.1 (18-10-2026, with the Portal's "a sign-in stays until Sign out": "app madhun pn auto log out nko aahe"):**
* **No sign-out by itself.** The Portal now keeps a sign-in until "Sign out" (no 6 hours, no 30 days). The app already renews
  its Mechanical and Store sign-ins from it by itself.
* **No network when the app opens, or while a site opens** (or the server is not reached – 502 / 503 / 504): before, the app
  showed the sign-in (the kept sign-in stayed, but it looked like a log-out). Now it shows **"No connection – you are still
  signed in"**. It tries again by itself every 10 seconds, and at once with **Try again** (`Stage.waiting`, `Session.tryAgain`,
  the `Waiting` screen in `lib/main.dart`).
* The sign-in screen shows only when the Portal says it does not know him any more: "Sign out", or the Super Admin switched him
  off or gave him a new password. That is as before.

**Version 3.20.0 (18-10-2026, with Mechanical update-124: "tax invoice war debit as nko … fkt month ani tya month chi
amount"):**
* **The party's Tax Invoice** of a bill made from now on (Make Bill marks it, `txNet`) shows:
  * each vehicle "FOR THE MONTH OF SEPTEMBER 2026" (or "FOR THE PERIOD …" when the bill is not one whole month);
  * its amount AFTER its own diesel debit;
  * no hours, days, rate or diesel line;
  * GST on that amount, and no TDS (that is on the Abstract).
* The Abstract, the Debit Note and every figure are as before.
* A bill made before (RCL Drive) keeps its papers exactly as they were.
* The web's own code (`txPeriod`, `taxInvoiceHtml`) is ported in `lib/core/bill.dart` and checked against it to the character:
  the new papers, and the papers of the same bills without the mark.

**Version 3.19.1 (17-10-2026: "android warti app updet krtana khup slow hote te speed up kr"; with Mechanical update-123):**
* **A smaller Android update.** The APK was 95 MB:
  * 18 MB were the emulators' part (x86_64) of ML Kit – of no use on a phone;
  * every phone also downloaded both the 32-bit and the 64-bit parts.
* Now the build keeps only the phones' processors (`ndk.abiFilters`), and the release also carries **one APK per processor**
  (`rcl-erp-<v>-<b>.arm64-v8a.apk` / `.armeabi-v7a.apk`, the same version code, their fingerprints in "apk").
* The app's update downloads **only its own** file (`appAbi`, `parseRelease`). The file for every phone stays for the first install
  and for the apps before 3.19.1: it is uploaded first and its name sorts first, so they take it as before.
* **Company & site** (Admin) no longer has the opening film's link and tick, as the web (Mechanical update-123: the film is gone).
  The values the server keeps go back unchanged.

**Version 3.19.0 (17-10-2026: "windows and ios app banaw direct app ya windows war chaltil browser open krnechi garaj nahi updet pn
in app ch yeil"):** **the Windows app** – the same app on a computer (Windows 10 / 11, 64-bit), no browser: the same sign-in,
screens, server actions, checks and access.
* **Install:** the file **RCL-ERP-Setup-<version>-<build>.exe** of the newest GitHub Release (next to the APK) – installed for the
  person signed in to Windows (no administrator), RCL ERP in the Start menu and on the Desktop. The setup is not signed with a
  code-signing certificate (none bought): the first time Windows says "Windows protected your PC" → **More info → Run anyway**.
* **Update from inside the app** (Me → Check Update, or the green bar on Home): the setup of the newest release is downloaded, its
  fingerprint (SHA-256, "win" in the release's data line) checked, then run – it closes the app, puts the new version in its
  place and opens it again; the sign-in and settings stay.
* **What a computer does differently:** no QR scanner and no number plate photo (the phone's live camera and ML Kit); a photo
  (the 4 of a Diesel Issue, a bill copy) is **chosen from a file** – as the web does on a computer – and gets the same band (date,
  time, place: the computer's location must be on, as for the web); a made file (Excel, CSV) is **saved in Downloads** and opened
  (as the web's download, "name (2).xlsx" when one is there); printing is the page's own (the computer's printers or "Save as
  PDF"); a list is also dragged with the mouse (and pulled down to refresh). The window opens tall like the phone's screen, in the
  middle of the screen; it can be made bigger, never smaller than a small phone.
* Built by GitHub Actions on Windows (job **windows** of build.yml: `flutter build windows`, the Visual C++ files next to the app,
  Inno Setup – `windows/installer.iss`, `tool/windows_setup.ps1`); the release builds it with the Android app and publishes both
  in the same release (if only the Windows part fails, Android is still released). `windows/` was made by `flutter create` and
  `tool/patch_platforms.py --windows` (name rcl_erp.exe, company and product, the window); the icon is the app's.
* **iPhone:** built on every push without signing (job **ios** – the check that it builds). Apple lets an iPhone app be installed
  and updated only through TestFlight / the App Store: that needs the company's (or the owner's) **Apple Developer account**
  (99 USD a year); then the build signs it and sends it to TestFlight, and the update comes through TestFlight by itself.

**Version 3.18.2 (17-10-2026):** the **QR scanner** of a machinery label (Home → the scan button) is the app's own live scanner –
the camera's picture with a square; a QR code in it is read at once, nothing to press (before, the phone's camera opened to take a
photo); the torch for a dark place; Back closes it. The code is read on the phone (mobile_scanner, ML Kit) – nothing is sent.

**Version 3.18.1 (17-10-2026, with Mechanical update-121):** the water tanker Excel (Edit Log Book → a tanker → Export / Import
Excel) is of **every water tanker of every agency**, not of the one open: Export – the trips of all of them in the dates, 100 empty
lines whose VEHICLE NO is picked from the list of tankers (a new tanker set to Format I is in it) and whose agency comes by itself,
Shift on every line; Import – each line its own VEHICLE NO (a line without one: "Fix the file first", nothing imported).

**Version 3.18.0 (17-10-2026, the last part of the whole web in the app):** **no web page anywhere in the app** – every page of
the web is the app's own screen. Gone: Me → "Full web ERP", the web view that loaded in the background at the start, and the web
page a module or a report fell back to (every module and every report has its own screen now). The only web view left prints
what the app made (a report, a bill, a Log Book page → PDF).

**Version 3.17.0 (17-10-2026, part 16 of the whole web in the app):** the Portal's **Super Admin** console in the app's own
screens (Me → **Super Admin**, for the Super Admin only) – the same Portal actions (`/api/admin`), checks and words:
**Users & Access** (one site at a time: every user with No access / User / Admin for each module; a user added with a one-time
password, switched off, given a new one-time password; his **pages** in Mechanical – Edit / View / No access, kept in Mechanical –
and in the Store), **Sites** (name, company, Active / Closed; **Diesel places** with the tank size and the stock now; **New site** –
the checklist the system works through until Ready: the key in Vercel, Mechanical's SQL copied, the Supabase links; a Closed site
deleted with its code typed again – its data stays in its own database), **Companies** (one no site belongs to can be deleted),
**Modules** (Live / Off and the link; one that is Off deleted with its key typed again – never Mechanical), **Activity** (the last
200). A Portal sign-in that ended goes back to the sign-in. His own password: My settings → Change password (as the Portal's "My
account").

**Version 3.16.0 (17-10-2026, part 15 of the whole web in the app):** the web's **help** on every screen of the app, in its own
words (`assets/help/web_help.json`): every red message – a toast, a red box, a "Nothing saved / Fix the file first" message, a
question that says "anyway" – has **Help**: what is wrong and what to do (the web's first three rules that know the message, else
its general one), in English / मराठी / हिंदी, and **Ask the assistant about this** when the AI service is set up; every page has its
**?** (About this page – what it is for, what the app checks / how its figures come; on Entries and the Log Book: ⋮ → About this
page).

**Version 3.15.0 (17-10-2026, part 14 of the whole web in the app):** the web's **assistant ("Ask")** in the app's own screen
(Home → **Ask**, next to the site), its working the web's own: the **⚡ questions** the app answers itself (the daily summary, the Log Book
entries still pending, yesterday's / today's diesel and to whom, the stock, those over the standard); a **typed question** the app
understands by itself (diesel, pending, stock, average, work, the last reading – in English, मराठी, हिंदी, also Marathi in English
letters; the machinery and the dates found in the words); an **entry from words** ("8511 ला 60 लिटर diesel दे, km 148200",
"EX-200 आज idle") – shown with Save / Open in the form / Cancel, saved **only** by his Save or "हो", through the app's own save and
checks (his access; "check the reading – Save anyway"); half said → it asks, and the next words complete it; otherwise the **AI
service** (getAiReply) with the day's figures, its look-ups run with his own sign-in, "Looked up …" under the answer, the page
buttons of an answer opening the app's screens; when the service fails, the app's own best answer or the guide of the page that
fits; **the daily summary once a day** (a red dot on Ask; Settings → Daily summary); the Admin's **Test the AI service**; the
**voice** – 🔊 on an answer says it aloud, the microphone starts a talk (he speaks in मराठी / हिंदी / English, it answers aloud and
listens again; "थांब", Stop or three silences end it; Settings → Speak the answer aloud).
The web's **help** – what every page is for and the help for every error message, in three languages – is in the app as the
web's own words (`assets/help/web_help.json`, made by `tool/web_help.js` from the web page).

**Version 3.14.0 (16-10-2026, part 13 of the whole web in the app):** the web's remaining pieces of the diesel pages, Settings and
Administration: the **diesel history of a machinery** while a Diesel Issue is filled (its last fills, last reading – the hint of
the reading box –, this month; the last fill's driver in an empty Driver box; the "last fill" line of each row of "one date – many
machinery"); **the photos of a saved fill** (large, when, where – the map); a **transfer's stock** of From and To, after the
litres; **Settings**: Log Book list shows (2 / 7 / 30 days), the page to open after sign-in (it opens by itself), my last
sign-ins, back to the usual settings; **the notice of the site** on Home; **Administration**: the faults of the app (listed,
emptied – the app's own faults are reported there too) and the backup to Google Sheet; **a machinery label scanned in the app**
(Home → the QR button): Diesel Issue with the machinery in it, Log Book entry, its diesel ledger; **Search** (Home → 🔍, the web's
Ctrl + K): pages, quick actions, machinery, owners, the server's entries and the Store's items – the web's own matcher (a spelling
mistake allowed only when nothing is found, "Did you mean …"), each result opening the app's screen with the web's filter.

**Version 3.13.0 (16-10-2026, part 12 of the whole web in the app):** the other **Excel imports** and the **QR labels**, as the web
does them: **Asset Master → ⋮ Import from Excel** (for Edit: the tab "Master", the columns by their names, N/A and Lifetime papers,
the dates; checked by the server – the rows with a mistake listed – "Import this file?", then saved) and **QR labels** (all the
machinery on site today, or one; the web's QR code of the Mechanical link, 12 labels on an A4 page, printed); **Vehicle
Compliance → ⋮ Import Excel** (the paper dates checked, the changes asked, saved); a **water tanker's Edit Log Book → Export
Excel** (now the web's own file: its 100 empty lines and the Shift drop-down) and **Import Excel** (checkTankerImport,
importTankerTrips); the **Store's Item Master → Import from Excel** (the Store Admin: every row checked – new, already there, a
near name to confirm with "Different item – add it", a mistake – then imported) and **Import template**.

**Version 3.12.0 (16-10-2026, part 11 of the whole web in the app):** the rest of the **Log Book** (Log Book → ⋮) in the app's own
screens: **Log Book – all dates** (the web's list with its filters – dates, the "Last N days" button, machinery, shift, and the
rest under "More filters"; the period's totals; **Print** of the list), the two **Exports** (one date – many machinery, one
machinery – many dates: the web's files cell by cell, with the Total formulas and the drop-downs), **Import from Excel** (for
Edit: the file read as the web reads it, every row checked by the server – checkLogImport / checkTankerImport, the rows already in
the Log Book shown with "overwrite or keep" – then importLogBook / importTankerTrips) and the two **templates** (the web's
200-line files with the machinery of the site on a hidden tab).

**Version 3.11.0 (16-10-2026, part 10 of the whole web in the app):** the rest of the **diesel pages** (Entries → Diesel Issue /
Diesel Inward / Transfer → ⋮) in the app's own screens: **All dates & Export** (the web's list with its filters – dates, Today /
Yesterday / Last 7 days / This month, and the page's own filters under "More filters"; the server's totals; on Diesel Issue each
entry's % of the total and "% by machinery"; Export to Excel – the web's file), **Import from Excel** (an .xlsx or .csv from the
phone, read as the web's library reads it; every row checked ✓ / ✗ – "Fix the file first" or "Import N rows"; all rows saved or
none, by the server), **Download template** (the web's file) and **Multiple entries** (Transfer: rows → saveTransferBulk;
Diesel Issue: one date – many machinery → saveDieselBulk with its "Please check these rows" / Save all anyway, and one machinery –
many dates → importDiesel, with the running stock as on the web). An old .xls is not read: "save it as .xlsx".

**Version 3.10.0 (16-10-2026, part 9 of the whole web in the app):** **Store** (Home → Store) in the app's own screens – its own
sign-in through the Portal (a ticket for the Store, used once), by the pages the Portal gave: the **Dashboard** (items, active,
inactive, categories, added this month; recently added; items by category) and the **Item Master** of this site (search,
category, status; + Add item – the name checked while typing, a proper name suggested, the same name refused, a near name asked
"is it the same item?", a near category asked; Edit / Delete by the Store Admin; Export to Excel).

**Version 3.9.0 (16-10-2026, part 8 of the whole web in the app):** **Administration** (Home → Administration, Admin only) in
the app's own screens: **Users & Access** (every user and his access per page – Edit / View / No access; read only once the
Super Admin gives users and access, else add a user, change one, a one-time password, set a whole column; the Access report and
its full list as a file), **Company & site**, the **Rules of this site** (days back, the notice, the shift hours), **Screen share
– who may use it**, the **Activity Log** (dates, user, module, action, record / text; what changed, field by field), the
**Database check** and **Read Me** (drawn with the app's own widgets – headings, lists, tables, the SQL to copy, the first
Admin's SQL as it is typed); Approvals from here too. The same server actions as the web.

**Version 3.8.0 (16-10-2026, part 7 of the whole web in the app):** **Billing** (Home → Billing) in the app's own screens, each
by its access as the web's tabs: **Machinery Billing** – the period, the bill date, the name on the bill, the vendors and their
machinery (search, a vendor ticks all its machinery), one bill per vendor or per machinery; **Build bills** works every bill out
on the phone with the web's own rules (the Log Book, the diesel and the BOQ of each date – per day / KM / trip / night trip /
hour slabs / month / item-wise / no BOQ, diesel debited or above the standard, the last fill still in the tank, a final bill),
the warnings to check, Idle days Paid / Not paid, the diesel rate of a bill, the other deduction and its reason, debit notes and
corrections of earlier bills to tick, the RA bill number; **Papers** / **Preview** – the Abstract of Bill, Tax Invoice, GST
declaration and Debit Note to the character of the web, with the Log Book after them, each bill fitted to one A4 page; **Verify &
Submit** (the server's checks ✔ ⚠ ✖, already-submitted bills kept as a revision or a new number), then the bills as saved open to
print; Company details; the Admin's Month close. **RCL Drive** – the saved bills (View / Print with the Log Book, the Log Book,
Delete by Admin) and debit notes (View / Print, Cancel by Admin, the diesel note of each bill), **+ New Debit Note** from the
Log Book entries charged to a party. **Bill Summary** (Net Payable month-wise / Detail), **Machinery Payments** (payment or
opening balance, edit, delete, the vendor's balance), **Vendor Ledger** and **Vendor Outstanding** – Print and Excel on the phone.
The Log Book print is now fitted to one page as on the web too. The same server actions as the web.

**Version 3.7.0 (16-10-2026, part 6 of the whole web in the app):** **Breakdown** (Home → Maintenance) in the app's own screen:
the daily machinery status – every machinery on site on a date (Own / Rental / Hired / Other, search), Working or Breakdown with
its reason (a list to pick from) and a remark, since when and for how many days (the breakdowns carried from the last saved day);
Submit / Save changes, Delete this day, Print; the saved days (tap one to open it); the period report – breakdown days per
machinery, per owner or owner → machinery, with when and why, Print and Excel. The same server actions as the web.

**Version 3.6.0 (16-10-2026, part 5 of the whole web in the app):** **Edit Log Book** (Log Book → ⋮) in the app's own screen: a
machinery and dates (Yesterday / This month / Last month) – all its entries as cards, worked out live (total, opening / issued /
consumed / closing diesel); a changed Close moves the next Start; red cards say what is wrong ("Use it"); + Add row (the first free
date, or the Night / Day of the ticked dates), Add all missing dates, + work in this shift (Bucket, then Breaker), ½ day, the way,
the Item-wise BOQ box, the opening diesel of the 1st, dates of a submitted RA Bill shown and not changed, Delete; **Save changes**
sends the whole lot once (saveLogBulk). A **water tanker** opens as its trips, one card each (saveTankerRange), with Export Excel.
**Print Log Book** – the site's monthly Log Book + bill in each machinery's format (A–I), the same sheets as the web prints (the
diesel rate of the print can be typed; portrait / landscape) – from Edit Log Book and from the Log Book of a day; **View format** on
Log Book Format prints a format with SAMPLE lines. Still to come: Import Excel (trips, entries) – with the other imports.

**Version 3.5.0 (16-10-2026, part 4 of the whole web in the app):** the **Dashboard** (Reports → Dashboard) and **Tank Check**
(Log Book → ⋮) in the app's own screens. Dashboard – Diesel: the dates (Today … All dates, From – To), the **Daily report** (one day on
one page to print / PDF), opening / received / issued / closing / stock now, the tanks (live or the closing of the last date) and
**Tank size**, issued by ownership (tap: machine-wise with Print), Own vehicle compliance, the stock of each place and combined, in &
out by day, top machines, the day-wise stock (a place or all). Dashboard – Log Book: the four figures, machine-wise work (chips),
pending Log Book by machinery – a date opens its new entry. Tank Check: what the system says, measured or filled to full, the
difference, saved once; the checks, Delete. The same server actions as the web.

**Version 3.4.0 (16-10-2026, part 3 of the whole web in the app):** **Machinery** (Home) – the web's Master pages in the app's own
screens, by access: **Asset Master** (the list with its filters and "on site" dates, the vendor chips, papers; a machinery's details;
Add / Edit – the changes shown first, a new Number moves everything, "did it come back?", earlier periods, papers with Lifetime /
N/A –; Add multiple; several ticked: Assign vendor, Edit selected, Delete selected; Export to Excel, Print list, Asset list by date /
month / period), **Vendor Master** (the list, a vendor's form – the GST number's State and PAN, the IFSC's bank and branch –, a
rename, save all owners as vendors), **Vendor BOQ** (BOQs and amendments, the form with every rent type – hour slabs, Night trip,
Item-wise –, the vendor's machinery ticked, same terms for others, machinery without a BOQ, Rate check, Print), **Vehicle
Compliance** (the counts and chips, renew a paper, papers per type, Export Excel, the history) and **Log Book Format** (each
machinery's format, set several, a format's name). The same server actions and checks as the web. Still to come with later parts:
the Excel imports, QR labels, a Log Book format's sample print.

**Version 3.3.0 (16-10-2026, part 2 of the whole web in the app):** **Reports** in the app's own screens – Daily Inward & Issue,
Monthly Diesel Issue, Monthly Diesel & Average and the 12 diesel reports (Debit Recovery – its rates can be changed, Machinery Cost,
Diesel Cost, Purchase Register, Machinery Diesel Ledger, Diesel Watch, Owner / Vendor-wise, Type-wise, Stock Register, Month vs
Month, Tank Check, Actual vs Standard): the same filters and the same server report as the web, the figures as tiles, the
tables as the web draws them (sideways on the phone), **Excel** (every table a sheet, made on the phone) and **Print** (A4 as the
web, the company chosen on top, the signatures; a printer or "Save as PDF").

**Version 3.2.0 (16-10-2026, "purn web application completely app ui madhe … app madhe mala kuthunch web ui dista kama naye"):**
the first part of the whole web in the app's own screens – **Approvals**: the counts (waiting for you, sent back, waiting in all,
yours, the oldest), every request (when, who, which work, what it changes, its steps, waiting at whom / sent back / decided),
Approve / Send back / Reject one or several ticked at once, Answer and send again / Take back, Remind; the Super Admin's
**Verification rules** (works, levels of people, "only when", remind after). The same actions and checks as the web.

**Version 3.1.13 (16-10-2026, with Mechanical update-120 – "inward bill copy pn add krayche aahet … inward copy eka weli multiple
click krun save kru shakel user"):** New / Change Diesel Inward has **Bill copy**: "Take photo" (the camera, one after another) and
"Choose photos" (several at once from the gallery), up to 10; each made a JPG of at most 2000 px and sent at once (`inwardPhoto`),
✓ on its tile, ✕ takes it out, a tap shows it large. A change shows the copies the inward has (`getInwardPhotos`) and sends the
list only when it was changed. The details of an inward say how many copies it has. The web's words (Marathi / Hindi) copied again.

**Version 3.1.12 (16-10-2026, with Mechanical update-119 – a machinery on a site several times: "vehicle ali … inactive hote …
part ali … period wise active inactive haway"):** `Machine.onSite` counts its earlier periods on site too (Mechanical's `earlier`),
so a machinery that came back is offered again from the day it came back, and not on the days it was away.

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
* **No web page in the app** (3.18.0, asked 16-10-2026: "app madhe mala kuthunch web ui dista kama naye"): every page of the
  web is the app's own screen, with the same server actions, checks and access. The only web view left prints a page the app
  made itself (`lib/web/print_view.dart` – a report, a bill, a Log Book page to PDF).
* 3D pictures: Microsoft Fluent Emoji (MIT, `assets/icons3d/LICENSE-fluentui-emoji.txt`). The Rachana logo is the picture the
  web ERP shows (fetched once by the build, `assets/brand/`).
* **Update from inside the app** (asked 14-10-2026: "git release madhe apk theun de"): the newest **GitHub Release** of this
  repository.
  * The release carries the APK, and its notes carry the build number and the SHA-256.
  * The app downloads the APK and checks the fingerprint. Android then installs it only if it carries the same signature.
  * (3.19.1) A phone takes its own processor's APK (`.arm64-v8a.apk` / `.armeabi-v7a.apk`, fingerprint in "apk") – about
    half the size; a release without them: the APK for every phone.
  * Windows (3.19.0): the release's setup (.exe) and its own fingerprint ("win"); the setup closes the app and opens the new one.
  * iPhone: App Store / TestFlight, later (the Apple Developer account).

## Build
GitHub Actions (`.github/workflows/build.yml`) runs on every push:
* `flutter analyze` and the tests;
* pictures of the screens (saved in the branch `screens/<branch>`);
* an Android file for checking (artifact **android-apk**, debug-signed);
* (3.19.0) the Windows app and its setup (job **windows**, artifact **windows-setup**) and the iPhone app without signing (job
  **ios**).

The first run makes the `android/` and `ios/` folders and saves them in the branch.

## Code
| Part | File |
|---|---|
| The Portal and Mechanical (sign-in, ticket, actions) | `lib/core/api.dart` |
| Person, sites, access, the site's lists | `lib/core/session.dart` |
| The 4 photos (camera, location, the printed band) | `lib/core/photo.dart` |
| Screens | `lib/screens/` (login, site_pick, shell, home, entries, forms, reports, me), `lib/main.dart` (opening) |
| Printing and the files the app makes (no web page) | `lib/web/print_view.dart`, `lib/web/files.dart` |
| Design | `lib/ui/theme.dart`, `lib/ui/brand.dart` (backgrounds, Rachana mark and logo), `lib/ui/widgets.dart` |
| Tests | `test/`, with pretend servers in `test/fake_server.dart` |

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
