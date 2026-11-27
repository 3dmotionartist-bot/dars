package com.dars.my_tutor_app

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Round D (D1): push notifications from the push-notifications edge function (Firebase Cloud Messaging).
 * They are "data" messages, so this code shows them the same way whether the app is open, in the background
 * or closed: incoming calls ring full screen, messages are grouped per chat, reminders and notices as usual.
 * While the app is open on screen it shows chats and calls itself, so nothing is doubled here.
 */
class DarsMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        // The app sends it to the server the next time it opens (Backend: save_device_token).
        DarsNotify.prefs(this).edit().putString("token", token).apply()
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val d = message.data
        val type = d["type"] ?: return
        val ar = (DarsNotify.prefs(this).getString("lang", "ar") ?: "ar") != "en"
        // Round H1: server notifications carry their Arabic (title_ar / body_ar) in their data.
        val title = (if (ar) d["title_ar"] else null) ?: d["title"] ?: "Dars"
        val body = (if (ar) d["body_ar"] else null) ?: d["body"] ?: ""
        val open = DarsNotify.appVisible(this)
        // One short line per push (no message text), so a phone log shows what arrived and what was done.
        val out = DarsNotify.signedOut(this)
        android.util.Log.i("DarsPush", "type=$type open=$open signedOut=$out room=${d["room"] ?: ""} conv=${d["conversation_id"] ?: ""}")
        // Signed out here: the server may still have this phone's address (sign-out while offline), but the
        // old account's calls and messages must not show on it.
        if (out) return
        when (type) {
            "call" -> {
                val room = d["room"] ?: return
                if (DarsNotify.prefs(this).getString("declined_room", "") == room) return
                val call = mapOf(
                    "room" to room,
                    "video" to (d["video"] ?: "true"),
                    "name" to (d["name"] ?: title),
                    "conversation_id" to (d["conversation_id"] ?: ""),
                    "sent_at" to (d["sent_at"] ?: ""),
                )
                // App open: its own ringing screen (it may have missed the call through live updates).
                if (open && MainActivity.deliverIncomingCall(call)) return
                DarsNotify.ring(this, title, body, if (ar) "انضم" else "Join", if (ar) "رفض" else "Decline", call)
            }
            "missed_call" -> {
                DarsNotify.stopRing(this, d["room"] ?: "")
                // Always in the notification bar: the in-app notice can be hidden (behind the lock screen).
                DarsNotify.missedCall(this, title, body, d["conversation_id"] ?: "")
            }
            "message" -> if (!open) DarsNotify.message(this, d["conversation_id"] ?: "", title, body)
            "reminder" -> DarsNotify.notice(
                this, DarsNotify.REMINDERS, 30000 + ((d["lesson_id"] ?: "") + (d["kind"] ?: "")).hashCode().and(0xffff),
                title, body, true, mapOf("dars_open" to "lessons"),
            )
            else -> if (!open) DarsNotify.notice(
                this, DarsNotify.GENERAL, 60000 + (d["notification_id"] ?: body).hashCode().and(0xffff),
                title, body, d["urgent"] == "true", mapOf("dars_open" to "notifications"),
            )
        }
    }
}
