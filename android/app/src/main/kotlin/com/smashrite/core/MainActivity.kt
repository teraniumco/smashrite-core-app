package com.smashrite.core

import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.Settings
import android.view.View
import android.view.WindowManager
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.view.WindowCompat

class MainActivity: FlutterActivity() {
    // ========== Screenshot Detection ==========
    private val VIOLATIONS_CHANNEL = "com.smashrite.core/violations"
    private var screenshotCount = 0
    private var violationsChannel: MethodChannel? = null
    private var isSecurityEnabled = false

    // Android 14+ screenshot detection (no permission required)
    private val screenshotCallback: Any? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            android.app.Activity.ScreenCaptureCallback {
                screenshotCount++
                val timestamp = System.currentTimeMillis() / 1000.0
                android.util.Log.w("Smashrite", "📸 Screenshot detected (API 34+)! Count: $screenshotCount")
                runOnUiThread {
                    violationsChannel?.invokeMethod("onScreenshotDetected", mapOf(
                        "count" to screenshotCount,
                        "timestamp" to timestamp
                    ))
                }
            }
        } else null
    }
    
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
        // Edge-to-edge: let content draw behind system bars
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
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
                "enableKioskMode" -> result.success(enableKioskMode())
                "disableKioskMode" -> result.success(disableKioskMode())
                "isKioskSupported" -> result.success(true)
                "getKioskCapabilities" -> result.success(mapOf(
                    "fullscreen" to true, "hideStatusBar" to true,
                    "hideNavigationBar" to true, "blockHomeButton" to true,
                    "blockRecentApps" to true, "blockNotifications" to true,
                    "keepScreenOn" to true
                ))
                else -> result.notImplemented()
            }
        }

        // ========== Storage Channel ==========
        storageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL)
        storageChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getFreeDiskSpace" -> {
                    try { result.success(getFreeDiskSpaceInMB()) }
                    catch (e: Exception) { result.error("STORAGE_ERROR", e.message, null) }
                }
                "getTotalDiskSpace" -> {
                    try { result.success(getTotalDiskSpaceInMB()) }
                    catch (e: Exception) { result.error("STORAGE_ERROR", e.message, null) }
                }
                else -> result.notImplemented()
            }
        }

        // ========== Settings Channel ==========
        settingsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL)
        settingsChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openWiFiSettings" -> {
                    try { openWiFiSettings(); result.success(true) }
                    catch (e: Exception) { result.error("SETTINGS_ERROR", e.message, null) }
                }
                "openStorageSettings" -> {
                    try { openStorageSettings(); result.success(true) }
                    catch (e: Exception) { result.error("SETTINGS_ERROR", e.message, null) }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    // ========== Screenshot Detection (No permissions required) ==========

    private fun enableScreenSecurity() {
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        if (!isSecurityEnabled) {
            registerScreenshotDetection()
            isSecurityEnabled = true
            android.util.Log.d("Smashrite", "✅ Screen security enabled")
        }
    }

    private fun disableScreenSecurity() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        unregisterScreenshotDetection()
        isSecurityEnabled = false
        android.util.Log.d("Smashrite", "🔓 Screen security disabled")
    }

    private fun registerScreenshotDetection() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+ — Official API, zero permissions needed
            @Suppress("UNCHECKED_CAST")
            val callback = screenshotCallback as? android.app.Activity.ScreenCaptureCallback
            callback?.let {
                registerScreenCaptureCallback(mainExecutor, it)
                android.util.Log.d("Smashrite", "✅ Screenshot detection registered (API 34+ native)")
            }
        } else {
            // Android < 14 — FLAG_SECURE already BLOCKS screenshots entirely.
            // ContentObserver approach removed: it required READ_MEDIA_IMAGES.
            // Blocking is more effective than detecting for exam integrity.
            android.util.Log.d("Smashrite", "ℹ️ Android < 14: Screenshots blocked via FLAG_SECURE")
        }
    }

    private fun unregisterScreenshotDetection() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            @Suppress("UNCHECKED_CAST")
            val callback = screenshotCallback as? android.app.Activity.ScreenCaptureCallback
            callback?.let { unregisterScreenCaptureCallback(it) }
        }
    }

    // ========== Multi-Window Detection ==========
    
    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration?) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        if (isInMultiWindowMode) {
            android.util.Log.e("MultiWindow", "🚨 CRITICAL: Multi-window mode detected!")
            runOnUiThread {
                violationsChannel?.invokeMethod("onMultiWindowDetected", mapOf(
                    "timestamp" to (System.currentTimeMillis() / 1000.0)
                ))
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try { moveTaskToBack(false) } catch (e: Exception) { }
            }
        }
    }
    
    // ========== Storage Methods ==========
    
    private fun getFreeDiskSpaceInMB(): Double {
        val stat = StatFs(Environment.getDataDirectory().path)
        return (stat.availableBlocksLong * stat.blockSizeLong) / (1024.0 * 1024.0)
    }
    
    private fun getTotalDiskSpaceInMB(): Double {
        val stat = StatFs(Environment.getDataDirectory().path)
        return (stat.blockCountLong * stat.blockSizeLong) / (1024.0 * 1024.0)
    }
    
    // ========== Settings Navigation ==========
    
    private fun openWiFiSettings() {
        val intent = Intent(Settings.ACTION_WIFI_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_HISTORY or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
        }
        if (intent.resolveActivity(packageManager) != null) startActivity(intent)
        else openFallbackSettings()
    }

    private fun openStorageSettings() {
        val action = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> "android.settings.INTERNAL_STORAGE_SETTINGS"
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1 -> Settings.ACTION_INTERNAL_STORAGE_SETTINGS
            else -> Settings.ACTION_MEMORY_CARD_SETTINGS
        }
        val intent = Intent(action).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_HISTORY or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
        }
        if (intent.resolveActivity(packageManager) != null) startActivity(intent)
        else openGeneralSettings()
    }

    private fun openGeneralSettings() {
        try { startActivity(Intent(Settings.ACTION_SETTINGS).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }) }
        catch (e: Exception) { }
    }

    private fun openFallbackSettings() {
        try { startActivity(Intent(Settings.ACTION_SETTINGS).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }) }
        catch (e: Exception) { }
    }
    
    // ========== Kiosk Mode ==========
    
    private fun enableKioskMode(): Boolean {
        return try {
            isKioskModeEnabled = true
            hideSystemUI()
            window.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SECURE
            )
            android.util.Log.d("KioskMode", "✅ Kiosk mode enabled")
            true
        } catch (e: Exception) { false }
    }
    
    private fun disableKioskMode(): Boolean {
        return try {
            isKioskModeEnabled = false
            showSystemUI()
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
            if (!isSecurityEnabled) window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            android.util.Log.d("KioskMode", "🔓 Kiosk mode disabled")
            true
        } catch (e: Exception) { false }
    }
    
    private fun hideSystemUI() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.apply {
                hide(android.view.WindowInsets.Type.statusBars())
                hide(android.view.WindowInsets.Type.navigationBars())
                systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            )
        }
    }
    
    private fun showSystemUI() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(true)
            window.insetsController?.apply {
                show(android.view.WindowInsets.Type.statusBars())
                show(android.view.WindowInsets.Type.navigationBars())
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
        }
    }
    
    // ========== Lifecycle ==========
    
    override fun onBackPressed() {
        if (isKioskModeEnabled) {
            runOnUiThread { kioskChannel?.invokeMethod("onHomeButtonPressed", null) }
        } else {
            super.onBackPressed()
        }
    }
    
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (isKioskModeEnabled) {
            return when (keyCode) {
                KeyEvent.KEYCODE_HOME, KeyEvent.KEYCODE_APP_SWITCH -> {
                    val method = if (keyCode == KeyEvent.KEYCODE_HOME) "onHomeButtonPressed" else "onRecentAppsPressed"
                    runOnUiThread { kioskChannel?.invokeMethod(method, null) }
                    true
                }
                else -> super.onKeyDown(keyCode, event)
            }
        }
        return super.onKeyDown(keyCode, event)
    }
    
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && isKioskModeEnabled) hideSystemUI()
    }
    
    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInMultiWindowMode) {
            runOnUiThread {
                violationsChannel?.invokeMethod("onMultiWindowDetected", mapOf(
                    "timestamp" to (System.currentTimeMillis() / 1000.0)
                ))
            }
        }
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        if (isKioskModeEnabled) hideSystemUI()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        unregisterScreenshotDetection()
        if (isKioskModeEnabled) disableKioskMode()
    }
}