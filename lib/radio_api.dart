import 'dart:convert';
import 'package:http/http.dart' as http;

class Station {
  final String id, name, url, country, tags, favicon;
  Station({
    required this.id,
    required this.name,
    required this.url,
    required this.country,
    required this.tags,
    required this.favicon,
  });

  factory Station.fromJson(Map<String, dynamic> j) => Station(
        id: j['stationuuid'] ?? '',
        name: (j['name'] ?? '').toString().trim(),
        url: j['url_resolved'] ?? j['url'] ?? '',
        country: j['country'] ?? '',
        tags: j['tags'] ?? '',
        favicon: j['favicon'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'stationuuid': id,
        'name': name,
        'url_resolved': url,
        'country': country,
        'tags': tags,
        'favicon': favicon,
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
  static const _host = 'de1.api.radio-browser.info';
  static const _headers = {'User-Agent': 'RadioMundo/0.2'};

  Future<List> _json(String path, Map<String, String> q) async {
    final r = await http.get(Uri.https(_host, path, q), headers: _headers);
    if (r.statusCode != 200) throw Exception('Error ${r.statusCode}');
    return jsonDecode(r.body) as List;
  }

  Future<List<Station>> search({
    String name = '',
    String country = '',
    String tag = '',
  }) async {
    final l = await _json('/json/stations/search', {
      'hidebroken': 'true',
      'order': 'clickcount',
      'reverse': 'true',
      'limit': '60',
      if (name.isNotEmpty) 'name': name,
      if (country.isNotEmpty) 'countrycode': country,
      if (tag.isNotEmpty) 'tag': tag,
    });
    return l
        .map((e) => Station.fromJson(e as Map<String, dynamic>))
        .where((s) => s.url.isNotEmpty)
        .toList();
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
