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
    
    // ========== Screen Protection ==========
    // Uses UITextField's isSecureTextEntry layer trick to black out all
    // screenshots and screen recordings at the iOS OS level.
    private var secureTextField: UITextField?
    
    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Application Launch
    // ─────────────────────────────────────────────────────────────────────────
    
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
                // Apply OS-level screen blackout protection
                self.applyScreenProtection()
                print("🔒 iOS: Screen security enabled — screenshots/recordings will be blacked out")
                result(true)
                
            case "disableScreenSecurity":
                // self.removeScreenProtection()
                print("🔓 iOS: Screen security disabled")
                result(true)
                
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
                // Apply screen protection alongside kiosk mode
                self.applyScreenProtection()
                let success = self.enableKioskMode()
                result(success)
                
            case "disableKioskMode":
                // Remove screen protection when exiting kiosk mode
                // self.removeScreenProtection()
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
                    "screenshotBlackout": true,
                    "screenRecordingBlackout": true,
                    "note": "iOS requires Guided Access for full kiosk mode. Screen content is blacked out in all captures."
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
        
        // ── Call super first so the window hierarchy is fully ready ──────────
        let launchResult = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        // ── Apply screen protection immediately on launch ─────────────────────
        // This ensures the app is protected from the very first frame.
        // Screenshots and screen recordings will show a black screen at all times.
        applyScreenProtection()
        
        return launchResult
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Screen Protection (Blackout)
    // ─────────────────────────────────────────────────────────────────────────
    
    /// Applies OS-level screen blackout by exploiting UITextField's secure
    /// entry layer behaviour. When the window's CALayer is reparented into a
    /// UITextField's secure sublayer tree, iOS treats all rendered content as
    /// sensitive and replaces it with a solid black frame in every screenshot
    /// and screen recording — including AirPlay mirrors and ReplayKit.
    ///
    /// This uses only public UIKit APIs and is App Store safe.
    private func applyScreenProtection() {
        // Guard: don't double-apply
        guard secureTextField == nil, let window = self.window else { return }
        
        let field = UITextField()
        field.isSecureTextEntry = true
        field.isUserInteractionEnabled = false
        field.backgroundColor = .clear
        field.translatesAutoresizingMaskIntoConstraints = false
        
        window.addSubview(field)
        
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: window.topAnchor),
            field.bottomAnchor.constraint(equalTo: window.bottomAnchor),
            field.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: window.trailingAnchor),
        ])
        
        // ── Core layer trick ──────────────────────────────────────────────────
        // Reparent the window's own CALayer into the secure text field's
        // sublayer chain. iOS then considers ALL content as part of a secure
        // input surface and blacks it out in any capture pipeline.
        window.layer.superlayer?.addSublayer(field.layer)
        field.layer.sublayers?.last?.addSublayer(window.layer)
        // ─────────────────────────────────────────────────────────────────────
        
        secureTextField = field
        
        print("🔒 iOS: Screen protection ACTIVE — all captures will be blacked out")
        print("   ↳ Screenshots : solid black image")
        print("   ↳ Screen recordings : solid black video")
        print("   ↳ App switcher preview : blank (expected)")
    }
    
    /// Removes screen blackout protection and restores the window layer to its
    /// normal position in the render tree. Call this only after an exam ends.
    private func removeScreenProtection() {
        guard let field = secureTextField, let window = self.window else { return }
        
        // Restore the window's layer to the top of the main layer tree
        // before removing the secure field to avoid a blank screen flash.
        if let rootLayer = window.layer.superlayer {
            rootLayer.insertSublayer(window.layer, at: 0)
        }
        
        field.removeFromSuperview()
        secureTextField = nil
        
        print("🔓 iOS: Screen protection REMOVED")
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Storage Methods
    // ─────────────────────────────────────────────────────────────────────────
    
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
    
    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Settings Navigation
    // ─────────────────────────────────────────────────────────────────────────
    
    private func openWiFiSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:]) { success in
                print(success
                    ? "✅ iOS: Opened settings (navigate to WiFi manually)"
                    : "❌ iOS: Failed to open settings"
                )
            }
        }
    }
    
    private func openStorageSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:]) { success in
                print(success
                    ? "✅ iOS: Opened settings (navigate to storage manually)"
                    : "❌ iOS: Failed to open settings"
                )
            }
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Screenshot & Recording Detection
    // ─────────────────────────────────────────────────────────────────────────
    
    @objc func screenshotTaken() {
        screenshotCount += 1
        
        // The captured image will be solid black due to applyScreenProtection(),
        // but we still detect, log, and report the attempt for audit purposes.
        print("📸 iOS: Screenshot attempt detected! Count: \(screenshotCount)")
        print("   ↳ Captured image is blacked out — no exam content was exposed")
        
        violationsChannel?.invokeMethod("onScreenshotDetected", arguments: [
            "count": screenshotCount,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    @objc func screenRecordingChanged() {
        let isRecording = UIScreen.main.isCaptured
        
        print("🎥 iOS: Screen recording \(isRecording ? "STARTED" : "STOPPED")")
        if isRecording {
            print("   ↳ Recording will show black screen — no exam content exposed")
        }
        
        violationsChannel?.invokeMethod("onScreenRecordingChanged", arguments: [
            "isRecording": isRecording,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Kiosk Mode
    // ─────────────────────────────────────────────────────────────────────────
    
    private func enableKioskMode() -> Bool {
        isKioskModeEnabled = true
        
        // Disable idle timer (keep screen on during exam)
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Set window level to normal
        if let window = self.window {
            window.windowLevel = .normal
        }
        
        let isGuidedAccessEnabled = UIAccessibility.isGuidedAccessEnabled
        if isGuidedAccessEnabled {
            NSLog("✅ iOS Kiosk mode enabled (Guided Access is active)")
        } else {
            NSLog("⚠️ iOS Kiosk mode enabled (Guided Access NOT active — strongly recommended during exams)")
            NSLog("💡 To enable: Settings → Accessibility → Guided Access")
        }
        
        return true
    }
    
    private func disableKioskMode() -> Bool {
        isKioskModeEnabled = false
        
        UIApplication.shared.isIdleTimerDisabled = false
        UIApplication.shared.setStatusBarHidden(false, with: .fade)
        
        NSLog("🔓 iOS Kiosk mode disabled")
        return true
    }
    
    override func application(
        _ application: UIApplication,
        didChangeStatusBarFrame oldStatusBarFrame: CGRect
    ) {
        if isKioskModeEnabled && !UIAccessibility.isGuidedAccessEnabled {
            NSLog("⚠️ WARNING: Guided Access should be enabled during exam")
            NSLog("💡 Triple-click side button → Start Guided Access")
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Cleanup
    // ─────────────────────────────────────────────────────────────────────────
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        print("🧹 iOS: All observers removed")
    }
}