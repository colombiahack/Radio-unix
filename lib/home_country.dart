import 'dart:ui' show PlatformDispatcher;
import 'package:shared_preferences/shared_preferences.dart';
import 'globe.dart';
import 'location.dart';
import 'radio_api.dart';

Future<String?> savedHome() async {
  try {
    final p = await SharedPreferences.getInstance();
    return p.getString('home_country');
  } catch (_) {
    return null;
  }
}

/// País donde estás: por ubicación (con las emisoras más cercanas) o,
/// si no hay permiso, por la región configurada en el teléfono.
Future<String?> detectHome(RadioApi api) async {
  String? code;
  final pos = await quietLocation();
  if (pos != null) {
    try {
      final l = await api.nearby(pos.$1, pos.$2);
      final counts = <String, int>{};
      for (final s in l.take(15)) {
        if (s.cc.length == 2) {
          final k = s.cc.toUpperCase();
          counts[k] = (counts[k] ?? 0) + 1;
        }
      }
      if (counts.isNotEmpty) {
        final e = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        code = e.first.key;
      }
    } catch (_) {}
    code ??= nearestCountry(pos.$1, pos.$2).code;
  }
  code ??= PlatformDispatcher.instance.locale.countryCode;
  if (code == null || code.length != 2) return null;
  code = code.toUpperCase();
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString('home_country', code);
  } catch (_) {}
  return code;
}
