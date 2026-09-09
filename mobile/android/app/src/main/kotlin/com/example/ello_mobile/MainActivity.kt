package com.example.ello_mobile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val callsChannel = "ello/phone"
    private val callPermissionRequestCode = 192
    private var pendingCallResult: MethodChannel.Result? = null
    private var pendingPhone: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, callsChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "call") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val phone = call.argument<String>("phone")?.trim().orEmpty()
                if (phone.isEmpty()) {
                    result.success(false)
                    return@setMethodCallHandler
                }

                startPhoneCall(phone, result)
            }
    }

    private fun startPhoneCall(phone: String, result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$phone"))
        if (intent.resolveActivity(packageManager) == null) {
            result.success(false)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingPhone = phone
            pendingCallResult = result
            requestPermissions(
                arrayOf(Manifest.permission.CALL_PHONE),
                callPermissionRequestCode
            )
            return
        }

        startActivity(intent)
        result.success(true)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == callPermissionRequestCode) {
            val result = pendingCallResult
            val phone = pendingPhone
            pendingCallResult = null
            pendingPhone = null

            if (result != null && phone != null &&
                grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            ) {
                startPhoneCall(phone, result)
            } else {
                result?.success(false)
            }
            return
        }

        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
