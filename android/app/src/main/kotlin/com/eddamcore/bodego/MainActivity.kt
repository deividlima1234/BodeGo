package com.eddamcore.bodego

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val OTA_CHANNEL = "com.eddamcore.bodego/ota_updater"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OTA_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppVersion" -> {
                    try {
                        val pInfo = context.packageManager.getPackageInfo(context.packageName, 0)
                        val versionName = pInfo.versionName ?: "1.0.0"
                        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            pInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            pInfo.versionCode.toLong()
                        }
                        result.success(
                            mapOf(
                                "versionName" to versionName,
                                "versionCode" to versionCode
                            )
                        )
                    } catch (e: Exception) {
                        result.error("VERSION_ERROR", e.localizedMessage, null)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "La ruta del APK no puede estar vacía", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "El archivo APK no existe en $filePath", null)
                            return@setMethodCallHandler
                        }

                        val uri: Uri = FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            file
                        )

                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }

                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.localizedMessage, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
