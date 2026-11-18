package com.dars.my_tutor_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * "Decline" on the ringing call notification, also while the app is closed: stops the ringing and tells the
 * caller's screen at once ("declined") through the call room, the same way the open app does.
 */
class CallActionReceiver : BroadcastReceiver() {
    companion object {
        const val DECLINE = "com.dars.my_tutor_app.DECLINE_CALL"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != DECLINE) return
        val room = intent.getStringExtra("room") ?: ""
        DarsNotify.stopRing(context)
        if (room.isEmpty()) return
        DarsNotify.prefs(context).edit().putString("declined_room", room).apply()
        MainActivity.deliverDeclined(room)
        val p = DarsNotify.prefs(context)
        val url = p.getString("backend_url", "") ?: ""
        val key = p.getString("backend_key", "") ?: ""
        if (url.isEmpty() || key.isEmpty()) return
        val pending = goAsync()
        Thread {
            try {
                val inner = JSONObject().put("from", "decline-" + System.currentTimeMillis()).put("room", room)
                val msg = JSONObject()
                    .put("topic", "dars-call-$room")
                    .put("event", "decline")
                    .put("payload", JSONObject().put("payload", inner))
                val body = JSONObject().put("messages", JSONArray().put(msg)).toString()
                val c = URL("$url/realtime/v1/api/broadcast").openConnection() as HttpURLConnection
                c.requestMethod = "POST"
                c.connectTimeout = 8000
                c.readTimeout = 8000
                c.doOutput = true
                c.setRequestProperty("Content-Type", "application/json")
                c.setRequestProperty("apikey", key)
                c.outputStream.use { it.write(body.toByteArray()) }
                c.responseCode
                c.disconnect()
            } catch (ignored: Exception) {
            } finally {
                pending.finish()
            }
        }.start()
    }
}
