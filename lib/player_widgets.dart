import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'player_service.dart';
import 'radio_api.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Station?>(
        valueListenable: PlayerService.i.current,
        builder: (_, s, __) {
          if (s == null) return const SizedBox.shrink();
          return Material(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: ListTile(
              title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(s.country),
              trailing: const PlayPauseButton(),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PlayerScreen())),
            ),
          );
        },
      );
}

class PlayPauseButton extends StatelessWidget {
  final double size;
  const PlayPauseButton({super.key, this.size = 28});
  @override
  Widget build(BuildContext context) => StreamBuilder<PlayerState>(
        stream: PlayerService.i.player.playerStateStream,
        builder: (_, snap) {
          final st = snap.data;
          final loading = st?.processingState == ProcessingState.loading ||
              st?.processingState == ProcessingState.buffering;
          if (loading) {
            return SizedBox(
              width: size + 12,
              height: size + 12,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final playing = st?.playing ?? false;
          return IconButton(
            iconSize: size,
            icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
            onPressed: () => playing
                ? PlayerService.i.player.pause()
                : PlayerService.i.player.play(),
          );
        },
      );
}

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = PlayerService.i;
    return Scaffold(
      appBar: AppBar(title: const Text('Reproduciendo')),
      body: ValueListenableBuilder<Station?>(
        valueListenable: p.current,
        builder: (_, s, __) {
          if (s == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: s.favicon.startsWith('http')
                      ? Image.network(s.favicon,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.radio, size: 120))
                      : const Icon(Icons.radio, size: 120),
                ),
                const SizedBox(height: 24),
                Text(s.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                Text(s.country),
                const SizedBox(height: 16),
                const PlayPauseButton(size: 72),
                const SizedBox(height: 16),
                ValueListenableBuilder<Duration?>(
                  valueListenable: p.sleepLeft,
                  builder: (_, left, __) => PopupMenuButton<int>(
                    onSelected: (m) => p.setSleep(m == 0 ? null : m),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 15, child: Text('15 min')),
                      PopupMenuItem(value: 30, child: Text('30 min')),
                      PopupMenuItem(value: 60, child: Text('60 min')),
                      PopupMenuItem(value: 0, child: Text('Desactivar')),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.bedtime),
                      label: Text(left == null
                          ? 'Temporizador para dormir'
                          : 'Se apaga en ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
