import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'jeko_payment_screen.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});
  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

/// Reseaux acceptes par Jeko (champ paymentMethod, voir jeko.METHODS cote
/// backend). Choisir ici plutot que sur la page Jeko permet de verrouiller le
/// moyen de paiement ET de ramener le client dans l'app apres paiement.
const _methods = [
  ('orange', 'Orange Money', Color(0xFFF7941D)),
  ('wave', 'Wave', Color(0xFF21C5F0)),
  ('mtn', 'MTN MoMo', Color(0xFFFFCC00)),
  ('moov', 'Moov Money', Color(0xFF0066B3)),
  ('djamo', 'Djamo', Color(0xFF1D2B64)),
];

class _DepositScreenState extends State<DepositScreen> {
  final _amount = TextEditingController();
  String? _method;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount.text) ?? 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Dépôt')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text('Combien voulez-vous déposer ?',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style:
                    const TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                    hintText: '0', suffixText: 'FCFA', border: InputBorder.none),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Avec quel compte payez-vous ?',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (code, label, color) in _methods)
                    ChoiceChip(
                      label: Text(label),
                      selected: _method == code,
                      avatar: CircleAvatar(backgroundColor: color, radius: 8),
                      onSelected: (_) => setState(() => _method = code),
                    ),
                ],
              ),
              const Spacer(),
              FilledButton(
                onPressed: _value <= 0 || _method == null
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => JekoPaymentScreen(
                                  amount: _value, method: _method!)),
                        ),
                child: const Text('Payer'),
              ),
            ],
          ),
        ),
      );
}
