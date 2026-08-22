import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../data.dart';
import '../main.dart';

/// Vue depuis Profil : lecture seule, telechargement uniquement. Corriger
/// une piece se fait via le bandeau KycBanner (KycFormScreen) tant que le
/// dossier n'est pas valide -- pas depuis cet ecran.
class KycSummaryScreen extends StatelessWidget {
  const KycSummaryScreen({super.key});

  Future<void> _open(BuildContext context, String relPath) async {
    final uri = Uri.parse(
        '${Api.baseUrl}$relPath${relPath.contains('?') ? '&' : '?'}token=${Uri.encodeComponent(Api.token ?? '')}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir le document.")));
    }
  }

  Widget _row(BuildContext context, String label, String? url) => Card(
        child: ListTile(
          leading: Icon(url != null ? Icons.check_circle : Icons.remove_circle_outline,
              color: url != null ? Colors.green : Colors.black38),
          title: Text(label),
          subtitle: Text(url != null ? 'Reçu' : 'Non fourni'),
          trailing: url == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () => _open(context, url)),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Documents & KYC')),
        body: ListenableBuilder(
          listenable: app,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Chip(
                label: Text(app.kycVerified
                    ? 'Compte vérifié'
                    : app.kyc == 'suspended'
                        ? 'Compte suspendu'
                        : 'En attente de vérification'),
                backgroundColor:
                    (app.kycVerified ? Colors.green : brandOrange).withValues(alpha: .12),
                labelStyle: TextStyle(color: app.kycVerified ? Colors.green[800] : brandOrange),
                side: BorderSide.none,
              ),
              const SizedBox(height: 12),
              const Text(
                  "Lecture seule. Pour corriger une pièce, utilisez le bandeau en haut de "
                  "l'application tant que le dossier n'est pas validé.",
                  style: TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 16),
              _row(context, 'Photo du visage', app.selfieUrl),
              _row(context, "Pièce d'identité — RECTO", app.cniRectoUrl),
              _row(context, "Pièce d'identité — VERSO", app.cniVersoUrl),
              _row(context, 'Justificatif de domicile', app.proofAddressUrl),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Contrat SGI BRVM'),
                  subtitle: Text(app.contractSigned ? 'Signé' : 'Non signé'),
                  trailing: app.contractSigned
                      ? IconButton(
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          onPressed: () => _open(context, '/api/contract/pdf'),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      );
}
