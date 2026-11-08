import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

const kAppBuild = 17;
const kAppVersion = '0.15.0';
const kRepo = 'Colombiahack/Radio-unix';

class UpdateInfo {
  final String tag, url, notes;
  final int build;
  UpdateInfo(this.tag, this.build, this.url, this.notes);
}

final updateAvailable = ValueNotifier<UpdateInfo?>(null);

Future<UpdateInfo?> checkForUpdate() async {
  try {
    final r = await http.get(
      Uri.https('api.github.com', '/repos/$kRepo/releases/latest'),
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'RadioMundo',
      },
    ).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final tag = (j['tag_name'] ?? '').toString();
    final m = RegExp(r'(\d+)\s*$').firstMatch(tag);
    if (m == null) return null;
    String? url;
    for (final a in (j['assets'] as List? ?? [])) {
      final map = a as Map;
      if ((map['name'] ?? '').toString().endsWith('.apk')) {
        url = map['browser_download_url']?.toString();
        break;
      }
    }
    if (url == null) return null;
    final info = UpdateInfo(tag, int.parse(m.group(1)!), url, (j['body'] ?? '').toString());
    updateAvailable.value = info.build > kAppBuild ? info : null;
    return info;
  } catch (_) {
    return null;
  }
}

void showUpdateSheet(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const Dialog(
      child: SingleChildScrollView(child: UpdateSheet()),
    ),
  );
}

class UpdateSheet extends StatefulWidget {
  const UpdateSheet({super.key});
  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<UpdateSheet> {
  static const _uch = MethodChannel('redunix/update');
  UpdateInfo? info;
  bool checking = true;
  bool busy = false;
  String msg = '';
  double? progress;

  @override
  void initState() {
    super.initState();
    _uch.setMethodCallHandler(_onCall);
    _check();
  }

  @override
  void dispose() {
    _uch.setMethodCallHandler(null);
    super.dispose();
  }

  Future<dynamic> _onCall(MethodCall c) async {
    if (!mounted) return null;
    if (c.method == 'progress') {
      final p = (c.arguments as int?) ?? 0;
      setState(() {
        progress = p / 100;
        msg = 'Descargando… $p%';
      });
    } else if (c.method == 'status') {
      final m = c.arguments as Map?;
      final st = (m?['s'] as String?) ?? '';
      final t = (m?['m'] as String?) ?? '';
      setState(() {
        busy = false;
        if (st == 'installing') {
          progress = 1;
          msg = 'Descarga lista. Android te pedirá confirmar la instalación: pulsa Instalar.';
        } else if (st == 'needPermission') {
          msg = 'Activa "Permitir desde esta fuente" para Radio Mundo, vuelve a la app y pulsa de nuevo.';
        } else {
          final sig = t.toLowerCase().contains('signature') ||
              t.contains('INCOMPATIBLE');
          msg = sig
              ? 'La firma no coincide con la app instalada. Desinstala Radio Mundo una vez e instala el APK firmado REDunix-2026.'
              : 'No se pudo instalar: $t';
        }
      });
    }
    return null;
  }

  Future<void> _check() async {
    final i = await checkForUpdate();
    if (!mounted) return;
    setState(() {
      info = i;
      checking = false;
    });
  }

  Future<void> _install() async {
    final i = info;
    if (i == null || busy) return;
    setState(() {
      busy = true;
      msg = 'Preparando la descarga…';
      progress = 0;
    });
    try {
      await _uch.invokeMethod('start', {'url': i.url});
    } catch (_) {
      if (!mounted) return;
      setState(() {
        msg = 'No se pudo iniciar la descarga.';
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = info;
    final newer = i != null && i.build > kAppBuild;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.system_update_alt, color: Color(0xFF00BFA5)),
            const SizedBox(width: 10),
            Text('Actualizaciones',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Text('Versión instalada: $kAppVersion',
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          if (checking)
            const Row(children: [
              SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Buscando actualizaciones…'),
            ])
          else if (i == null)
            const Text('No se pudo comprobar. Revisa tu conexión.')
          else if (!newer)
            const Text('Ya tienes la última versión.')
          else ...[
            Text('Nueva versión disponible: ${i.tag}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (i.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(i.notes, maxLines: 6, overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: 14),
            if (progress != null) LinearProgressIndicator(value: progress),
            if (msg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(msg, style: const TextStyle(color: Color(0xFF00E5CC))),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Descargar e instalar'),
                onPressed: busy ? null : _install,
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }
}
