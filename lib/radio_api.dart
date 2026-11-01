import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';

class Station {
  final String id, name, url, country, tags, favicon;
  final int bitrate;
  Station({
    required this.id,
    required this.name,
    required this.url,
    required this.country,
    required this.tags,
    required this.favicon,
    this.bitrate = 0,
  });

  factory Station.fromJson(Map<String, dynamic> j) => Station(
        id: j['stationuuid'] ?? '',
        name: (j['name'] ?? '').toString().trim(),
        url: j['url_resolved'] ?? j['url'] ?? '',
        country: j['country'] ?? '',
        tags: j['tags'] ?? '',
        favicon: j['favicon'] ?? '',
        bitrate: j['bitrate'] is num ? (j['bitrate'] as num).toInt() : 0,
      );

  Map<String, dynamic> toJson() => {
        'stationuuid': id,
        'name': name,
        'url_resolved': url,
        'country': country,
        'tags': tags,
        'favicon': favicon,
        'bitrate': bitrate,
      };
}

class Country {
  final String code, name;
  final int count;
  Country(this.code, this.name, this.count);
  String get flag => code.length == 2
      ? String.fromCharCodes(
          code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 65))
      : '🌍';
}

class RadioApi {
  static const _hosts = [
    'de1.api.radio-browser.info',
    'nl1.api.radio-browser.info',
    'at1.api.radio-browser.info',
    'fi1.api.radio-browser.info',
  ];
  static const _headers = {'User-Agent': 'RadioMundo/0.7'};
  static int _good = 0;
  static final usingCache = ValueNotifier<bool>(false);

  Future<void> _save(String key, String body) async {
    try {
      final p = await SharedPreferences.getInstance();
      final keys = p.getStringList('ckeys') ?? [];
      keys.remove(key);
      keys.add(key);
      while (keys.length > 12) {
        await p.remove(keys.removeAt(0));
      }
      await p.setString(key, body);
      await p.setStringList('ckeys', keys);
    } catch (_) {}
  }

  Future<List> _json(String path, Map<String, String> q) async {
    final key = 'c:$path?${q.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    for (var n = 0; n < _hosts.length; n++) {
      final idx = (_good + n) % _hosts.length;
      try {
        final r = await http
            .get(Uri.https(_hosts[idx], path, q), headers: _headers)
            .timeout(const Duration(seconds: 7));
        if (r.statusCode != 200) continue;
        final list = jsonDecode(r.body) as List;
        _good = idx;
        usingCache.value = false;
        _save(key, r.body);
        return list;
      } catch (_) {}
    }
    final p = await SharedPreferences.getInstance();
    final c = p.getString(key);
    if (c != null) {
      usingCache.value = true;
      return jsonDecode(c) as List;
    }
    throw Exception('Sin conexión');
  }

  Future<List<Station>> search({
    String name = '',
    String country = '',
    String tag = '',
  }) async {
    Future<List<Station>> go(bool low) async {
      final l = await _json('/json/stations/search', {
        'hidebroken': 'true',
        'order': 'clickcount',
        'reverse': 'true',
        'limit': Settings.saver.value ? '30' : '60',
        if (low) 'bitrateMax': '64',
        if (name.isNotEmpty) 'name': name,
        if (country.isNotEmpty) 'countrycode': country,
        if (tag.isNotEmpty) 'tag': tag,
      });
      return l
          .map((e) => Station.fromJson(e as Map<String, dynamic>))
          .where((s) => s.url.isNotEmpty)
          .toList();
    }

    if (Settings.saver.value) {
      final low = await go(true);
      if (low.length >= 8) return low;
    }
    return go(false);
  }

  Future<List<Station>> nearby(double lat, double lon) async {
    try {
      final l = await _json('/json/stations/search', {
        'hidebroken': 'true',
        'has_geo_info': 'true',
        'order': 'geo_distance',
        'geo_lat': lat.toStringAsFixed(4),
        'geo_long': lon.toStringAsFixed(4),
        'limit': '60',
      });
      return l
          .map((e) => Station.fromJson(e as Map<String, dynamic>))
          .where((s) => s.url.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Country>> countries() async {
    final l = await _json(
        '/json/countries', {'order': 'stationcount', 'reverse': 'true'});
    return l
        .map((e) => Country(
            (e['iso_3166_1'] ?? '').toString(),
            (e['name'] ?? '').toString(),
            (e['stationcount'] ?? 0) as int))
        .where((c) => c.code.length == 2 && c.count > 0)
        .toList();
  }

  Future<Station?> random() async {
    final l = await _json('/json/stations', {
      'hidebroken': 'true',
      'order': 'random',
      'limit': '1',
    });
    return l.isEmpty ? null : Station.fromJson(l.first as Map<String, dynamic>);
  }
}
