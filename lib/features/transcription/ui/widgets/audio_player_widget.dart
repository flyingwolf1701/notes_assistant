import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioPlayerWidget extends StatefulWidget {
  const AudioPlayerWidget({super.key, required this.audioPath, required this.duration});

  final String audioPath;
  final String duration;

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _total = d);
    });
    _player.onLog.listen((msg) {
      if (mounted) setState(() => _error = msg);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    setState(() => _error = null);
    try {
      if (_playerState == PlayerState.playing) {
        await _player.pause();
      } else {
        await _player.play(DeviceFileSource(widget.audioPath));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPlaying = _playerState == PlayerState.playing;
    final progress = _total.inMilliseconds > 0
        ? _position.inMilliseconds / _total.inMilliseconds
        : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RECORDING', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _toggle,
                  icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
                  iconSize: 40,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: scheme.primary,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(_position),
                              style: Theme.of(context).textTheme.labelSmall),
                          Text(widget.duration,
                              style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _error!,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: scheme.error,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
