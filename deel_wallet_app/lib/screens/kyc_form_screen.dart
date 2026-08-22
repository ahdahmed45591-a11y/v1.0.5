import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../data.dart';
import 'contract_screen.dart';

const Map<String, String> _kycDocLabels = {
  'selfie': 'Photo de votre visage',
  'cni_recto': "Pièce d'identité (CNI/Passeport) — RECTO",
  'cni_verso': "Pièce d'identité (CNI/Passeport) — VERSO",
  'proof_address': 'Justificatif de domicile (facture CIE/SODECI, < 3 mois)',
};

class KycFormScreen extends StatefulWidget {
  const KycFormScreen({super.key});
  @override
  State<KycFormScreen> createState() => _KycFormScreenState();
}

class _KycFormScreenState extends State<KycFormScreen> {
  final _picker = ImagePicker();
  late final _name = TextEditingController(text: app.userName);
  late final _whatsapp = TextEditingController(text: app.whatsapp);
  final Map<String, XFile?> _photos = {
    'selfie': null,
    'cni_recto': null,
    'cni_verso': null,
    'proof_address': null,
  };
  bool _busy = false;
  final Set<String> _picking = {}; // slots avec une capture en cours

  bool _already(String docType) => switch (docType) {
        'selfie' => app.selfieUrl != null,
        'cni_recto' => app.cniRectoUrl != null,
        'cni_verso' => app.cniVersoUrl != null,
        'proof_address' => app.proofAddressUrl != null,
        _ => false,
      };

  /// Reprendre une photo (mauvaise photo, refaire) : ouvre a nouveau la
  /// camera pour ce slot, quel que soit son etat actuel (deja envoyee ou
  /// juste prise). ponytail: sans le garde _picking, un double-tap pouvait
  /// declencher deux pickImage() concurrents -> PlatformException
  /// "already_active" côté image_picker, jamais affichee (try/catch absent)
  /// -> le bouton semblait ne rien faire.
  Future<void> _pick(String docType) async {
    if (_picking.contains(docType)) return;
    setState(() => _picking.add(docType));
    try {
      final photo =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
      if (photo == null) return; // photo annulee cote camera, pas une erreur
      setState(() => _photos[docType] = photo);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Impossible d'ouvrir la caméra. Réessayez.")));
      }
    } finally {
      if (mounted) setState(() => _picking.remove(docType));
    }
  }

  bool get _canSubmit =>
      _name.text.trim().isNotEmpty &&
      _whatsapp.text.trim().isNotEmpty &&
      _photos.keys.every((k) => _photos[k] != null || _already(k));

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await Repo.updateProfile(_name.text.trim(), whatsapp: _whatsapp.text.trim());
      for (final entry in _photos.entries) {
        final file = entry.value;
        if (file == null) continue; // deja envoye lors d'une soumission precedente
        final bytes = await file.readAsBytes();
        await Repo.uploadDocument(entry.key, file.name, base64Encode(bytes));
      }
      if (!mounted) return;
      if (!app.contractSigned) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const ContractScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Dossier envoyé. En attente de validation par l'administrateur.")));
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _slot(String docType) {
    final file = _photos[docType];
    final done = file != null || _already(docType);
    return Card(
      child: ListTile(
        leading: Icon(done ? Icons.check_circle : Icons.camera_alt_outlined,
            color: done ? Colors.green : Colors.black45),
        title: Text(_kycDocLabels[docType]!),
        subtitle: Text(file != null ? file.name : (done ? 'Déjà envoyé' : 'Non fourni')),
        trailing: TextButton(
            onPressed: _picking.contains(docType) ? null : () => _pick(docType),
            child: _picking.contains(docType)
                ? const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(done ? 'Reprendre' : 'Prendre la photo')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Dossier KYC')),
        body: ListenableBuilder(
          listenable: app,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (app.kyc == 'suspended')
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                      "Votre dossier a été rejeté ou votre compte suspendu. "
                      "Renvoyez vos pièces pour repasser en revue.",
                      style: TextStyle(color: Colors.red)),
                ),
              const Text('Informations personnelles',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nom complet'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _whatsapp,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Numéro WhatsApp', hintText: '07 00 00 00 00'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              const Text('Pièces justificatives',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              _slot('selfie'),
              _slot('cni_recto'),
              _slot('cni_verso'),
              _slot('proof_address'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: (_canSubmit && !_busy) ? _submit : null,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(app.contractSigned ? 'Envoyer le dossier' : 'Continuer vers le contrat'),
              ),
            ],
          ),
        ),
      );
}
