import 'dart:math';
import 'package:flutter/material.dart';
import 'radio_api.dart';

/// Cuando el globo elige un país, Explorar lo escucha y se filtra solo.
final pickedCountry = ValueNotifier<Country?>(null);

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

class _GlobePainter extends CustomPainter {
  final double lon0, lat0;
  final int? sel;
  _GlobePainter(this.lon0, this.lat0, this.sel);

  @override
  void paint(Canvas canvas, Size size) {
    final v = _View(size, lat0, lon0);
    canvas.drawCircle(
        v.c,
        v.r * 1.05,
        Paint()
          ..color = const Color(0x4400BFA5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28));
    canvas.drawCircle(
        v.c,
        v.r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [Color(0xFF1B6B73), Color(0xFF0B2A33)],
          ).createShader(Rect.fromCircle(center: v.c, radius: v.r)));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = const Color(0x3300E5CC);
    for (var la = -60.0; la <= 60; la += 30) {
      _poly(canvas, v, line, [for (var lo = -180.0; lo <= 180; lo += 4) (la, lo)]);
    }
    for (var lo = -180.0; lo < 180; lo += 30) {
      _poly(canvas, v, line, [for (var la = -90.0; la <= 90; la += 4) (la, lo)]);
    }
    for (var i = 0; i < _places.length; i++) {
      final o = v.project(_places[i].$3, _places[i].$4);
      if (o == null) continue;
      canvas.drawCircle(o, 9,
          Paint()..color = const Color(0x4400E5CC));
      canvas.drawCircle(o, 4.5, Paint()..color = const Color(0xFF00E5CC));
    }
    if (sel != null) {
      final pl = _places[sel!];
      final o = v.project(pl.$3, pl.$4);
      if (o != null) {
        canvas.drawCircle(
            o,
            9,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5);
        final tp = TextPainter(
          text: TextSpan(
              text: Country(pl.$1, pl.$2, 0).flag,
              style: const TextStyle(fontSize: 28)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, o - Offset(tp.width / 2, tp.height + 12));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter old) => true;
}

class GlobeScreen extends StatefulWidget {
  const GlobeScreen({super.key});
  @override
  State<GlobeScreen> createState() => _GlobeScreenState();
}

class _GlobeScreenState extends State<GlobeScreen>
    with SingleTickerProviderStateMixin {
  double lon0 = -70, lat0 = 15;
  bool touching = false;
  int? sel;
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 1))
    ..repeat();

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!touching && sel == null && mounted) setState(() => lon0 += 0.25);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap(Offset p, Size s) {
    final v = _View(s, lat0, lon0);
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
    setState(() => sel = best);
  }

  @override
  Widget build(BuildContext context) {
    final pl = sel == null ? null : _places[sel!];
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            const Icon(Icons.public, color: Color(0xFF00BFA5), size: 30),
            const SizedBox(width: 8),
            Text('Descubre el mundo',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
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
                      painter: _GlobePainter(lon0, lat0, sel), size: size),
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
          child: pl == null
              ? const Center(
                  child: Text('Arrastra el globo y toca un punto',
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
