import UIKit
import Flutter
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channel = "ringdrill/shared_file"
  private var methodChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller = window?.rootViewController as! FlutterViewController
    methodChannel = FlutterMethodChannel(name: channel, binaryMessenger: controller.binaryMessenger)

    // Required for flutter_local_notifications
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

    // 🔄 Handle .drill file opened via AirDrop, Files, Mail, etc.
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
      // Handle Share Extension (ringdrill://import)
      if url.scheme == "ringdrill", url.host == "import" {
        // A shared ringdrill.app link (Web Share API, "Share" on a chat
        // link, etc.) rides along as a query param — see
        // ShareViewController.launchMainApp. No App-Group file round-trip
        // needed for a link, unlike the .drill file case below.
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let link = components.queryItems?.first(where: { $0.name == "link" })?.value {
          methodChannel?.invokeMethod("onSharedLink", arguments: link)
          return true
        }

        let fileManager = FileManager.default
        if let sharedURL = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: "group.app.ringdrill.shared")?
            .appendingPathComponent("shared.drill") {
          if FileManager.default.fileExists(atPath: sharedURL.path) {
            methodChannel?.invokeMethod("onSharedFilePath", arguments: sharedURL.path)
          }
        }
        return true
      }

      // Handle .drill file opened via Files app, AirDrop, Mail, etc.
      if url.pathExtension.lowercased() == "drill" {
        methodChannel?.invokeMethod("onSharedFilePath", arguments: url.path)
        return true
      }

      return false
    }
    
}
