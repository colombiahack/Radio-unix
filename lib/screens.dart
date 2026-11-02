import 'package:flutter/material.dart';
import 'alarms.dart';
import 'equalizer.dart';
import 'globe.dart';
import 'home_country.dart';
import 'location.dart';
import 'player_service.dart';
import 'player_widgets.dart';
import 'saver_sheet.dart';
import 'settings.dart';
import 'update.dart';
import 'radio_api.dart';

const bgGradient = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B2A33), Color(0xFF0A0F14)],
  ),
);

const genres = {
  'Todos': '',
  'Pop': 'pop',
  'Rock': 'rock',
  'Salsa': 'salsa',
  'Vallenato': 'vallenato',
  'Reggaetón': 'reggaeton',
  'Noticias': 'news',
  'Jazz': 'jazz',
  'Clásica': 'classical',
  'Electrónica': 'electronic',
  'Hip hop': 'hip hop',
};

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  void _onPick() => setState(() => tab = 0);
  @override
  void initState() {
    super.initState();
    pickedCountry.addListener(_onPick);
    nearbyPick.addListener(_onPick);
  }

  @override
  void dispose() {
    pickedCountry.removeListener(_onPick);
    nearbyPick.removeListener(_onPick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: Settings.saver,
        builder: (_, saver, __) => Container(
        decoration: saver ? const BoxDecoration(color: Colors.black) : bgGradient,
        child: Scaffold(
          body: IndexedStack(
              index: tab,
              children: [
                const ExploreScreen(),
                GlobeScreen(active: tab == 1),
                const FavoritesScreen(),
                const AlarmScreen()
              ]),
          bottomNavigationBar:
              Column(mainAxisSize: MainAxisSize.min, children: [
            const MiniPlayer(),
            NavigationBar(
              backgroundColor: const Color(0xFF0A0F14),
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.search), label: 'Explorar'),
                NavigationDestination(
                    icon: Icon(Icons.public), label: 'Globo'),
                NavigationDestination(
                    icon: Icon(Icons.favorite), label: 'Favoritos'),
                NavigationDestination(
                    icon: Icon(Icons.alarm), label: 'Alarma'),
              ],
            ),
          ]),
        ),
      ),
    );
}

class StationTile extends StatelessWidget {
  final Station s;
  final List<Station>? list;
  const StationTile(this.s, {super.key, this.list});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Station?>(
        valueListenable: PlayerService.i.current,
        builder: (_, cur, __) {
          final active = cur?.id == s.id;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: active ? const Color(0x3300BFA5) : const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: active ? Border.all(color: const Color(0xFF00BFA5)) : null,
            ),
            child: ListTile(
              leading: Logo(s, size: 48),
              title: Row(children: [
                Expanded(
                  child: Text(s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (active) const PlayingEqualizer(height: 16, bars: 4),
              ]),
              subtitle: Text(
                  '${s.country}${s.bitrate > 0 ? ' · ${s.bitrate} kbps' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: ValueListenableBuilder(
                valueListenable: PlayerService.i.favorites,
                builder: (_, __, ___) => IconButton(
                  icon: Icon(
                      PlayerService.i.isFav(s)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: PlayerService.i.isFav(s) ? Colors.pinkAccent : null),
                  onPressed: () => PlayerService.i.toggleFav(s),
                ),
              ),
              onTap: () => PlayerService.i.playFrom(list ?? [s], s),
            ),
          );
        },
      );
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final api = RadioApi();
  late final Future<List<Country>> countriesF = api.countries();
  late Future<List<Station>> future = _initial();
  String? homeCode;

  Future<List<Station>> _initial() async {
    final saved = await savedHome();
    if (saved != null) {
      homeCode = saved;
      _setHome(saved);
      _refreshHome(saved);
      return api.search(country: saved);
    }
    // Primera vez: espera un poco para no chocar con el aviso de notificaciones.
    await Future.delayed(const Duration(seconds: 3));
    final code = await detectHome(api);
    if (code != null) {
      homeCode = code;
      _setHome(code);
      return api.search(country: code);
    }
    return api.search();
  }

  Future<void> _setHome(String code) async {
    String? apiName;
    try {
      final l = await countriesF;
      apiName = l.firstWhere((e) => e.code == code).name;
    } catch (_) {}
    if (!mounted) return;
    setState(() => country = Country(code, placeName(code) ?? apiName ?? code, 0));
  }

  Future<void> _refreshHome(String old) async {
    final code = await detectHome(api);
    if (!mounted || code == null || code == old) return;
    final untouched = country?.code == old && !near;
    homeCode = code;
    if (untouched) {
      await _setHome(code);
      _reload();
    }
  }
  Country? country;
  String tag = '';
  String query = '';
  bool near = false;
  (double, double)? pos;

  Future<List<Station>> _nearby() async {
    final p = pos!;
    final l = await api.nearby(p.$1, p.$2);
    if (l.length >= 5) return l;
    return api.search(country: nearestCountry(p.$1, p.$2).code);
  }

  Future<void> _locateMe() async {
    final p = await getMyLocation(context);
    if (p == null || !mounted) return;
    near = true;
    pos = p;
    _reload();
  }

  void _onNearby() {
    final p = nearbyPick.value;
    if (p == null) return;
    near = true;
    pos = p;
    _reload();
  }

  void _onPick() {
    final c = pickedCountry.value;
    if (c == null) return;
    country = c;
    near = false;
    _reload();
  }

  @override
  void initState() {
    super.initState();
    pickedCountry.addListener(_onPick);
    nearbyPick.addListener(_onNearby);
  }

  @override
  void dispose() {
    pickedCountry.removeListener(_onPick);
    nearbyPick.removeListener(_onNearby);
    super.dispose();
  }

  void _reload() => setState(() => future = near
      ? _nearby()
      : api.search(name: query, country: country?.code ?? '', tag: tag));

  Future<void> _pickCountry() async {
    List<Country> list;
    try {
      list = await countriesF;
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final c = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CountryPicker(list),
    );
    if (c != null) {
      country = c.code.isEmpty ? null : c;
      near = false;
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
            child: Row(children: [
              const Icon(Icons.radio, color: Color(0xFF00BFA5), size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Radio Mundo',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const Text('REDunix-2026',
                          style: TextStyle(
                              color: Color(0xFF00BFA5), fontSize: 11)),
                    ]),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: Settings.saver,
                builder: (_, on, __) => IconButton(
                  tooltip: 'Ahorro de batería y datos',
                  icon: Icon(on ? Icons.eco : Icons.eco_outlined,
                      color: on ? const Color(0xFF69F0AE) : null),
                  onPressed: () => showSaverSheet(context),
                ),
              ),
              ValueListenableBuilder<UpdateInfo?>(
                valueListenable: updateAvailable,
                builder: (_, u, __) => IconButton(
                  tooltip: 'Actualizaciones',
                  icon: Badge(
                    smallSize: 10,
                    isLabelVisible: u != null,
                    child: const Icon(Icons.system_update_alt),
                  ),
                  onPressed: () => showUpdateSheet(context),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchBar(
              hintText: 'Buscar emisora…',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onSubmitted: (q) {
                query = q.trim();
                near = false;
                _reload();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickCountry,
                  icon: Text(country?.flag ?? '🌍',
                      style: const TextStyle(fontSize: 20)),
                  label: Text(country?.name ?? 'Todo el mundo',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'Cerca de mí',
                icon: const Icon(Icons.my_location),
                onPressed: _locateMe,
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                icon: const Icon(Icons.shuffle),
                label: const Text('Sorpréndeme'),
                onPressed: () async {
                  final s = await api.random();
                  if (s != null) PlayerService.i.play(s);
                },
              ),
            ]),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: RadioApi.usingCache,
            builder: (_, u, __) => u
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text('Sin conexión: mostrando la última lista guardada',
                        style: TextStyle(color: Colors.amber)),
                  )
                : const SizedBox.shrink(),
          ),
          if (!near && homeCode != null && country?.code == homeCode)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Mostrando emisoras de tu país',
                  style: TextStyle(color: Color(0xFF00BFA5))),
            ),
          if (near)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Emisoras cerca de tu ubicación',
                  style: TextStyle(color: Color(0xFF2979FF))),
            ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: genres.entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(e.key),
                          selected: tag == e.value,
                          onSelected: (_) {
                            tag = e.value;
                            near = false;
                            _reload();
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Station>>(
              future: future,
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: TextButton(
                        onPressed: _reload,
                        child: const Text('No se pudo cargar. Toca para reintentar')),
                  );
                }
                final l = snap.data!;
                if (l.isEmpty) {
                  return const Center(child: Text('No hay emisoras aquí'));
                }
                return ListView.builder(
                  itemCount: l.length,
                  itemBuilder: (_, i) => StationTile(l[i], list: l),
                );
              },
            ),
          ),
        ]),
      );
}

class CountryPicker extends StatefulWidget {
  final List<Country> all;
  const CountryPicker(this.all, {super.key});
  @override
  State<CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<CountryPicker> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final l = widget.all
        .where((c) => c.name.toLowerCase().contains(q.toLowerCase()))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar país…',
                border: OutlineInputBorder()),
            onChanged: (v) => setState(() => q = v),
          ),
        ),
        ListTile(
          leading: const Text('🌍', style: TextStyle(fontSize: 24)),
          title: const Text('Todo el mundo'),
          onTap: () => Navigator.pop(context, Country('', 'Todo el mundo', 0)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: l.length,
            itemBuilder: (_, i) => ListTile(
              leading: Text(l[i].flag, style: const TextStyle(fontSize: 24)),
              title: Text(l[i].name),
              trailing: Text('${l[i].count}'),
              onTap: () => Navigator.pop(context, l[i]),
            ),
          ),
        ),
      ]),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
        child: ValueListenableBuilder<List<Station>>(
          valueListenable: PlayerService.i.favorites,
          builder: (_, l, __) => l.isEmpty
              ? const Center(child: Text('Aún no tienes favoritas'))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 12),
                  itemCount: l.length,
                  itemBuilder: (_, i) => StationTile(l[i], list: l)),
        ),
      );
}
