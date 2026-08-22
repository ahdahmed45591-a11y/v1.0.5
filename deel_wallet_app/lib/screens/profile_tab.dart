import 'package:flutter/material.dart';

import '../api.dart';
import '../data.dart';
import '../main.dart';
import 'common.dart';
import 'kyc_summary_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _editName(BuildContext context) async {
    final ctrl = TextEditingController(text: app.userName);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifier le profil'),
        content: TextField(
            controller: ctrl, decoration: const InputDecoration(labelText: 'Nom complet')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Enregistrer')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await Repo.updateProfile(name.trim());
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Profil',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                      radius: 36,
                      backgroundColor: brandOrange,
                      child: Icon(Icons.person, color: Colors.white, size: 36)),
                  const SizedBox(height: 12),
                  Text(app.userName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  if (app.userEmail.isNotEmpty)
                    Text(app.userEmail, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const KycSummaryScreen())),
                    child: Chip(
                      label: Text(app.kycVerified
                          ? 'Compte vérifié'
                          : app.kyc == 'suspended'
                              ? 'Compte suspendu'
                              : (app.kycDocsSubmitted && app.contractSigned)
                                  ? 'Vérification en attente'
                                  : 'Dossier à compléter'),
                      backgroundColor: (app.kycVerified ? Colors.green : brandOrange)
                          .withValues(alpha: .12),
                      labelStyle: TextStyle(color: app.kycVerified ? Colors.green[800] : brandOrange),
                      side: BorderSide.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Modifier le profil'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _editName(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Sécurité'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => infoDialog(context, 'Sécurité',
                        'Changement de mot de passe et authentification à deux facteurs — bientôt disponibles.'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Documents & KYC'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const KycSummaryScreen())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Aide & Support'),
                    subtitle: const Text('WhatsApp : $adminWhatsapp'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openWhatsApp(context, adminWhatsapp,
                        message: 'Bonjour, j\'ai besoin d\'aide sur mon compte BAOU Finance '
                            '(${app.userEmail}).'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined),
                    title: const Text('Conditions d\'utilisation'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => infoDialog(context, 'Conditions d\'utilisation',
                        'Document légal à venir.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Se déconnecter', style: TextStyle(color: Colors.red)),
                onTap: () => logout(context),
              ),
            ),
          ],
        ),
      );
}
