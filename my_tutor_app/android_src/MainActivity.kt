package com.dars.my_tutor_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Dars: rings the phone for incoming calls and shows message notifications.
 * Copied over the generated MainActivity by the GitHub build (see .github/workflows/build.yml).
 * Uses only the Android SDK — no extra libraries.
 */
class MainActivity : FlutterActivity() {
    private val callsChannel = "dars_calls_v1"
    private val messagesChannel = "dars_messages_v1"
    private val callId = 7001
    private var pendingAction: String? = null

    private fun manager(): NotificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        readIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readIntent(intent)
    }

    private fun readIntent(i: Intent?) {
        val isCall = i != null && i.getBooleanExtra("dars_call", false)
        // Only an incoming call may appear over the lock screen; normal use still needs the phone unlocked.
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(isCall)
            setTurnScreenOn(isCall)
        }
        if (isCall) pendingAction = i?.getStringExtra("dars_action") ?: "open"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createChannels()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dars/ring").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "ring" -> {
                        ring(call.argument<String>("title") ?: "Dars", call.argument<String>("body") ?: "", call.argument<String>("join") ?: "Join")
                        result.success(true)
                    }
                    "stop" -> {
                        manager().cancel(callId)
                        result.success(true)
                    }
                    "notify" -> {
                        notifyMessage(call.argument<String>("title") ?: "Dars", call.argument<String>("body") ?: "")
                        result.success(true)
                    }
                    "askPermission" -> {
                        askPermission()
                        result.success(true)
                    }
                    "takeAction" -> {
                        val a = pendingAction
                        pendingAction = null
                        result.success(a)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("ring_failed", e.message, null)
            }
        }
    }

    private fun askPermission() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission("android.permission.POST_NOTIFICATIONS") != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 7002)
        }
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < 26) return
        val ringtone = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        val calls = NotificationChannel(callsChannel, "Calls", NotificationManager.IMPORTANCE_HIGH)
        calls.description = "Incoming voice and video calls"
        calls.setSound(
            ringtone,
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        calls.enableVibration(true)
        calls.vibrationPattern = longArrayOf(0, 1000, 800, 1000, 800)
        calls.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        val messages = NotificationChannel(messagesChannel, "Messages", NotificationManager.IMPORTANCE_HIGH)
        messages.description = "New chat messages"
        manager().createNotificationChannel(calls)
        manager().createNotificationChannel(messages)
    }

    private fun openIntent(action: String, code: Int): PendingIntent {
        val i = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra("dars_call", action != "message")
            .putExtra("dars_action", action)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(this, code, i, flags)
    }

    @Suppress("DEPRECATION")
    private fun builder(channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel) else Notification.Builder(this)

    @Suppress("DEPRECATION")
    private fun ring(title: String, body: String, joinLabel: String) {
        val open = openIntent("open", 1)
        val b = builder(callsChannel)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(Notification.CATEGORY_CALL)
            .setPriority(Notification.PRIORITY_MAX)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(open)
            .setFullScreenIntent(open, true)
            .setAutoCancel(true)
            .setOngoing(true)
            .addAction(android.R.drawable.sym_action_call, joinLabel, openIntent("join", 2))
        if (Build.VERSION.SDK_INT >= 26) {
            b.setTimeoutAfter(45000)
        } else {
            b.setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE), AudioManager.STREAM_RING)
            b.setVibrate(longArrayOf(0, 1000, 800, 1000, 800))
        }
        val n = b.build()
        n.flags = n.flags or Notification.FLAG_INSISTENT
        manager().notify(callId, n)
    }

    @Suppress("DEPRECATION")
    private fun notifyMessage(title: String, body: String) {
        val b = builder(messagesChannel)
            .setSmallIcon(android.R.drawable.sym_action_chat)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(Notification.PRIORITY_HIGH)
            .setContentIntent(openIntent("message", 3))
            .setAutoCancel(true)
        if (Build.VERSION.SDK_INT < 26) b.setDefaults(Notification.DEFAULT_ALL)
        manager().notify((System.currentTimeMillis() % 100000).toInt() + 100, b.build())
    }
}
