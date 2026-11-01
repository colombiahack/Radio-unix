import 'package:flutter/material.dart';
import 'player_service.dart';
import 'player_widgets.dart';
import 'radio_api.dart';

const countries = {
  'ES': 'España', 'MX': 'México', 'AR': 'Argentina', 'CO': 'Colombia',
  'CL': 'Chile', 'PE': 'Perú', 'US': 'Estados Unidos', 'GB': 'Reino Unido',
  'FR': 'Francia', 'DE': 'Alemania', 'IT': 'Italia', 'BR': 'Brasil',
  'JP': 'Japón', 'IN': 'India', 'NG': 'Nigeria', 'ZA': 'Sudáfrica',
};

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
            index: tab,
            children: const [ExploreScreen(), FavoritesScreen()]),
        bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.public), label: 'Explorar'),
              NavigationDestination(icon: Icon(Icons.favorite), label: 'Favoritos'),
            ],
          ),
        ]),
      );
}

class StationTile extends StatelessWidget {
  final Station s;
  const StationTile(this.s, {super.key});
  @override
  Widget build(BuildContext context) => ListTile(
        leading: SizedBox(
          width: 44,
          height: 44,
          child: s.favicon.startsWith('http')
              ? Image.network(s.favicon,
                  errorBuilder: (_, __, ___) => const Icon(Icons.radio))
              : const Icon(Icons.radio),
        ),
        title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(s.country, maxLines: 1),
        trailing: ValueListenableBuilder(
          valueListenable: PlayerService.i.favorites,
          builder: (_, __, ___) => IconButton(
            icon: Icon(PlayerService.i.isFav(s)
                ? Icons.favorite
                : Icons.favorite_border),
            onPressed: () => PlayerService.i.toggleFav(s),
          ),
        ),
        onTap: () => PlayerService.i.play(s),
      );
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final api = RadioApi();
  late Future<List<Station>> future = api.top();
  String? country;

  void _load(Future<List<Station>> f) => setState(() => future = f);

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchBar(
              hintText: 'Buscar emisora…',
              leading: const Icon(Icons.search),
              onSubmitted: (q) {
                if (q.trim().isNotEmpty) _load(api.search(q.trim()));
              },
            ),
          ),
          Row(children: [
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: country,
                hint: const Text('Elige un país'),
                items: countries.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) {
                  setState(() => country = v);
                  _load(api.byCountry(v!));
                },
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
            const SizedBox(width: 12),
          ]),
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
                        onPressed: () => _load(api.top()),
                        child: const Text('Sin conexión. Reintentar')),
                  );
                }
                final l = snap.data!;
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

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
        child: ValueListenableBuilder<List<Station>>(
          valueListenable: PlayerService.i.favorites,
          builder: (_, l, __) => l.isEmpty
              ? const Center(child: Text('Aún no tienes favoritas'))
              : ListView.builder(
                  itemCount: l.length,
                  itemBuilder: (_, i) => StationTile(l[i])),
        ),
      );
}
