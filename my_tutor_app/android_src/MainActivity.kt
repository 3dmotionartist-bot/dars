package com.dars.my_tutor_app

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Dars: rings the phone for incoming calls, shows notifications (DarsNotify), voice notes, the call service
 * (CallService), push tokens (DarsMessagingService) and meeting links.
 * Copied over the generated MainActivity by the GitHub build (see my_tutor_app/tool/prepare_android.sh).
 */
class MainActivity : FlutterActivity() {
    companion object {
        /** True while the app is on screen (push messages for chats / calls are then shown by the app itself). */
        @Volatile var foreground = false
        private var instance: MainActivity? = null

        /** A push said "incoming call" while the app is open: let the app ring (false if it can't). */
        fun deliverIncomingCall(call: Map<String, String>): Boolean {
            val a = instance ?: return false
            val ch = a.channel ?: return false
            Handler(Looper.getMainLooper()).post { ch.invokeMethod("incomingCall", call) }
            return true
        }

        /** "Decline" was tapped in the ringing notification: the open app stops its ringing screen too. */
        fun deliverDeclined(room: String) {
            val ch = instance?.channel ?: return
            Handler(Looper.getMainLooper()).post { ch.invokeMethod("callDeclined", mapOf("room" to room)) }
        }
    }

    private var channel: MethodChannel? = null
    private var pendingAction: String? = null
    private var pendingCall: Map<String, String>? = null
    private var pendingOpen: Map<String, String>? = null
    private var pendingLink: String? = null
    private var proximityLock: PowerManager.WakeLock? = null
    private var recorder: MediaRecorder? = null
    private var recordFile: File? = null
    private var recordStarted = 0L
    private var player: MediaPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        readIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        foreground = true
    }

    override fun onPause() {
        foreground = false
        super.onPause()
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        foreground = false
        releaseProximity()
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readIntent(intent)
    }

    private fun readIntent(i: Intent?) {
        // Meeting links: dars://join?room=...&video=1 (from the call page "Open in the Dars app"), or the shared
        // https link itself (https://3dmotionartist-bot.github.io/dars/call/?room=...) tapped in WhatsApp etc.
        val data = i?.data
        if (data != null && (data.scheme == "dars" ||
                (data.scheme == "https" && data.host == "3dmotionartist-bot.github.io" && (data.path ?: "").contains("/call")))) {
            pendingLink = data.toString()
        }
        val isCall = i != null && i.getBooleanExtra("dars_call", false)
        // Only an incoming call may appear over the lock screen; normal use still needs the phone unlocked.
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(isCall)
            setTurnScreenOn(isCall)
        }
        if (isCall) {
            pendingAction = i?.getStringExtra("dars_action") ?: "open"
            val room = i?.getStringExtra("room") ?: ""
            if (room.isNotEmpty()) {
                pendingCall = mapOf(
                    "action" to (pendingAction ?: "open"),
                    "room" to room,
                    "video" to (i?.getStringExtra("video") ?: "true"),
                    "name" to (i?.getStringExtra("name") ?: ""),
                    "conversation_id" to (i?.getStringExtra("conversation_id") ?: ""),
                    "sent_at" to (i?.getStringExtra("sent_at") ?: ""),
                )
            }
            if (pendingAction == "join") DarsNotify.stopRing(this)
        }
        // A tapped chat / reminder / notice notification: which screen to open.
        val open = i?.getStringExtra("dars_open") ?: ""
        if (open.isNotEmpty()) {
            pendingOpen = mapOf("open" to open, "conversation_id" to (i?.getStringExtra("conversation_id") ?: ""))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DarsNotify.createChannels(this)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dars/ring")
        channel = ch
        CallService.onHangUp = { Handler(Looper.getMainLooper()).post { channel?.invokeMethod("hangUp", null) } }
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "ring" -> {
                        val room = call.argument<String>("room") ?: ""
                        val details: Map<String, String> = if (room.isEmpty()) emptyMap() else mapOf(
                            "room" to room,
                            "video" to (call.argument<String>("video") ?: "true"),
                            "name" to (call.argument<String>("title") ?: ""),
                            "conversation_id" to (call.argument<String>("conversation_id") ?: ""),
                            "sent_at" to "",
                        )
                        DarsNotify.ring(
                            this, call.argument<String>("title") ?: "Dars", call.argument<String>("body") ?: "",
                            call.argument<String>("join") ?: "Join", call.argument<String>("decline") ?: "", details,
                        )
                        result.success(true)
                    }
                    "stop" -> {
                        DarsNotify.stopRing(this)
                        result.success(true)
                    }
                    "missedCall" -> {
                        // The app heard the caller hang up while it was not in front of the person (background,
                        // or behind the lock screen): same notification (same id) as the "missed_call" push,
                        // so the two never show twice.
                        if (!DarsNotify.appVisible(this)) DarsNotify.missedCall(
                            this, call.argument<String>("title") ?: "Dars", call.argument<String>("body") ?: "",
                            call.argument<String>("conversation_id") ?: "",
                        )
                        result.success(true)
                    }
                    "abis" -> {
                        // Which app file fits this phone (arm64 / arm32 / other), for the update download.
                        result.success(Build.SUPPORTED_ABIS.toList())
                    }
                    "versionCode" -> {
                        // Installed version number: 1xxx arm32 file, 2xxx arm64 file, 3xxx all-phones file.
                        val info = packageManager.getPackageInfo(packageName, 0)
                        @Suppress("DEPRECATION")
                        result.success(if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong())
                    }
                    "callEnded" -> {
                        // The call is over (declined, dismissed or hung up): the app needs the phone unlocked again.
                        if (Build.VERSION.SDK_INT >= 27) {
                            setShowWhenLocked(false)
                            setTurnScreenOn(false)
                        }
                        result.success(true)
                    }
                    "notify" -> {
                        DarsNotify.simple(this, call.argument<String>("title") ?: "Dars", call.argument<String>("body") ?: "")
                        result.success(true)
                    }
                    "askPermission" -> {
                        askPermission()
                        result.success(true)
                    }
                    "fullScreenOk" -> result.success(fullScreenOk())
                    "openFullScreenSettings" -> {
                        openFullScreenSettings()
                        result.success(true)
                    }
                    "takeAction" -> {
                        val a = pendingAction
                        pendingAction = null
                        result.success(a)
                    }
                    "takeCall" -> {
                        // Opened from a ringing notification (push): which call, and "open" or "join".
                        val c = pendingCall
                        pendingCall = null
                        pendingAction = null
                        result.success(c)
                    }
                    "takeOpen" -> {
                        val o = pendingOpen
                        pendingOpen = null
                        result.success(o)
                    }
                    "clearChat" -> {
                        DarsNotify.clearChat(this, call.argument<String>("conversation_id") ?: "")
                        result.success(true)
                    }
                    "pushToken" -> pushToken(result)
                    "setBackend" -> {
                        DarsNotify.prefs(this).edit()
                            .putString("backend_url", call.argument<String>("url") ?: "")
                            .putString("backend_key", call.argument<String>("key") ?: "")
                            .putString("lang", call.argument<String>("lang") ?: "ar")
                            .apply()
                        result.success(true)
                    }
                    "callActive" -> {
                        callActive(
                            call.argument<Boolean>("on") ?: false, call.argument<Boolean>("video") ?: false,
                            call.argument<String>("title") ?: "", call.argument<String>("text") ?: "", call.argument<String>("hangUp") ?: "",
                        )
                        result.success(true)
                    }
                    "callShare" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        val i = Intent(this, CallService::class.java).setAction(if (on) CallService.SHARE_ON else CallService.SHARE_OFF)
                        if (on) CallService.shareReady = false
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
                        result.success(CallService.shareReady)
                    }
                    "callShareReady" -> result.success(CallService.shareReady)
                    "proximity" -> {
                        if (call.argument<Boolean>("on") == true) acquireProximity() else releaseProximity()
                        result.success(true)
                    }
                    "takeLink" -> {
                        val l = pendingLink
                        pendingLink = null
                        result.success(l)
                    }
                    "recStart" -> result.success(startRecording())
                    "recStop" -> result.success(stopRecording())
                    "recCancel" -> {
                        cancelRecording()
                        result.success(true)
                    }
                    "play" -> playAudio(call.argument<String>("url") ?: "", result)
                    "stopPlay" -> {
                        stopAudio()
                        result.success(true)
                    }
                    // Older app code paths: screen sharing alone (now part of the call service).
                    "shareStart" -> {
                        val i = Intent(this, CallService::class.java).setAction(CallService.SHARE_ON)
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
                        result.success(true)
                    }
                    "shareStop" -> {
                        val i = Intent(this, CallService::class.java).setAction(CallService.SHARE_OFF)
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("ring_failed", e.message, null)
            }
        }
    }

    // ------------------------------------------------------------ voice notes
    /** Returns "ok", or "permission" when the microphone is not allowed yet (we ask, the user taps again). */
    @Suppress("DEPRECATION")
    private fun startRecording(): String {
        if (Build.VERSION.SDK_INT >= 23 &&
            checkSelfPermission("android.permission.RECORD_AUDIO") != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf("android.permission.RECORD_AUDIO"), 7003)
            return "permission"
        }
        cancelRecording()
        val f = File(cacheDir, "voice_" + System.currentTimeMillis() + ".m4a")
        val r = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(this) else MediaRecorder()
        r.setAudioSource(MediaRecorder.AudioSource.MIC)
        r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        r.setAudioSamplingRate(44100)
        r.setAudioEncodingBitRate(64000)
        r.setOutputFile(f.absolutePath)
        r.prepare()
        r.start()
        recorder = r
        recordFile = f
        recordStarted = System.currentTimeMillis()
        return "ok"
    }

    private fun stopRecording(): Map<String, Any>? {
        val r = recorder ?: return null
        val f = recordFile
        recorder = null
        recordFile = null
        val ms = (System.currentTimeMillis() - recordStarted).toInt()
        try {
            r.stop()
        } catch (e: Exception) {
            r.release()
            f?.delete()
            return null // too short
        }
        r.release()
        if (f == null || !f.exists()) return null
        val bytes = f.readBytes()
        f.delete()
        return mapOf("bytes" to bytes, "ms" to ms, "mime" to "audio/mp4", "ext" to "m4a")
    }

    private fun cancelRecording() {
        val r = recorder ?: return
        recorder = null
        try {
            r.stop()
        } catch (ignored: Exception) {
        }
        r.release()
        recordFile?.delete()
        recordFile = null
    }

    private fun playAudio(url: String, result: MethodChannel.Result) {
        stopAudio()
        if (url.isEmpty()) {
            result.success(-1)
            return
        }
        val p = MediaPlayer()
        var answered = false
        try {
            p.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            p.setDataSource(this, Uri.parse(url))
            p.setOnPreparedListener {
                it.start()
                if (!answered) {
                    answered = true
                    result.success(it.duration)
                }
            }
            p.setOnErrorListener { _, _, _ ->
                if (!answered) {
                    answered = true
                    result.success(-1)
                }
                true
            }
            p.setOnCompletionListener { stopAudio() }
            p.prepareAsync()
            player = p
        } catch (e: Exception) {
            p.release()
            if (!answered) {
                answered = true
                result.success(-1)
            }
        }
    }

    private fun stopAudio() {
        val p = player ?: return
        player = null
        try {
            p.stop()
        } catch (ignored: Exception) {
        }
        p.release()
    }

    private fun askPermission() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission("android.permission.POST_NOTIFICATIONS") != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 7002)
        }
    }

    /** Android 14+: may incoming calls fill the locked screen? Phones (and Xiaomi dual apps) can switch this off. */
    private fun fullScreenOk(): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        return try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            nm.javaClass.getMethod("canUseFullScreenIntent").invoke(nm) as Boolean
        } catch (e: Exception) {
            true
        }
    }

    /** Opens the system page where "full-screen notifications" can be turned on for Dars. */
    private fun openFullScreenSettings() {
        val pkg = Uri.parse("package:$packageName")
        val tries = listOf(
            Intent("android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT", pkg),
            Intent("android.settings.APP_NOTIFICATION_SETTINGS").putExtra("android.provider.extra.APP_PACKAGE", packageName),
            Intent("android.settings.APPLICATION_DETAILS_SETTINGS", pkg),
        )
        for (i in tries) {
            try {
                startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return
            } catch (ignored: Exception) {
            }
        }
    }

    // ------------------------------------------------------------ calls (Round D, D2)
    private fun callActive(on: Boolean, video: Boolean, title: String, text: String, hangUp: String) {
        if (on) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            val i = Intent(this, CallService::class.java).setAction(CallService.START)
                .putExtra("video", video).putExtra("title", title).putExtra("text", text).putExtra("hangUp", hangUp)
            try {
                if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
            } catch (ignored: Exception) {
            }
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            releaseProximity()
            stopService(Intent(this, CallService::class.java))
        }
    }

    @Suppress("DEPRECATION")
    private fun acquireProximity() {
        if (proximityLock?.isHeld == true) return
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (Build.VERSION.SDK_INT >= 21 && pm.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) {
                val l = pm.newWakeLock(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, "dars:proximity")
                l.acquire(4 * 60 * 60 * 1000L)
                proximityLock = l
            }
        } catch (ignored: Exception) {
        }
    }

    private fun releaseProximity() {
        try {
            proximityLock?.let { if (it.isHeld) it.release() }
        } catch (ignored: Exception) {
        }
        proximityLock = null
    }

    // ------------------------------------------------------------ push (Round D, D1)
    private fun pushToken(result: MethodChannel.Result) {
        val saved = DarsNotify.prefs(this).getString("token", null)
        try {
            com.google.firebase.messaging.FirebaseMessaging.getInstance().token.addOnCompleteListener { t ->
                val token = if (t.isSuccessful) t.result else saved
                if (token != null) DarsNotify.prefs(this).edit().putString("token", token).apply()
                result.success(token)
            }
        } catch (e: Exception) {
            // Firebase is not set up in this build (no google-services values): no push, the app works as before.
            result.success(saved)
        }
    }
}
