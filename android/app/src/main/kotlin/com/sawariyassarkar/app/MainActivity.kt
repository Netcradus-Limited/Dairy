package com.sawariyassarkar.app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val BATTERY_CHANNEL = "com.sawariyassarkar.app/battery_optimization"
    private val LOCATION_PERMISSION_CHANNEL = "com.sawariyassarkar.app/location_permissions"

    companion object {
        private const val REQ_FOREGROUND_LOCATION = 4101
        private const val REQ_BACKGROUND_LOCATION = 4102
        private const val REQ_POST_NOTIFICATIONS = 4103
    }

    private var pendingLocationResult: MethodChannel.Result? = null
    private var pendingNotificationResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "openBatteryOptimizationSettings" -> {
                    result.success(openBatteryOptimizationSettings())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_PERMISSION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndroidSdkInt" -> {
                    result.success(Build.VERSION.SDK_INT)
                }
                "getLocationPermissionState" -> {
                    result.success(buildLocationPermissionState())
                }
                "requestForegroundLocationOnly" -> {
                    requestForegroundLocationOnly(result)
                }
                "requestNotificationPermission" -> {
                    requestNotificationPermission(result)
                }
                "requestBackgroundLocationOnly" -> {
                    requestBackgroundLocationOnly(result)
                }
                "openAppLocationSettings" -> {
                    result.success(openAppDetailsSettings())
                }
                "openAppNotificationSettings" -> {
                    result.success(openAppNotificationSettings())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasPermission(permission: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun buildLocationPermissionState(): Map<String, Any> {
        val fineGranted = hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        val coarseGranted = hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        val foregroundGranted = fineGranted || coarseGranted
        val backgroundGranted = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            foregroundGranted
        } else {
            hasPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        }
        val notificationGranted = if (Build.VERSION.SDK_INT >= 33) {
            hasPermission("android.permission.POST_NOTIFICATIONS")
        } else {
            true
        }
        val shouldShowFgRationale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_FINE_LOCATION) ||
                shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_COARSE_LOCATION)
        } else false
        val shouldShowBgRationale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        } else false

        return mapOf(
            "sdkInt" to Build.VERSION.SDK_INT,
            "fineGranted" to fineGranted,
            "coarseGranted" to coarseGranted,
            "foregroundGranted" to foregroundGranted,
            "backgroundGranted" to backgroundGranted,
            "notificationGranted" to notificationGranted,
            "shouldShowForegroundRationale" to shouldShowFgRationale,
            "shouldShowBackgroundRationale" to shouldShowBgRationale
        )
    }

    private fun requestForegroundLocationOnly(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(buildLocationPermissionState())
            return
        }
        val state = buildLocationPermissionState()
        if (state["foregroundGranted"] == true) {
            result.success(state)
            return
        }
        if (pendingLocationResult != null) {
            result.error("PERMISSION_IN_PROGRESS", "A location permission request is already in progress.", null)
            return
        }
        pendingLocationResult = result
        // Strictly request foreground permissions only; never mix ACCESS_BACKGROUND_LOCATION here.
        requestPermissions(
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ),
            REQ_FOREGROUND_LOCATION
        )
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33) {
            result.success(true)
            return
        }
        if (hasPermission("android.permission.POST_NOTIFICATIONS")) {
            result.success(true)
            return
        }
        if (pendingNotificationResult != null) {
            result.error("PERMISSION_IN_PROGRESS", "A notification permission request is already in progress.", null)
            return
        }
        pendingNotificationResult = result
        requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), REQ_POST_NOTIFICATIONS)
    }

    private fun requestBackgroundLocationOnly(result: MethodChannel.Result) {
        val state = buildLocationPermissionState()
        if (state["foregroundGranted"] != true) {
            // Background permission cannot be requested before foreground location is granted.
            result.success(state)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || state["backgroundGranted"] == true) {
            result.success(state)
            return
        }
        if (pendingLocationResult != null) {
            result.error("PERMISSION_IN_PROGRESS", "A location permission request is already in progress.", null)
            return
        }
        pendingLocationResult = result
        // Request ACCESS_BACKGROUND_LOCATION completely standalone (required on Android 10 & 11+).
        requestPermissions(
            arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
            REQ_BACKGROUND_LOCATION
        )
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        when (requestCode) {
            REQ_FOREGROUND_LOCATION, REQ_BACKGROUND_LOCATION -> {
                val cb = pendingLocationResult
                pendingLocationResult = null
                cb?.success(buildLocationPermissionState())
            }
            REQ_POST_NOTIFICATIONS -> {
                val cb = pendingNotificationResult
                pendingNotificationResult = null
                val granted = if (Build.VERSION.SDK_INT >= 33) {
                    hasPermission("android.permission.POST_NOTIFICATIONS")
                } else true
                cb?.success(granted)
            }
            else -> {
                super.onRequestPermissionsResult(requestCode, permissions, grantResults)
            }
        }
    }

    private fun openAppDetailsSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun openAppNotificationSettings(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // Fall through to app details settings
            }
        }
        return openAppDetailsSettings()
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        return try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            powerManager?.isIgnoringBatteryOptimizations(packageName) ?: true
        } catch (e: Exception) {
            true
        }
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        // Attempt 1: System battery optimization settings list (Android 6.0+)
        // Note: Does NOT use ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS so no
        // REQUEST_IGNORE_BATTERY_OPTIMIZATIONS manifest permission is required.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return true
            } catch (e: Exception) {
                // Fall through to App Details Settings
            }
        }

        // Attempt 2: App details settings where user can configure battery permissions
        if (openAppDetailsSettings()) {
            return true
        }

        // Attempt 3: General system settings fallback
        return try {
            val intent = Intent(Settings.ACTION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
