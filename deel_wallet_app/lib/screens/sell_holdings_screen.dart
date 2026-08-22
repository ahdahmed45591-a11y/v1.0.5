import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import 'sell_stock_screen.dart';

class SellHoldingsScreen extends StatelessWidget {
  const SellHoldingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Vendre des titres')),
        body: ListenableBuilder(
          listenable: app,
          builder: (context, _) => app.holdings.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Aucun titre en portefeuille pour le moment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: app.holdings.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final h = app.holdings[i];
                    final stock = findStock(h.ticker);
                    return ListTile(
                      leading: CircleAvatar(
                          backgroundColor: brandOrange.withValues(alpha: .12),
                          child: Text(h.ticker.substring(0, 2),
                              style: const TextStyle(
                                  color: brandOrange, fontSize: 12, fontWeight: FontWeight.w700))),
                      title: Text(h.company),
                      subtitle: Text('${h.quantity} titres détenus • PRU ${money(h.avgPrice)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: stock == null
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => SellStockScreen(stock: stock, maxQty: h.quantity))),
                    );
                  },
                ),
        ),
      );
}
