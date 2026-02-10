package com.smashrite.core

import android.content.Intent
import android.content.res.Configuration
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.MediaStore
import android.provider.Settings
import android.view.View
import android.view.WindowManager
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    // ========== Screenshot Detection ==========
    private val VIOLATIONS_CHANNEL = "com.smashrite.core/violations"
    private var screenshotObserver: ContentObserver? = null
    private var screenshotCount = 0
    private var violationsChannel: MethodChannel? = null
    private var isSecurityEnabled = false
    
    // ========== Kiosk Mode ==========
    private val KIOSK_CHANNEL = "com.smashrite.core/kiosk"
    private var kioskChannel: MethodChannel? = null
    private var isKioskModeEnabled = false
    
    // ========== Storage ==========
    private val STORAGE_CHANNEL = "com.smashrite.core/storage"
    private var storageChannel: MethodChannel? = null
    
    // ========== Settings Navigation ==========
    private val SETTINGS_CHANNEL = "com.smashrite.core/settings"
    private var settingsChannel: MethodChannel? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Block screenshots and screen recording by default
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // ========== Violations Channel ==========
        violationsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIOLATIONS_CHANNEL)
        
        violationsChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enableScreenSecurity" -> {
                    enableScreenSecurity()
                    result.success(true)
                }
                "disableScreenSecurity" -> {
                    disableScreenSecurity()
                    result.success(false)
                }
                else -> result.notImplemented()
            }
        }
        
        // ========== Kiosk Channel ==========
        kioskChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KIOSK_CHANNEL)
        
        kioskChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enableKioskMode" -> {
                    val success = enableKioskMode()
                    result.success(success)
                }
                "disableKioskMode" -> {
                    val success = disableKioskMode()
                    result.success(success)
                }
                "isKioskSupported" -> {
                    result.success(true)
                }
                "getKioskCapabilities" -> {
                    result.success(mapOf(
                        "fullscreen" to true,
                        "hideStatusBar" to true,
                        "hideNavigationBar" to true,
                        "blockHomeButton" to true,
                        "blockRecentApps" to true,
                        "blockNotifications" to true,
                        "keepScreenOn" to true
                    ))
                }
                else -> result.notImplemented()
            }
        }
        
        // ========== Storage Channel ==========
        storageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL)
        
        storageChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getFreeDiskSpace" -> {
                    try {
                        val freeMB = getFreeDiskSpaceInMB()
                        android.util.Log.d("StorageChannel", "✅ Free space: $freeMB MB")
                        result.success(freeMB)
                    } catch (e: Exception) {
                        android.util.Log.e("StorageChannel", "❌ Error getting disk space: ${e.message}")
                        result.error("STORAGE_ERROR", "Failed to get disk space: ${e.message}", null)
                    }
                }
                "getTotalDiskSpace" -> {
                    try {
                        val totalMB = getTotalDiskSpaceInMB()
                        android.util.Log.d("StorageChannel", "✅ Total space: $totalMB MB")
                        result.success(totalMB)
                    } catch (e: Exception) {
                        android.util.Log.e("StorageChannel", "❌ Error getting total disk space: ${e.message}")
                        result.error("STORAGE_ERROR", "Failed to get total disk space: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // ========== Settings Navigation Channel ==========
        settingsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL)
        
        settingsChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openWiFiSettings" -> {
                    try {
                        openWiFiSettings()
                        android.util.Log.d("SettingsChannel", "✅ Opened WiFi settings")
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("SettingsChannel", "❌ Error opening WiFi settings: ${e.message}")
                        result.error("SETTINGS_ERROR", "Failed to open WiFi settings: ${e.message}", null)
                    }
                }
                "openStorageSettings" -> {
                    try {
                        openStorageSettings()
                        android.util.Log.d("SettingsChannel", "✅ Opened storage settings")
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("SettingsChannel", "❌ Error opening storage settings: ${e.message}")
                        result.error("SETTINGS_ERROR", "Failed to open storage settings: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // ========== Multi-Window Detection ==========
    
    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration?) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        
        if (isInMultiWindowMode) {
            android.util.Log.e("MultiWindow", "🚨 CRITICAL: Multi-window mode detected!")
            
            // Notify Flutter immediately
            runOnUiThread {
                violationsChannel?.invokeMethod("onMultiWindowDetected", mapOf(
                    "timestamp" to (System.currentTimeMillis() / 1000.0)
                ))
            }
            
            // Force exit multi-window mode
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try {
                    // Attempt to force full-screen
                    moveTaskToBack(false)
                    
                    // Show alert
                    android.util.Log.w("MultiWindow", "Attempting to exit multi-window mode")
                } catch (e: Exception) {
                    android.util.Log.e("MultiWindow", "Failed to exit multi-window: ${e.message}")
                }
            }
        }
    }
    
    // ========== Storage Methods ==========
    
    private fun getFreeDiskSpaceInMB(): Double {
        val stat = StatFs(Environment.getDataDirectory().path)
        val availableBytes = stat.availableBlocksLong * stat.blockSizeLong
        return availableBytes / (1024.0 * 1024.0)
    }
    
    private fun getTotalDiskSpaceInMB(): Double {
        val stat = StatFs(Environment.getDataDirectory().path)
        val totalBytes = stat.blockCountLong * stat.blockSizeLong
        return totalBytes / (1024.0 * 1024.0)
    }
    
    // ========== Settings Navigation Methods ==========
    
    private fun openWiFiSettings() {
        try {
            // Create WiFi settings intent
            val intent = Intent()
            intent.action = Settings.ACTION_WIFI_SETTINGS
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY)
            intent.addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            
            // Verify the intent can be resolved
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                android.util.Log.d("SettingsChannel", "✅ Opened WiFi settings")
            } else {
                android.util.Log.e("SettingsChannel", "❌ WiFi settings not available")
                openFallbackSettings()
            }
        } catch (e: Exception) {
            android.util.Log.e("SettingsChannel", "❌ Failed to open WiFi settings: ${e.message}")
            openFallbackSettings()
        }
    }

    private fun openStorageSettings() {
        try {
            val intent = Intent()
            
            // Try different actions based on Android version
            intent.action = when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> {
                    // Android 8.0+ - Storage management
                    "android.settings.INTERNAL_STORAGE_SETTINGS"
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1 -> {
                    Settings.ACTION_INTERNAL_STORAGE_SETTINGS
                }
                else -> {
                    Settings.ACTION_MEMORY_CARD_SETTINGS
                }
            }
            
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY)
            intent.addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            
            // Verify the intent can be resolved
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                android.util.Log.d("SettingsChannel", "✅ Opened storage settings")
            } else {
                // If storage settings not available, try general settings
                android.util.Log.w("SettingsChannel", "⚠️ Storage settings not available, opening general settings")
                openGeneralSettings()
            }
        } catch (e: Exception) {
            android.util.Log.e("SettingsChannel", "❌ Failed to open storage settings: ${e.message}")
            openGeneralSettings()
        }
    }

    private fun openGeneralSettings() {
        try {
            val intent = Intent(Settings.ACTION_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY)
            intent.addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e("SettingsChannel", "❌ Failed to open general settings: ${e.message}")
        }
    }

    private fun openFallbackSettings() {
        // Open device settings homepage as fallback
        try {
            val intent = Intent(Settings.ACTION_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e("SettingsChannel", "❌ All fallbacks failed: ${e.message}")
        }
    }
    
    // ========== Screenshot Detection Methods ==========
    
    private fun enableScreenSecurity() {
        // 1. Block screenshots at OS level
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        
        // 2. Start detection (for devices that bypass FLAG_SECURE)
        if (!isSecurityEnabled) {
            startScreenshotDetection()
            isSecurityEnabled = true
        }
    }
    
    private fun disableScreenSecurity() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        stopScreenshotDetection()
        isSecurityEnabled = false
    }
    
    private fun startScreenshotDetection() {
        if (screenshotObserver != null) {
            return // Already monitoring
        }
        
        screenshotObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                super.onChange(selfChange, uri)
                
                if (uri != null) {
                    // Check if this is actually a screenshot
                    checkIfScreenshot(uri)
                }
            }
        }

        try {
            contentResolver.registerContentObserver(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                true,
                screenshotObserver!!
            )
            android.util.Log.d("Smashrite", "✅ Screenshot detection started")
        } catch (e: Exception) {
            android.util.Log.e("Smashrite", "❌ Failed to start screenshot detection: ${e.message}")
        }
    }
    
    private fun stopScreenshotDetection() {
        screenshotObserver?.let {
            try {
                contentResolver.unregisterContentObserver(it)
                screenshotObserver = null
                android.util.Log.d("Smashrite", "🛑 Screenshot detection stopped")
            } catch (e: Exception) {
                android.util.Log.e("Smashrite", "❌ Error stopping detection: ${e.message}")
            }
        }
    }
    
    private fun checkIfScreenshot(uri: Uri) {
        try {
            val projection = arrayOf(
                MediaStore.Images.Media.DISPLAY_NAME,
                MediaStore.Images.Media.DATA,
                MediaStore.Images.Media.DATE_ADDED
            )

            contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val displayNameIndex = cursor.getColumnIndex(MediaStore.Images.Media.DISPLAY_NAME)
                    val dataIndex = cursor.getColumnIndex(MediaStore.Images.Media.DATA)
                    val dateAddedIndex = cursor.getColumnIndex(MediaStore.Images.Media.DATE_ADDED)
                    
                    if (displayNameIndex >= 0 && dataIndex >= 0) {
                        val displayName = cursor.getString(displayNameIndex)?.lowercase() ?: ""
                        val data = cursor.getString(dataIndex)?.lowercase() ?: ""
                        
                        // Check for screenshot patterns
                        val isScreenshot = displayName.contains("screenshot") ||
                                         displayName.contains("screen_shot") ||
                                         displayName.contains("screencap") ||
                                         data.contains("screenshot") ||
                                         data.contains("screenshots") ||
                                         data.contains("screencap")
                        
                        if (isScreenshot) {
                            // Check if this is a recent screenshot (within last 3 seconds)
                            if (dateAddedIndex >= 0) {
                                val dateAdded = cursor.getLong(dateAddedIndex)
                                val currentTime = System.currentTimeMillis() / 1000
                                
                                if (currentTime - dateAdded <= 3) {
                                    notifyScreenshotDetected()
                                }
                            } else {
                                notifyScreenshotDetected()
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("Smashrite", "❌ Error checking screenshot: ${e.message}")
        }
    }
    
    private fun notifyScreenshotDetected() {
        screenshotCount++
        val timestamp = System.currentTimeMillis() / 1000.0
        
        android.util.Log.w("Smashrite", "📸 Screenshot detected! Count: $screenshotCount")
        
        // Notify Flutter via violations channel
        runOnUiThread {
            violationsChannel?.invokeMethod("onScreenshotDetected", mapOf(
                "count" to screenshotCount,
                "timestamp" to timestamp
            ))
        }
    }
    
    // ========== Kiosk Mode Methods ==========
    
    private fun enableKioskMode(): Boolean {
        return try {
            isKioskModeEnabled = true
            
            // 1. Enter fullscreen immersive mode
            hideSystemUI()
            
            // 2. Keep screen on
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            
            // 3. Disable lock screen
            window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
            
            // 4. FLAG_SECURE is already set in onCreate, but ensure it's still there
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            
            android.util.Log.d("KioskMode", "✅ Kiosk mode enabled")
            true
        } catch (e: Exception) {
            android.util.Log.e("KioskMode", "❌ Failed to enable kiosk mode", e)
            false
        }
    }
    
    private fun disableKioskMode(): Boolean {
        return try {
            isKioskModeEnabled = false
            
            // 1. Show system UI
            showSystemUI()
            
            // 2. Remove screen-on flag
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            
            // 3. Remove lock screen flags
            window.clearFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
            window.clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            window.clearFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
            
            // 4. Keep FLAG_SECURE if security is still enabled
            if (!isSecurityEnabled) {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
            
            android.util.Log.d("KioskMode", "🔓 Kiosk mode disabled")
            true
        } catch (e: Exception) {
            android.util.Log.e("KioskMode", "❌ Failed to disable kiosk mode", e)
            false
        }
    }
    
    private fun hideSystemUI() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+ (API 30+)
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.apply {
                hide(android.view.WindowInsets.Type.statusBars())
                hide(android.view.WindowInsets.Type.navigationBars())
                systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            // Android 10 and below
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            )
        }
    }
    
    private fun showSystemUI() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+ (API 30+)
            window.setDecorFitsSystemWindows(true)
            window.insetsController?.apply {
                show(android.view.WindowInsets.Type.statusBars())
                show(android.view.WindowInsets.Type.navigationBars())
            }
        } else {
            // Android 10 and below
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
        }
    }
    
    // ========== LIFECYCLE OVERRIDES (Updated for Kiosk) ==========
    
    // Block back button during kiosk mode
    override fun onBackPressed() {
        if (isKioskModeEnabled) {
            android.util.Log.w("KioskMode", "🚨 Back button blocked during exam")
            // Notify Flutter about back button press
            runOnUiThread {
                kioskChannel?.invokeMethod("onHomeButtonPressed", null)
            }
            // Don't call super.onBackPressed() - this blocks the back button
        } else {
            super.onBackPressed()
        }
    }
    
    // Intercept home and recent apps button
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (isKioskModeEnabled) {
            return when (keyCode) {
                KeyEvent.KEYCODE_HOME,
                KeyEvent.KEYCODE_APP_SWITCH -> {
                    android.util.Log.w("KioskMode", "🚨 System button blocked: $keyCode")
                    
                    // Notify Flutter
                    runOnUiThread {
                        val method = if (keyCode == KeyEvent.KEYCODE_HOME) {
                            "onHomeButtonPressed"
                        } else {
                            "onRecentAppsPressed"
                        }
                        kioskChannel?.invokeMethod(method, null)
                    }
                    
                    true // Block the button
                }
                else -> super.onKeyDown(keyCode, event)
            }
        }
        return super.onKeyDown(keyCode, event)
    }
    
    // Re-hide system UI when it reappears (for kiosk mode)
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && isKioskModeEnabled) {
            hideSystemUI()
        }
    }
    
    override fun onResume() {
        super.onResume()

        // Check if in multi-window mode
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInMultiWindowMode) {
            android.util.Log.e("MultiWindow", "🚨 App resumed in multi-window mode!")
            runOnUiThread {
                violationsChannel?.invokeMethod("onMultiWindowDetected", mapOf(
                    "timestamp" to (System.currentTimeMillis() / 1000.0)
                ))
            }
        }
        
        // Re-enable security when app resumes
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        
        // Re-hide system UI if kiosk is enabled
        if (isKioskModeEnabled) {
            hideSystemUI()
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopScreenshotDetection()
        
        // Cleanup kiosk mode if still enabled
        if (isKioskModeEnabled) {
            disableKioskMode()
        }
    }
}