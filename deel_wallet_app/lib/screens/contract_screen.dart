import 'dart:convert';

import 'package:flutter/material.dart';

import '../api.dart';
import '../data.dart';
import 'signature_pad.dart';

class ContractScreen extends StatefulWidget {
  const ContractScreen({super.key});
  @override
  State<ContractScreen> createState() => _ContractScreenState();
}

class _ContractScreenState extends State<ContractScreen> {
  late Future<String> _future = Repo.contractText();
  final _padKey = GlobalKey<SignaturePadState>();
  bool _accepted = false;
  bool _hasStroke = false;
  bool _busy = false;

  Future<void> _sign() async {
    if (!_accepted || !_hasStroke) return;
    setState(() => _busy = true);
    try {
      final png = await _padKey.currentState?.capture();
      if (png == null) {
        setState(() => _hasStroke = false); // pad vide malgre le flag : on revalide
        return;
      }
      await Repo.uploadDocument(
          'contract', 'signature_${DateTime.now().millisecondsSinceEpoch}.png', base64Encode(png));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Contrat signé. Dossier envoyé pour validation.')));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Contrat SGI BRVM')),
        body: FutureBuilder<String>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData && !snap.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${snap.error}'),
                  TextButton(
                      onPressed: () => setState(() => _future = Repo.contractText()),
                      child: const Text('Réessayer')),
                ]),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Text(snap.data!, style: const TextStyle(height: 1.5)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.black12)), color: Colors.white),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        value: _accepted,
                        onChanged: (v) => setState(() => _accepted = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text("J'ai lu et j'accepte les termes du contrat SGI BRVM."),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Signez ci-dessous avec le doigt',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          TextButton(
                            onPressed: () {
                              _padKey.currentState?.clear();
                              setState(() => _hasStroke = false);
                            },
                            child: const Text('Effacer'),
                          ),
                        ],
                      ),
                      SignaturePad(key: _padKey, onChanged: (v) => setState(() => _hasStroke = v)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: (_accepted && _hasStroke && !_busy) ? _sign : null,
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Signer et envoyer'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
}
