import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  /// 0 = apagado, 1 = automático (datos móviles), 2 = siempre
  static final mode = ValueNotifier<int>(1);
  static final onMobile = ValueNotifier<bool>(false);
  static final saver = ValueNotifier<bool>(false);

  static void _recompute() =>
      saver.value = mode.value == 2 || (mode.value == 1 && onMobile.value);

  static void _apply(List<ConnectivityResult> r) {
    onMobile.value = r.contains(ConnectivityResult.mobile) &&
        !r.contains(ConnectivityResult.wifi) &&
        !r.contains(ConnectivityResult.ethernet);
    _recompute();
  }

  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      mode.value = p.getInt('saver_mode') ?? 1;
    } catch (_) {}
    try {
      final c = Connectivity();
      _apply(await c.checkConnectivity());
      c.onConnectivityChanged.listen(_apply);
    } catch (_) {}
    _recompute();
  }

  static Future<void> setMode(int m) async {
    mode.value = m;
    _recompute();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('saver_mode', m);
    } catch (_) {}
  }
}
