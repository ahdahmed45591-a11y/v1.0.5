import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'data.dart';
import 'legal_texts.dart';
import 'main.dart';

// ---------------------------------------------------------------- onboarding

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

  void _next() => _i == _slides.length - 1
      ? Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()))
      : _pc.nextPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);

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

// -------------------------------------------------------------------- login

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Repo.login(_email.text, _password.text);
      await app.refresh();
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const Shell()));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.black87),
              tooltip: 'Paramètres du serveur',
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Center(child: Logo(height: 64)),
                const SizedBox(height: 32),
                const Text('Se connecter',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('Accédez à votre compte BAOU Finance.',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  validator: (v) =>
                      (v ?? '').contains('@') ? null : 'E-mail invalide',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _hide,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    suffixIcon: IconButton(
                      icon: Icon(
                          _hide ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Mot de passe requis' : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Se connecter'),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                    child: const Text('Mot de passe oublié ?',
                        style: TextStyle(color: Colors.black54)),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text.rich(TextSpan(children: [
                      TextSpan(
                          text: "Pas encore de compte ? ",
                          style: TextStyle(color: Colors.black54)),
                      TextSpan(
                          text: "S'inscrire",
                          style: TextStyle(
                              color: brandGreen, fontWeight: FontWeight.w600)),
                    ])),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// -------------------------------------------------------- mot de passe oublie

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  bool _busy = false;
  bool _codeSent = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_email.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-mail invalide')));
      return;
    }
    setState(() => _busy = true);
    try {
      await Repo.requestPasswordReset(_email.text.trim());
      if (!mounted) return;
      setState(() => _codeSent = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Si ce compte existe, un code a été envoyé par e-mail.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_code.text.trim().isEmpty || _newPassword.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Collez le code reçu et choisissez un mot de passe (6 caractères min.)')));
      return;
    }
    setState(() => _busy = true);
    try {
      await Repo.resetPassword(_code.text.trim(), _newPassword.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe mis à jour. Connectez-vous.')));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mot de passe oublié')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                _codeSent
                    ? 'Collez le code reçu par e-mail et choisissez un nouveau mot de passe.'
                    : "Entrez l'e-mail de votre compte : un code de réinitialisation valable 1 heure vous sera envoyé.",
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _email,
                enabled: !_codeSent,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: 16),
              if (!_codeSent)
                FilledButton(
                  onPressed: _busy ? null : _sendCode,
                  child: _busy
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Envoyer le code'),
                ),
              if (_codeSent) ...[
                TextField(
                  controller: _code,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Code reçu par e-mail', alignLabelWithHint: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPassword,
                  obscureText: _hide,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    suffixIcon: IconButton(
                      icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _resetPassword,
                  child: _busy
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Réinitialiser le mot de passe'),
                ),
                TextButton(
                  onPressed: _busy ? null : _sendCode,
                  child: const Text('Renvoyer le code'),
                ),
              ],
            ],
          ),
        ),
      );
}

// ----------------------------------------------------------------- register

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Repo.register(_name.text, _email.text, _password.text);
      await app.refresh();
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const Shell()));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Créer un compte',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('Rejoignez BAOU Finance en quelques secondes.',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nom complet'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Nom requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  validator: (v) =>
                      (v ?? '').contains('@') ? null : 'E-mail invalide',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _hide,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    suffixIcon: IconButton(
                      icon: Icon(
                          _hide ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                  validator: (v) => (v ?? '').length >= 4
                      ? null
                      : '4 caractères minimum',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  obscureText: _hide,
                  decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
                  validator: (v) =>
                      v == _password.text ? null : 'Les mots de passe ne correspondent pas',
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Créer mon compte'),
                ),
              ],
            ),
          ),
        ),
      );
}

// --------------------------------------------------------------------- shell

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

void _logout(BuildContext context) {
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

void _infoDialog(BuildContext context, String title, String body) {
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

/// Numero WhatsApp de l'administrateur SGI (support client).
const adminWhatsapp = '0545591789';

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

// ---------------------------------------------------------------------- home

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onNavigate});
  final void Function(int) onNavigate;

  Future<void> _openPlusMenu(BuildContext context) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Paramètres'),
                onTap: () {
                  Navigator.pop(context);
                  _infoDialog(context, 'Paramètres',
                      'Réglages de langue, thème et notifications — bientôt disponibles.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Aide'),
                onTap: () {
                  Navigator.pop(context);
                  _infoDialog(context, 'Aide',
                      'Une question ? Écrivez-nous à baoufinance@gmail.com');
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Conditions générales'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const LegalScreen(
                          title: 'Conditions générales', text: cguText)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Politique de confidentialité'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const LegalScreen(
                          title: 'Politique de confidentialité', text: privacyText)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Se déconnecter', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _logout(context);
                },
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Text('Bonjour 👋',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () => _infoDialog(
                      context, 'Notifications', 'Aucune nouvelle notification.'),
                  icon: const Icon(Icons.notifications_none),
                ),
                GestureDetector(
                  onTap: () => onNavigate(2),
                  child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: brandOrange,
                      child: Icon(Icons.person, color: Colors.white, size: 18)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [brandGreen, Color(0xFF0F7A38)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BAOU Finance',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Text(money(app.balance),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Solde restant dû ${money(app.owing)}',
                      style: TextStyle(color: Colors.white.withValues(alpha: .8))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Action(Icons.add_circle_outline, 'Dépôt', () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const DepositScreen()));
                }),
                _Action(Icons.sell_outlined, 'Vendre', () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SellHoldingsScreen()));
                }),
                _Action(Icons.history, 'Historique', () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()));
                }),
                _Action(Icons.more_horiz, 'Plus', () => _openPlusMenu(context)),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Mon portefeuille',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => onNavigate(1),
                          child: const Text('Voir la BRVM'),
                        ),
                      ],
                    ),
                    for (final h in app.holdings) _holdingTile(context, h),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.savings_outlined, color: brandGreen, size: 18),
                        const SizedBox(width: 8),
                        const Text('Dividendes reçus'),
                        const Spacer(),
                        Text(money(app.dividendsReceived),
                            style: const TextStyle(
                                color: brandGreen, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Dépensé ce mois-ci',
                            style: TextStyle(color: Colors.black54)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const HistoryScreen())),
                          child: const Text('Voir détails',
                              style: TextStyle(color: brandGreen, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(money(app.spent),
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        Chip(
                          label: const Text('Dans les clous'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: brandGreen.withValues(alpha: .12),
                          labelStyle: const TextStyle(color: brandGreen),
                          side: BorderSide.none,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: app.spent / app.budget,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade100,
                        color: brandOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Transactions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen())),
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            FutureBuilder(
              future: Repo.transactions(),
              builder: (_, snap) => Column(
                  children: (snap.data ?? []).take(3).map(_txnTile).toList()),
            ),
          ],
        ),
      );

  Widget _holdingTile(BuildContext context, Holding h) {
    final stock = findStock(h.ticker);
    final value = h.quantity * (stock?.price ?? h.avgPrice);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
          backgroundColor: brandGreen.withValues(alpha: .12),
          child: Text(h.ticker.substring(0, 2),
              style: const TextStyle(color: brandGreen, fontSize: 12, fontWeight: FontWeight.w700))),
      title: Text(h.company),
      subtitle: Text('${h.quantity} titres • PRU ${money(h.avgPrice)}'),
      trailing: Text(money(value), style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: stock == null
          ? null
          : () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => StockDetailScreen(stock: stock))),
    );
  }

  Widget _txnTile(Txn t) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(child: Text(t.initials)),
        title: Text(t.name),
        subtitle: Text(t.note),
        trailing: Text(
          money(t.amount.abs()),
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: t.amount >= 0 ? brandGreen : Colors.black87),
        ),
      );
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          IconButton.filled(
            onPressed: onTap,
            icon: Icon(icon),
            style: IconButton.styleFrom(
                backgroundColor: brandOrange.withValues(alpha: .12),
                foregroundColor: brandOrange,
                padding: const EdgeInsets.all(14)),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );
}

// ------------------------------------------------------------------- history

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Historique')),
        body: FutureBuilder(
          future: Repo.transactions(),
          builder: (_, snap) => ListView(
            padding: const EdgeInsets.all(16),
            children: (snap.data ?? [])
                .map((t) => ListTile(
                      leading: CircleAvatar(child: Text(t.initials)),
                      title: Text(t.name),
                      subtitle: Text(
                          '${t.note} • ${t.date.day}/${t.date.month}/${t.date.year}'),
                      trailing: Text(
                        money(t.amount.abs()),
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: t.amount >= 0 ? brandGreen : Colors.black87),
                      ),
                    ))
                .toList(),
          ),
        ),
      );
}

// -------------------------------------------------------------- deposit flow

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});
  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount.text) ?? 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Dépôt')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text('Combien voulez-vous déposer ?',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _amount,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style:
                    const TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                    hintText: '0', suffixText: 'FCFA', border: InputBorder.none),
                onChanged: (_) => setState(() {}),
              ),
              const Spacer(),
              Text('Orange Money, Wave, MTN, carte bancaire — via Jèko.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _value <= 0
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => JekoPaymentScreen(amount: _value)),
                        ),
                child: const Text('Payer avec Jèko'),
              ),
            ],
          ),
        ),
      );
}

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

// ---------------------------------------------------------------------- brvm

class BrvmTab extends StatefulWidget {
  const BrvmTab({super.key});
  @override
  State<BrvmTab> createState() => _BrvmTabState();
}

/// Seance BRVM : lun-ven, 9h00-15h00 GMT (source : data/brvm_data, mis a
/// jour toutes les 15 min sur ce creneau). Abidjan est en UTC+0 toute
/// l'annee, DateTime.now().toUtc() donne donc directement l'heure locale.
class _MarketStatus {
  const _MarketStatus(this.open, this.label);
  final bool open;
  final String label;
}

_MarketStatus _brvmMarketStatus() {
  final now = DateTime.now().toUtc();
  final isWeekday = now.weekday <= DateTime.friday;
  final minutesNow = now.hour * 60 + now.minute;
  final isOpen = isWeekday && minutesNow >= 9 * 60 && minutesNow < 15 * 60;
  return _MarketStatus(
    isOpen,
    isOpen ? 'Marché ouvert — ferme à 15h00 (GMT)' : 'Marché fermé — 9h-15h GMT, lun-ven',
  );
}

class _BrvmTabState extends State<BrvmTab> {
  late Future<List<Stock>> _future = Repo.stocks();
  String _query = '';

  List<Stock> _filter(List<Stock> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((s) => s.ticker.toLowerCase().contains(q) || s.company.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () async => setState(() => _future = Repo.stocks()),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('BRVM',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const Text('Bourse Régionale des Valeurs Mobilières',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final status = _brvmMarketStatus();
              return Chip(
                avatar: Icon(Icons.circle,
                    size: 10, color: status.open ? brandGreen : Colors.black45),
                label: Text(status.label, style: const TextStyle(fontSize: 12)),
                backgroundColor: (status.open ? brandGreen : Colors.black45).withValues(alpha: .08),
                side: BorderSide.none,
              );
            }),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Rechercher une société ou un ticker',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _query = ''),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Stock>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                        child: Text(
                            snap.error is ApiException ? (snap.error as ApiException).message : 'Erreur.')),
                  );
                }
                final results = _filter(snap.data!);
                if (results.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: Text('Aucun résultat.')),
                  );
                }
                return Column(children: [for (final s in results) _stockTile(context, s)]);
              },
            ),
          ],
        ),
      );

  Widget _stockTile(BuildContext context, Stock s) {
    final up = s.change >= 0;
    return Card(
      child: ListTile(
        title: Text(s.company, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${s.ticker} • ${s.sector}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(money(s.price), style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${up ? '+' : ''}${s.change.toStringAsFixed(2)} %',
                style: TextStyle(
                    color: up ? brandGreen : Colors.red, fontSize: 12)),
          ],
        ),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => StockDetailScreen(stock: s))),
      ),
    );
  }
}

class StockDetailScreen extends StatelessWidget {
  const StockDetailScreen({super.key, required this.stock});
  final Stock stock;

  @override
  Widget build(BuildContext context) {
    final up = stock.change >= 0;
    return Scaffold(
      appBar: AppBar(title: Text(stock.ticker)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stock.company,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text(stock.sector, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 20),
            Text(money(stock.price),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
            Row(
              children: [
                Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                    color: up ? brandGreen : Colors.red, size: 16),
                Text('${up ? '+' : ''}${stock.change.toStringAsFixed(2)} % aujourd\'hui',
                    style: TextStyle(color: up ? brandGreen : Colors.red)),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row('Secteur', stock.sector),
                    _row('Ticker', stock.ticker),
                    _row('Marché', 'BRVM — Abidjan'),
                    if (stock.prevClose > 0) _row('Clôture précédente', money(stock.prevClose)),
                    if (stock.volume > 0) _row('Volume', '${stock.volume}'),
                    if (stock.marketCap.isNotEmpty) _row('Capitalisation', stock.marketCap),
                    if (stock.high52 > 0) _row('Plus haut (52 sem.)', money(stock.high52)),
                    if (stock.low52 > 0) _row('Plus bas (52 sem.)', money(stock.low52)),
                    if (stock.pe > 0) _row('PER', stock.pe.toStringAsFixed(1)),
                    if (stock.dividend > 0) _row('Dividende', money(stock.dividend)),
                    if (stock.yieldPct > 0) _row('Rendement', '${stock.yieldPct.toStringAsFixed(2)} %'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => BuyStockScreen(stock: stock))),
              child: const Text('Acheter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.black54)),
            const Spacer(),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class BuyStockScreen extends StatefulWidget {
  const BuyStockScreen({super.key, required this.stock});
  final Stock stock;
  @override
  State<BuyStockScreen> createState() => _BuyStockScreenState();
}

class _BuyStockScreenState extends State<BuyStockScreen> {
  int _qty = 1;
  bool _busy = false;

  double get _total => _qty * widget.stock.price;
  double get _fees => _total * 0.005;
  double get _tva => _fees * 0.18;
  double get _grandTotal => _total + _fees + _tva;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await Repo.buy(widget.stock, _qty);
      await app.refresh();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Ordre d'achat envoyé"),
          content: Text(
              '$_qty ${widget.stock.ticker} pour ${money(_grandTotal)}, en attente de validation.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Acheter ${widget.stock.ticker}')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(widget.stock.company,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text('$_qty',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => setState(() => _qty++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row('Sous-total', money(_total)),
                      _row('Frais (0,5 %)', money(_fees)),
                      _row('TVA', money(_tva)),
                      const Divider(),
                      _row('Total', money(_grandTotal), bold: true),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _confirm,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Confirmer l\'achat'),
              ),
            ],
          ),
        ),
      );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: bold ? null : Colors.black54)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    fontSize: bold ? 16 : 14)),
          ],
        ),
      );
}

class SellHoldingsScreen extends StatelessWidget {
  const SellHoldingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Vendre des titres')),
        body: ListenableBuilder(
          listenable: app,
          builder: (context, _) => app.holdings.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Aucun titre en portefeuille pour le moment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: app.holdings.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final h = app.holdings[i];
                    final stock = findStock(h.ticker);
                    return ListTile(
                      leading: CircleAvatar(
                          backgroundColor: brandOrange.withValues(alpha: .12),
                          child: Text(h.ticker.substring(0, 2),
                              style: const TextStyle(
                                  color: brandOrange, fontSize: 12, fontWeight: FontWeight.w700))),
                      title: Text(h.company),
                      subtitle: Text('${h.quantity} titres détenus • PRU ${money(h.avgPrice)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: stock == null
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => SellStockScreen(stock: stock, maxQty: h.quantity))),
                    );
                  },
                ),
        ),
      );
}

class SellStockScreen extends StatefulWidget {
  const SellStockScreen({super.key, required this.stock, required this.maxQty});
  final Stock stock;
  final int maxQty;
  @override
  State<SellStockScreen> createState() => _SellStockScreenState();
}

class _SellStockScreenState extends State<SellStockScreen> {
  late int _qty = widget.maxQty > 0 ? 1 : 0;
  bool _busy = false;

  double get _total => _qty * widget.stock.price;
  double get _fees => _total * 0.005;
  double get _tva => _fees * 0.18;
  double get _net => _total - _fees - _tva;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await Repo.sell(widget.stock, _qty);
      await app.refresh();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ordre de vente envoyé'),
          content: Text(
              '$_qty ${widget.stock.ticker} pour ${money(_net)} net, en attente de validation.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Vendre ${widget.stock.ticker}')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(widget.stock.company,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Text('${widget.maxQty} titres détenus',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text('$_qty',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  ),
                  IconButton.filledTonal(
                    onPressed: _qty < widget.maxQty ? () => setState(() => _qty++) : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _sellRow('Sous-total', money(_total)),
                      _sellRow('Frais (0,5 %)', '- ${money(_fees)}'),
                      _sellRow('TVA', '- ${money(_tva)}'),
                      const Divider(),
                      _sellRow('Net crédité', money(_net), bold: true),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: (_busy || _qty <= 0) ? null : _confirm,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Confirmer la vente'),
              ),
            ],
          ),
        ),
      );

  Widget _sellRow(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: bold ? null : Colors.black54)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    fontSize: bold ? 16 : 14)),
          ],
        ),
      );
}

// ------------------------------------------------------------------- profil

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
                    onTap: () => _infoDialog(context, 'Sécurité',
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
                    onTap: () => _infoDialog(context, 'Conditions d\'utilisation',
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
                onTap: () => _logout(context),
              ),
            ),
          ],
        ),
      );
}

// -------------------------------------------------------------- parametres

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _url = TextEditingController(text: Api.baseUrl);
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    await Api.setBaseUrl(_url.text);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Adresse enregistrée.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Paramètres')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Adresse du serveur',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              const Text(
                'Émulateur : http://10.0.2.2:3001\n'
                'Téléphone (Ngrok) : https://xxxx.ngrok-free.app\n'
                'Wi-Fi local : http://[IP de l\'ordinateur]:3001',
                style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                    labelText: 'URL du serveur', hintText: 'https://xxxx.ngrok-free.app'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      );
}

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

// -------------------------------------------------------------------- kyc

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

class ContractScreen extends StatefulWidget {
  const ContractScreen({super.key});
  @override
  State<ContractScreen> createState() => _ContractScreenState();
}

class _ContractScreenState extends State<ContractScreen> {
  late Future<String> _future = Repo.contractText();
  final _padKey = GlobalKey<_SignaturePadState>();
  bool _accepted = false;
  bool _hasStroke = false;
  bool _busy = false;

  Future<void> _sign() async {
    if (!_accepted || !_hasStroke) return;
    setState(() => _busy = true);
    try {
      final png = await _padKey.currentState?.capture();
      if (png == null) {
        setState(() => _hasStroke = false); // pad vide malgre le flag : on revalide
        return;
      }
      await Repo.uploadDocument(
          'contract', 'signature_${DateTime.now().millisecondsSinceEpoch}.png', base64Encode(png));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Contrat signé. Dossier envoyé pour validation.')));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Contrat SGI BRVM')),
        body: FutureBuilder<String>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData && !snap.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${snap.error}'),
                  TextButton(
                      onPressed: () => setState(() => _future = Repo.contractText()),
                      child: const Text('Réessayer')),
                ]),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Text(snap.data!, style: const TextStyle(height: 1.5)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.black12)), color: Colors.white),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        value: _accepted,
                        onChanged: (v) => setState(() => _accepted = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text("J'ai lu et j'accepte les termes du contrat SGI BRVM."),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Signez ci-dessous avec le doigt',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          TextButton(
                            onPressed: () {
                              _padKey.currentState?.clear();
                              setState(() => _hasStroke = false);
                            },
                            child: const Text('Effacer'),
                          ),
                        ],
                      ),
                      SignaturePad(key: _padKey, onChanged: (v) => setState(() => _hasStroke = v)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: (_accepted && _hasStroke && !_busy) ? _sign : null,
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Signer et envoyer'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
}

/// Pad de signature manuscrite : capture les traits au doigt et les rend en
/// PNG (RepaintBoundary.toImage). Natif Flutter (CustomPainter), pas de
/// dependance signature/canvas externe pour un besoin aussi simple.
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, required this.onChanged});
  final ValueChanged<bool> onChanged;
  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final _boundaryKey = GlobalKey();
  final List<Offset?> _points = [];

  void _addPoint(Offset? p) {
    setState(() => _points.add(p));
    widget.onChanged(_points.any((p) => p != null));
  }

  void clear() {
    setState(() => _points.clear());
  }

  Future<Uint8List?> capture() async {
    if (_points.every((p) => p == null)) return null;
    final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        key: _boundaryKey,
        child: Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
              border: Border.all(color: Colors.black26),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white),
          // ClipRRect : le trait ne doit jamais deborder du cadre arrondi,
          // sinon la capture (boundary.toImage) inclut des pixels hors zone.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, // capte le geste meme sur zone non peinte
              onPanStart: (d) => _addPoint(d.localPosition),
              onPanUpdate: (d) => _addPoint(d.localPosition),
              onPanEnd: (_) => _addPoint(null),
              child: SizedBox.expand(child: CustomPaint(painter: _SignaturePainter(_points))),
            ),
          ),
        ),
      );
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.points);
  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    // ponytail: noir opaque + trait plus epais -- Colors.black87 (87%
    // d'opacite) + strokeWidth 2.4 pouvait paraitre invisible sur certains
    // ecrans/backends de rendu. Colors.black (100%) + 3.5 est net partout.
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    for (var i = 0; i < points.length - 1; i++) {
      final p1 = points[i], p2 = points[i + 1];
      if (p1 != null && p2 != null) canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => old.points != points;
}
