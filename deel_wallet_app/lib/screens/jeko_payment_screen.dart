import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../data.dart';
import '../main.dart';

/// Ouvre le lien de paiement Jèko dans le navigateur, puis attend la
/// confirmation reelle (webhook cote backend, voir jeko_webhook) : sondage
/// periodique + verification immediate au retour dans l'application (voir
/// didChangeAppLifecycleState, c'est le "retour dans l'app" apres paiement).
class JekoPaymentScreen extends StatefulWidget {
  const JekoPaymentScreen({super.key, required this.amount});
  final double amount;
  @override
  State<JekoPaymentScreen> createState() => _JekoPaymentScreenState();
}

enum _DepositStep { starting, waiting, done, error }

class _JekoPaymentScreenState extends State<JekoPaymentScreen> with WidgetsBindingObserver {
  _DepositStep _step = _DepositStep.starting;
  String? _txId;
  String? _paymentMethod;
  String? _error;
  Timer? _poll;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _step == _DepositStep.waiting) _check();
  }

  Future<void> _start() async {
    try {
      final res = await Repo.initDeposit(widget.amount);
      final tx = res['data'] as Map<String, dynamic>?;
      if (tx == null) throw ApiException('Réponse de paiement invalide.');
      if (tx['status'] == 'validated') {
        // Jeko non configure cote serveur (dev/CI, voir create_transaction) :
        // deja credite, rien a ouvrir.
        await app.refresh();
        if (!mounted) return;
        setState(() => _step = _DepositStep.done);
        return;
      }
      final url = res['paymentUrl'] as String?;
      if (url == null) throw ApiException('Lien de paiement indisponible.');
      _txId = tx['id'] as String?;
      _paymentMethod = tx['paymentMethod'] as String?;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() => _step = _DepositStep.waiting);
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check());
    } on ApiException catch (e) {
      if (mounted) setState(() { _step = _DepositStep.error; _error = e.message; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _step = _DepositStep.error;
          _error = "Impossible d'ouvrir la page de paiement.";
        });
      }
    }
  }

  Future<void> _check() async {
    if (_txId == null || _checking) return;
    _checking = true;
    try {
      final rows = await Repo.transactions();
      final match = rows.where((t) => t.id == _txId);
      if (match.isNotEmpty && match.first.status == 'validated') {
        _poll?.cancel();
        await app.refresh();
        if (!mounted) return;
        setState(() => _step = _DepositStep.done);
      }
    } on ApiException {
      // Sondage silencieux : une erreur reseau ponctuelle ne doit pas
      // interrompre l'attente, le prochain tick reessaiera.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Dépôt Jèko')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: _body(context)),
        ),
      );

  Widget _body(BuildContext context) {
    switch (_step) {
      case _DepositStep.starting:
        return const Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Préparation du paiement…'),
        ]);
      case _DepositStep.waiting:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('En attente de la confirmation du paiement de ${money(widget.amount)}…',
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Une fois le paiement effectué sur la page Jèko, revenez ici.',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          if (_paymentMethod?.contains('partagé') == true) ...[
            const SizedBox(height: 16),
            // ponytail: lien Jèko de secours (compte pas encore active pour
            // l'API, voir backend) -> montant non verrouillable cote Jeko.
            // Seul avertissement possible : demander au client de saisir le
            // bon montant lui-meme ; jeko_webhook associe par montant.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Important : sur la page Jèko, saisissez bien ${money(widget.amount)} exactement. '
                'La confirmation est automatique mais se base sur ce montant : un autre montant bloquera la validation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton(onPressed: _check, child: const Text("J'ai payé, vérifier")),
        ]);
      case _DepositStep.done:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          const CircleAvatar(
              radius: 28,
              backgroundColor: brandGreen,
              child: Icon(Icons.check, color: Colors.white, size: 32)),
          const SizedBox(height: 16),
          const Text('Votre argent est arrivé !',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Le solde a été mis à jour.', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('Terminé')),
        ]);
      case _DepositStep.error:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 16),
          Text(_error ?? 'Une erreur est survenue.', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Retour')),
        ]);
    }
  }
}
