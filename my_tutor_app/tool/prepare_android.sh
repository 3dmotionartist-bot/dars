#!/usr/bin/env bash
# Generates the Android and web platform folders and adds Dars' own Android parts.
# Used by both GitHub workflows (build.yml on main, check.yml on other branches), so the branch check
# compiles exactly what main will ship. Run from my_tutor_app/.
#
# Optional: GOOGLE_SERVICES_JSON (repository secret, the google-services.json from Firebase) turns on push
# notifications. Without it the app builds and works as before, just without push.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create --org com.dars --project-name my_tutor_app --platforms=android,web .
M=android/app/src/main/AndroidManifest.xml
sed -i 's/android:label="my_tutor_app"/android:label="Dars"/' "$M"

perm() { grep -q "android.permission.$1\"" "$M" || sed -i "s#<application#<uses-permission android:name=\"android.permission.$1\"/>\n    <application#" "$M"; }
# Release builds need this to reach the backend
perm INTERNET
# Calls open in the browser: let the app find one
grep -q 'android:scheme="https"' "$M" || \
  sed -i 's#<queries>#<queries>\n        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>#' "$M"
# Ringing phone, notifications, the call service (Round D: microphone + camera + screen capture, Android 14 rules)
for p in POST_NOTIFICATIONS USE_FULL_SCREEN_INTENT VIBRATE WAKE_LOCK FOREGROUND_SERVICE \
         FOREGROUND_SERVICE_MEDIA_PROJECTION FOREGROUND_SERVICE_MICROPHONE FOREGROUND_SERVICE_CAMERA; do
  perm "$p"
done
# In-app voice / video calls (flutter_webrtc): camera + microphone
for p in CAMERA RECORD_AUDIO MODIFY_AUDIO_SETTINGS ACCESS_NETWORK_STATE CHANGE_NETWORK_STATE; do perm "$p"; done
grep -q 'android.hardware.camera' "$M" || \
  sed -i 's#<application#<uses-feature android:name="android.hardware.camera" android:required="false"/>\n    <application#' "$M"
sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 23/; s/minSdkVersion flutter.minSdkVersion/minSdkVersion 23/' android/app/build.gradle* || true
grep -n "minSdk" android/app/build.gradle* || true

# Dars' own Android code (android_src/): MainActivity, notifications, call service, push service, decline button.
K=android/app/src/main/kotlin/com/dars/my_tutor_app
cp android_src/*.kt "$K/"
grep -q '.CallService' "$M" || \
  sed -i 's#</application>#    <service android:name=".CallService" android:exported="false" android:foregroundServiceType="microphone|camera|mediaProjection"/>\n    </application>#' "$M"
grep -q '.DarsMessagingService' "$M" || \
  sed -i 's#</application>#    <service android:name=".DarsMessagingService" android:exported="false">\n            <intent-filter><action android:name="com.google.firebase.MESSAGING_EVENT"/></intent-filter>\n        </service>\n    </application>#' "$M"
grep -q '.CallActionReceiver' "$M" || \
  sed -i 's#</application>#    <receiver android:name=".CallActionReceiver" android:exported="false"/>\n    </application>#' "$M"

# Meeting links (dars://join?room=...) open the app
grep -q 'android:scheme="dars"' "$M" || \
  sed -i 's#</activity>#    <intent-filter>\n                <action android:name="android.intent.action.VIEW"/>\n                <category android:name="android.intent.category.DEFAULT"/>\n                <category android:name="android.intent.category.BROWSABLE"/>\n                <data android:scheme="dars" android:host="join"/>\n            </intent-filter>\n        </activity>#' "$M"
# Shared meeting links (https://3dmotionartist-bot.github.io/dars/call/?room=...) open the app directly.
# Android checks https://3dmotionartist-bot.github.io/.well-known/assetlinks.json against the signing key.
grep -q 'android:autoVerify' "$M" || \
  sed -i 's#</activity>#    <intent-filter android:autoVerify="true">\n                <action android:name="android.intent.action.VIEW"/>\n                <category android:name="android.intent.category.DEFAULT"/>\n                <category android:name="android.intent.category.BROWSABLE"/>\n                <data android:scheme="https" android:host="3dmotionartist-bot.github.io" android:pathPrefix="/dars/call"/>\n            </intent-filter>\n        </activity>#' "$M"
printf -- '-keep class org.webrtc.** { *; }\n-dontwarn org.webrtc.**\n-keep class com.cloudwebrtc.webrtc.** { *; }\n' > android/app/proguard-rules.pro

# Push notifications (Round D): Firebase Cloud Messaging, used directly by DarsMessagingService.kt.
# 23.4.1 is built with Kotlin 1.8, the same as Flutter 3.27's Android template.
for f in android/app/build.gradle android/app/build.gradle.kts; do
  if [ -f "$f" ] && ! grep -q 'firebase-messaging' "$f"; then
    printf '\ndependencies {\n    implementation("com.google.firebase:firebase-messaging:23.4.1")\n}\n' >> "$f"
  fi
done
# Firebase settings from google-services.json (what the Google services Gradle plugin would generate):
# Firebase starts by itself when these values are in the app. Missing secret → no push, nothing else changes.
if [ -n "${GOOGLE_SERVICES_JSON:-}" ]; then
  mkdir -p android/app/src/main/res/values
  printf '%s' "$GOOGLE_SERVICES_JSON" | python3 -c '
import json, sys
from xml.sax.saxutils import escape
g = json.load(sys.stdin)
p = g["project_info"]
c = next(x for x in g["client"] if x["client_info"]["android_client_info"]["package_name"] == "com.dars.my_tutor_app")
v = {
  "google_app_id": c["client_info"]["mobilesdk_app_id"],
  "gcm_defaultSenderId": p["project_number"],
  "google_api_key": c["api_key"][0]["current_key"],
  "google_crash_reporting_api_key": c["api_key"][0]["current_key"],
  "project_id": p["project_id"],
  "google_storage_bucket": p.get("storage_bucket", ""),
}
print("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>")
for k, x in v.items():
  print("    <string name=\"%s\" translatable=\"false\">%s</string>" % (k, escape(str(x))))
print("</resources>")
' > android/app/src/main/res/values/dars_firebase.xml
  echo "Push notifications: Firebase settings added for project $(grep project_id android/app/src/main/res/values/dars_firebase.xml | sed 's/<[^>]*>//g' | xargs)"
else
  echo "::warning::GOOGLE_SERVICES_JSON is not set: this build has no push notifications (everything else works)."
fi
cat "$M"
