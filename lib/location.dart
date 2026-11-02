import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(double, double)?> getMyLocation(BuildContext context) async {
  final m = ScaffoldMessenger.of(context);
  void say(String t) => m.showSnackBar(SnackBar(content: Text(t)));
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      say('Activa la ubicación del teléfono.');
      return null;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      say('Sin permiso de ubicación. Actívalo en Ajustes.');
      return null;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 15),
      );
      return (pos.latitude, pos.longitude);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return (last.latitude, last.longitude);
      rethrow;
    }
  } catch (_) {
    say('No se pudo obtener tu ubicación.');
    return null;
  }
}

/// Ubicación sin avisos en pantalla. Pide el permiso solo la primera vez.
Future<(double, double)?> quietLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('loc_asked') ?? false) return null;
      await prefs.setBool('loc_asked', true);
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      return null;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 6),
      );
      return (pos.latitude, pos.longitude);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return (last.latitude, last.longitude);
      return null;
    }
  } catch (_) {
    return null;
  }
}
