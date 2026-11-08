import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'location.dart';
import 'radio_api.dart';
import 'settings.dart';
import 'world_data.dart';

/// Explorar escucha estos avisos y se filtra solo.
final pickedCountry = ValueNotifier<Country?>(null);
final nearbyPick = ValueNotifier<(double, double)?>(null);

const _places = <(String, String, double, double)>[
  ('CO', 'Colombia', 4.6, -74.1), ('MX', 'México', 23.6, -102.5),
  ('US', 'Estados Unidos', 39.8, -98.6), ('CA', 'Canadá', 56, -106),
  ('BR', 'Brasil', -10, -52), ('AR', 'Argentina', -34, -64),
  ('CL', 'Chile', -30, -71), ('PE', 'Perú', -9.2, -75),
  ('VE', 'Venezuela', 7, -66), ('EC', 'Ecuador', -1.4, -78.4),
  ('BO', 'Bolivia', -16.7, -64.7), ('UY', 'Uruguay', -32.8, -56),
  ('PY', 'Paraguay', -23.4, -58.4), ('CU', 'Cuba', 21.5, -79.5),
  ('DO', 'Rep. Dominicana', 18.9, -70.5), ('PR', 'Puerto Rico', 18.2, -66.5),
  ('GT', 'Guatemala', 15.5, -90.3), ('CR', 'Costa Rica', 9.9, -84),
  ('PA', 'Panamá', 8.5, -80), ('ES', 'España', 40.4, -3.7),
  ('PT', 'Portugal', 39.5, -8), ('FR', 'Francia', 46.6, 2.4),
  ('GB', 'Reino Unido', 54, -2.5), ('IE', 'Irlanda', 53.3, -8),
  ('DE', 'Alemania', 51.2, 10.4), ('IT', 'Italia', 42.8, 12.5),
  ('NL', 'Países Bajos', 52.2, 5.3), ('BE', 'Bélgica', 50.6, 4.7),
  ('CH', 'Suiza', 46.8, 8.2), ('AT', 'Austria', 47.5, 14.5),
  ('SE', 'Suecia', 62, 15), ('NO', 'Noruega', 64.5, 11),
  ('FI', 'Finlandia', 64, 26), ('DK', 'Dinamarca', 56, 10),
  ('PL', 'Polonia', 52, 19), ('GR', 'Grecia', 39, 22),
  ('TR', 'Turquía', 39, 35), ('RU', 'Rusia', 60, 90),
  ('UA', 'Ucrania', 49, 32), ('RO', 'Rumania', 45.9, 25),
  ('EG', 'Egipto', 26.8, 30.8), ('MA', 'Marruecos', 31.8, -7),
  ('DZ', 'Argelia', 28, 2.6), ('NG', 'Nigeria', 9, 8),
  ('GH', 'Ghana', 7.9, -1), ('ZA', 'Sudáfrica', -29, 24),
  ('KE', 'Kenia', 0.2, 37.9), ('ET', 'Etiopía', 9, 40),
  ('SN', 'Senegal', 14.5, -14.5), ('SA', 'Arabia Saudita', 24, 45),
  ('IL', 'Israel', 31, 35), ('IR', 'Irán', 32, 53),
  ('IN', 'India', 21, 78), ('PK', 'Pakistán', 30, 69),
  ('CN', 'China', 35, 103), ('JP', 'Japón', 36, 138),
  ('KR', 'Corea del Sur', 36.5, 127.8), ('TH', 'Tailandia', 15, 101),
  ('VN', 'Vietnam', 16, 106), ('ID', 'Indonesia', -2, 118),
  ('PH', 'Filipinas', 12.9, 122), ('MY', 'Malasia', 4, 102),
  ('AU', 'Australia', -25, 134), ('NZ', 'Nueva Zelanda', -41, 174),
];

String? placeName(String code) {
  for (final p in _places) {
    if (p.$1 == code) return p.$2;
  }
  return null;
}

const _boxes = <String, List<double>>{
  'CO': [-4.2, 13.4, -79.0, -66.8],
  'MX': [14.5, 32.7, -118.4, -86.7],
  'US': [24.5, 49.4, -125, -66.9],
  'CA': [41.7, 83.1, -141, -52.6],
  'BR': [-33.8, 5.3, -73.99, -34.8],
  'AR': [-55.1, -21.8, -73.6, -53.6],
  'CL': [-56, -17.5, -75.6, -66.4],
  'PE': [-18.4, -0.04, -81.4, -68.7],
  'VE': [0.6, 12.2, -73.4, -59.8],
  'EC': [-5.0, 1.5, -81.1, -75.2],
  'BO': [-22.9, -9.7, -69.6, -57.5],
  'UY': [-35, -30.1, -58.4, -53.1],
  'PY': [-27.6, -19.3, -62.6, -54.3],
  'CU': [19.8, 23.3, -85, -74.1],
  'DO': [17.5, 20.0, -72.0, -68.3],
  'PR': [17.9, 18.5, -67.3, -65.2],
  'GT': [13.7, 17.8, -92.3, -88.2],
  'CR': [8.0, 11.2, -85.95, -82.55],
  'PA': [7.2, 9.7, -83.05, -77.2],
  'ES': [36.0, 43.8, -9.4, 3.4],
  'PT': [36.9, 42.2, -9.5, -6.2],
  'FR': [41.3, 51.1, -5.2, 9.6],
  'GB': [49.9, 60.9, -8.2, 1.8],
  'IE': [51.4, 55.4, -10.5, -6.0],
  'DE': [47.3, 55.1, 5.9, 15.0],
  'IT': [36.6, 47.1, 6.6, 18.5],
  'NL': [50.75, 53.6, 3.3, 7.2],
  'BE': [49.5, 51.5, 2.5, 6.4],
  'CH': [45.8, 47.8, 5.96, 10.5],
  'AT': [46.4, 49.0, 9.5, 17.2],
  'SE': [55.3, 69.1, 11.1, 24.2],
  'NO': [58.0, 71.2, 4.6, 31.1],
  'FI': [59.8, 70.1, 20.5, 31.6],
  'DK': [54.5, 57.8, 8.0, 12.7],
  'PL': [49.0, 54.8, 14.1, 24.1],
  'GR': [34.8, 41.8, 19.4, 28.2],
  'TR': [36.0, 42.1, 26.0, 44.8],
  'RU': [41.2, 77.7, 27.3, 180],
  'UA': [44.4, 52.4, 22.1, 40.2],
  'RO': [43.6, 48.3, 20.3, 29.7],
  'EG': [22.0, 31.7, 24.7, 36.9],
  'MA': [27.7, 35.9, -13.2, -1.0],
  'DZ': [19.0, 37.1, -8.7, 12.0],
  'NG': [4.3, 13.9, 2.7, 14.7],
  'GH': [4.7, 11.2, -3.3, 1.2],
  'ZA': [-34.8, -22.1, 16.5, 33.0],
  'KE': [-4.7, 5.0, 33.9, 41.9],
  'ET': [3.4, 14.9, 33.0, 48.0],
  'SN': [12.3, 16.7, -17.6, -11.4],
  'SA': [16.4, 32.2, 34.5, 55.7],
  'IL': [29.5, 33.3, 34.2, 35.9],
  'IR': [25.1, 39.8, 44.0, 63.3],
  'IN': [6.7, 35.5, 68.1, 97.4],
  'PK': [23.7, 37.1, 60.9, 77.8],
  'CN': [18.2, 53.6, 73.5, 134.8],
  'JP': [24.0, 45.6, 122.9, 146.0],
  'KR': [33.1, 38.6, 124.6, 131.9],
  'TH': [5.6, 20.5, 97.3, 105.6],
  'VN': [8.4, 23.4, 102.1, 109.5],
  'ID': [-11.0, 5.9, 95.0, 141.0],
  'PH': [4.6, 21.1, 116.9, 126.6],
  'MY': [0.85, 7.4, 99.6, 119.3],
  'AU': [-43.7, -10.7, 113.2, 153.6],
  'NZ': [-47.3, -34.4, 166.4, 178.6],
};

const _colombia = <double>[
  -71.7, 12.45,
  -71.32, 11.85,
  -72.1, 11.35,
  -72.8, 10.3,
  -73.0, 9.3,
  -72.8, 8.6,
  -72.4, 7.9,
  -72.0, 7.2,
  -71.0, 7.15,
  -70.1, 7.05,
  -69.4, 6.3,
  -67.5, 6.3,
  -67.4, 5.3,
  -67.6, 4.2,
  -67.5, 3.0,
  -67.2, 2.0,
  -66.9, 1.2,
  -69.8, 1.05,
  -70.0, 0.6,
  -69.5, -0.2,
  -69.6, -1.2,
  -69.75, -4.3,
  -70.2, -4.1,
  -70.4, -3.7,
  -71.3, -2.4,
  -72.5, -2.4,
  -73.3, -1.5,
  -74.3, -0.9,
  -75.3, -0.1,
  -76.4, 0.3,
  -77.3, 0.4,
  -78.0, 0.9,
  -78.8, 1.3,
  -78.8, 1.9,
  -78.4, 2.5,
  -77.7, 3.4,
  -77.2, 3.9,
  -77.3, 4.6,
  -77.55, 5.5,
  -77.4, 6.2,
  -77.9, 7.2,
  -77.4, 7.9,
  -77.35, 8.67,
  -76.9, 8.2,
  -76.5, 8.7,
  -75.8, 9.4,
  -75.6, 10.0,
  -75.5, 10.4,
  -74.8, 11.0,
  -74.2, 11.3,
  -73.0, 11.55,
  -72.2, 12.2,
];

bool _inColombia(double lat, double lon) {
  var c = false;
  for (var i = 0, j = _colombia.length - 2; i < _colombia.length; j = i, i += 2) {
    final xi = _colombia[i], yi = _colombia[i + 1];
    final xj = _colombia[j], yj = _colombia[j + 1];
    if ((yi > lat) != (yj > lat) && lon < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
      c = !c;
    }
  }
  return c;
}

/// País donde cae un punto: primero por cajas geográficas (la más pequeña
/// que lo contiene) y, si no cae en ninguna, por el centro más cercano.
Country nearestCountry(double lat, double lon) {
  if (_inColombia(lat, lon)) return Country('CO', 'Colombia', 0);
  String? inside;
  var boxD = double.infinity;
  for (final e in _boxes.entries) {
    final b = e.value;
    if (lat >= b[0] && lat <= b[1] && lon >= b[2] && lon <= b[3]) {
      final dy = lat - (b[0] + b[1]) / 2, dx = lon - (b[2] + b[3]) / 2;
      final d = dy * dy + dx * dx;
      if (d < boxD) {
        boxD = d;
        inside = e.key;
      }
    }
  }
  if (inside != null) {
    for (final p in _places) {
      if (p.$1 == inside) return Country(p.$1, p.$2, 0);
    }
  }
  var best = 0;
  var bd = double.infinity;
  final p = lat * pi / 180, l = lon * pi / 180;
  for (var i = 0; i < _places.length; i++) {
    final q = _places[i].$3 * pi / 180, m = _places[i].$4 * pi / 180;
    final d = -(sin(p) * sin(q) + cos(p) * cos(q) * cos(l - m));
    if (d < bd) {
      bd = d;
      best = i;
    }
  }
  final pl = _places[best];
  return Country(pl.$1, pl.$2, 0);
}

class _View {
  final Size size;
  final double lat0, lon0, r;
  final Offset c;
  _View(this.size, this.lat0, this.lon0)
      : r = size.width * 0.44,
        c = Offset(size.width / 2, size.height / 2);

  Offset? project(double lat, double lon) {
    final p = lat * pi / 180, l = (lon - lon0) * pi / 180, p0 = lat0 * pi / 180;
    final cosc = sin(p0) * sin(p) + cos(p0) * cos(p) * cos(l);
    if (cosc <= 0) return null;
    final x = cos(p) * sin(l);
    final y = cos(p0) * sin(p) - sin(p0) * cos(p) * cos(l);
    return Offset(c.dx + r * x, c.dy - r * y);
  }
}

void _poly(Canvas canvas, _View v, Paint paint, List<(double, double)> pts) {
  final path = Path();
  var pen = false;
  for (final p in pts) {
    final o = v.project(p.$1, p.$2);
    if (o == null) {
      pen = false;
      continue;
    }
    if (!pen) {
      path.moveTo(o.dx, o.dy);
      pen = true;
    } else {
      path.lineTo(o.dx, o.dy);
    }
  }
  canvas.drawPath(path, paint);
}

/// Foto de la Tierra (NASA) + sombreador en la GPU. Si no está disponible
/// (o en modo ahorro) se usa el globo de puntos de siempre.
class GlobeAssets {
  static ui.FragmentShader? shader;
  static ui.Image? tex;
  static bool _loading = false;
  static final ready = ValueNotifier<bool>(false);

  static Future<void> load() async {
    if (_loading || ready.value) return;
    _loading = true;
    try {
      final data = await rootBundle.load('assets/earth.jpg');
      if (data.lengthInBytes < 50000) return; // no se pudo descargar al compilar
      final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          targetWidth: 2048);
      final frame = await codec.getNextFrame();
      final program = await ui.FragmentProgram.fromAsset('shaders/globe.frag');
      tex = frame.image;
      shader = program.fragmentShader();
      ready.value = true;
    } catch (_) {
    } finally {
      _loading = false;
    }
  }
}

const _biomeColors = [
  Color(0xFFF1F5F7),
  Color(0xFF9DAE95),
  Color(0xFFD2B26F),
  Color(0xFF2E7D32),
  Color(0xFF5FA04E),
];

void _pill(Canvas canvas, Offset o, String text, {bool emoji = false}) {
  final tp = TextPainter(
    text: TextSpan(
        text: text,
        style: emoji
            ? const TextStyle(fontSize: 28)
            : const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A0F14))),
    textDirection: TextDirection.ltr,
  )..layout();
  if (emoji) {
    tp.paint(canvas, o - Offset(tp.width / 2, tp.height + 12));
  } else {
    final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: o - const Offset(0, 28),
            width: tp.width + 18,
            height: tp.height + 8),
        const Radius.circular(10));
    canvas.drawRRect(rect, Paint()..color = Colors.white);
    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }
}

class _GlobePainter extends CustomPainter {
  final double lon0, lat0, pulse;
  final int? sel;
  final (double, double)? me;
  final bool meSel, saver, useTex;
  _GlobePainter(this.lon0, this.lat0, this.sel, this.me, this.meSel, this.pulse,
      this.saver, this.useTex);

  @override
  void paint(Canvas canvas, Size size) {
    final v = _View(size, lat0, lon0);
    final rect = Rect.fromCircle(center: v.c, radius: v.r);
    final rnd = Random(7);
    final starPaint = Paint()..color = const Color(0x66FFFFFF);
    for (var i = 0; i < (saver ? 0 : 45); i++) {
      final o = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final rr = 0.6 + rnd.nextDouble() * 0.8;
      if ((o - v.c).distance > v.r * 1.12) canvas.drawCircle(o, rr, starPaint);
    }
    canvas.drawCircle(
        v.c,
        v.r * 1.04,
        Paint()
          ..color = const Color(0x884FC3F7)
          ..maskFilter = saver ? null : const MaskFilter.blur(BlurStyle.normal, 16));
    if (useTex && GlobeAssets.shader != null && GlobeAssets.tex != null) {
      _paintReal(canvas, v, size);
    } else {
    canvas.drawCircle(
        v.c,
        v.r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.4),
            radius: 1.05,
            colors: [Color(0xFF3A9AD9), Color(0xFF1565A8), Color(0xFF082B57)],
            stops: [0, 0.55, 1],
          ).createShader(rect));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0x1AFFFFFF);
    for (var la = -60.0; la <= 60; la += 30) {
      _poly(canvas, v, line, [for (var lo = -180.0; lo <= 180; lo += 4) (la, lo)]);
    }
    for (var lo = -180.0; lo < 180; lo += 30) {
      _poly(canvas, v, line, [for (var la = -90.0; la <= 90; la += 4) (la, lo)]);
    }
    final buckets = List.generate(5, (_) => <Offset>[]);
    for (final d in (saver ? landDotsLite : landDots)) {
      final o = v.project(d.$1, d.$2);
      if (o != null) buckets[d.$3].add(o);
    }
    for (var b = 0; b < 5; b++) {
      canvas.drawPoints(
          ui.PointMode.points,
          buckets[b],
          Paint()
            ..color = _biomeColors[b]
            ..strokeWidth = v.r * (saver ? 0.058 : 0.03)
            ..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(
        v.c,
        v.r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.35),
            radius: 1.1,
            colors: [Color(0x22FFFFFF), Color(0x00000000), Color(0xAA010A1A)],
            stops: [0, 0.55, 1],
          ).createShader(rect));
    canvas.drawCircle(
        v.c,
        v.r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0x6690CAF9));
    }
    for (var i = 0; i < _places.length; i++) {
      final o = v.project(_places[i].$3, _places[i].$4);
      if (o == null) continue;
      canvas.drawCircle(o, 8, Paint()..color = const Color(0x2600E5FF));
      canvas.drawCircle(o, 4.8, Paint()..color = const Color(0x5500E5FF));
      canvas.drawCircle(o, 2.6, Paint()..color = const Color(0xFFBFF6FF));
    }
    if (sel != null) {
      final pl = _places[sel!];
      final o = v.project(pl.$3, pl.$4);
      if (o != null) {
        _ripples(canvas, o, 0, 229, 255, v.r);
        _pill(canvas, o, Country(pl.$1, pl.$2, 0).flag, emoji: true);
      }
    }
    if (me != null) {
      final o = v.project(me!.$1, me!.$2);
      if (o != null) {
        if (meSel) _ripples(canvas, o, 68, 138, 255, v.r);
        canvas.drawCircle(o, 7.5, Paint()..color = Colors.white);
        canvas.drawCircle(o, 5.5, Paint()..color = const Color(0xFF2979FF));
        if (meSel) _pill(canvas, o, 'Tú');
      }
    }
  }

  /// Fotografía de la Tierra dibujada por la GPU.
  void _paintReal(Canvas canvas, _View v, Size size) {
    final sh = GlobeAssets.shader!;
    sh.setFloat(0, size.width);
    sh.setFloat(1, size.height);
    sh.setFloat(2, lon0 * pi / 180);
    sh.setFloat(3, lat0 * pi / 180);
    sh.setFloat(4, v.r);
    sh.setImageSampler(0, GlobeAssets.tex!);
    canvas.drawCircle(v.c, v.r, Paint()..shader = sh);
    canvas.drawCircle(
        v.c,
        v.r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0x5590CAF9));
  }

  /// Ondas que salen del punto, como una emisora transmitiendo.
  void _ripples(Canvas canvas, Offset o, int r, int g, int b, double globeR) {
    final reach = globeR * 0.5;
    for (var k = 0; k < 3; k++) {
      final ph = (pulse + k / 3) % 1.0;
      canvas.drawCircle(
          o,
          8 + reach * ph,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5 * (1 - ph) + 0.8
            ..color = Color.fromRGBO(r, g, b, (1 - ph) * 0.9));
    }
    canvas.drawCircle(o, 14, Paint()..color = Color.fromRGBO(r, g, b, 0.28));
    canvas.drawCircle(o, 9, Paint()..color = Color.fromRGBO(r, g, b, 0.55));
    canvas.drawCircle(o, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _GlobePainter old) => true;
}

class GlobeScreen extends StatefulWidget {
  final bool active;
  const GlobeScreen({super.key, this.active = true});
  @override
  State<GlobeScreen> createState() => _GlobeScreenState();
}

class _GlobeScreenState extends State<GlobeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  double lon0 = -70, lat0 = 15;
  bool touching = false;
  int? sel;
  (double, double)? me;
  bool meSel = false;
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 2));
  bool _resumed = true;
  int _tick = 0;

  void _syncAnim() {
    final run = widget.active && _resumed && !Settings.saver.value;
    if (run) GlobeAssets.load();
    if (run) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  void _onSaver() {
    _syncAnim();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Settings.saver.addListener(_onSaver);
    GlobeAssets.ready.addListener(_onSaver);
    _c.addListener(() {
      if (!mounted || touching) return;
      if (++_tick % 2 != 0) return;
      final rotating = sel == null && !meSel;
      setState(() {
        if (rotating) lon0 = (lon0 + 0.5) % 360;
      });
    });
    _syncAnim();
  }

  @override
  void didUpdateWidget(GlobeScreen old) {
    super.didUpdateWidget(old);
    _syncAnim();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncAnim();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Settings.saver.removeListener(_onSaver);
    GlobeAssets.ready.removeListener(_onSaver);
    _c.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    final p = await getMyLocation(context);
    if (p == null || !mounted) return;
    setState(() {
      me = p;
      meSel = true;
      sel = null;
      lon0 = p.$2;
      lat0 = p.$1.clamp(-60.0, 60.0).toDouble();
    });
  }

  void _tap(Offset p, Size s) {
    final v = _View(s, lat0, lon0);
    if (me != null) {
      final o = v.project(me!.$1, me!.$2);
      if (o != null && (o - p).distance < 30) {
        setState(() {
          meSel = true;
          sel = null;
        });
        return;
      }
    }
    int? best;
    var bd = 28.0;
    for (var i = 0; i < _places.length; i++) {
      final o = v.project(_places[i].$3, _places[i].$4);
      if (o == null) continue;
      final d = (o - p).distance;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    setState(() {
      sel = best;
      meSel = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pl = sel == null ? null : _places[sel!];
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(children: [
            const Icon(Icons.public, color: Color(0xFF00BFA5), size: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Descubre el mundo',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            IconButton.filledTonal(
              tooltip: 'Mi ubicación',
              icon: const Icon(Icons.my_location),
              onPressed: _locate,
            ),
          ]),
        ),
        Expanded(
          child: LayoutBuilder(builder: (_, box) {
            final side = min(box.maxWidth, box.maxHeight);
            final size = Size(side, side);
            return Center(
              child: SizedBox(
                width: side,
                height: side,
                child: GestureDetector(
                  onPanStart: (_) => touching = true,
                  onPanUpdate: (d) => setState(() {
                    lon0 -= d.delta.dx * 0.4;
                    lat0 = (lat0 + d.delta.dy * 0.3).clamp(-60.0, 60.0).toDouble();
                  }),
                  onPanEnd: (_) => touching = false,
                  onTapUp: (d) => _tap(d.localPosition, size),
                  child: CustomPaint(
                      painter: _GlobePainter(
                          lon0,
                          lat0,
                          sel,
                          me,
                          meSel,
                          Settings.saver.value ? 0.35 : _c.value,
                          Settings.saver.value,
                          GlobeAssets.ready.value && !Settings.saver.value),
                      size: size),
                ),
              ),
            );
          }),
        ),
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: meSel && me != null
              ? Row(children: [
                  const Icon(Icons.my_location, color: Color(0xFF2979FF), size: 32),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Tu ubicación',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.radio),
                    label: const Text('Ver cerca'),
                    onPressed: () {
                      nearbyPick.value = null;
                      nearbyPick.value = me;
                    },
                  ),
                ])
              : pl == null
                  ? const Center(
                      child: Text(
                          'Arrastra el globo, toca un país o usa el botón de ubicación',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70)))
                  : Row(children: [
                      Text(Country(pl.$1, pl.$2, 0).flag,
                          style: const TextStyle(fontSize: 34)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(pl.$2,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Escuchar'),
                        onPressed: () =>
                            pickedCountry.value = Country(pl.$1, pl.$2, 0),
                      ),
                    ]),
        ),
      ]),
    );
  }
}
