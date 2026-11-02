import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'player_service.dart';
import 'radio_api.dart';

final appNavKey = GlobalKey<NavigatorState>();

class Alarm {
  final int id, hour, minute;
  final List<int> days;
  final bool enabled;
  final Station station;
  const Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.days,
    required this.enabled,
    required this.station,
  });

  Alarm copyWith({bool? enabled}) => Alarm(
      id: id,
      hour: hour,
      minute: minute,
      days: days,
      enabled: enabled ?? this.enabled,
      station: station);

  Map<String, dynamic> toJson() => {
        'id': id,
        'h': hour,
        'm': minute,
        'd': days,
        'on': enabled,
        's': station.toJson(),
      };

  factory Alarm.fromJson(Map<String, dynamic> j) => Alarm(
        id: j['id'] as int,
        hour: j['h'] as int,
        minute: j['m'] as int,
        days: (j['d'] as List).map((e) => e as int).toList(),
        enabled: j['on'] as bool,
        station: Station.fromJson(Map<String, dynamic>.from(j['s'] as Map)),
      );
}

class _Lifecycle with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Alarms.checkRinging();
  }
}

/// Las alarmas las programa y reproduce un servicio nativo de Android,
/// igual que un reloj: suena aunque la app esté cerrada.
class Alarms {
  static final list = ValueNotifier<List<Alarm>>([]);
  static const _ch = MethodChannel('redunix/alarm');
  static bool _dialogOpen = false;

  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      list.value = (p.getStringList('alarms') ?? [])
          .map((e) => Alarm.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
    } catch (_) {}
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'ringing') {
        final m = call.arguments as Map?;
        _showRinging((m?['aid'] as int?) ?? -1, (m?['name'] as String?) ?? '');
      }
      return null;
    });
    WidgetsBinding.instance.addObserver(_Lifecycle());
    await _schedule();
  }

  static Future<void> ensurePermissions() async {
    try {
      final ok = await _ch.invokeMethod<bool>('canExact') ?? true;
      if (!ok) await _ch.invokeMethod('requestExact');
    } catch (_) {}
  }

  static List<DateTime> _occurrences(Alarm a, DateTime now) {
    final out = <DateTime>[];
    for (var d = 0; d < 14; d++) {
      final day = now.add(Duration(days: d));
      final at = DateTime(day.year, day.month, day.day, a.hour, a.minute);
      if (!at.isAfter(now)) continue;
      if (a.days.isNotEmpty && !a.days.contains(at.weekday)) continue;
      out.add(at);
      if (a.days.isEmpty) break;
    }
    return out;
  }

  static Future<void> _schedule() async {
    final items = <Map<String, Object>>[];
    final now = DateTime.now();
    for (final a in list.value) {
      if (!a.enabled) continue;
      final occ = _occurrences(a, now);
      for (var k = 0; k < occ.length; k++) {
        items.add({
          'id': a.id * 100 + k,
          't': occ[k].millisecondsSinceEpoch,
          'aid': a.id,
          'name': a.station.name,
          'url': a.station.url,
        });
      }
    }
    try {
      await _ch.invokeMethod('schedule', items);
    } catch (_) {}
  }

  /// Si hay una alarma sonando, ofrece detenerla o seguir escuchando en la app.
  static Future<void> checkRinging() async {
    try {
      final r = await _ch.invokeMethod<Map>('ringing');
      if (r != null) {
        _showRinging((r['aid'] as int?) ?? -1, (r['name'] as String?) ?? '');
      }
    } catch (_) {}
  }

  static Future<void> _showRinging(int aid, String name) async {
    if (_dialogOpen) return;
    Alarm? found;
    for (final a in list.value) {
      if (a.id == aid) found = a;
    }
    final al = found;
    if (al != null && al.days.isEmpty && al.enabled) {
      toggle(al);
    }
    var ctx = appNavKey.currentContext;
    if (ctx == null) {
      await Future.delayed(const Duration(seconds: 1));
      ctx = appNavKey.currentContext;
    }
    if (ctx == null) return;
    _dialogOpen = true;
    final keep = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (d) => AlertDialog(
        title: const Text('Despertador'),
        content: Text('Está sonando: $name'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Detener')),
          if (al != null)
            FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: const Text('Seguir en la app')),
        ],
      ),
    );
    _dialogOpen = false;
    try {
      await _ch.invokeMethod('stop');
    } catch (_) {}
    if (keep == true && al != null) PlayerService.i.play(al.station);
  }

  static Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(
          'alarms', list.value.map((a) => jsonEncode(a.toJson())).toList());
    } catch (_) {}
    await _schedule();
  }

  static int newId() {
    final used = list.value.map((a) => a.id).toSet();
    var i = 1;
    while (used.contains(i)) {
      i++;
    }
    return i;
  }

  static Future<void> add(Alarm a) async {
    list.value = [...list.value, a];
    await ensurePermissions();
    await _save();
  }

  static Future<void> update(Alarm a) async {
    list.value = [for (final x in list.value) x.id == a.id ? a : x];
    await ensurePermissions();
    await _save();
  }

  static Future<void> toggle(Alarm a) async {
    list.value = [
      for (final x in list.value)
        x.id == a.id ? x.copyWith(enabled: !x.enabled) : x
    ];
    await _save();
  }

  static Future<void> remove(Alarm a) async {
    list.value = list.value.where((x) => x.id != a.id).toList();
    await _save();
  }
}

const _dayShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

String _daysText(List<int> d) {
  if (d.isEmpty) return 'Una sola vez';
  if (d.length == 7) return 'Todos los días';
  final s = [...d]..sort();
  return s.map((x) => _dayShort[x - 1]).join(' · ');
}

void _openSheet(BuildContext context, {Alarm? edit}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AlarmSheet(edit: edit),
  );
}

Future<bool> _askDelete(BuildContext context, Alarm a) async {
  final t = TimeOfDay(hour: a.hour, minute: a.minute).format(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Eliminar alarma'),
      content: Text('¿Eliminar la alarma de las $t?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancelar')),
        TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.redAccent))),
      ],
    ),
  );
  return ok == true;
}

class AlarmScreen extends StatelessWidget {
  const AlarmScreen({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(children: [
              const Icon(Icons.alarm, color: Color(0xFF00BFA5), size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Despertador',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              IconButton.filledTonal(
                tooltip: 'Nueva alarma',
                icon: const Icon(Icons.add),
                onPressed: () => _openSheet(context),
              ),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
                'Toca una alarma para editarla o usa el basurero para eliminarla. Para que suene con la pantalla apagada, permite "Alarmas y recordatorios" y deja la batería en "Sin restricciones".',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
          ),
          Expanded(
            child: ValueListenableBuilder<List<Alarm>>(
              valueListenable: Alarms.list,
              builder: (_, l, __) => l.isEmpty
                  ? const Center(
                      child: Text('No tienes alarmas. Toca + para crear una.'))
                  : ListView.builder(
                      itemCount: l.length,
                      itemBuilder: (_, i) {
                        final a = l[i];
                        final t = TimeOfDay(hour: a.hour, minute: a.minute)
                            .format(context);
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x14FFFFFF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            onTap: () => _openSheet(context, edit: a),
                            title: Text(t,
                                style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w500,
                                    color: a.enabled
                                        ? Colors.white
                                        : Colors.white38)),
                            subtitle: Text(
                                '${a.station.name}\n${_daysText(a.days)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                    value: a.enabled,
                                    onChanged: (_) => Alarms.toggle(a)),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    if (await _askDelete(context, a)) {
                                      Alarms.remove(a);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ]),
      );
}

class AlarmSheet extends StatefulWidget {
  final Alarm? edit;
  const AlarmSheet({super.key, this.edit});
  @override
  State<AlarmSheet> createState() => _AlarmSheetState();
}

class _AlarmSheetState extends State<AlarmSheet> {
  late TimeOfDay time;
  late final Set<int> days;
  int sel = 0;
  late final List<Station> cands;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    time = e == null
        ? const TimeOfDay(hour: 7, minute: 0)
        : TimeOfDay(hour: e.hour, minute: e.minute);
    days = {...?e?.days};
    final cur = PlayerService.i.current.value;
    cands = [...PlayerService.i.favorites.value];
    if (cur != null && !cands.any((x) => x.id == cur.id)) cands.insert(0, cur);
    if (e != null) {
      final i = cands.indexWhere((x) => x.id == e.station.id);
      if (i < 0) {
        cands.insert(0, e.station);
        sel = 0;
      } else {
        sel = i;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.edit != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(editing ? 'Editar alarma' : 'Nueva alarma',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.access_time),
              label: Text(time.format(context),
                  style: const TextStyle(fontSize: 26)),
              onPressed: () async {
                final t =
                    await showTimePicker(context: context, initialTime: time);
                if (t != null) setState(() => time = t);
              },
            ),
            const SizedBox(height: 14),
            const Text('Emisora'),
            if (cands.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                    'Marca una emisora como favorita (corazón) y vuelve aquí.',
                    style: TextStyle(color: Colors.amber)),
              )
            else
              DropdownButton<int>(
                isExpanded: true,
                value: sel,
                items: [
                  for (var i = 0; i < cands.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child:
                          Text(cands[i].name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => sel = v ?? 0),
              ),
            const SizedBox(height: 10),
            const Text('Días (sin marcar = una sola vez)'),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(const ['L', 'M', 'X', 'J', 'V', 'S', 'D'][d - 1]),
                  selected: days.contains(d),
                  onSelected: (on) =>
                      setState(() => on ? days.add(d) : days.remove(d)),
                ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.alarm_add),
                label: Text(editing ? 'Guardar cambios' : 'Guardar alarma'),
                onPressed: cands.isEmpty
                    ? null
                    : () async {
                        final alarm = Alarm(
                          id: widget.edit?.id ?? Alarms.newId(),
                          hour: time.hour,
                          minute: time.minute,
                          days: days.toList()..sort(),
                          enabled: true,
                          station: cands[sel],
                        );
                        if (editing) {
                          await Alarms.update(alarm);
                        } else {
                          await Alarms.add(alarm);
                        }
                        if (mounted) Navigator.pop(context);
                      },
              ),
            ),
            if (editing)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  label: const Text('Eliminar alarma',
                      style: TextStyle(color: Colors.redAccent)),
                  onPressed: () async {
                    final e = widget.edit!;
                    if (await _askDelete(context, e)) {
                      await Alarms.remove(e);
                      if (mounted) Navigator.pop(context);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
