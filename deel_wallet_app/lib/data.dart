import 'package:flutter/foundation.dart';
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

/// Numero mobile ivoirien : 10 chiffres, commence par 0. Plus utilise par le
/// depot (Jeko collecte le numero sur sa propre page de paiement) mais garde
/// pour le champ WhatsApp du profil (test/data_test.dart) et une reutilisation
/// future.
bool phoneValid(String s) => RegExp(r'^0\d{9}$').hasMatch(s.replaceAll(' ', ''));

DateTime _parseDate(String? iso) {
  if (iso == null || iso.isEmpty) return DateTime.now();
  return DateTime.tryParse(iso) ?? DateTime.now();
}

class Txn {
  const Txn(this.name, this.amount, this.note, this.date,
      {this.id = '',
      this.ticker = '',
      this.company = '',
      this.quantity = 0,
      this.unitPrice = 0,
      this.type = '',
      this.status = 'validated'});
  final String id;
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
              id: (t['id'] ?? '').toString(),
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

  /// Depot : cree un lien de paiement Jeko pour `amount` et renvoie la
  /// reponse brute (contient `data` la transaction "pending" + `paymentUrl`
  /// a ouvrir). Le solde n'est credite qu'a la confirmation reelle du
  /// paiement (webhook Jeko, voir jeko_webhook cote backend) — plus de
  /// credit instantane non verifie.
  /// `method` = reseau choisi dans l'app (orange/wave/mtn/moov/djamo) : il
  /// verrouille le moyen de paiement cote Jeko et permet le retour
  /// automatique dans l'application apres paiement (deep link baou://).
  static Future<Map<String, dynamic>> initDeposit(double amount, String method) =>
      Api.post('/api/transactions',
          {'type': 'DEPOSIT', 'price': amount, 'paymentMethod': method});

  /// Ordre d'achat : cree une transaction BUY "pending". Le solde n'est
  /// debite qu'a la validation admin (voir validate_transaction) — le
  /// serveur refuse deja si le solde est insuffisant au moment de l'ordre.
  static Future<void> buy(Stock stock, int qty) => Api.post(
      '/api/transactions', {'type': 'BUY', 'ticker': stock.ticker, 'quantity': qty, 'price': stock.price});

  /// Ordre de vente : cree une transaction SELL "pending". Le serveur refuse
  /// deja si la quantite depasse ce qui est reellement detenu (voir
  /// _owned_quantity/create_transaction) ; le solde est credite du montant
  /// net (frais deduits) a la validation admin.
  static Future<void> sell(Stock stock, int qty) => Api.post(
      '/api/transactions', {'type': 'SELL', 'ticker': stock.ticker, 'quantity': qty, 'price': stock.price});

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

  /// Meme reponse que l'email existe ou non cote serveur : ne pas se fier au
  /// contenu pour dire a l'utilisateur "cet email n'existe pas".
  static Future<void> requestPasswordReset(String email) =>
      Api.post('/api/auth/request-password-reset', {'email': email});

  static Future<void> resetPassword(String token, String newPassword) =>
      Api.post('/api/auth/reset-password', {'token': token, 'newPassword': newPassword});

  static Future<void> updateProfile(String name, {String? whatsapp}) async {
    final body = {'firstName': name, if (whatsapp != null) 'whatsapp': whatsapp};
    final res = await Api.patch('/api/auth/profile', body);
    app._applyUser((res['user'] as Map?)?.cast<String, dynamic>() ?? {});
  }

  /// Envoie une piece KYC (photo prise via image_picker, deja en base64).
  /// docType : cni_recto | cni_verso | selfie | proof_address | contract.
  static Future<void> uploadDocument(String docType, String fileName, String fileBase64) async {
    final res = await Api.post('/api/auth/upload-document',
        {'docType': docType, 'fileName': fileName, 'fileBase64': fileBase64});
    final user = (res['user'] as Map?)?.cast<String, dynamic>();
    if (user != null) app._applyUser(user);
  }

  static Future<String> contractText() async {
    final res = await Api.get('/api/contract');
    return (res['text'] ?? '').toString();
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

  // KYC : "pending" (verrouille, dossier pas encore valide), "verified"
  // (deverrouille), "suspended" (bloque par l'admin). Cf. create_transaction
  // cote Django, qui applique le meme verrou — ceci n'est que l'affichage.
  String kyc = 'pending';
  String whatsapp = '';
  String? cniRectoUrl, cniVersoUrl, selfieUrl, proofAddressUrl, contractUrl;

  bool get kycVerified => kyc == 'verified';
  bool get kycDocsSubmitted =>
      cniRectoUrl != null && cniVersoUrl != null && selfieUrl != null && proofAddressUrl != null;
  bool get contractSigned => contractUrl != null;

  void _applyUser(Map<String, dynamic> u) {
    if (u['name'] != null) userName = u['name'].toString();
    if (u['email'] != null) userEmail = u['email'].toString();
    if (u['balance'] != null) balance = (u['balance'] as num).toDouble();
    if (u['kyc'] != null) kyc = u['kyc'].toString();
    if (u['whatsapp'] != null) whatsapp = u['whatsapp'].toString();
    cniRectoUrl = (u['cniRectoUrl'] as String?);
    cniVersoUrl = (u['cniVersoUrl'] as String?);
    selfieUrl = (u['selfieUrl'] as String?);
    proofAddressUrl = (u['proofAddressUrl'] as String?);
    contractUrl = (u['contractUrl'] as String?);
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
      if ((t.type == 'BUY' || t.type == 'SELL') && t.ticker.isNotEmpty) {
        // ponytail: putIfAbsent(qty: 0) plutot que "creer seulement sur BUY"
        // -- l'historique est trie du plus recent au plus ancien, donc une
        // vente peut apparaitre avant l'achat correspondant dans la boucle ;
        // le total final est correct quel que soit l'ordre de parcours.
        final h = byTicker.putIfAbsent(
            t.ticker, () => Holding(t.ticker, t.company.isNotEmpty ? t.company : t.ticker, 0, t.unitPrice));
        if (t.type == 'BUY') {
          final newQty = h.quantity + t.quantity;
          h.avgPrice = ((h.avgPrice * h.quantity) + (t.unitPrice * t.quantity)) / newQty;
          h.quantity = newQty;
        } else {
          h.quantity -= t.quantity;
        }
      }
      if (t.type == 'DIVIDEND' || t.type == 'DIVIDENDE') dividends += t.amount;
      if (t.amount < 0 && t.date.year == now.year && t.date.month == now.month) {
        spentThisMonth += t.amount.abs();
      }
    }
    holdings = byTicker.values.where((h) => h.quantity > 0).toList();
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
    kyc = 'pending';
    whatsapp = '';
    cniRectoUrl = cniVersoUrl = selfieUrl = proofAddressUrl = contractUrl = null;
    notifyListeners();
  }
}

final app = AppState();
