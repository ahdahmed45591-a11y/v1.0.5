import 'package:flutter/material.dart';

import '../data.dart';
import '../main.dart';
import 'brvm_tab.dart';
import 'home_tab.dart';
import 'kyc_banner.dart';
import 'profile_tab.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    // Rechauffe le cache brvmStocks pour la tuile portefeuille. Echec
    // silencieux ici : chaque ecran qui a besoin des cours refait sa propre
    // requete (BrvmTab) et affiche l'erreur lui-meme.
    Repo.stocks().catchError((_) => <Stock>[]);
  }

  void _goTo(int i) => setState(() => _i = i);

  @override
  Widget build(BuildContext context) {
    final tabs = [HomeTab(onNavigate: _goTo), const BrvmTab(), const ProfileTab()];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const KycBanner(),
            Expanded(child: tabs[_i]),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        indicatorColor: brandOrange,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'BRVM'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
