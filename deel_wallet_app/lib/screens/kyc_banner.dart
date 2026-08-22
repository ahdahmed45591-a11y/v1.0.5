import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import 'kyc_form_screen.dart';

/// Bandeau permanent tant que le compte n'est pas verifie par l'admin :
/// le client peut naviguer dans l'app mais create_transaction (cote
/// Django) refuse toute operation d'argent jusqu'a app.kycVerified.
class KycBanner extends StatelessWidget {
  const KycBanner({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (app.kycVerified) return const SizedBox.shrink();
          final String text;
          if (app.kyc == 'suspended') {
            text = "Compte suspendu par l'administrateur — contactez le support.";
          } else if (app.kycDocsSubmitted && app.contractSigned) {
            text = 'Dossier KYC en cours de vérification par l\'administrateur.';
          } else {
            text = 'Complétez votre dossier KYC et signez le contrat SGI pour trader.';
          }
          return GestureDetector(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const KycFormScreen())),
            child: Container(
              width: double.infinity,
              color: brandOrange.withValues(alpha: .12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 18, color: brandOrange),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(text,
                          style: const TextStyle(
                              color: brandOrange, fontSize: 12.5, fontWeight: FontWeight.w600))),
                  const Icon(Icons.chevron_right, size: 18, color: brandOrange),
                ],
              ),
            ),
          );
        },
      );
}
