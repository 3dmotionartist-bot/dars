// Round D: call decisions that need no phone (D0 failure details, D3 restart / retries, D4 rejoin and ringing).
import 'package:flutter_test/flutter_test.dart';
import 'package:my_tutor_app/services/call_logic.dart';

void main() {
  group('D0 — what a failed connection looked like', () {
    test('candidate types are read from the candidate text', () {
      expect(candidateType('candidate:1 1 udp 2122260223 192.168.1.5 54400 typ host generation 0'), 'host');
      expect(candidateType('candidate:2 1 udp 1686052607 5.6.7.8 54400 typ srflx raddr 192.168.1.5 rport 54400'), 'srflx');
      expect(candidateType('candidate:3 1 udp 41885439 1.2.3.4 3478 typ relay raddr 5.6.7.8 rport 54400'), 'relay');
      expect(candidateType('candidate:4 1 tcp 1518280447 abc.local 9 typ host tcptype active'), 'host');
      expect(candidateType(''), '');
      expect(candidateType(null), '');
    });

    test('the details line counts routes per side and says whether the relay answered', () {
      final d = IceDiag()
        ..relayHost = 'turn.example.com'
        ..addLocal('candidate:1 1 udp 1 192.168.1.5 1 typ host')
        ..addLocal('candidate:2 1 udp 1 192.168.1.6 1 typ host')
        ..addLocal('candidate:3 1 udp 1 5.6.7.8 1 typ srflx')
        ..addRemote('candidate:4 1 udp 1 abc.local 1 typ host');
      expect(d.relayGathered, isFalse);
      expect(d.summary(), contains('me: host 2, srflx 1'));
      expect(d.summary(), contains('them: host 1'));
      expect(d.summary(), contains('relay: no (turn.example.com)'));
      d.addLocal('candidate:5 1 udp 1 1.2.3.4 3478 typ relay');
      expect(d.relayGathered, isTrue);
      expect(d.toJson()['relay'], isTrue);
      d.resetRoutes();
      expect(d.local, isEmpty);
      expect(d.relayHost, 'turn.example.com', reason: 'the relay host stays for the rebuilt connection');
    });

    test('the message matches the reason', () {
      expect(failureKind(relayConfigured: false, relayGathered: false), FailureKind.noRelay);
      expect(failureKind(relayConfigured: true, relayGathered: false), FailureKind.relayNotAnswering,
          reason: 'relay set up but no relay route: allowance used up / wrong password / unreachable');
      expect(failureKind(relayConfigured: true, relayGathered: true), FailureKind.network);
    });

    test('relay host from the ICE server list', () {
      expect(relayHostOf([
        {'urls': ['stun:stun.l.google.com:19302']},
        {'urls': ['turn:global.relay.metered.ca:80', 'turns:global.relay.metered.ca:443?transport=tcp'], 'username': 'u', 'credential': 'c'},
      ]), 'global.relay.metered.ca');
      expect(relayHostOf([{'urls': 'turn:turn.cloudflare.com:3478?transport=udp'}]), 'turn.cloudflare.com');
      expect(relayHostOf([{'urls': 'stun:stun.cloudflare.com:3478'}]), '');
    });
  });

  group('D3 — rebuild on both sides, retry for a minute', () {
    test('retries start at once, then wait longer', () {
      expect([for (var n = 0; n < 7; n++) retryDelay(n).inSeconds], [0, 3, 6, 12, 20, 20, 20]);
    });

    test('automatic retries stop after 60 seconds (then "Try again")', () {
      final first = DateTime(2026, 11, 18, 12);
      expect(keepRetrying(first, first.add(const Duration(seconds: 59))), isTrue);
      expect(keepRetrying(first, first.add(const Duration(seconds: 60))), isFalse);
    });

    test('offers: older counter ignored, newer one rebuilds first, older apps always taken', () {
      expect(offerAction(peerHasRestart: true, myGen: 3, offerGen: 2, connectionUsed: true), OfferAction.ignore);
      expect(offerAction(peerHasRestart: true, myGen: 3, offerGen: 4, connectionUsed: true), OfferAction.rebuildThenAccept);
      expect(offerAction(peerHasRestart: true, myGen: 3, offerGen: 4, connectionUsed: false), OfferAction.accept,
          reason: 'a fresh connection (after my own restart) takes it as is');
      expect(offerAction(peerHasRestart: true, myGen: 3, offerGen: 3, connectionUsed: true), OfferAction.accept,
          reason: 'same connection: a renegotiation (e.g. screen share added in a voice call)');
      expect(offerAction(peerHasRestart: false, myGen: 5, offerGen: 0, connectionUsed: true), OfferAction.accept);
    });

    test('a restart counter is above what either side used', () {
      expect(nextGen(0, 0), 1);
      expect(nextGen(4, 2), 5);
      expect(nextGen(2, 7), 8);
    });
  });

  group('D4 — rejoining, ringing, missed call', () {
    test('the same account coming back with a new id is taken, not told "call is full"', () {
      expect(isRejoin(helloUid: 'u1', partnerUid: 'u1', sincePartnerSeen: Duration.zero), isTrue);
      expect(isRejoin(helloUid: 'u2', partnerUid: 'u1', sincePartnerSeen: const Duration(seconds: 3)), isFalse);
      expect(isRejoin(helloUid: '', partnerUid: '', sincePartnerSeen: const Duration(seconds: 16)), isTrue,
          reason: 'older app / guest: the old partner went quiet');
      expect(isRejoin(helloUid: '', partnerUid: '', sincePartnerSeen: const Duration(seconds: 10)), isFalse,
          reason: 'a connected older app says hello only every ~12 s: not stale yet');
    });

    test('live calls ring whatever the phone clock says; reloaded ones by the server clock', () {
      final sent = DateTime.utc(2026, 11, 18, 12);
      expect(callStillRinging(arrivedLive: true, sentAt: sent.subtract(const Duration(hours: 3))), isTrue,
          reason: 'a phone clock 3 hours off no longer stops the ringing');
      expect(callStillRinging(arrivedLive: false, sentAt: sent, serverNow: sent.add(const Duration(seconds: 20))), isTrue);
      expect(callStillRinging(arrivedLive: false, sentAt: sent, serverNow: sent.add(const Duration(seconds: 50))), isFalse);
      expect(callStillRinging(arrivedLive: false, sentAt: sent, serverNow: null), isFalse);
    });

    test('"missed call" only for my own unanswered, not declined call', () {
      expect(sendMissedCall(outgoing: true, everConnected: false, declined: false), isTrue);
      expect(sendMissedCall(outgoing: true, everConnected: true, declined: false), isFalse);
      expect(sendMissedCall(outgoing: true, everConnected: false, declined: true), isFalse);
      expect(sendMissedCall(outgoing: false, everConnected: false, declined: false), isFalse, reason: 'meetings / lessons');
    });
  });

  group('Round D fixes — phone test of 19 Nov', () {
    test('a chat call ends on both sides when one person hangs up', () {
      expect(afterBye(direct: true), AfterBye.endCall);
    });
    test('meetings and lessons keep waiting for the other person to come back', () {
      expect(afterBye(direct: false), AfterBye.waitForReturn);
    });
    test('switched-off full-screen alerts: asked at most once a week', () {
      const day = 24 * 3600 * 1000;
      expect(askFullScreenAgain(lastAskedMs: 0, nowMs: 100 * day), isTrue); // never asked
      expect(askFullScreenAgain(lastAskedMs: 10 * day, nowMs: 16 * day), isFalse);
      expect(askFullScreenAgain(lastAskedMs: 10 * day, nowMs: 17 * day), isTrue);
    });
  });

  group('Calls on the lock screen — Xiaomi (phone test 19 Nov 2026)', () {
    test('Xiaomi phones are sent to Xiaomi\'s own permissions page', () {
      expect(lockScreenFix(xiaomi: true), LockScreenFix.xiaomiPermissions);
    });
    test('other phones are sent to Android\'s full-screen setting', () {
      expect(lockScreenFix(xiaomi: false), LockScreenFix.androidSetting);
    });
  });

  group('Signed-out phones stay silent (phone test 22 Nov 2026)', () {
    test('signed in: notifications belong to that account', () {
      expect(pushAccount(loggedIn: true, hasSavedSession: true, uid: 'u1'), 'u1');
    });
    test('signed out: pushes that still arrive are dropped', () {
      expect(pushAccount(loggedIn: false, hasSavedSession: false, uid: null), '');
    });
    test('saved sign-in not restored yet (offline): leave it as it was', () {
      expect(pushAccount(loggedIn: true, hasSavedSession: true, uid: null), isNull);
      expect(pushAccount(loggedIn: false, hasSavedSession: true, uid: null), isNull);
    });
  });
}
