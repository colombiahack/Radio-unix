import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'radio_api.dart';

class PlayerService {
  PlayerService._();
  static final i = PlayerService._();

  static const _ch = MethodChannel('redunix/alarm');
  final player = AudioPlayer();
  final current = ValueNotifier<Station?>(null);
  final favorites = ValueNotifier<List<Station>>([]);
  final sleepLeft = ValueNotifier<Duration?>(null);
  final dataKb = ValueNotifier<double>(0);
  final lastEvent = ValueNotifier<String>('');
  List<Station> queue = [];
  Timer? _sleep;
  Timer? _dt;
  Timer? _wd;

  int _retries = 0;
  int _bufTicks = 0;
  bool _intent = false; // quieres que esté sonando
  bool _busy = false; // cargando una emisora
  bool _reconnecting = false;

  String _hm() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  void _log(String m) => lastEvent.value = '${_hm()} $m';

  void _watch() {
    player.playingStream.listen((on) {
      _setLocks(on);
      _dt?.cancel();
      _wd?.cancel();
      if (on) {
        _intent = true;
        _dt = Timer.periodic(const Duration(seconds: 5), (_) {
          final br = current.value?.bitrate ?? 0;
          dataKb.value += (br > 0 ? br : 128) * 5 / 8;
        });
        _wd = Timer.periodic(const Duration(seconds: 10), (_) => _tick());
      } else if (!_busy) {
        _intent = false;
      }
    });
    player.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace st) {
      _log('Error de reproducción');
      _reconnect('error');
    });
    player.playerStateStream.listen((st) {
      if (st.playing && st.processingState == ProcessingState.ready) {
        if (_retries > 0) _log('Reproduciendo de nuevo');
        _retries = 0;
        _bufTicks = 0;
      }
    });
    try {
      Connectivity().onConnectivityChanged.listen((r) {
        final online = r.any((e) => e != ConnectivityResult.none);
        if (online && _intent && player.processingState != ProcessingState.ready) {
          _retries = 0;
          _reconnect('red recuperada');
        }
      });
    } catch (_) {}
  }

  /// Vigilante: si la emisora se queda muda o muerta con la pantalla apagada, reconecta.
  void _tick() {
    if (!player.playing || _reconnecting || _busy) {
      _bufTicks = 0;
      return;
    }
    final st = player.processingState;
    if (st == ProcessingState.idle || st == ProcessingState.completed) {
      _reconnect(st.name);
    } else if (st == ProcessingState.loading ||
        st == ProcessingState.buffering) {
      _bufTicks++;
      if (_bufTicks >= 3) {
        _bufTicks = 0;
        _reconnect('sin datos');
      }
    } else {
      _bufTicks = 0;
    }
  }

  void _reconnect(String why) {
    final s = current.value;
    if (s == null || _reconnecting || !_intent) return;
    _reconnecting = true;
    final secs = const [2, 4, 8, 15, 30][_retries.clamp(0, 4).toInt()];
    _retries++;
    _log('Se cortó ($why). Reconectando en ${secs}s');
    Future.delayed(Duration(seconds: secs), () async {
      _reconnecting = false;
      if (_intent && current.value?.id == s.id) await _playQueue(queue, s);
    });
  }

  Future<void> init() async {
    _watch();
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('favs') ?? [];
    favorites.value =
        raw.map((e) => Station.fromJson(jsonDecode(e))).toList();
  }

  Future<void> play(Station s) => playFrom([s], s);

  Future<void> playFrom(List<Station> list, Station s) {
    _retries = 0;
    return _playQueue(list, s);
  }

  Future<void> _playQueue(List<Station> list, Station s) async {
    final ok = list.where((e) => Uri.tryParse(e.url) != null).toList();
    if (!ok.any((e) => e.id == s.id)) ok.insert(0, s);
    queue = ok;
    current.value = s;
    _intent = true;
    _busy = true;
    try {
      // Una sola emisora (no una lista): si el servidor corta, reconecta la
      // misma emisora en vez de saltar a otra.
      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(s.url),
          tag: MediaItem(
            id: s.id,
            title: s.name,
            album: s.country,
            artUri: s.favicon.startsWith('http')
                ? Uri.tryParse(s.favicon)
                : null,
          ),
        ),
      );
      _busy = false;
      await player.play();
    } catch (e) {
      _busy = false;
      debugPrint('No se pudo reproducir: $e');
      _log('No se pudo abrir la emisora');
      _reconnect('error');
    } finally {
      _busy = false;
    }
  }

  Future<void> _step(int d) async {
    final cur = current.value;
    final i = cur == null ? -1 : queue.indexWhere((e) => e.id == cur.id);
    final n = queue[(i + d + queue.length) % queue.length];
    _retries = 0;
    await _playQueue(queue, n);
  }

  /// Siguiente emisora de la lista. Si solo hay una (Sorpréndeme), busca otra al azar.
  Future<void> next() async {
    if (queue.length > 1) {
      await _step(1);
    } else {
      final s = await RadioApi().random();
      if (s != null) await play(s);
    }
  }

  /// Emisora anterior de la lista.
  Future<void> previous() async {
    if (queue.length > 1) await _step(-1);
  }

  /// Mantiene despierto el procesador y el WiFi mientras suena la radio.
  void _setLocks(bool on) {
    try {
      _ch.invokeMethod('locks', {'on': on});
    } catch (_) {}
  }

  bool isFav(Station s) => favorites.value.any((f) => f.id == s.id);

  Future<void> toggleFav(Station s) async {
    final l = [...favorites.value];
    isFav(s) ? l.removeWhere((f) => f.id == s.id) : l.add(s);
    favorites.value = l;
    final p = await SharedPreferences.getInstance();
    await p.setStringList('favs', l.map((e) => jsonEncode(e.toJson())).toList());
  }

  void setSleep(int? minutes) {
    _sleep?.cancel();
    sleepLeft.value = null;
    if (minutes == null) return;
    var left = Duration(minutes: minutes);
    sleepLeft.value = left;
    _sleep = Timer.periodic(const Duration(seconds: 1), (t) {
      left -= const Duration(seconds: 1);
      if (left.inSeconds <= 0) {
        _intent = false;
        player.stop();
        t.cancel();
        sleepLeft.value = null;
      } else {
        sleepLeft.value = left;
      }
    });
  }
}
