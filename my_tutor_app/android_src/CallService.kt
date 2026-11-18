package com.dars.my_tutor_app

import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Round D (D2): one "call in progress" service for the whole call. Android keeps the microphone (and the
 * camera on video calls) working while the person is in another app or shares the screen only when such a
 * service runs with the matching types (Android 11+; Android 14 also checks the FOREGROUND_SERVICE_* permissions).
 * While the screen is shared the type "screen capture" (mediaProjection) is added. The notification has a
 * "Hang up" button. Replaces the screen-share-only service of earlier builds.
 */
class CallService : Service() {
    companion object {
        const val START = "com.dars.my_tutor_app.CALL_START"
        const val SHARE_ON = "com.dars.my_tutor_app.CALL_SHARE_ON"
        const val SHARE_OFF = "com.dars.my_tutor_app.CALL_SHARE_OFF"
        const val HANG_UP = "com.dars.my_tutor_app.CALL_HANG_UP"
        private const val ID = 7101

        /** True once the service runs as "screen capture" (the app may start capturing then). */
        @Volatile var shareReady = false

        /** Set by MainActivity: passes "Hang up" to the call screen. */
        var onHangUp: (() -> Unit)? = null
    }

    private var video = false
    private var sharing = false
    private var title = "Dars"
    private var text = ""
    private var hangUpLabel = "Hang up"

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            HANG_UP -> {
                onHangUp?.invoke()
                return START_NOT_STICKY
            }
            SHARE_ON -> {
                sharing = true
                shareReady = false
                shareReady = show()
            }
            SHARE_OFF -> {
                sharing = false
                shareReady = false
                show()
            }
            else -> {
                video = intent?.getBooleanExtra("video", false) ?: false
                title = intent?.getStringExtra("title")?.takeIf { it.isNotEmpty() } ?: "Dars"
                text = intent?.getStringExtra("text") ?: ""
                hangUpLabel = intent?.getStringExtra("hangUp")?.takeIf { it.isNotEmpty() } ?: "Hang up"
                show()
            }
        }
        return START_NOT_STICKY
    }

    private fun granted(p: String) = Build.VERSION.SDK_INT < 23 || checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    /** Shows the notification and (re)starts as a foreground service with the types this call needs. */
    @Suppress("DEPRECATION")
    private fun show(): Boolean {
        DarsNotify.createChannels(this)
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) f = f or PendingIntent.FLAG_IMMUTABLE
        val hang = PendingIntent.getService(this, 8, Intent(this, CallService::class.java).setAction(HANG_UP), f)
        val n = DarsNotify.builder(this, DarsNotify.ONGOING)
            .setSmallIcon(android.R.drawable.sym_action_call)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setContentIntent(DarsNotify.openApp(this, 9, false, emptyMap()))
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, hangUpLabel, hang)
            .build()
        var types = 0
        if (Build.VERSION.SDK_INT >= 30) {
            if (granted("android.permission.RECORD_AUDIO")) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            if (video && granted("android.permission.CAMERA")) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
        }
        if (sharing && Build.VERSION.SDK_INT >= 29) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
        return try {
            if (Build.VERSION.SDK_INT >= 29 && types != 0) startForeground(ID, n, types) else startForeground(ID, n)
            true
        } catch (e: Exception) {
            // A type was refused (e.g. a permission missing on Android 14): keep what can run.
            try {
                if (Build.VERSION.SDK_INT >= 29 && sharing) {
                    startForeground(ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
                    true
                } else if (Build.VERSION.SDK_INT >= 30) {
                    startForeground(ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
                    !sharing
                } else {
                    startForeground(ID, n)
                    true
                }
            } catch (e2: Exception) {
                stopSelf()
                false
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onDestroy() {
        shareReady = false
        if (Build.VERSION.SDK_INT >= 24) stopForeground(Service.STOP_FOREGROUND_REMOVE) else stopForeground(true)
        super.onDestroy()
    }
}
