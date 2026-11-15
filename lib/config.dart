/// The one address of the RCL ERP (the Portal sits under it at /portal). When the own domain comes, only this changes.
const kMainUrl = 'https://oneclicksolution-erp.vercel.app';
const kPortalUrl = '$kMainUrl/portal';

/// (15-11-2026, his decisions: "Beta testing must use a separate Test Database … Beta Testers must also receive every Stable release")
/// TWO APPS from the same code: "Sketchline" (in.rachana.rcl.rcl_mobile – everybody, testers too: the live data, only the STABLE
/// versions) and "Sketchline Beta" (in.rachana.rcl.rcl_mobile.beta – the testers' app: the Portal gives it only the modules' BETA
/// copies, which work only on the one Beta TEST database; it takes only the Beta app's versions). Only .github/workflows/beta.yml
/// builds the Beta app (RCL_CHANNEL=beta for Gradle and --dart-define=RCL_CHANNEL=beta here).
const kBetaApp = String.fromEnvironment('RCL_CHANNEL') == 'beta';

/// The app's releases (GitHub Releases of the app's repository): the newest one is the update (asked 14-10-2026).
const kReleasesApi = 'https://api.github.com/repos/khandagalesuraj48-sys/rcl-mobile/releases/latest';

/// (02-11-2026) the newest releases, a pre-release ("Beta") included – (15-11-2026) read only by the Beta app (its own versions).
const kReleasesListApi = 'https://api.github.com/repos/khandagalesuraj48-sys/rcl-mobile/releases?per_page=20';
