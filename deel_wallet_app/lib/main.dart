import 'package:flutter/material.dart';

import 'api.dart';
import 'screens.dart';

// Orange, blanc, vert.
const brandOrange = Color(0xFFFF6B00);
const brandGreen = Color(0xFF16A34A);
const brandDark = Color(0xFF1A1A1A);

final theme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: brandOrange,
    secondary: brandGreen,
  ),
  scaffoldBackgroundColor: Colors.white,
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: brandOrange,
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: brandOrange, width: 1.5),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    surfaceTintColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Colors.grey.shade100),
    ),
  ),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.loadSettings();
  runApp(const BaouFinanceApp());
}

class BaouFinanceApp extends StatelessWidget {
  const BaouFinanceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'BAOU',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const OnboardingScreen(),
      );
}

/// Logo importe depuis assets/logo.jpg. Bascule sur le wordmark texte si le
/// fichier venait a manquer — rien ne casse.
class Logo extends StatelessWidget {
  const Logo({super.key, this.height = 72});
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/logo.jpg',
          height: height,
          errorBuilder: (_, __, ___) => Text(
            'BAOU Finance',
            style: TextStyle(
                fontSize: height * .3,
                fontWeight: FontWeight.w700,
                color: brandDark),
          ),
        ),
      );
}
