import 'package:flutter/material.dart';
import 'equalizer.dart';
import 'globe.dart';
import 'player_service.dart';
import 'player_widgets.dart';
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
  }

  @override
  void dispose() {
    pickedCountry.removeListener(_onPick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: bgGradient,
        child: Scaffold(
          body: IndexedStack(
              index: tab,
              children: const [ExploreScreen(), GlobeScreen(), FavoritesScreen()]),
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
              ],
            ),
          ]),
        ),
      );
}

class StationTile extends StatelessWidget {
  final Station s;
  const StationTile(this.s, {super.key});
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
                  s.tags.isEmpty ? s.country : '${s.country} · ${s.tags.split(',').first}',
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
              onTap: () => PlayerService.i.play(s),
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
  late Future<List<Station>> future = api.search();
  Country? country;
  String tag = '';
  String query = '';

  void _onPick() {
    final c = pickedCountry.value;
    if (c == null) return;
    country = c;
    _reload();
  }

  @override
  void initState() {
    super.initState();
    pickedCountry.addListener(_onPick);
  }

  @override
  void dispose() {
    pickedCountry.removeListener(_onPick);
    super.dispose();
  }

  void _reload() => setState(() => future = api.search(
      name: query, country: country?.code ?? '', tag: tag));

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
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              const Icon(Icons.radio, color: Color(0xFF00BFA5), size: 30),
              const SizedBox(width: 8),
              Text('Radio Mundo',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              const Text('Sin anuncios · REDunix-2026',
                  style: TextStyle(color: Color(0xFF00BFA5), fontSize: 12)),
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
              const SizedBox(width: 8),
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
                        child: const Text('Sin conexión. Reintentar')),
                  );
                }
                final l = snap.data!;
                if (l.isEmpty) {
                  return const Center(child: Text('No hay emisoras aquí'));
                }
                return ListView.builder(
                  itemCount: l.length,
                  itemBuilder: (_, i) => StationTile(l[i]),
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
                  itemBuilder: (_, i) => StationTile(l[i])),
        ),
      );
}
