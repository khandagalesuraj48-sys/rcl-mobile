import Flutter
import UIKit
import GoogleMaps   // (20-11-2026) the Google Maps SDK (the google_maps_flutter plugin brings it)

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // (20-11-2026) Google Maps for the app: the key comes from Info.plist (GMSApiKey), put there at build from the GitHub
    // secret MAPS_API_KEY. Empty / not set = the OpenStreetMap map, no Google – exactly as before.
    if let k = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String, !k.isEmpty {
      GMSServices.provideAPIKey(k)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
