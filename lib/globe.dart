import 'dart:math';
import 'dart:ui' show PointMode;
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

Country nearestCountry(double lat, double lon) {
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
  final bool meSel, saver;
  _GlobePainter(this.lon0, this.lat0, this.sel, this.me, this.meSel, this.pulse,
      this.saver);

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
          PointMode.points,
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
    for (var i = 0; i < _places.length; i++) {
      final o = v.project(_places[i].$3, _places[i].$4);
      if (o == null) continue;
      canvas.drawCircle(o, 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(o, 3.8, Paint()..color = const Color(0xFFFF8F00));
    }
    if (sel != null) {
      final pl = _places[sel!];
      final o = v.project(pl.$3, pl.$4);
      if (o != null) {
        canvas.drawCircle(
            o,
            10,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5);
        _pill(canvas, o, Country(pl.$1, pl.$2, 0).flag, emoji: true);
      }
    }
    if (me != null) {
      final o = v.project(me!.$1, me!.$2);
      if (o != null) {
        canvas.drawCircle(o, 9 + 9 * pulse,
            Paint()..color = Color.fromRGBO(41, 121, 255, 0.4 * (1 - pulse)));
        canvas.drawCircle(o, 7.5, Paint()..color = Colors.white);
        canvas.drawCircle(o, 5.5, Paint()..color = const Color(0xFF2979FF));
        if (meSel) _pill(canvas, o, 'Tú');
      }
    }
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
      vsync: this, duration: const Duration(seconds: 1));
  bool _resumed = true;
  int _tick = 0;

  void _syncAnim() {
    final run = widget.active && _resumed && !Settings.saver.value;
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
    _c.addListener(() {
      if (!mounted || touching || sel != null || meSel) return;
      if (++_tick % 2 != 0) return;
      setState(() => lon0 += 0.5);
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
                      painter: _GlobePainter(lon0, lat0, sel, me, meSel, 0.35, Settings.saver.value),
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
