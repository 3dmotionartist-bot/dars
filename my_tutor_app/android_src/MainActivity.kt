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

        /** The Dars window has the screen focus: false while it sits behind the lock screen or another app. */
        @Volatile var focused = false
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
    private var playRate = 1.0f

    private fun applyRate() {
        val p = player ?: return
        if (Build.VERSION.SDK_INT < 23) return
        try {
            if (p.isPlaying) p.playbackParams = p.playbackParams.setSpeed(playRate)
        } catch (ignored: Exception) {
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        readIntent(intent)
    }

    // A volume button silences an incoming call's ring and vibration (the call keeps ringing on screen).
    override fun onKeyDown(keyCode: Int, event: android.view.KeyEvent?): Boolean {
        if ((keyCode == android.view.KeyEvent.KEYCODE_VOLUME_UP || keyCode == android.view.KeyEvent.KEYCODE_VOLUME_DOWN) &&
            DarsNotify.Ringing.active
        ) {
            DarsNotify.Ringing.silence(this)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onResume() {
        super.onResume()
        foreground = true
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        focused = hasFocus
    }

    override fun onPause() {
        foreground = false
        focused = false
        super.onPause()
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        foreground = false
        focused = false
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
                        // The app heard the caller hang up: always in the notification bar (a missed call must
                        // not depend on guessing whether Dars is on screen). Same id as the "missed_call" push,
                        // so the two never show twice.
                        DarsNotify.missedCall(
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
                    "isXiaomi" -> result.success(isXiaomi())
                    "callSetup" -> result.success(callSetup())
                    "openSetup" -> {
                        openSetup(call.argument<String>("step") ?: "")
                        result.success(null)
                    }
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
                    "setAccount" -> {
                        // Which account this phone's pushes are for; '' = signed out: drop them, clear the bar.
                        val id = call.argument<String>("id") ?: ""
                        DarsNotify.prefs(this).edit().putString("account", id).apply()
                        if (id.isEmpty()) DarsNotify.clearAll(this)
                        result.success(true)
                    }
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
                    // Round G2: voice notes — where it is, jump, faster.
                    "playPos" -> {
                        val p = player
                        result.success(
                            if (p == null) listOf(-1, 0)
                            else try { listOf(p.currentPosition, p.duration) } catch (e: Exception) { listOf(-1, 0) }
                        )
                    }
                    "playSeek" -> {
                        try { player?.seekTo(call.argument<Int>("ms") ?: 0) } catch (ignored: Exception) {}
                        result.success(true)
                    }
                    "playSpeed" -> {
                        playRate = (call.argument<Double>("rate") ?: 1.0).toFloat()
                        applyRate()
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
                applyRate()
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

    /**
     * May an incoming call fill the locked screen? Android 14+ has its own switch, and Xiaomi (MIUI / HyperOS)
     * adds "Show on lock screen", off for newly installed apps (phone test, 19 Nov 2026). Both must be on.
     */
    private fun fullScreenOk(): Boolean = androidFullScreenOk() && miuiLockScreenOk()

    private fun androidFullScreenOk(): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        return try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            nm.javaClass.getMethod("canUseFullScreenIntent").invoke(nm) as Boolean
        } catch (e: Exception) {
            true
        }
    }

    private fun isXiaomi(): Boolean {
        val m = (Build.MANUFACTURER ?: "").lowercase()
        val b = (Build.BRAND ?: "").lowercase()
        return m.contains("xiaomi") || b == "xiaomi" || b == "redmi" || b == "poco"
    }

    /** Xiaomi's "Show on lock screen" (its own app-op 10020). Unknown → treated as on, so nobody is nagged by mistake. */
    private fun miuiLockScreenOk(): Boolean {
        if (!isXiaomi()) return true
        return try {
            val ops = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
            val check = ops.javaClass.getMethod(
                "checkOpNoThrow", Int::class.javaPrimitiveType, Int::class.javaPrimitiveType, String::class.java,
            )
            (check.invoke(ops, 10020, applicationInfo.uid, packageName) as Int) == android.app.AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            true
        }
    }

    /** Opens the page where calls can be allowed on the lock screen: Xiaomi's own Dars permissions first. */
    private fun openFullScreenSettings() {
        val pkg = Uri.parse("package:$packageName")
        val tries = mutableListOf<Intent>()
        if (isXiaomi() && !miuiLockScreenOk()) {
            tries.add(
                Intent("miui.intent.action.APP_PERM_EDITOR")
                    .setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity")
                    .putExtra("extra_pkgname", packageName),
            )
            tries.add(Intent("miui.intent.action.APP_PERM_EDITOR").putExtra("extra_pkgname", packageName))
        }
        tries += listOf(
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

    // ------------------------------------------------------------ "Receive calls" setup (26 Nov 2026)
    /**
     * What this phone needs so calls ring while it sleeps (phone test, 25–26 Nov 2026: with Xiaomi's Autostart
     * off and Dars not exempt from battery saving, calls to a sleeping phone did not ring).
     * autostart: "on" / "off" (Xiaomi can tell), "unknown" (a brand with its own Autostart page that can't be
     * read), "none" (no such page on this phone).
     */
    private fun callSetup(): Map<String, Any> {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val notifications = try {
            val on = Build.VERSION.SDK_INT < 24 || nm.areNotificationsEnabled()
            val ch = if (Build.VERSION.SDK_INT >= 26) nm.getNotificationChannel(DarsNotify.CALLS) else null
            on && (ch == null || ch.importance != android.app.NotificationManager.IMPORTANCE_NONE)
        } catch (e: Exception) {
            true
        }
        val battery = try {
            val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            pm.isIgnoringBatteryOptimizations(packageName)
        } catch (e: Exception) {
            true
        }
        return mapOf(
            "notifications" to notifications,
            "fullScreen" to fullScreenOk(),
            "battery" to battery,
            "autostart" to autostartState(),
            "brand" to brand(),
        )
    }

    private fun brand(): String {
        val m = "${Build.MANUFACTURER ?: ""} ${Build.BRAND ?: ""}".lowercase()
        return when {
            isXiaomi() -> "xiaomi"
            m.contains("oppo") || m.contains("realme") || m.contains("oneplus") -> "oppo"
            m.contains("vivo") || m.contains("iqoo") -> "vivo"
            m.contains("huawei") || m.contains("honor") -> "huawei"
            m.contains("asus") -> "asus"
            else -> "other"
        }
    }

    private fun autostartState(): String {
        val b = brand()
        if (b == "other") return "none"
        if (b != "xiaomi") return "unknown"
        return try {
            val ops = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
            val check = ops.javaClass.getMethod(
                "checkOpNoThrow", Int::class.javaPrimitiveType, Int::class.javaPrimitiveType, String::class.java,
            )
            // Xiaomi's Autostart is its own app-op 10008: "ignore" while off (phone test, 26 Nov 2026).
            val mode = check.invoke(ops, 10008, applicationInfo.uid, packageName) as Int
            if (mode == android.app.AppOpsManager.MODE_IGNORED) "off" else "on"
        } catch (e: Exception) {
            "unknown"
        }
    }

    private fun autostartPages(): List<Intent> {
        fun page(pkg: String, cls: String) = Intent().setComponent(android.content.ComponentName(pkg, cls))
        return when (brand()) {
            "xiaomi" -> listOf(page("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"))
            "oppo" -> listOf(
                page("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
                page("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
                page("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            )
            "vivo" -> listOf(
                page("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
                page("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
            )
            "huawei" -> listOf(
                page("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
                page("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
                page("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            )
            "asus" -> listOf(page("com.asus.mobilemanager", "com.asus.mobilemanager.autostart.AutoStartActivity"))
            else -> emptyList()
        }
    }

    /** Opens the phone's page for one step: notifications, fullScreen, battery or autostart. */
    @android.annotation.SuppressLint("BatteryLife")
    private fun openSetup(step: String) {
        if (step == "fullScreen") {
            openFullScreenSettings()
            return
        }
        val pkg = Uri.parse("package:$packageName")
        val tries = mutableListOf<Intent>()
        when (step) {
            "notifications" -> {
                if (Build.VERSION.SDK_INT >= 33 &&
                    checkSelfPermission("android.permission.POST_NOTIFICATIONS") != PackageManager.PERMISSION_GRANTED &&
                    shouldShowRequestPermissionRationale("android.permission.POST_NOTIFICATIONS")
                ) {
                    askPermission()
                    return
                }
                tries.add(Intent("android.settings.APP_NOTIFICATION_SETTINGS").putExtra("android.provider.extra.APP_PACKAGE", packageName))
            }
            "battery" -> {
                tries.add(Intent("android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS", pkg))
                tries.add(Intent("android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS"))
            }
            "autostart" -> tries.addAll(autostartPages())
        }
        tries.add(Intent("android.settings.APPLICATION_DETAILS_SETTINGS", pkg))
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
