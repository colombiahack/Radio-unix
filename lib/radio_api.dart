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

class RadioApi {
  static const _host = 'de1.api.radio-browser.info';

  Future<List<Station>> _get(String path, [Map<String, String> q = const {}]) async {
    final uri = Uri.https(_host, path, {
      'hidebroken': 'true',
      'order': 'clickcount',
      'reverse': 'true',
      'limit': '50',
      ...q,
    });
    final r = await http.get(uri, headers: {'User-Agent': 'RadioMundo/0.1'});
    if (r.statusCode != 200) throw Exception('Error ${r.statusCode}');
    final list = jsonDecode(r.body) as List;
    return list
        .map((e) => Station.fromJson(e as Map<String, dynamic>))
        .where((s) => s.url.isNotEmpty)
        .toList();
  }

  Future<List<Station>> top() => _get('/json/stations');
  Future<List<Station>> byCountry(String code) =>
      _get('/json/stations/bycountrycodeexact/$code');
  Future<List<Station>> search(String name) =>
      _get('/json/stations/byname/$name');
  Future<Station?> random() async {
    final l = await _get('/json/stations', {'order': 'random', 'limit': '1'});
    return l.isEmpty ? null : l.first;
  }
}
