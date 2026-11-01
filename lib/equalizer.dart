import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'player_service.dart';
import 'settings.dart';

class Equalizer extends StatefulWidget {
  final bool playing;
  final double height;
  final int bars;
  const Equalizer(
      {super.key, required this.playing, this.height = 24, this.bars = 5});
  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  void _sync() {
    if (Settings.saver.value || !widget.playing) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void initState() {
    super.initState();
    Settings.saver.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(Equalizer old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    Settings.saver.removeListener(_sync);
    _c.dispose();
    super.dispose();
  }

  double _v(int i) {
    if (!widget.playing) return 0.1;
    final k = 1 + (i % 3);
    final s = sin(2 * pi * (_c.value * k) + i * 1.7);
    return 0.25 + 0.75 * (0.5 + 0.5 * s);
  }

  @override
  Widget build(BuildContext context) {
    final bw = max(3.0, widget.height / 7);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => SizedBox(
        height: widget.height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < widget.bars; i++)
              Container(
                width: bw,
                height: widget.height * _v(i),
                margin: EdgeInsets.symmetric(horizontal: bw / 3),
                decoration: BoxDecoration(
                  color: Color.lerp(const Color(0xFF00BFA5), Colors.white,
                      i / widget.bars * 0.5),
                  borderRadius: BorderRadius.circular(bw / 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PlayingEqualizer extends StatelessWidget {
  final double height;
  final int bars;
  const PlayingEqualizer({super.key, this.height = 24, this.bars = 5});
  @override
  Widget build(BuildContext context) => StreamBuilder<PlayerState>(
        stream: PlayerService.i.player.playerStateStream,
        builder: (_, snap) {
          final st = snap.data;
          final on = (st?.playing ?? false) &&
              st?.processingState == ProcessingState.ready;
          return Equalizer(playing: on, height: height, bars: bars);
        },
      );
}

class Pulse extends StatefulWidget {
  final Widget child;
  const Pulse({super.key, required this.child});
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  void _sync() {
    if (Settings.saver.value) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void initState() {
    super.initState();
    Settings.saver.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    Settings.saver.removeListener(_sync);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
        stream: PlayerService.i.player.playingStream,
        builder: (_, snap) => AnimatedBuilder(
          animation: _c,
          child: widget.child,
          builder: (_, child) => Transform.scale(
            scale: (snap.data ?? false) ? 1 + 0.04 * _c.value : 1,
            child: child,
          ),
        ),
      );
}
