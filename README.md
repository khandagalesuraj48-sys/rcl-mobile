# RCL ERP – mobile app

Android and iPhone app for the people at the sites – and (3.19.0) the same app on a Windows computer.

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
