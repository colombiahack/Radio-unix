import 'package:shared_preferences/shared_preferences.dart';
import 'globe.dart';
import 'location.dart';

const kDefaultCountry = 'CO';

Future<String?> savedHome() async {
  try {
    final p = await SharedPreferences.getInstance();
    return p.getString('home_country2');
  } catch (_) {
    return null;
  }
}

/// País donde estás, según tus coordenadas. Si no hay ubicación, Colombia.
Future<String> detectHome() async {
  var code = kDefaultCountry;
  final pos = await quietLocation();
  if (pos != null) code = nearestCountry(pos.$1, pos.$2).code;
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString('home_country2', code);
  } catch (_) {}
  return code;
}
