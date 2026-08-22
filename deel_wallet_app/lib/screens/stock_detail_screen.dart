import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import 'buy_stock_screen.dart';

class StockDetailScreen extends StatelessWidget {
  const StockDetailScreen({super.key, required this.stock});
  final Stock stock;

  @override
  Widget build(BuildContext context) {
    final up = stock.change >= 0;
    return Scaffold(
      appBar: AppBar(title: Text(stock.ticker)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stock.company,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text(stock.sector, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 20),
            Text(money(stock.price),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
            Row(
              children: [
                Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                    color: up ? brandGreen : Colors.red, size: 16),
                Text('${up ? '+' : ''}${stock.change.toStringAsFixed(2)} % aujourd\'hui',
                    style: TextStyle(color: up ? brandGreen : Colors.red)),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row('Secteur', stock.sector),
                    _row('Ticker', stock.ticker),
                    _row('Marché', 'BRVM — Abidjan'),
                    if (stock.prevClose > 0) _row('Clôture précédente', money(stock.prevClose)),
                    if (stock.volume > 0) _row('Volume', '${stock.volume}'),
                    if (stock.marketCap.isNotEmpty) _row('Capitalisation', stock.marketCap),
                    if (stock.high52 > 0) _row('Plus haut (52 sem.)', money(stock.high52)),
                    if (stock.low52 > 0) _row('Plus bas (52 sem.)', money(stock.low52)),
                    if (stock.pe > 0) _row('PER', stock.pe.toStringAsFixed(1)),
                    if (stock.dividend > 0) _row('Dividende', money(stock.dividend)),
                    if (stock.yieldPct > 0) _row('Rendement', '${stock.yieldPct.toStringAsFixed(2)} %'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => BuyStockScreen(stock: stock))),
              child: const Text('Acheter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.black54)),
            const Spacer(),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
