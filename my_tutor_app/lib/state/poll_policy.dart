/// How often the app reloads chats by itself, as a safety net for live updates (Stage 3 A2).
///
/// - App in the background: never (one reload happens when it comes back).
/// - Live updates connected: every 90 seconds (they bring everything; this only catches a missed one).
/// - Live updates down: every 20 seconds.
Duration? fallbackReloadEvery({required bool foreground, required bool realtimeConnected}) {
  if (!foreground) return null;
  return realtimeConnected ? const Duration(seconds: 90) : const Duration(seconds: 20);
}

/// While live updates are down, every [every]th fallback reload is a full one (picks up "read" ticks).
bool fullReloadDue({required bool realtimeConnected, required int tick, int every = 5}) =>
    !realtimeConnected && tick > 0 && tick % every == 0;

/// The later of two server times (ISO text), used as "loaded up to" for the next fallback reload.
String? laterServerTime(String? a, String? b) {
  if (a == null) return b;
  if (b == null) return a;
  final da = DateTime.tryParse(a), db = DateTime.tryParse(b);
  if (da == null) return b;
  if (db == null) return a;
  return db.isAfter(da) ? b : a;
}
