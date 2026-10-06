import 'package:audioplayers/audioplayers.dart';

enum SoundCue { delivery, pickup, dishReady, eventWarning, overload, levelUp, gameOver }

class AudioService {
  AudioService({required bool enabled}) : _enabled = enabled;
  bool _enabled;
  final Map<SoundCue, AudioPlayer> _players = <SoundCue, AudioPlayer>{};

  set enabled(bool value) => _enabled = value;

  Future<void> preload() async {
    for (final cue in SoundCue.values) {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(AssetSource('audio/${cue.name}.wav'));
      _players[cue] = player;
    }
  }

  Future<void> play(SoundCue cue) async {
    if (!_enabled) return;
    final player = _players[cue];
    if (player == null) return;
    await player.stop();
    await player.resume();
  }

  Future<void> dispose() async {
    for (final player in _players.values) { await player.dispose(); }
  }
}
