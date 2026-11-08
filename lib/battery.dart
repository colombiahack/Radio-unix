import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'alarms.dart';
import 'player_service.dart';

const _ch = MethodChannel('redunix/alarm');

Future<bool> batteryOk() async {
  try {
    return await _ch.invokeMethod<bool>('batteryOk') ?? true;
  } catch (_) {
    return true;
  }
}

Future<void> requestBattery() async {
  try {
    await _ch.invokeMethod('requestBattery');
  } catch (_) {}
}

bool _asking = false;

/// La primera vez que suena una emisora, ofrece quitar la restricción de
/// batería para que la radio no se corte con la pantalla apagada.
void watchBattery() {
  PlayerService.i.current.addListener(() async {
    if (PlayerService.i.current.value == null || _asking) return;
    _asking = true;
    try {
      final p = await SharedPreferences.getInstance();
      final n = p.getInt('bat_asked') ?? 0;
      if (n >= 2) return;
      if (await batteryOk()) return;
      await Future.delayed(const Duration(seconds: 4));
      final ctx = appNavKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      await p.setInt('bat_asked', n + 1);
      final go = await showDialog<bool>(
        context: ctx,
        builder: (d) => AlertDialog(
          title: const Text('Que la radio no se corte'),
          content: const Text(
              'Para que siga sonando con la pantalla apagada, permite que Radio Mundo funcione sin restricciones de batería.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('Ahora no')),
            FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: const Text('Permitir')),
          ],
        ),
      );
      if (go == true) await requestBattery();
    } finally {
      _asking = false;
    }
  });
}
