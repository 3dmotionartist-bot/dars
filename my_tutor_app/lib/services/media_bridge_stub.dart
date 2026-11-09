// Non-web builds: Android goes through the platform channel instead.
import 'media_bridge.dart';

Future<bool> startRecording() async => false;
Future<VoiceClip?> stopRecording() async => null;
void cancelRecording() {}
Future<int> play(String url) async => -1;
void stopPlaying() {}
Uri? takeLaunchLink() => null;
