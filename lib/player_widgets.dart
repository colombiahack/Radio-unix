import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'player_service.dart';
import 'radio_api.dart';

class Logo extends StatelessWidget {
  final Station s;
  final double size;
  const Logo(this.s, {super.key, this.size = 48});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size / 4),
        child: Container(
          width: size,
          height: size,
          color: const Color(0x22FFFFFF),
          child: s.favicon.startsWith('http')
              ? Image.network(s.favicon,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.radio, size: size / 2))
              : Icon(Icons.radio, size: size / 2),
        ),
      );
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Station?>(
        valueListenable: PlayerService.i.current,
        builder: (_, s, __) {
          if (s == null) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PlayerScreen())),
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF123F46),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Logo(s, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text(s.country,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      ]),
                ),
                const PlayPauseButton(size: 36),
              ]),
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
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            );
          }
          final playing = st?.playing ?? false;
          return IconButton(
            iconSize: size,
            color: const Color(0xFF00BFA5),
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14525C), Color(0xFF0A0F14)],
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Reproduciendo'),
        ),
        body: ValueListenableBuilder<Station?>(
          valueListenable: p.current,
          builder: (_, s, __) {
            if (s == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: const [
                        BoxShadow(color: Color(0x6600BFA5), blurRadius: 40)
                      ],
                    ),
                    child: Logo(s, size: 240),
                  ),
                  const SizedBox(height: 28),
                  Text(s.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(s.country, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  StreamBuilder<IcyMetadata?>(
                    stream: p.player.icyMetadataStream,
                    builder: (_, snap) {
                      final t = snap.data?.info?.title ?? '';
                      return SizedBox(
                        height: 40,
                        child: Text(t,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF00BFA5))),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    ValueListenableBuilder(
                      valueListenable: p.favorites,
                      builder: (_, __, ___) => IconButton(
                        iconSize: 32,
                        icon: Icon(
                            p.isFav(s) ? Icons.favorite : Icons.favorite_border,
                            color: p.isFav(s) ? Colors.pinkAccent : null),
                        onPressed: () => p.toggleFav(s),
                      ),
                    ),
                    const PlayPauseButton(size: 84),
                    ValueListenableBuilder<Duration?>(
                      valueListenable: p.sleepLeft,
                      builder: (_, left, __) => PopupMenuButton<int>(
                        tooltip: 'Temporizador',
                        onSelected: (m) => p.setSleep(m == 0 ? null : m),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 15, child: Text('15 min')),
                          PopupMenuItem(value: 30, child: Text('30 min')),
                          PopupMenuItem(value: 60, child: Text('60 min')),
                          PopupMenuItem(value: 0, child: Text('Desactivar')),
                        ],
                        child: Column(children: [
                          Icon(Icons.bedtime,
                              size: 32,
                              color: left == null ? null : const Color(0xFF00BFA5)),
                          Text(
                              left == null
                                  ? 'Dormir'
                                  : '${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 12)),
                        ]),
                      ),
                    ),
                  ]),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
