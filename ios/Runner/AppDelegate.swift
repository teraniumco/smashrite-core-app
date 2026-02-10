import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    // ========== Screenshot/Recording Detection ==========
    private let VIOLATIONS_CHANNEL = "com.smashrite.core/violations"
    private var screenshotCount = 0
    private var violationsChannel: FlutterMethodChannel?
    
    // ========== Kiosk Mode ==========
    private let KIOSK_CHANNEL = "com.smashrite.core/kiosk"
    private var kioskChannel: FlutterMethodChannel?
    private var isKioskModeEnabled = false
    
    // ========== Storage ==========
    private let STORAGE_CHANNEL = "com.smashrite.core/storage"
    private var storageChannel: FlutterMethodChannel?
    
    // ========== Settings Navigation ==========
    private let SETTINGS_CHANNEL = "com.smashrite.core/settings"
    private var settingsChannel: FlutterMethodChannel?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let controller = window?.rootViewController as! FlutterViewController
        
        // ========== Violations Channel Setup ==========
        violationsChannel = FlutterMethodChannel(
            name: VIOLATIONS_CHANNEL,
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
        
        violationsChannel?.setMethodCallHandler { [weak self] (call, result) in
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
        
        // ========== Kiosk Channel Setup ==========
        kioskChannel = FlutterMethodChannel(
            name: KIOSK_CHANNEL,
            binaryMessenger: controller.binaryMessenger
        )
        
        kioskChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            switch call.method {
            case "enableKioskMode":
                let success = self.enableKioskMode()
                result(success)
                
            case "disableKioskMode":
                let success = self.disableKioskMode()
                result(success)
                
            case "isKioskSupported":
                result(true)
                
            case "getKioskCapabilities":
                result([
                    "fullscreen": true,
                    "guidedAccess": true,
                    "keepScreenOn": true,
                    "hideStatusBar": true,
                    "note": "iOS requires Guided Access for full kiosk mode"
                ])
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        print("✅ iOS: Kiosk mode channel initialized")
        
        // ========== Storage Channel Setup ==========
        storageChannel = FlutterMethodChannel(
            name: STORAGE_CHANNEL,
            binaryMessenger: controller.binaryMessenger
        )
        
        storageChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            switch call.method {
            case "getFreeDiskSpace":
                do {
                    let freeMB = try self.getFreeDiskSpaceInMB()
                    print("✅ iOS: Free space: \(freeMB) MB")
                    result(freeMB)
                } catch {
                    print("❌ iOS: Error getting disk space: \(error.localizedDescription)")
                    result(FlutterError(
                        code: "STORAGE_ERROR",
                        message: "Failed to get disk space: \(error.localizedDescription)",
                        details: nil
                    ))
                }
                
            case "getTotalDiskSpace":
                do {
                    let totalMB = try self.getTotalDiskSpaceInMB()
                    print("✅ iOS: Total space: \(totalMB) MB")
                    result(totalMB)
                } catch {
                    print("❌ iOS: Error getting total disk space: \(error.localizedDescription)")
                    result(FlutterError(
                        code: "STORAGE_ERROR",
                        message: "Failed to get total disk space: \(error.localizedDescription)",
                        details: nil
                    ))
                }
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        print("✅ iOS: Storage channel initialized")
        
        // ========== Settings Navigation Channel Setup ==========
        settingsChannel = FlutterMethodChannel(
            name: SETTINGS_CHANNEL,
            binaryMessenger: controller.binaryMessenger
        )
        
        settingsChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            switch call.method {
            case "openWiFiSettings":
                self.openWiFiSettings()
                print("✅ iOS: Opened WiFi settings")
                result(true)
                
            case "openStorageSettings":
                self.openStorageSettings()
                print("✅ iOS: Opened storage settings (general)")
                result(true)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        print("✅ iOS: Settings navigation channel initialized")
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // ========== Storage Methods ==========
    
    private func getFreeDiskSpaceInMB() throws -> Double {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
        let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        
        if let capacity = values.volumeAvailableCapacityForImportantUsage {
            return Double(capacity) / (1024.0 * 1024.0)
        }
        
        throw NSError(
            domain: "StorageError",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Could not determine free space"]
        )
    }
    
    private func getTotalDiskSpaceInMB() throws -> Double {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
        let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey])
        
        if let capacity = values.volumeTotalCapacity {
            return Double(capacity) / (1024.0 * 1024.0)
        }
        
        throw NSError(
            domain: "StorageError",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Could not determine total space"]
        )
    }
    
    // ========== Settings Navigation Methods ==========

    private func openWiFiSettings() {
        // iOS 13+ - Open WiFi settings
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    print("✅ iOS: Opened settings (navigate to WiFi manually)")
                } else {
                    print("❌ iOS: Failed to open settings")
                }
            }
        }
    }

    private func openStorageSettings() {
        // iOS doesn't have direct storage settings access, open general settings
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    print("✅ iOS: Opened settings (navigate to storage manually)")
                } else {
                    print("❌ iOS: Failed to open settings")
                }
            }
        }
    }
    
    // ========== Screenshot Detection ==========
    
    @objc func screenshotTaken() {
        screenshotCount += 1
        
        print("📸 iOS: Screenshot detected! Count: \(screenshotCount)")
        
        // Notify Flutter via violations channel
        violationsChannel?.invokeMethod("onScreenshotDetected", arguments: [
            "count": screenshotCount,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    @objc func screenRecordingChanged() {
        let isRecording = UIScreen.main.isCaptured
        
        print("🎥 iOS: Screen recording changed = \(isRecording)")
        
        // Notify Flutter via violations channel
        violationsChannel?.invokeMethod("onScreenRecordingChanged", arguments: [
            "isRecording": isRecording,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // ========== Kiosk Mode Methods ==========
    
    private func enableKioskMode() -> Bool {
        isKioskModeEnabled = true
        
        // 1. Disable idle timer (keep screen on)
        UIApplication.shared.isIdleTimerDisabled = true
        
        // 2. Hide status bar
        if #available(iOS 13.0, *) {
            // For iOS 13+, status bar hiding is controlled by view controller
            // We'll set a flag and the view controller should handle it
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.statusBarManager?.statusBarFrame = .zero
                }
            }
        }
        UIApplication.shared.setStatusBarHidden(true, with: .fade)
        
        // 3. Set full screen
        if let window = self.window {
            window.windowLevel = .normal
        }
        
        // 4. Check if Guided Access is enabled
        let isGuidedAccessEnabled = UIAccessibility.isGuidedAccessEnabled
        if isGuidedAccessEnabled {
            NSLog("✅ iOS Kiosk mode enabled (Guided Access is active)")
        } else {
            NSLog("⚠️ iOS Kiosk mode enabled (Guided Access NOT active - recommend enabling)")
            NSLog("💡 To enable Guided Access: Settings → Accessibility → Guided Access")
        }
        
        return true
    }
    
    private func disableKioskMode() -> Bool {
        isKioskModeEnabled = false
        
        // 1. Re-enable idle timer
        UIApplication.shared.isIdleTimerDisabled = false
        
        // 2. Show status bar
        UIApplication.shared.setStatusBarHidden(false, with: .fade)
        
        NSLog("🔓 iOS Kiosk mode disabled")
        return true
    }
    
    // Monitor Guided Access status
    override func application(
        _ application: UIApplication,
        didChangeStatusBarFrame oldStatusBarFrame: CGRect
    ) {
        if isKioskModeEnabled && !UIAccessibility.isGuidedAccessEnabled {
            NSLog("⚠️ WARNING: Guided Access should be enabled during exam")
            NSLog("💡 Triple-click side button → Start Guided Access")
        }
    }
    
    // ========== CLEANUP ==========
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        print("🧹 iOS: All observers removed")
    }
}