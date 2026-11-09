package com.dars.my_tutor_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Android needs a visible "foreground service" while the screen is being shared in a call.
 * Started by the app right after the user allows screen capture, stopped when sharing ends.
 */
class ScreenShareService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    @Suppress("DEPRECATION")
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel("dars_share", "Screen sharing", NotificationManager.IMPORTANCE_LOW))
        }
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "dars_share") else Notification.Builder(this)
        val n = b.setSmallIcon(android.R.drawable.ic_menu_share)
            .setContentTitle("Dars")
            .setContentText("Sharing your screen in the call")
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(7101, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(7101, n)
        }
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= 24) {
            stopForeground(Service.STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
        super.onDestroy()
    }
}
