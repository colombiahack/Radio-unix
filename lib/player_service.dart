import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'radio_api.dart';

class PlayerService {
  PlayerService._();
  static final i = PlayerService._();

  final player = AudioPlayer();
  final current = ValueNotifier<Station?>(null);
  final favorites = ValueNotifier<List<Station>>([]);
  final sleepLeft = ValueNotifier<Duration?>(null);
  Timer? _sleep;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('favs') ?? [];
    favorites.value =
        raw.map((e) => Station.fromJson(jsonDecode(e))).toList();
  }

  Future<void> play(Station s) async {
    current.value = s;
    try {
      await player.setAudioSource(AudioSource.uri(
        Uri.parse(s.url),
        tag: MediaItem(
          id: s.id,
          title: s.name,
          album: s.country,
          artUri: s.favicon.startsWith('http') ? Uri.parse(s.favicon) : null,
        ),
      ));
      await player.play();
    } catch (e) {
      debugPrint('No se pudo reproducir: $e');
    }
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
        player.stop();
        t.cancel();
        sleepLeft.value = null;
      } else {
        sleepLeft.value = left;
      }
    });
  }
}
