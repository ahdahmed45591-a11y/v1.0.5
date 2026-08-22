import 'package:flutter/material.dart';

import '../api.dart';
import '../data.dart';

class BuyStockScreen extends StatefulWidget {
  const BuyStockScreen({super.key, required this.stock});
  final Stock stock;
  @override
  State<BuyStockScreen> createState() => _BuyStockScreenState();
}

class _BuyStockScreenState extends State<BuyStockScreen> {
  int _qty = 1;
  bool _busy = false;

  double get _total => _qty * widget.stock.price;
  double get _fees => _total * 0.005;
  double get _tva => _fees * 0.18;
  double get _grandTotal => _total + _fees + _tva;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await Repo.buy(widget.stock, _qty);
      await app.refresh();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Ordre d'achat envoyé"),
          content: Text(
              '$_qty ${widget.stock.ticker} pour ${money(_grandTotal)}, en attente de validation.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Acheter ${widget.stock.ticker}')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(widget.stock.company,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text('$_qty',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => setState(() => _qty++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row('Sous-total', money(_total)),
                      _row('Frais (0,5 %)', money(_fees)),
                      _row('TVA', money(_tva)),
                      const Divider(),
                      _row('Total', money(_grandTotal), bold: true),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _confirm,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Confirmer l\'achat'),
              ),
            ],
          ),
        ),
      );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: bold ? null : Colors.black54)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    fontSize: bold ? 16 : 14)),
          ],
        ),
      );
}
