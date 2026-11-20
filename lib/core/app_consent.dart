/* THE APP'S TERMS / LOCATION CONSENT (20-11-2026, his decision: "user approval … app open krel user terms and condition pop up yeil …
 * allow decline … user ne allow kel ki te data store aswa"). Shown ONCE when the app opens; on "Allow" it is recorded for the user on
 * the Portal (api/auth appConsent → users.app_consent); on "Decline" nothing is recorded and the person cannot MARK ATTENDANCE until he
 * allows (the rest of the app works). The notice can be opened again from anywhere (Me, the attendance screen). While he is on duty the
 * app shows no "you are being tracked" banner – this notice is the one place it is said; the phone's own location mark stays (the system
 * does not let an app hide it). What the notice covers is written in full on the website's Privacy Policy, linked from the notice.
 *   – The VERSION must match the Portal's APP_CONSENT_VERSION (api/auth.js). Bump both together when the notice changes so everybody
 *     sees it once more.
 *   – Kept per phone in the secure store (Keep): which version was seen (so the open-notice is not shown again) and whether AI features
 *     were allowed. Whether consent is IN FORCE is the Portal's word (session.consentNeed: empty = in force / nothing to accept). */
import 'dart:io' show Platform;

import 'session.dart';

class AppConsent {
  AppConsent._();

  /// The current version of the notice. Must equal APP_CONSENT_VERSION in rcl-portal/api/auth.js.
  static const version = '2026-11-20';

  static const _seenKey = 'app_consent_seen'; // the version whose open-notice this phone has already shown (allow or decline)
  static const _aiKey = 'ai_consent_ok'; // '1' once AI features were allowed on this phone

  /// Consent is in force (the Portal has his acceptance of the current version) – attendance may be marked.
  static bool ok(Session s) => s.consentNeed.isEmpty;

  /// Show the notice on opening? The Portal still wants it AND this phone has not shown this version yet.
  static Future<bool> popupOnOpen(Session s) async {
    if (s.consentNeed.isEmpty) return false;
    return (await s.api.keep.read(_seenKey)) != s.consentNeed;
  }

  /// Remember that the open-notice for the version the Portal wants was shown on this phone (so it is not shown again on opening).
  static Future<void> markSeen(Session s) async {
    if (s.consentNeed.isNotEmpty) await s.api.keep.write(_seenKey, s.consentNeed);
  }

  /// "Allow": record the acceptance on the Portal and mark consent in force for this session. Throws on a network / server problem.
  static Future<void> accept(Session s) async {
    final v = s.consentNeed.isEmpty ? version : s.consentNeed;
    await s.api.auth({'action': 'appConsent', 'version': v, 'platform': _platform()});
    s.consentNeed = ''; // in force now
    await s.api.keep.write(_seenKey, v);
  }

  /// Have the AI features been allowed on this phone?
  static Future<bool> aiOk(Session s) async => (await s.api.keep.read(_aiKey)) == '1';

  /// Remember that the AI features were allowed on this phone (asked once, before anything is sent to an AI service).
  static Future<void> aiAccept(Session s) async => s.api.keep.write(_aiKey, '1');

  static String _platform() => Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : '');
}
