import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'jeko_payment_screen.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});
  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _amount = TextEditingController();

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
              const Spacer(),
              Text('Orange Money, Wave, MTN, carte bancaire.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _value <= 0
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => JekoPaymentScreen(amount: _value)),
                        ),
                child: const Text('Payer avec Mobile Money'),
              ),
            ],
          ),
        ),
      );
}
