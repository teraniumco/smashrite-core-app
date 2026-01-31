import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let CHANNEL = "com.smashrite/violations"
    private var screenshotCount = 0
    private var methodChannel: FlutterMethodChannel?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let controller = window?.rootViewController as! FlutterViewController
        methodChannel = FlutterMethodChannel(
            name: CHANNEL,
            binaryMessenger: controller.binaryMessenger
        )
        
        // Setup screenshot detection
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenshotTaken),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
        
        // Setup screen recording detection
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenRecordingChanged),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
        
        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            switch call.method {
            case "checkScreenRecording":
                let isRecording = UIScreen.main.isCaptured
                print("🔍 iOS: Check screen recording = \(isRecording)")
                result(isRecording)
            case "enableScreenSecurity":
                // iOS doesn't support blocking screenshots, just acknowledge
                print("🔒 iOS: Screen security enabled (detection only)")
                result(false)
            case "disableScreenSecurity":
                print("🔓 iOS: Screen security disabled")
                result(false)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        print("✅ iOS: Security monitoring initialized")
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    @objc func screenshotTaken() {
        screenshotCount += 1
        
        print("📸 iOS: Screenshot detected! Count: \(screenshotCount)")
        
        // Notify Flutter
        methodChannel?.invokeMethod("onScreenshotDetected", arguments: [
            "count": screenshotCount,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    @objc func screenRecordingChanged() {
        let isRecording = UIScreen.main.isCaptured
        
        print("🎥 iOS: Screen recording changed = \(isRecording)")
        
        // Notify Flutter
        methodChannel?.invokeMethod("onScreenRecordingChanged", arguments: [
            "isRecording": isRecording,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        print("🧹 iOS: Observers removed")
    }
}