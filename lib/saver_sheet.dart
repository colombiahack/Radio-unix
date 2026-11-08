import 'package:flutter/material.dart';
import 'battery.dart';
import 'player_service.dart';
import 'settings.dart';

void showSaverSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const SaverSheet(),
  );
}

class SaverSheet extends StatelessWidget {
  const SaverSheet({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ValueListenableBuilder<int>(
            valueListenable: Settings.mode,
            builder: (_, m, __) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.eco, color: Color(0xFF69F0AE)),
                  const SizedBox(width: 10),
                  Text('Ahorro de batería y datos',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Apagado')),
                      ButtonSegment(value: 1, label: Text('Automático')),
                      ButtonSegment(value: 2, label: Text('Siempre')),
                    ],
                    selected: {m},
                    onSelectionChanged: (s) => Settings.setMode(s.first),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                    'Automático activa el ahorro solo cuando usas datos móviles.',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 10),
                ValueListenableBuilder<bool>(
                  valueListenable: Settings.saver,
                  builder: (_, on, __) => Text(
                      on ? 'Ahorro activo ahora' : 'Ahorro desactivado ahora',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: on ? const Color(0xFF69F0AE) : Colors.white70)),
                ),
                const SizedBox(height: 12),
                const Text('Cuando está activo:'),
                ...[
                  'Prefiere emisoras de baja calidad (64 kbps o menos)',
                  'Listas más cortas y sin descargar logos',
                  'Globo sin animación ni efectos',
                  'Fondo negro puro, que gasta menos en pantallas OLED',
                  'Ecualizador quieto',
                ].map((t) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('•  $t',
                          style: const TextStyle(color: Colors.white70)),
                    )),
                const SizedBox(height: 16),
                const Divider(height: 28),
                const Text('Reproducción con pantalla apagada',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                FutureBuilder<bool>(
                  future: batteryOk(),
                  builder: (_, s) {
                    final ok = s.data ?? true;
                    return Row(children: [
                      Expanded(
                        child: Text(
                            ok
                                ? 'Batería: sin restricciones'
                                : 'La batería puede cortar la radio',
                            style: TextStyle(
                                color: ok
                                    ? const Color(0xFF69F0AE)
                                    : Colors.amber)),
                      ),
                      if (!ok)
                        FilledButton.tonal(
                            onPressed: requestBattery,
                            child: const Text('Permitir')),
                    ]);
                  },
                ),
                const SizedBox(height: 4),
                const Text(
                    'En Xiaomi, Oppo, Vivo o Huawei activa también el "inicio automático" de Radio Mundo en los ajustes del teléfono.',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                ValueListenableBuilder<String>(
                  valueListenable: PlayerService.i.lastEvent,
                  builder: (_, e, __) => e.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Último evento: $e',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<double>(
                  valueListenable: PlayerService.i.dataKb,
                  builder: (_, kb, __) => Text(
                      'Datos estimados en esta sesión: ${(kb / 1024).toStringAsFixed(1)} MB',
                      style: const TextStyle(color: Color(0xFF00E5CC))),
                ),
                const SizedBox(height: 4),
                const Text('Estimación según la calidad de cada emisora.',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
}
