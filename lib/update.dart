import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';

const kAppBuild = 12;
const kAppVersion = '0.12.0';
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
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const UpdateSheet(),
  );
}

class UpdateSheet extends StatefulWidget {
  const UpdateSheet({super.key});
  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<UpdateSheet> {
  UpdateInfo? info;
  bool checking = true;
  bool busy = false;
  String msg = '';
  double? progress;
  StreamSubscription? sub;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final i = await checkForUpdate();
    if (!mounted) return;
    setState(() {
      info = i;
      checking = false;
    });
  }

  void _install() {
    final i = info;
    if (i == null || busy) return;
    setState(() {
      busy = true;
      msg = 'Descargando…';
      progress = 0;
    });
    try {
      sub = OtaUpdate()
          .execute(i.url, destinationFilename: 'REDunix-2026.apk')
          .listen((e) {
        if (!mounted) return;
        setState(() {
          switch (e.status) {
            case OtaStatus.DOWNLOADING:
              final p = double.tryParse(e.value ?? '') ?? 0;
              progress = p / 100;
              msg = 'Descargando… ${p.round()}%';
              break;
            case OtaStatus.INSTALLING:
              progress = 1;
              msg = 'Abriendo el instalador…';
              busy = false;
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              msg = 'Permite instalar apps desde Radio Mundo y vuelve a pulsar.';
              busy = false;
              break;
            default:
              msg = 'No se pudo completar (${e.status.name}).';
              busy = false;
          }
        });
      }, onError: (_) {
        if (!mounted) return;
        setState(() {
          msg = 'Error al descargar. Inténtalo de nuevo.';
          busy = false;
        });
      });
    } catch (_) {
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
