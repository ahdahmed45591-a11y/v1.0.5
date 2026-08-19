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
    created = models.DateTimeField(auto_now_add=True)

    class Meta:
        # unshift() cote Node : le plus recent en premier.
        ordering = ["-created"]

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
