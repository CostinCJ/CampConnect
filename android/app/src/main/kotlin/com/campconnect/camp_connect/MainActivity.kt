package com.campconnect.camp_connect

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
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
