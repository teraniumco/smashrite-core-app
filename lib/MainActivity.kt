package com.smashrite.app

import android.database.ContentObserver
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.smashrite/violations"
    private var screenshotObserver: ContentObserver? = null
    private var screenshotCount = 0
    private var methodChannel: MethodChannel? = null
    private var isSecurityEnabled = false
    
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
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        methodChannel?.setMethodCallHandler { call, result ->
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
    }
    
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
        
        // Notify Flutter
        runOnUiThread {
            methodChannel?.invokeMethod("onScreenshotDetected", mapOf(
                "count" to screenshotCount,
                "timestamp" to timestamp
            ))
        }
    }
    
    override fun onResume() {
        super.onResume()
        // Re-enable security when app resumes
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopScreenshotDetection()
    }
}