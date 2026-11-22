/// Round D: the call decisions that need no phone, kept here so they can be unit-tested.
///
/// - D0: what a failed connection looked like (which routes each side found, whether the relay answered),
///   and which message to show.
/// - D3: rebuilding the connection on both sides ("restart" with a counter), retry timing, "is this the same
///   person rejoining?".
/// - D4: "is this call still ringing?" without trusting the phone's clock.
library;

/// The kind of route an ICE candidate offers: 'host' (same network), 'srflx' / 'prflx' (through the router),
/// 'relay' (through the call relay). '' if the text is not a candidate.
String candidateType(String? candidate) {
  final m = RegExp(r'\btyp\s+(host|srflx|prflx|relay)\b').firstMatch(candidate ?? '');
  return m?.group(1) ?? '';
}

/// Why the call could not connect, as far as one side can tell.
enum FailureKind {
  /// No relay is set up at all and the direct route was blocked.
  noRelay,

  /// A relay is set up, but this side never got a relay route from it (allowance used up, wrong or expired
  /// password, relay unreachable).
  relayNotAnswering,

  /// A relay route was available and it still failed (the network blocks even the relay, or the other side
  /// is unreachable).
  network,
}

FailureKind failureKind({required bool relayConfigured, required bool relayGathered}) {
  if (!relayConfigured) return FailureKind.noRelay;
  if (!relayGathered) return FailureKind.relayNotAnswering;
  return FailureKind.network;
}

/// Connection details collected during a call; kept when it fails ("details" line, saved on the phone).
class IceDiag {
  final Map<String, int> local = {};
  final Map<String, int> remote = {};
  String gathering = '';
  String iceState = '';
  String selected = ''; // e.g. "relay → srflx"
  String relayHost = '';
  String lastError = '';
  int attempts = 0;

  bool get relayGathered => (local['relay'] ?? 0) > 0;

  void addLocal(String? candidate) {
    final t = candidateType(candidate);
    if (t.isNotEmpty) local[t] = (local[t] ?? 0) + 1;
  }

  void addRemote(String? candidate) {
    final t = candidateType(candidate);
    if (t.isNotEmpty) remote[t] = (remote[t] ?? 0) + 1;
  }

  /// Starts over for a rebuilt connection (the relay host and the attempt count stay).
  void resetRoutes() {
    local.clear();
    remote.clear();
    gathering = '';
    iceState = '';
    selected = '';
  }

  static String _counts(Map<String, int> m) => m.isEmpty
      ? 'none'
      : [for (final k in const ['host', 'srflx', 'prflx', 'relay']) if ((m[k] ?? 0) > 0) '$k ${m[k]}'].join(', ');

  /// One short line, e.g. "me: host 2, srflx 1 · them: host 1 · relay: no (turn.example.com) · ice failed".
  String summary() => [
        'me: ${_counts(local)}',
        'them: ${_counts(remote)}',
        'relay: ${relayGathered ? 'yes' : 'no'}${relayHost.isEmpty ? '' : ' ($relayHost)'}',
        if (selected.isNotEmpty) 'pair: $selected',
        if (gathering.isNotEmpty) 'gather $gathering',
        if (iceState.isNotEmpty) 'ice $iceState',
        if (attempts > 0) 'tries $attempts',
        if (lastError.isNotEmpty) 'err: $lastError',
      ].join(' · ');

  Map<String, dynamic> toJson() => {
        'local': local,
        'remote': remote,
        'relay': relayGathered,
        'relay_host': relayHost,
        'selected': selected,
        'gathering': gathering,
        'ice': iceState,
        'attempts': attempts,
        'error': lastError,
      };
}

/// The relay's host name from the ICE server list ('' when there is no relay).
String relayHostOf(List<Map<String, dynamic>> iceServers) {
  for (final s in iceServers) {
    final urls = s['urls'];
    for (final u in urls is List ? urls : [urls]) {
      final m = RegExp(r'^turns?:([^:?]+)').firstMatch('$u');
      if (m != null) return m.group(1)!;
    }
  }
  return '';
}

/// D3: wait before the n-th automatic retry (0 = right away), within a 60-second window.
Duration retryDelay(int n) {
  const steps = [0, 3, 6, 12, 20];
  return Duration(seconds: steps[n.clamp(0, steps.length - 1)]);
}

/// D3: keep retrying by itself while the first failure is less than [window] ago.
bool keepRetrying(DateTime firstFailure, DateTime now, {Duration window = const Duration(seconds: 60)}) =>
    now.difference(firstFailure) < window;

/// D3: what to do with an offer that carries [offerGen] when this side is at [myGen].
/// Older apps send no counter: their offers are always taken ("legacy").
enum OfferAction { ignore, accept, rebuildThenAccept }

OfferAction offerAction({required bool peerHasRestart, required int myGen, required int offerGen, required bool connectionUsed}) {
  if (!peerHasRestart) return OfferAction.accept;
  if (offerGen < myGen) return OfferAction.ignore; // an offer for a connection both sides already dropped
  if (offerGen > myGen && connectionUsed) return OfferAction.rebuildThenAccept;
  return OfferAction.accept;
}

/// D3: the counter for a new "restart": higher than anything either side has used.
int nextGen(int mine, int theirs) => (mine > theirs ? mine : theirs) + 1;

/// D4: a "hello" from a new id while this side still has a partner. Is it the same person coming back (the
/// app crashed, the page was reloaded)? Then take them instead of answering "call is full".
bool isRejoin({
  required String helloUid,
  required String partnerUid,
  required Duration sincePartnerSeen,
  Duration stale = const Duration(seconds: 15),
}) {
  if (helloUid.isNotEmpty && helloUid == partnerUid) return true;
  return sincePartnerSeen > stale; // older apps / guests without an id: the old partner went quiet
}

/// D4: should a call message ring? Messages that arrive live always do (the phone's clock does not matter);
/// ones found by a reload only while the call is less than [maxAge] old by the SERVER's clock.
bool callStillRinging({
  required bool arrivedLive,
  required DateTime sentAt,
  DateTime? serverNow,
  Duration maxAge = const Duration(seconds: 45),
}) {
  if (arrivedLive) return true;
  if (serverNow == null) return false; // unknown server time: a reloaded call is not rung
  final age = serverNow.difference(sentAt);
  return age < maxAge && age > const Duration(seconds: -30);
}

/// D4: the caller's screen, when the call ends before the other person ever connected:
/// tell the other phone ("missed call", which also stops its ringing).
bool sendMissedCall({required bool outgoing, required bool everConnected, required bool declined}) =>
    outgoing && !everConnected && !declined;

/// What the screen does when the other person says "bye" (hung up).
enum AfterBye { endCall, waitForReturn }

/// Round D fix: a one-to-one call from a chat ends on both sides when one person hangs up. Meetings and
/// lessons keep waiting, so people can leave and come back.
AfterBye afterBye({required bool direct}) => direct ? AfterBye.endCall : AfterBye.waitForReturn;

/// Round D fix: ask about switched-off full-screen call alerts at most once a week.
bool askFullScreenAgain({required int lastAskedMs, required int nowMs, Duration every = const Duration(days: 7)}) =>
    nowMs - lastAskedMs >= every.inMilliseconds;

/// Where a person turns on calls over the lock screen: Xiaomi phones need Xiaomi's own permissions page
/// ("Other permissions" → "Show on lock screen" + background pop-ups); other phones Android's setting.
enum LockScreenFix { androidSetting, xiaomiPermissions }

LockScreenFix lockScreenFix({required bool xiaomi}) => xiaomi ? LockScreenFix.xiaomiPermissions : LockScreenFix.androidSetting;

/// Which account this phone's notifications belong to, for the phone's own push code: the user id while
/// signed in, '' once surely signed out (then a push that still arrives is dropped, not rung), or null when it
/// is not known yet (offline with a saved sign-in): leave it as it was. Phone test 22 Nov 2026: a signed-out
/// dual app still rang for the tutor.
String? pushAccount({required bool loggedIn, required bool hasSavedSession, String? uid}) {
  if (loggedIn && uid != null && uid.isNotEmpty) return uid;
  if (!loggedIn && !hasSavedSession) return '';
  return null;
}

/// Whether a call heard by the app itself (live updates, not a push) may ring. With "Calls" switched off in
/// Notification settings, only while Dars is open on screen; in the background it stays silent, like the
/// push path already does on the server (phone test 22 Nov 2026: a swiped-away Dars still rang through its
/// live connection with "Calls" off).
bool mayRingCall({required bool callsOn, required bool foreground}) => callsOn || foreground;
