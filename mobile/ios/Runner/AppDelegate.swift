import Flutter
import UIKit

class HomeIndicatorFlutterViewController: FlutterViewController {
  override var prefersHomeIndicatorAutoHidden: Bool {
    true
  }

  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
    .bottom
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
