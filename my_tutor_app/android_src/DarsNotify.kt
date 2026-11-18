package com.dars.my_tutor_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import android.os.Build
import org.json.JSONArray

/**
 * Dars notifications, shared by the open app (MainActivity) and the push service (DarsMessagingService):
 * the ringing incoming call, "missed call", chat messages grouped per chat, lesson reminders and other notices.
 * Uses only the Android SDK.
 */
object DarsNotify {
    const val CALLS = "dars_calls_v1"
    const val MESSAGES = "dars_messages_v1"
    const val REMINDERS = "dars_reminders_v1"
    const val GENERAL = "dars_general_v1"
    const val ONGOING = "dars_ongoing_call_v1"
    const val RING_ID = 7001
    private const val GROUP = "dars_chats"
    private const val PREFS = "dars_push"

    fun manager(c: Context): NotificationManager = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun createChannels(c: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val m = manager(c)
        val ringtone = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        val calls = NotificationChannel(CALLS, "Calls", NotificationManager.IMPORTANCE_HIGH)
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
        val messages = NotificationChannel(MESSAGES, "Messages", NotificationManager.IMPORTANCE_HIGH)
        messages.description = "New chat messages and missed calls"
        val reminders = NotificationChannel(REMINDERS, "Lesson reminders", NotificationManager.IMPORTANCE_HIGH)
        reminders.description = "24 hours, 1 hour and 10 minutes before a lesson"
        val general = NotificationChannel(GENERAL, "Bookings and payments", NotificationManager.IMPORTANCE_DEFAULT)
        general.description = "Bookings, payments, payouts and other notices"
        val ongoing = NotificationChannel(ONGOING, "Call in progress", NotificationManager.IMPORTANCE_LOW)
        ongoing.description = "Shown while you are in a call"
        ongoing.setSound(null, null)
        for (ch in listOf(calls, messages, reminders, general, ongoing)) m.createNotificationChannel(ch)
    }

    @Suppress("DEPRECATION")
    fun builder(c: Context, channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, channel) else Notification.Builder(c)

    private fun flags(): Int {
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) f = f or PendingIntent.FLAG_IMMUTABLE
        return f
    }

    /** Opens the app. [extras] go to the app (call details, which chat to open). */
    fun openApp(c: Context, code: Int, call: Boolean, extras: Map<String, String>): PendingIntent {
        val i = Intent(c, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra("dars_call", call)
        for ((k, v) in extras) i.putExtra(k, v)
        return PendingIntent.getActivity(c, code, i, flags())
    }

    // ------------------------------------------------------------ incoming call
    /** Rings like a phone call (full screen over the lock screen), for up to 45 seconds. */
    @Suppress("DEPRECATION")
    fun ring(c: Context, title: String, body: String, joinLabel: String, declineLabel: String, call: Map<String, String>) {
        createChannels(c)
        val open = openApp(c, 1, true, call + ("dars_action" to "open"))
        val b = builder(c, CALLS)
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
        if (declineLabel.isNotEmpty() && (call["room"] ?: "").isNotEmpty()) {
            val d = Intent(c, CallActionReceiver::class.java).setAction(CallActionReceiver.DECLINE)
            for ((k, v) in call) d.putExtra(k, v)
            b.addAction(android.R.drawable.ic_menu_close_clear_cancel, declineLabel, PendingIntent.getBroadcast(c, 4, d, flags()))
        }
        b.addAction(android.R.drawable.sym_action_call, joinLabel, openApp(c, 2, true, call + ("dars_action" to "join")))
        if (Build.VERSION.SDK_INT >= 26) {
            b.setTimeoutAfter(45000)
        } else {
            b.setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE), AudioManager.STREAM_RING)
            b.setVibrate(longArrayOf(0, 1000, 800, 1000, 800))
        }
        val n = b.build()
        n.flags = n.flags or Notification.FLAG_INSISTENT
        prefs(c).edit().putString("ringing_room", call["room"] ?: "").apply()
        manager(c).notify(RING_ID, n)
    }

    fun stopRing(c: Context, room: String = "") {
        val ringing = prefs(c).getString("ringing_room", "") ?: ""
        if (room.isEmpty() || room == ringing) {
            manager(c).cancel(RING_ID)
            prefs(c).edit().remove("ringing_room").apply()
        }
    }

    fun missedCall(c: Context, title: String, body: String, conversationId: String) {
        createChannels(c)
        val b = builder(c, MESSAGES)
            .setSmallIcon(android.R.drawable.sym_call_missed)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(openApp(c, 5, false, mapOf("dars_open" to "chat", "conversation_id" to conversationId)))
            .setAutoCancel(true)
        if (Build.VERSION.SDK_INT >= 30) b.setCategory(Notification.CATEGORY_MISSED_CALL)
        manager(c).notify(9000 + (conversationId.hashCode() and 0x3ff), b.build())
    }

    // ------------------------------------------------------------ chat messages, one notification per chat
    private fun chatId(conversationId: String) = 20000 + (conversationId.hashCode() and 0xffff)

    @Suppress("DEPRECATION")
    fun message(c: Context, conversationId: String, title: String, line: String) {
        createChannels(c)
        val key = "chat_$conversationId"
        val lines = try { JSONArray(prefs(c).getString(key, "[]")) } catch (e: Exception) { JSONArray() }
        lines.put(line)
        while (lines.length() > 6) lines.remove(0)
        prefs(c).edit().putString(key, lines.toString()).apply()
        val style = Notification.InboxStyle()
        for (i in 0 until lines.length()) style.addLine(lines.optString(i))
        if (lines.length() > 1) style.setSummaryText("${lines.length()}")
        val b = builder(c, MESSAGES)
            .setSmallIcon(android.R.drawable.sym_action_chat)
            .setContentTitle(title)
            .setContentText(line)
            .setStyle(style)
            .setNumber(lines.length())
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setPriority(Notification.PRIORITY_HIGH)
            .setGroup(GROUP)
            .setContentIntent(openApp(c, chatId(conversationId), false, mapOf("dars_open" to "chat", "conversation_id" to conversationId)))
            .setAutoCancel(true)
        if (Build.VERSION.SDK_INT < 26) b.setDefaults(Notification.DEFAULT_ALL)
        manager(c).notify(chatId(conversationId), b.build())
        if (Build.VERSION.SDK_INT >= 24) {
            val summary = builder(c, MESSAGES)
                .setSmallIcon(android.R.drawable.sym_action_chat)
                .setContentTitle("Dars")
                .setGroup(GROUP)
                .setGroupSummary(true)
                .setAutoCancel(true)
                .build()
            manager(c).notify(19999, summary)
        }
    }

    fun clearChat(c: Context, conversationId: String) {
        prefs(c).edit().remove("chat_$conversationId").apply()
        manager(c).cancel(chatId(conversationId))
    }

    // ------------------------------------------------------------ reminders and other notices
    @Suppress("DEPRECATION")
    fun notice(c: Context, channel: String, id: Int, title: String, body: String, urgent: Boolean, extras: Map<String, String>) {
        createChannels(c)
        val b = builder(c, channel)
            .setSmallIcon(if (channel == REMINDERS) android.R.drawable.ic_lock_idle_alarm else android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setPriority(if (urgent) Notification.PRIORITY_HIGH else Notification.PRIORITY_DEFAULT)
            .setContentIntent(openApp(c, id, false, extras))
            .setAutoCancel(true)
        if (Build.VERSION.SDK_INT < 26) b.setDefaults(Notification.DEFAULT_ALL)
        manager(c).notify(id, b.build())
    }

    /** A message notice from the open app (used before push existed; kept for the web-free fallback). */
    @Suppress("DEPRECATION")
    fun simple(c: Context, title: String, body: String) {
        createChannels(c)
        val b = builder(c, MESSAGES)
            .setSmallIcon(android.R.drawable.sym_action_chat)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(Notification.PRIORITY_HIGH)
            .setContentIntent(openApp(c, 3, false, mapOf("dars_open" to "notifications")))
            .setAutoCancel(true)
        if (Build.VERSION.SDK_INT < 26) b.setDefaults(Notification.DEFAULT_ALL)
        manager(c).notify((System.currentTimeMillis() % 100000).toInt() + 100, b.build())
    }
}
