import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "absen.dev_options"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.engine.binaryMessenger
    let methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    methodChannel.setMethodCallHandler { call, result in
      if call.method == "isDeveloperOptionsEnabled" {
        result(false)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
