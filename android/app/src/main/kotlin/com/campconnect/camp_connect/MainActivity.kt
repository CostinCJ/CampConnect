package com.campconnect.camp_connect

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.campconnect/file_saver"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "saveToDownloads") {
                    val bytes = call.argument<ByteArray>("bytes")
                    val filename = call.argument<String>("filename") ?: "document.pdf"
                    val mimeType = call.argument<String>("mimeType") ?: "application/pdf"

                    if (bytes == null) {
                        result.error("INVALID_ARGS", "bytes is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val savedPath = saveToDownloads(bytes, filename, mimeType)
                        result.success(savedPath)
                    } catch (e: Exception) {
                        result.error("SAVE_ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun saveToDownloads(bytes: ByteArray, filename: String, mimeType: String): String {
        val resolver = contentResolver
        val contentValues = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, filename)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        }

        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
            ?: throw Exception("Failed to create file in Downloads")

        resolver.openOutputStream(uri)?.use { outputStream ->
            outputStream.write(bytes)
        } ?: throw Exception("Failed to open output stream")

        return filename
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java)

            // Announcements channel (default priority)
            val announcementsChannel = NotificationChannel(
                "announcements",
                "Anunturi / Kozlemenyek",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Notificari pentru anunturi noi"
            }

            // Emergency channel (high priority, bypasses DND)
            val emergencyChannel = NotificationChannel(
                "emergency",
                "Urgente / Veszhelyzet",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerte de urgenta pentru ghizi"
                setBypassDnd(true)
                enableVibration(true)
                enableLights(true)
            }

            notificationManager.createNotificationChannel(announcementsChannel)
            notificationManager.createNotificationChannel(emergencyChannel)
        }
    }
}
