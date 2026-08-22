import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import 'login_screen.dart';

/// Numero WhatsApp de l'administrateur SGI (support client).
const adminWhatsapp = '0545591789';

void logout(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Se déconnecter'),
      content: const Text('Voulez-vous vraiment vous déconnecter ?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(
          onPressed: () {
            app.logout();
            Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
          },
          child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

void infoDialog(BuildContext context, String title, String body) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
      ],
    ),
  );
}

/// Ouvre WhatsApp sur une conversation avec [phone] (format local 0XXXXXXXXX,
/// converti en indicatif +225). Affiche un message d'erreur si aucune app
/// WhatsApp/navigateur ne peut ouvrir le lien (device sans WhatsApp installe).
Future<void> openWhatsApp(BuildContext context, String phone, {String message = ''}) async {
  final clean = '225${phone.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0'), '')}';
  final uri = Uri.parse('https://wa.me/$clean${message.isEmpty ? '' : '?text=${Uri.encodeComponent(message)}'}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir WhatsApp.")));
  }
}
