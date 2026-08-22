import 'package:flutter/material.dart';

import '../api.dart';
import '../data.dart';
import '../main.dart';
import 'stock_detail_screen.dart';

class BrvmTab extends StatefulWidget {
  const BrvmTab({super.key});
  @override
  State<BrvmTab> createState() => _BrvmTabState();
}

/// Seance BRVM : lun-ven, 9h00-15h00 GMT (source : data/brvm_data, mis a
/// jour toutes les 15 min sur ce creneau). Abidjan est en UTC+0 toute
/// l'annee, DateTime.now().toUtc() donne donc directement l'heure locale.
class _MarketStatus {
  const _MarketStatus(this.open, this.label);
  final bool open;
  final String label;
}

_MarketStatus _brvmMarketStatus() {
  final now = DateTime.now().toUtc();
  final isWeekday = now.weekday <= DateTime.friday;
  final minutesNow = now.hour * 60 + now.minute;
  final isOpen = isWeekday && minutesNow >= 9 * 60 && minutesNow < 15 * 60;
  return _MarketStatus(
    isOpen,
    isOpen ? 'Marché ouvert — ferme à 15h00 (GMT)' : 'Marché fermé — 9h-15h GMT, lun-ven',
  );
}

class _BrvmTabState extends State<BrvmTab> {
  late Future<List<Stock>> _future = Repo.stocks();
  String _query = '';

  List<Stock> _filter(List<Stock> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((s) => s.ticker.toLowerCase().contains(q) || s.company.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async => setState(() => _future = Repo.stocks()),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('BRVM',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const Text('Bourse Régionale des Valeurs Mobilières',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final status = _brvmMarketStatus();
              return Chip(
                avatar: Icon(Icons.circle,
                    size: 10, color: status.open ? brandGreen : Colors.black45),
                label: Text(status.label, style: const TextStyle(fontSize: 12)),
                backgroundColor: (status.open ? brandGreen : Colors.black45).withValues(alpha: .08),
                side: BorderSide.none,
              );
            }),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Rechercher une société ou un ticker',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _query = ''),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Stock>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                        child: Text(
                            snap.error is ApiException ? (snap.error as ApiException).message : 'Erreur.')),
                  );
                }
                final results = _filter(snap.data!);
                if (results.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: Text('Aucun résultat.')),
                  );
                }
                return Column(children: [for (final s in results) _stockTile(context, s)]);
              },
            ),
          ],
        ),
      );

  Widget _stockTile(BuildContext context, Stock s) {
    final up = s.change >= 0;
    return Card(
      child: ListTile(
        title: Text(s.company, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${s.ticker} • ${s.sector}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(money(s.price), style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${up ? '+' : ''}${s.change.toStringAsFixed(2)} %',
                style: TextStyle(
                    color: up ? brandGreen : Colors.red, fontSize: 12)),
          ],
        ),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => StockDetailScreen(stock: s))),
      ),
    );
  }
}
