import 'package:flutter/material.dart';

/// Ecran generique pour afficher un texte juridique long (CGU / politique de
/// confidentialite, voir legal_texts.dart) -- evite de dupliquer un Scaffold
/// scrollable pour chacun des deux textes.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.6)),
        ),
      );
}
