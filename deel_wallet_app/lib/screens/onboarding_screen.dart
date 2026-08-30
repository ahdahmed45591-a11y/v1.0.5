import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _i = 0;

  static const _slides = [
    (Icons.smartphone, 'Paiement via mobile money',
        'Rechargez et payez avec Orange Money, Wave, MTN.'),
    (Icons.verified_user, 'Paiement sécurisé',
        'Protégé par un chiffrement de niveau bancaire.'),
    (Icons.trending_up, "Achat & vente d'actions",
        'Investissez sur la BRVM en toute simplicité.'),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_i != _slides.length - 1) {
      _pc.nextPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      return;
    }
    (await SharedPreferences.getInstance()).setBool(onboardingSeenKey, true);
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Align(alignment: Alignment.centerLeft, child: Logo(height: 40)),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pc,
                  onPageChanged: (i) => setState(() => _i = i),
                  itemCount: _slides.length,
                  itemBuilder: (_, i) {
                    final s = _slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 200,
                            width: 200,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [brandOrange, Color(0xFFFF9A4D)],
                              ),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Icon(s.$1, size: 88, color: Colors.white),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            s.$2,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(
                                fontSize: 21, fontWeight: FontWeight.w600, height: 1.25),
                          ),
                          const SizedBox(height: 12),
                          Text(s.$3,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    height: 6,
                    width: i == _i ? 20 : 6,
                    decoration: BoxDecoration(
                      color: i == _i ? brandGreen : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                      _i == _slides.length - 1 ? 'Commencer' : 'Suivant'),
                ),
              ),
            ],
          ),
        ),
      );
}
