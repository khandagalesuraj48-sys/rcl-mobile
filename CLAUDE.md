# CLAUDE.md – RCL ERP mobile app (Flutter, Android + iPhone)

Read this first, then `README.md`. The same owner and rules as the Mechanical module (`rclerp/CLAUDE.md`), the Portal and the
Store; the short version:

## The owner and how to talk to him
* Sujit Mule, MD of Rachana Construction Limited (RCL).
* **Reply in Marathi (Devanagari).** Answer first. Simple. One step at a time.
* "adhi charcha kar" = discuss first, no code. "fkt check kr" = only check, change nothing.

## Rules
1. **Exactly what he asks, nothing extra.** He decides each step.
2. **Simple screens**, clear at a glance. Premium phone design from his three pictures (14-10-2026): own phone screens, not the web's.
3. **Live and business-critical:** the app uses the LIVE servers. No test entry is ever saved live. No push to `main` without
   his yes; a server change follows the server's own rules (Mechanical / Portal repos).
4. **Evidence, not claims:** the build (GitHub Actions) runs analyze, the tests and draws the screens – say plainly what was not
   run or not verified (a real phone, iPhone).
5. **Every command has a timeout.**
6. **Fix a thing everywhere it is used.**
7. **The repository is PUBLIC:** no secret, key, password, keystore or personal data in any file. The signing key and the
   store key live only in the private Supabase bucket / GitHub secrets.
8. Work arrives as a branch + pull request; he merges.

## The app's own screens – never the web's (asked 16-10-2026)
* "app madhe mala kuthunch web ui dista kama naye … ethun pudhe jewa jewa web war new kahi yeil app madhe pn te app version app
  ui pramane rahil": every page of the web is in the app as the app's OWN screens (same server actions, same checks, same
  access – the web UI and the server are not changed for it). **Whatever is added to the web from now on gets its app screen
  in the same piece of work.** No web view of an ERP page is shown in the app.

## How it is built
* No server of its own: the Portal (sign-in, sites, a ticket for Mechanical) and Mechanical's `/api/rpc` (the same actions,
  checks and access as the web page). See `lib/core/api.dart`.
* This computer (the assistant's) cannot download Flutter: the app is built and tested by `.github/workflows/build.yml`.
