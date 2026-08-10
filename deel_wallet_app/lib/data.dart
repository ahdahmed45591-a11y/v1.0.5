import 'package:flutter/material.dart';

import 'api.dart';

/// FCFA n'a pas de centimes en usage courant. Regroupement par espaces,
/// ecrit a la main plutot que via intl : evite l'espace insecable que
/// NumberFormat('fr_FR') produit et qui casserait une comparaison de test.
String money(double v) {
  final digits = v.round().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return '${v < 0 ? '-' : ''}$buf FCFA';
}

/// Numero mobile ivoirien : 10 chiffres, commence par 0.
bool phoneValid(String s) => RegExp(r'^0\d{9}$').hasMatch(s.replaceAll(' ', ''));

DateTime _parseDate(String? iso) {
  if (iso == null || iso.isEmpty) return DateTime.now();
  return DateTime.tryParse(iso) ?? DateTime.now();
}

class Txn {
  const Txn(this.name, this.amount, this.note, this.date,
      {this.ticker = '',
      this.company = '',
      this.quantity = 0,
      this.unitPrice = 0,
      this.type = '',
      this.status = 'validated'});
  final String name;
  final double amount; // negatif = sortant
  final String note;
  final DateTime date;
  final String ticker, company, type, status;
  final int quantity;
  final double unitPrice;
  String get initials => name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0])
      .join()
      .toUpperCase();
}

/// Operateur de mobile money. [color]/[textColor] tiennent lieu de logo tant
/// qu'un vrai fichier de marque n'est pas fourni — remplacer par Image.asset
/// une fois les logos Wave/Orange/MTN disponibles sous licence.
class Funding {
  const Funding(this.label, this.sub, this.color, this.textColor);
  final String label, sub;
  final Color color, textColor;
}

const fundingSources = [
  Funding('Wave CI', 'Paiement mobile Wave', Color(0xFF1DC8E0), Colors.white),
  Funding('Orange Money', 'Paiement mobile Orange', Color(0xFFFF6600), Colors.white),
  Funding('MTN Money', 'Paiement mobile MTN', Color(0xFFFFCC00), Colors.black87),
];

class Stock {
  const Stock(this.ticker, this.company, this.sector, this.price, this.change,
      {this.prevClose = 0,
      this.volume = 0,
      this.marketCap = '',
      this.high52 = 0,
      this.low52 = 0,
      this.pe = 0,
      this.dividend = 0,
      this.yieldPct = 0});
  final String ticker, company, sector;
  final double price; // FCFA
  final double change; // pourcentage vs cloture precedente
  final double prevClose, high52, low52, pe, dividend, yieldPct;
  final int volume;
  final String marketCap;
}

/// Cache alimente par Repo.stocks() (GET /api/stocks). Vide tant qu'aucun
/// appel n'a ete fait — l'onglet BRVM et le portefeuille en tiennent compte.
List<Stock> brvmStocks = [];

Stock? findStock(String ticker) {
  for (final s in brvmStocks) {
    if (s.ticker == ticker) return s;
  }
  return null;
}

class Holding {
  Holding(this.ticker, this.company, this.quantity, this.avgPrice);
  final String ticker, company;
  int quantity;
  double avgPrice;
}

String _txnLabel(Map<String, dynamic> t) {
  final type = (t['type'] ?? '').toString();
  final ticker = (t['ticker'] ?? '').toString();
  if (type == 'DEPOSIT' || type == 'RECHARGE') {
    return 'Dépôt ${t['paymentMethod'] ?? ''}'.trim();
  }
  if (type == 'BUY') return 'Achat $ticker';
  if (type == 'SELL') return 'Vente $ticker';
  if (type == 'DIVIDEND' || type == 'DIVIDENDE') return 'Dividende $ticker';
  final company = (t['company'] ?? '').toString();
  return company.isNotEmpty ? company : type;
}

String _txnNote(Map<String, dynamic> t) {
  final type = (t['type'] ?? '').toString();
  final status = (t['status'] ?? '').toString();
  final base = switch (type) {
    'DEPOSIT' || 'RECHARGE' => 'Recharge',
    'BUY' => 'Bourse',
    'SELL' => 'Vente',
    'DIVIDEND' || 'DIVIDENDE' => 'Dividende',
    _ => type,
  };
  if (status == 'pending') return '$base • en attente';
  if (status == 'rejected') return '$base • rejeté';
  return base;
}

double _txnAmount(Map<String, dynamic> t) {
  final type = (t['type'] ?? '').toString();
  final total = (t['total'] as num?)?.toDouble() ?? 0;
  final grandTotal = (t['grandTotal'] as num?)?.toDouble() ?? total;
  return type == 'BUY' ? -grandTotal : total;
}

/// ponytail: un seul seam vers le backend_django (voir api.dart). Chaque
/// methode reprend exactement les routes/formes JSON de backend_django/api.
class Repo {
  static Future<List<Txn>> transactions() async {
    final res = await Api.get('/api/transactions');
    final rows = (res['data'] as List? ?? const []).cast<Map<String, dynamic>>();
    return rows
        .map((t) => Txn(
              _txnLabel(t),
              _txnAmount(t),
              _txnNote(t),
              _parseDate((t['processedAt'] ?? t['submittedAt'])?.toString()),
              ticker: (t['ticker'] ?? '').toString(),
              company: (t['company'] ?? '').toString(),
              quantity: (t['quantity'] as num?)?.toInt() ?? 0,
              unitPrice: (t['price'] as num?)?.toDouble() ?? 0,
              type: (t['type'] ?? '').toString(),
              status: (t['status'] ?? 'validated').toString(),
            ))
        .toList();
  }

  static Future<List<Stock>> stocks() async {
    final res = await Api.get('/api/stocks');
    final rows = (res['data'] as List? ?? const []).cast<Map<String, dynamic>>();
    brvmStocks = rows
        .map((s) => Stock(
              (s['ticker'] ?? '').toString(),
              (s['company'] ?? '').toString(),
              (s['sector'] ?? '').toString(),
              (s['price'] as num?)?.toDouble() ?? 0,
              (s['change'] as num?)?.toDouble() ?? 0,
              prevClose: (s['prevClose'] as num?)?.toDouble() ?? 0,
              volume: (s['volume'] as num?)?.toInt() ?? 0,
              marketCap: (s['marketCap'] ?? '').toString(),
              high52: (s['high52'] as num?)?.toDouble() ?? 0,
              low52: (s['low52'] as num?)?.toDouble() ?? 0,
              pe: (s['pe'] as num?)?.toDouble() ?? 0,
              dividend: (s['dividend'] as num?)?.toDouble() ?? 0,
              yieldPct: (s['yield'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
    return brvmStocks;
  }

  /// Depot mobile money : le serveur valide et credite le solde
  /// immediatement (voir create_transaction, branche DEPOSIT/RECHARGE).
  static Future<void> topUp(double amount, String method) =>
      Api.post('/api/transactions', {'type': 'DEPOSIT', 'price': amount, 'paymentMethod': method});

  /// Ordre d'achat : cree une transaction BUY "pending". Le solde n'est
  /// debite qu'a la validation admin (voir validate_transaction) — le
  /// serveur refuse deja si le solde est insuffisant au moment de l'ordre.
  static Future<void> buy(Stock stock, int qty) => Api.post(
      '/api/transactions', {'type': 'BUY', 'ticker': stock.ticker, 'quantity': qty, 'price': stock.price});

  static Future<void> login(String email, String password) async {
    final res = await Api.post('/api/auth/login', {'email': email, 'password': password});
    Api.token = res['token'] as String?;
    app._applyUser((res['user'] as Map?)?.cast<String, dynamic>() ?? {});
  }

  /// L'API ne renvoie pas de jeton a l'inscription : on enchaine avec login.
  static Future<void> register(String name, String email, String password) async {
    await Api.post('/api/auth/register', {'name': name, 'email': email, 'password': password});
    await login(email, password);
  }

  static Future<void> updateProfile(String name) async {
    final res = await Api.patch('/api/auth/profile', {'firstName': name});
    app._applyUser((res['user'] as Map?)?.cast<String, dynamic>() ?? {});
  }
}

class AppState extends ChangeNotifier {
  double balance = 0;
  final double owing = 0; // pas de champ equivalent cote API pour l'instant
  final double budget = 160000; // objectif d'affichage local, pas un champ serveur
  double spent = 0;
  double dividendsReceived = 0;
  String userName = 'Utilisateur';
  String userEmail = '';
  List<Holding> holdings = [];
  List<Txn> transactions = [];

  void _applyUser(Map<String, dynamic> u) {
    if (u['name'] != null) userName = u['name'].toString();
    if (u['email'] != null) userEmail = u['email'].toString();
    if (u['balance'] != null) balance = (u['balance'] as num).toDouble();
    notifyListeners();
  }

  /// Recharge solde, transactions et portefeuille depuis le serveur.
  /// A appeler apres connexion/inscription et apres chaque depot/achat.
  Future<void> refresh() async {
    // /api/auth/profile n'accepte que PATCH/POST cote Django (jamais GET) —
    // un POST a corps vide se contente de renvoyer l'utilisateur courant.
    final profile = await Api.post('/api/auth/profile', {});
    _applyUser((profile['user'] as Map?)?.cast<String, dynamic>() ?? {});
    transactions = await Repo.transactions();
    _recomputeFromTransactions();
    notifyListeners();
  }

  void _recomputeFromTransactions() {
    final byTicker = <String, Holding>{};
    var dividends = 0.0;
    var spentThisMonth = 0.0;
    final now = DateTime.now();
    for (final t in transactions) {
      if (t.status != 'validated') continue;
      if (t.type == 'BUY' && t.ticker.isNotEmpty) {
        final h = byTicker[t.ticker];
        if (h == null) {
          byTicker[t.ticker] =
              Holding(t.ticker, t.company.isNotEmpty ? t.company : t.ticker, t.quantity, t.unitPrice);
        } else {
          final newQty = h.quantity + t.quantity;
          h.avgPrice = ((h.avgPrice * h.quantity) + (t.unitPrice * t.quantity)) / newQty;
          h.quantity = newQty;
        }
      }
      if (t.type == 'DIVIDEND' || t.type == 'DIVIDENDE') dividends += t.amount;
      if (t.amount < 0 && t.date.year == now.year && t.date.month == now.month) {
        spentThisMonth += t.amount.abs();
      }
    }
    holdings = byTicker.values.toList();
    dividendsReceived = dividends;
    spent = spentThisMonth;
  }

  void logout() {
    Api.token = null;
    balance = 0;
    holdings = [];
    transactions = [];
    userName = 'Utilisateur';
    userEmail = '';
    notifyListeners();
  }
}

final app = AppState();
