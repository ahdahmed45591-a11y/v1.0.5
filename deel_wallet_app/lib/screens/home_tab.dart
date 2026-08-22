import 'package:flutter/material.dart';

import '../data.dart';
import '../legal_texts.dart';
import '../main.dart';
import 'common.dart';
import 'deposit_screen.dart';
import 'history_screen.dart';
import 'legal_screen.dart';
import 'sell_holdings_screen.dart';
import 'stock_detail_screen.dart';

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
                  infoDialog(context, 'Paramètres',
                      'Réglages de langue, thème et notifications — bientôt disponibles.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Aide'),
                onTap: () {
                  Navigator.pop(context);
                  infoDialog(context, 'Aide',
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
                  logout(context);
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
                  onPressed: () => infoDialog(
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
