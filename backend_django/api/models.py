from django.db import models

# Montants en FCFA. Decimal et pas float : 0,5 % de frais + 18 % de TVA
# produisent de vraies fractions, et l'erreur binaire du float s'accumule
# dans les soldes a chaque operation. max_digits=14 -> jusqu'a
# 999 999 999 999,99 FCFA, largement au-dela de tout solde realiste.
MONEY = dict(max_digits=14, decimal_places=2, default=0)


class User(models.Model):
    id = models.CharField(primary_key=True, max_length=64)
    name = models.CharField(max_length=200)
    email = models.EmailField(unique=True)
    password = models.CharField(max_length=255)
    role = models.CharField(max_length=20, default="client")
    level = models.IntegerField(default=1)
    avatar = models.CharField(max_length=20, blank=True, default="")
    whatsapp = models.CharField(max_length=50, blank=True, default="")
    birth_date = models.CharField(max_length=30, blank=True, default="")
    profession = models.CharField(max_length=120, blank=True, default="")
    residence = models.CharField(max_length=200, blank=True, default="")
    kyc = models.CharField(max_length=20, default="pending")
    email_verified = models.BooleanField(default=False)
    balance = models.DecimalField(**MONEY)
    portfolio_value = models.DecimalField(**MONEY)
    # Verrouillage progressif du login (voir login() dans views.py) :
    # 5 echecs -> 10 min, 10 echecs -> 1h, 15 echecs -> reset obligatoire.
    failed_login_attempts = models.IntegerField(default=0)
    locked_until = models.DateTimeField(null=True, blank=True)
    must_reset_password = models.BooleanField(default=False)
    joined_at = models.CharField(max_length=40, blank=True, default="")
    identity_doc_status = models.CharField(max_length=30, blank=True, default="")
    proof_of_address_status = models.CharField(max_length=30, blank=True, default="")
    signature_status = models.CharField(max_length=30, blank=True, default="")
    cni_recto_url = models.CharField(max_length=300, null=True, blank=True)
    cni_verso_url = models.CharField(max_length=300, null=True, blank=True)
    selfie_url = models.CharField(max_length=300, null=True, blank=True)
    proof_address_url = models.CharField(max_length=300, null=True, blank=True)
    contract_url = models.CharField(max_length=300, null=True, blank=True)
    documents = models.JSONField(default=dict, blank=True)

    # Les cles JSON restent en camelCase : l'app Android et l'admin React
    # consomment deja ce format, le changer casserait les clients.
    def as_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "role": self.role,
            "level": self.level,
            "avatar": self.avatar,
            "whatsapp": self.whatsapp,
            "birthDate": self.birth_date,
            "profession": self.profession,
            "residence": self.residence,
            "kyc": self.kyc,
            "emailVerified": self.email_verified,
            # float() : le contrat JSON ne change pas (Flutter et l'admin React
            # lisent des nombres). Seul le stockage et les calculs passent en
            # Decimal ; la serialisation reste identique a l'octet pres.
            "balance": float(self.balance),
            "portfolioValue": float(self.portfolio_value),
            "joinedAt": self.joined_at,
            "identityDocStatus": self.identity_doc_status,
            "proofOfAddressStatus": self.proof_of_address_status,
            "signatureStatus": self.signature_status,
            "cniRectoUrl": self.cni_recto_url,
            "cniVersoUrl": self.cni_verso_url,
            "selfieUrl": self.selfie_url,
            "proofAddressUrl": self.proof_address_url,
            "contractUrl": self.contract_url,
            "documents": self.documents,
        }


class Transaction(models.Model):
    id = models.CharField(primary_key=True, max_length=64)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="transactions")
    user_email = models.CharField(max_length=200, blank=True, default="")
    user_name = models.CharField(max_length=200, blank=True, default="")
    ticker = models.CharField(max_length=20, blank=True, default="")
    company = models.CharField(max_length=200, blank=True, default="")
    type = models.CharField(max_length=20)
    quantity = models.IntegerField(default=0)
    price = models.DecimalField(**MONEY)
    total = models.DecimalField(**MONEY)
    fees = models.DecimalField(**MONEY)
    tva = models.DecimalField(**MONEY)
    grand_total = models.DecimalField(**MONEY)
    status = models.CharField(max_length=20, default="pending")
    payment_ref = models.CharField(max_length=120, blank=True, default="")
    payment_method = models.CharField(max_length=120, blank=True, default="")
    rejection_reason = models.CharField(max_length=300, null=True, blank=True)
    submitted_at = models.CharField(max_length=40, blank=True, default="")
    processed_at = models.CharField(max_length=40, null=True, blank=True)
    processed_by = models.CharField(max_length=64, null=True, blank=True)
    # Cle d'idempotence fournie par le client (en-tete Idempotency-Key).
    # Un reseau mobile qui coupe entre l'envoi et la reponse pousse l'app a
    # rejouer la requete : sans cette cle, le client se retrouve avec deux
    # ordres et deux fois le montant gele. Voir create_transaction.
    idempotency_key = models.CharField(max_length=64, null=True, blank=True)
    created = models.DateTimeField(auto_now_add=True)

    class Meta:
        # unshift() cote Node : le plus recent en premier.
        ordering = ["-created"]
        constraints = [
            # Index unique partiel : les NULL ne se genent pas entre eux, donc
            # les ordres sans cle (clients pas encore a jour) passent toujours.
            models.UniqueConstraint(
                fields=["user", "idempotency_key"],
                condition=models.Q(idempotency_key__isnull=False),
                name="uniq_tx_idempotency_per_user",
            )
        ]

    def as_dict(self):
        return {
            "id": self.id,
            "userId": self.user_id,
            "userEmail": self.user_email,
            "userName": self.user_name,
            "ticker": self.ticker,
            "company": self.company,
            "type": self.type,
            "quantity": self.quantity,
            # float() : voir User.as_dict -- contrat JSON inchange.
            "price": float(self.price),
            "total": float(self.total),
            "fees": float(self.fees),
            "tva": float(self.tva),
            "grandTotal": float(self.grand_total),
            "status": self.status,
            "paymentRef": self.payment_ref,
            "paymentMethod": self.payment_method,
            "rejectionReason": self.rejection_reason,
            "submittedAt": self.submitted_at,
            "processedAt": self.processed_at,
            "processedBy": self.processed_by,
        }


class Message(models.Model):
    id = models.CharField(primary_key=True, max_length=64)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="messages")
    user_name = models.CharField(max_length=200, blank=True, default="")
    sender = models.CharField(max_length=20, default="ADMIN")
    text = models.TextField(blank=True, default="")
    time = models.CharField(max_length=10, blank=True, default="")
    created = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created"]

    def as_dict(self):
        return {
            "id": self.id,
            "userId": self.user_id,
            "userName": self.user_name,
            "sender": self.sender,
            "text": self.text,
            "time": self.time,
        }


class LedgerEntry(models.Model):
    """Journal immuable de TOUS les mouvements de solde (tracabilite exigee
    par la BCEAO / l'AMF-UMOA). Ecrit par apply_balance() dans views.py, seul
    point de mutation du solde -- si une ligne manque ici, c'est qu'un solde a
    bouge hors du chemin officiel.

    Append-only : save() refuse toute modification, et les FK sont en PROTECT
    (on ne supprime pas un compte dont le journal financier existe encore).
    """

    user = models.ForeignKey(User, on_delete=models.PROTECT, related_name="ledger")
    transaction = models.ForeignKey(Transaction, on_delete=models.PROTECT, null=True, blank=True)
    delta = models.DecimalField(**MONEY)  # signe : negatif = debit
    balance_before = models.DecimalField(**MONEY)
    balance_after = models.DecimalField(**MONEY)
    reason = models.CharField(max_length=60)
    created = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created"]

    def save(self, *args, **kwargs):
        if self.pk:
            raise ValueError("LedgerEntry est append-only : modification interdite.")
        super().save(*args, **kwargs)


class AuditLog(models.Model):
    """Journal immuable des actions sensibles NON financieres : connexions,
    decisions KYC, suspensions, decisions sur les ordres, uploads.

    Complementaire de LedgerEntry, qui ne couvre que l'argent. Un regulateur
    demande les deux : « combien a bouge » (LedgerEntry) et « qui a decide
    quoi, quand, depuis ou » (ici).

    actor_id / target_id sont des CharField et non des FK : un acteur peut
    etre "SYSTEM" (webhook, tache automatique) ou "ANONYME" (login echoue sur
    un email inexistant), et un journal doit survivre a la suppression du
    compte qu'il decrit.

    Append-only : save() refuse toute modification.
    """

    actor_id = models.CharField(max_length=64, db_index=True)
    actor_role = models.CharField(max_length=20, blank=True, default="")
    action = models.CharField(max_length=40, db_index=True)  # ex: "kyc.change"
    target_id = models.CharField(max_length=64, blank=True, default="", db_index=True)
    details = models.JSONField(default=dict, blank=True)
    ip = models.CharField(max_length=64, blank=True, default="")
    created = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created"]

    def save(self, *args, **kwargs):
        if self.pk:
            raise ValueError("AuditLog est append-only : modification interdite.")
        super().save(*args, **kwargs)

    def as_dict(self):
        return {
            "id": self.id,
            "actorId": self.actor_id,
            "actorRole": self.actor_role,
            "action": self.action,
            "targetId": self.target_id,
            "details": self.details,
            "ip": self.ip,
            "at": self.created.isoformat(),
        }


class Ticket(models.Model):
    id = models.CharField(primary_key=True, max_length=64)
    client_name = models.CharField(max_length=200, blank=True, default="")
    client_id = models.CharField(max_length=200, blank=True, default="")
    subject = models.CharField(max_length=300, blank=True, default="")
    message = models.TextField(blank=True, default="")
    status = models.CharField(max_length=20, default="OUVERT")
    date_string = models.CharField(max_length=60, blank=True, default="")
    created = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created"]

    def as_dict(self):
        return {
            "id": self.id,
            "clientName": self.client_name,
            "clientId": self.client_id,
            "subject": self.subject,
            "message": self.message,
            "status": self.status,
            "dateString": self.date_string,
        }
