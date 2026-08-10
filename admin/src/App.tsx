import React, { useState, useEffect, useCallback } from 'react';
import { Page, Transaction, User, SupportTicket } from './types';
import { initialMarketQuotes } from './data';
import { Sidebar } from './components/Sidebar';
import { Header } from './components/Header';
import { DashboardView } from './components/DashboardView';
import { TransactionsView } from './components/TransactionsView';
import { UserManagementView } from './components/UserManagementView';
import { SettingsView } from './components/SettingsView';
import { SupportView } from './components/SupportView';
import {
  Bell,
  X,
  Landmark,
  Eye,
  EyeOff,
  Loader2
} from 'lucide-react';

// ── Backend URL ───────────────────────────────────────────────────────────────
const API_BASE = (import.meta as any).env?.VITE_API_BASE || 
  (typeof window !== 'undefined' && window.location.hostname !== 'localhost' 
    ? `${window.location.origin}/api` 
    : 'http://localhost:3001/api');
const DEFAULT_AVATAR = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 24 24" fill="%23ff8200"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 4c1.93 0 3.5 1.57 3.5 3.5S13.93 13 12 13s-3.5-1.57-3.5-3.5S10.07 6 12 6zm0 14c-2.03 0-3.8-1.04-4.83-2.61.03-1.6 3.22-2.47 4.83-2.47s4.8 1.87 4.83 2.47C15.8 18.96 14.03 20 12 20z"/></svg>';

// ── Backend URL for uploads (strips /api suffix) ─────────────────────────────
const BACKEND_BASE = API_BASE.replace(/\/api\/?$/, '');

// ── Data mappers ──────────────────────────────────────────────────────────────
function buildDocUrl(relUrl: string | undefined): string | undefined {
  if (!relUrl) return undefined;
  if (relUrl.startsWith('http')) return relUrl;
  return `${BACKEND_BASE}${relUrl}`;
}

function mapUser(u: any): User {
  const kyc = (u.kyc || '').toLowerCase();
  return {
    id: u.id,
    name: u.name || 'Inconnu',
    email: u.email || '',
    avatar: u.avatar || DEFAULT_AVATAR,
    accountType: u.accountType === 'Premium' ? 'Premium' : 'Standard',
    kycStatus:
      kyc === 'verified'
        ? 'VERIFIED'
        : kyc === 'rejected' || kyc === 'suspended'
        ? 'REJECTED'
        : 'PENDING',
    lastActivityDate: u.joinedAt
      ? new Date(u.joinedAt).toLocaleDateString('fr-FR')
      : 'Aujourd\'hui',
    lastActivityPlatform: 'App Android',
    birthDate: u.birthDate || 'Non renseignée',
    profession: u.profession || 'Non renseignée',
    residence: u.residence || 'Abidjan, Côte d\'Ivoire',
    whatsapp: u.whatsapp || 'Non renseigné',
    // ponytail: plus de fallback "Présent" par defaut -- avant ce correctif
    // un dossier vide affichait quand meme "Présent (CNI / Passeport)" a
    // l'admin, ce qui pouvait faire valider un compte sans aucune piece.
    identityDocStatus: u.identityDocStatus || 'Non fourni',
    proofOfAddressStatus: u.proofOfAddressStatus || 'Non fourni',
    signatureStatus: u.signatureStatus || 'Non signé',
    cniRectoUrl: buildDocUrl(u.cniRectoUrl),
    cniVersoUrl: buildDocUrl(u.cniVersoUrl),
    selfieUrl: buildDocUrl(u.selfieUrl),
    proofAddressUrl: buildDocUrl(u.proofAddressUrl),
    contractUrl: buildDocUrl(u.contractUrl),
  };
}

function mapTransaction(t: any): Transaction {
  const s = (t.status || '').toLowerCase();
  const rawType = (t.type || 'BUY').toUpperCase();
  const txType: 'BUY' | 'SELL' | 'DEPOSIT' = (rawType === 'DEPOSIT' || rawType === 'RECHARGE') ? 'DEPOSIT' : (rawType === 'SELL' ? 'SELL' : 'BUY');
  return {
    id: t.id,
    clientName: t.userName || 'Client',
    clientId: t.userId || t.id,
    // ✅ Utiliser le vrai email retourné par le backend
    clientEmail: t.userEmail || t.userId || 'inconnu@email.ci',
    clientAvatar: DEFAULT_AVATAR,
    accountType: 'Standard',
    balance: typeof t.balance === 'number' ? t.balance : (parseFloat(t.balance) || 0),
    ticker: t.ticker || (txType === 'DEPOSIT' ? 'CASH' : '-'),
    companyName: t.company || (txType === 'DEPOSIT' ? 'Dépôt Mobile Money' : (t.ticker || '-')),
    type: txType,
    quantity: t.quantity || 1,
    unitPrice: t.price || t.total || 0,
    totalAmount: t.total || t.grandTotal || 0,
    market: 'BRVM',
    // ✅ toLocaleString() supporte hour/minute (toLocaleDateString ne le supporte pas)
    dateString: t.submittedAt
      ? new Date(t.submittedAt).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })
      : 'Aujourd\'hui',
    status:
      s === 'validated'
        ? 'APPROVED'
        : s === 'rejected'
        ? 'REJECTED'
        : 'PENDING',
    paymentMethod: t.paymentMethod || 'Wave CI',
    paymentMethodCode: (t.paymentMethod || '').toLowerCase().includes('wave') ? 'WV' : 'OM',
    reference: t.paymentRef || `REF-${t.id}`,
    proofFileName: `Reçu_${t.id}.pdf`,
    proofFileSize: '1.2 MB',
    proofUploadTime: 'A l\'instant',
  };
}


function mapTicket(tk: any): SupportTicket {
  const s = (tk.status || 'OUVERT').toUpperCase();
  return {
    id: tk.id,
    clientName: tk.clientName || 'Client',
    clientId: tk.clientId || tk.userId || '-',
    subject: tk.subject || 'Message de support',
    description: tk.message || '',
    priority: 'MOYENNE',
    status:
      s === 'EN_COURS'
        ? 'EN_COURS'
        : s === 'RESOLU'
        ? 'RESOLU'
        : 'OUVERT',
    dateString: tk.createdAt
      ? new Date(tk.createdAt).toLocaleDateString('fr-FR')
      : 'Aujourd\'hui',
    timeString: tk.createdAt
      ? new Date(tk.createdAt).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })
      : '10:00',
  };
}

// ═════════════════════════════════════════════════════════════════════════════
export default function App() {

  // ── Auth State ───────────────────────────────────────────
  const [token, setToken] = useState<string | null>(() => localStorage.getItem('admin_token'));
  const [isLoggedIn, setIsLoggedIn] = useState(() => !!localStorage.getItem('admin_token'));
  const [isLoggingIn, setIsLoggingIn] = useState(false);
  const [loginEmail, setLoginEmail] = useState('');
  const [loginPassword, setLoginPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loginError, setLoginError] = useState('');

  // ── Navigation & States ─────────────────────────────────
  const [currentPage, setCurrentPage] = useState<Page>(Page.Dashboard);
  const [searchQuery, setSearchQuery] = useState('');

  // ── Central State stores ────────────────────────────────
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [tickets, setTickets] = useState<SupportTicket[]>([]);
  const [isLoadingData, setIsLoadingData] = useState(false);

  // ── Selection pointers ──────────────────────────────────
  const [selectedTransaction, setSelectedTransaction] = useState<Transaction | null>(null);

  // ── Toast System ────────────────────────────────────────
  const [toast, setToast] = useState<{ message: string; type: 'success' | 'error' | 'info' } | null>(null);

  // ── Modal state ─────────────────────────────────────────
  const [showNewOpModal, setShowNewOpModal] = useState(false);

  // ── New Operation form fields ────────────────────────────
  const [opClientName, setOpClientName] = useState('');
  const [opClientId, setOpClientId] = useState('EB-CI-09221');
  const [opTicker, setOpTicker] = useState('SNTS');
  const [opQty, setOpQty] = useState('100');
  const [opUnitPrice, setOpUnitPrice] = useState('16200');
  const [opType, setOpType] = useState<'BUY' | 'SELL' | 'DEPOSIT'>('BUY');
  const [opMethod, setOpMethod] = useState<'OM' | 'WV' | 'BANK'>('OM');

  // ── Toast helper ─────────────────────────────────────────
  const triggerToast = useCallback((message: string, type: 'success' | 'error' | 'info' = 'success') => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 4500);
  }, []);

  // ── Fetch all data from backend ──────────────────────────
  const fetchAllData = useCallback(async (adminToken: string) => {
    if (!adminToken) return;
    setIsLoadingData(true);
    try {
      const headers = { Authorization: `Bearer ${adminToken}` };

      const [usersRes, txRes, supportRes] = await Promise.allSettled([
        fetch(`${API_BASE}/admin/users`, { headers }),
        fetch(`${API_BASE}/transactions/all`, { headers }),
        fetch(`${API_BASE}/admin/support`, { headers }),
      ]);

      if (usersRes.status === 'fulfilled' && usersRes.value.ok) {
        const json = await usersRes.value.json();
        if (json.success && Array.isArray(json.data)) {
          setUsers(json.data.map(mapUser));
        }
      }

      if (txRes.status === 'fulfilled' && txRes.value.ok) {
        const json = await txRes.value.json();
        if (json.success && Array.isArray(json.data)) {
          setTransactions(json.data.map(mapTransaction));
        }
      }

      if (supportRes.status === 'fulfilled' && supportRes.value.ok) {
        const json = await supportRes.value.json();
        if (json.success && Array.isArray(json.data)) {
          setTickets(json.data.map(mapTicket));
        }
      }
    } catch (err) {
      console.error('[Admin] Erreur chargement données:', err);
    } finally {
      setIsLoadingData(false);
    }
  }, []);

  // ── Auto-load data when logged in ────────────────────────
  useEffect(() => {
    if (isLoggedIn && token) {
      fetchAllData(token);
      const interval = setInterval(() => fetchAllData(token), 15000); // refresh every 15s
      return () => clearInterval(interval);
    }
  }, [isLoggedIn, token, fetchAllData]);

  // ── Auth Handlers ────────────────────────────────────────
  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoggingIn(true);
    setLoginError('');
    try {
      const res = await fetch(`${API_BASE}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: loginEmail, password: loginPassword }),
      });
      const data = await res.json();
      if (res.ok && data.success) {
        if (data.user?.role !== 'admin') {
          setLoginError('Accès réservé aux administrateurs.');
          return;
        }
        localStorage.setItem('admin_token', data.token);
        setToken(data.token);
        setIsLoggedIn(true);
        setLoginError('');
      } else {
        setLoginError(data.error || 'Email ou mot de passe incorrect.');
      }
    } catch (err) {
      setLoginError('Impossible de joindre le serveur. Vérifiez que le backend est démarré.');
    } finally {
      setIsLoggingIn(false);
    }
  };

  const handleLogout = async () => {
    // ✅ Révoquer le token côté serveur
    try {
      if (token) {
        await fetch(`${API_BASE}/auth/logout`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${token}` },
        });
      }
    } catch {
      // Ignorer les erreurs réseau lors du logout
    }
    localStorage.removeItem('admin_token');
    setToken(null);
    setIsLoggedIn(false);
    setLoginEmail('');
    setLoginPassword('');
    setUsers([]);
    setTransactions([]);
    setTickets([]);
    setCurrentPage(Page.Dashboard);
    triggerToast('Vous avez été déconnecté avec succès.', 'info');
  };

  // ── Auto Logout after 15 minutes of inactivity ─────────────────
  useEffect(() => {
    if (!isLoggedIn) return;

    let inactivityTimer: NodeJS.Timeout;

    const resetInactivityTimer = () => {
      clearTimeout(inactivityTimer);
      // 15 minutes = 15 * 60 * 1000 = 900,000 ms
      inactivityTimer = setTimeout(() => {
        handleLogout();
        triggerToast('Session expirée : Déconnexion automatique après 15 minutes d\'inactivité.', 'info');
      }, 15 * 60 * 1000);
    };

    const activityEvents = ['mousemove', 'keydown', 'click', 'scroll', 'touchstart'];
    activityEvents.forEach(event => window.addEventListener(event, resetInactivityTimer));

    resetInactivityTimer();

    return () => {
      clearTimeout(inactivityTimer);
      activityEvents.forEach(event => window.removeEventListener(event, resetInactivityTimer));
    };
  }, [isLoggedIn]);

  // ── Transaction actions (real API) ───────────────────────
  const handleApproveTransaction = async (id: string) => {
    if (!token) return;
    try {
      const res = await fetch(`${API_BASE}/transactions/${id}/validate`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      if (res.ok && data.success) {
        triggerToast(`Transaction ${id} validée avec succès ! Portefeuille client mis à jour.`, 'success');
        fetchAllData(token);
      } else {
        triggerToast(data.error || 'Erreur lors de la validation.', 'error');
      }
    } catch {
      triggerToast('Impossible de joindre le serveur.', 'error');
    }
  };

  const handleRejectTransaction = async (id: string, reason?: string) => {
    if (!token) return;
    try {
      const res = await fetch(`${API_BASE}/transactions/${id}/reject`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ reason: reason || 'Preuve non-conforme' }),
      });
      const data = await res.json();
      if (res.ok && data.success) {
        triggerToast(`Transaction ${id} rejetée.`, 'error');
        fetchAllData(token);
      } else {
        triggerToast(data.error || 'Erreur lors du rejet.', 'error');
      }
    } catch {
      triggerToast('Impossible de joindre le serveur.', 'error');
    }
  };

  // ── User KYC actions (real API) ──────────────────────────
  const handleUpdateKyc = async (id: string, status: 'VERIFIED' | 'PENDING' | 'REJECTED') => {
    if (!token) return;
    const backendStatus = status === 'VERIFIED' ? 'verified' : status === 'REJECTED' ? 'rejected' : 'pending';
    try {
      const res = await fetch(`${API_BASE}/admin/users/${id}/kyc`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ status: backendStatus }),
      });
      const data = await res.json();
      if (res.ok && data.success) {
        const label = status === 'VERIFIED' ? 'validé ✅' : 'rejeté ❌';
        triggerToast(`KYC du client ${id} ${label}. Le client peut ${status === 'VERIFIED' ? 'désormais effectuer des opérations.' : 'être notifié.'}`, 'success');
        fetchAllData(token);
      } else {
        triggerToast(data.error || 'Erreur mise à jour KYC.', 'error');
      }
    } catch {
      triggerToast('Impossible de joindre le serveur.', 'error');
    }
  };

  const handleToggleSuspend = async (id: string) => {
    if (!token) return;
    try {
      const res = await fetch(`${API_BASE}/admin/users/${id}/suspend`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      if (res.ok && data.success) {
        triggerToast(`Compte ${id} mis à jour.`, 'info');
        fetchAllData(token);
      } else {
        triggerToast(data.error || 'Erreur suspension.', 'error');
      }
    } catch {
      triggerToast('Impossible de joindre le serveur.', 'error');
    }
  };

  // ── User creation (local only – pour référence future) ───
  const handleAddUser = (user: Omit<User, 'id'>) => {
    const newId = `EB-2024-${Math.floor(1000 + Math.random() * 9000)}`;
    const fullUser: User = { ...user, id: newId };
    setUsers(prev => [fullUser, ...prev]);
    triggerToast(`Nouveau compte client ${user.name} créé localement.`, 'success');
  };

  // ── Support ticket actions (real API) ────────────────────
  const handleUpdateTicketStatus = async (id: string, status: SupportTicket['status']) => {
    if (!token) return;
    try {
      const res = await fetch(`${API_BASE}/admin/support/${id}/status`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ status }),
      });
      const data = await res.json();
      if (res.ok && data.success) {
        const msg =
          status === 'RESOLU'
            ? `Ticket ${id} marqué comme RÉSOLU.`
            : `Ticket ${id} mis à jour : EN COURS.`;
        triggerToast(msg, status === 'RESOLU' ? 'success' : 'info');
        fetchAllData(token);
      } else {
        triggerToast(data.error || 'Erreur mise à jour ticket.', 'error');
      }
    } catch {
      triggerToast('Impossible de joindre le serveur.', 'error');
    }
  };

  // ── New operation creator (appel API réel) ──────────────
  const handleCreateOperation = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!opClientName || !token) return;

    const priceNum = parseFloat(opUnitPrice) || 1000;
    const qtyNum = parseFloat(opQty) || 10;

    // Trouver l'utilisateur correspondant
    const clientMatch = users.find(u => u.name.toLowerCase() === opClientName.toLowerCase());
    if (!clientMatch) {
      triggerToast('Client introuvable. Vérifiez le nom exact.', 'error');
      return;
    }

    try {
      const res = await fetch(`${API_BASE}/transactions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          ticker: opTicker,
          type: opType,
          quantity: qtyNum,
          price: priceNum,
          paymentMethod: opMethod === 'OM' ? 'Orange Money' : opMethod === 'WV' ? 'Wave' : 'Virement Bancaire',
        }),
      });
      const data = await res.json();
      if (res.ok && data.success) {
        triggerToast(`Ordre soumis en attente de vérification !`, 'success');
        setShowNewOpModal(false);
        setOpClientName('');
        fetchAllData(token); // ✅ Recharger depuis le backend
      } else {
        triggerToast(data.error || 'Erreur lors de la création de l\'ordre.', 'error');
      }
    } catch {
      triggerToast('Impossible de joindre le serveur.', 'error');
    }
  };

  // ═══════════════════════════════════════════════════════
  //  LOGIN SCREEN
  // ═══════════════════════════════════════════════════════
  if (!isLoggedIn) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-[#0b1c30] via-[#1a2f4a] to-[#0b1c30] flex items-center justify-center p-4">
        {toast && (
          <div className="fixed top-6 right-6 z-[200] max-w-sm w-full bg-white border border-[#dec1af]/40 shadow-2xl rounded-2xl p-4 flex gap-3">
            <Bell className="w-6 h-6 text-[#ff8200] shrink-0" />
            <div className="flex-1">
              <h4 className="font-sans font-bold text-[14px] text-[#0b1c30]">Notification</h4>
              <p className="font-sans text-[12px] text-[#574235]/90 mt-1">{toast.message}</p>
            </div>
            <button onClick={() => setToast(null)}><X className="w-4 h-4 text-gray-400" /></button>
          </div>
        )}
        <div className="w-full max-w-md">
          {/* Brand */}
          <div className="text-center mb-8">
            <img 
              src="/baou_logo.jpg" 
              alt="BAOU Logo" 
              className="w-20 h-20 rounded-2xl mx-auto mb-4 object-cover shadow-2xl border-2 border-white/20" 
            />
            <h1 className="text-3xl font-bold text-white tracking-tight">BAOU Finance</h1>
            <p className="text-[#ff8200] mt-1 text-sm font-bold uppercase tracking-wider">Portail Administrateur</p>
          </div>

          {/* Login Card */}
          <div className="bg-white/5 backdrop-blur-sm border border-white/10 rounded-3xl p-8 shadow-2xl">
            <h2 className="text-white font-bold text-xl mb-6">Connexion sécurisée</h2>
            <form onSubmit={handleLogin} className="space-y-5">
              <div className="space-y-1.5">
                <label className="block font-sans font-bold text-[11px] text-[#dec1af]/80 uppercase tracking-wider">
                  Adresse Email
                </label>
                <input
                  type="email"
                  required
                  value={loginEmail}
                  onChange={e => setLoginEmail(e.target.value)}
                  placeholder="admin@elephantbourse.ci"
                  className="w-full bg-white/10 border border-white/20 rounded-xl px-4 py-3 text-white placeholder-white/30 font-sans text-[14px] focus:outline-none focus:border-[#ff8200] focus:bg-white/15 transition-all"
                />
              </div>

              <div className="space-y-1.5">
                <label className="block font-sans font-bold text-[11px] text-[#dec1af]/80 uppercase tracking-wider">
                  Mot de passe
                </label>
                <div className="relative">
                  <input
                    type={showPassword ? 'text' : 'password'}
                    required
                    value={loginPassword}
                    onChange={e => setLoginPassword(e.target.value)}
                    placeholder="••••••••"
                    className="w-full bg-white/10 border border-white/20 rounded-xl px-4 py-3 pr-12 text-white placeholder-white/30 font-sans text-[14px] focus:outline-none focus:border-[#ff8200] focus:bg-white/15 transition-all"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(v => !v)}
                    className="absolute right-4 top-1/2 -translate-y-1/2 text-white/40 hover:text-white/80 transition-colors"
                  >
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              {loginError && (
                <div className="bg-red-500/15 border border-red-500/30 rounded-xl px-4 py-3">
                  <p className="text-red-300 font-sans text-[13px] font-medium">{loginError}</p>
                </div>
              )}

              <button
                type="submit"
                disabled={isLoggingIn}
                className="w-full bg-[#ff8200] hover:bg-[#e67400] text-white font-sans font-bold text-[15px] py-3.5 rounded-xl transition-all active:scale-95 shadow-lg shadow-[#ff8200]/30 flex items-center justify-center gap-2 disabled:opacity-60 disabled:cursor-not-allowed"
              >
                {isLoggingIn ? (
                  <>
                    <Loader2 className="w-5 h-5 animate-spin" />
                    Connexion en cours...
                  </>
                ) : (
                  'Se connecter'
                )}
              </button>
            </form>
          </div>

          <p className="text-center text-[#dec1af]/40 font-sans text-[12px] mt-6">
            BAOU Finance Admin v2.0 · Accès restreint
          </p>
        </div>
      </div>
    );
  }

  // ═══════════════════════════════════════════════════════
  //  MAIN ADMIN DASHBOARD
  // ═══════════════════════════════════════════════════════
  return (
    <div className="min-h-screen bg-[#f4f5f9] font-sans relative">

      {/* Toast notification */}
      {toast && (
        <div className={`fixed top-6 right-6 z-[200] max-w-sm w-full border shadow-2xl rounded-2xl p-4 flex gap-3 animate-slideInRight
          ${toast.type === 'success' ? 'bg-white border-emerald-200' : toast.type === 'error' ? 'bg-white border-red-200' : 'bg-white border-blue-200'}`}>
          <Bell className={`w-6 h-6 shrink-0 ${toast.type === 'success' ? 'text-emerald-500' : toast.type === 'error' ? 'text-red-500' : 'text-[#ff8200]'}`} />
          <div className="flex-1">
            <h4 className="font-sans font-bold text-[14px] text-[#0b1c30]">
              {toast.type === 'success' ? 'Succès' : toast.type === 'error' ? 'Erreur' : 'Information'}
            </h4>
            <p className="font-sans text-[12px] text-[#574235]/90 mt-1">{toast.message}</p>
          </div>
          <button onClick={() => setToast(null)}><X className="w-4 h-4 text-gray-400" /></button>
        </div>
      )}

      {/* Loading indicator */}
      {isLoadingData && (
        <div className="fixed top-4 left-1/2 -translate-x-1/2 z-[150] bg-[#0b1c30] text-white font-sans text-[12px] font-bold px-4 py-2 rounded-full flex items-center gap-2 shadow-xl">
          <Loader2 className="w-3.5 h-3.5 animate-spin" />
          Synchronisation en cours...
        </div>
      )}

      {/* New Operation Modal */}
      {showNewOpModal && (
        <div className="fixed inset-0 bg-[#0b1c30]/60 backdrop-blur-sm z-[100] flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl w-full max-w-lg shadow-2xl border border-[#dec1af]/30 overflow-hidden">
            <div className="p-6 border-b border-[#dec1af]/25 flex justify-between items-center bg-[#f8f9ff]">
              <h3 className="font-sans font-bold text-[18px] text-[#0b1c30]">Nouvelle Opération Manuelle</h3>
              <button onClick={() => setShowNewOpModal(false)} className="text-[#574235] hover:bg-gray-100 rounded-full p-1.5">
                <X className="w-5 h-5" />
              </button>
            </div>
            <form onSubmit={handleCreateOperation} className="p-6 space-y-4 font-sans text-[14px]">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5 col-span-2">
                  <label className="block font-bold text-[11px] text-[#574235] uppercase">Nom du client</label>
                  <input
                    type="text" required value={opClientName}
                    onChange={e => setOpClientName(e.target.value)}
                    placeholder="Nom complet du client"
                    className="w-full border border-[#dec1af]/45 rounded-lg px-3 py-2 text-[#0b1c30] focus:ring-1 focus:ring-[#ff8200] outline-none"
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="block font-bold text-[11px] text-[#574235] uppercase">Ticker</label>
                  <select value={opTicker} onChange={e => setOpTicker(e.target.value)}
                    className="w-full bg-white border border-[#dec1af]/45 rounded-lg px-3 py-2 focus:ring-1 focus:ring-[#ff8200] outline-none">
                    {initialMarketQuotes.map(q => <option key={q.ticker} value={q.ticker}>{q.ticker} – {q.name}</option>)}
                  </select>
                </div>
                <div className="space-y-1.5">
                  <label className="block font-bold text-[11px] text-[#574235] uppercase">Type</label>
                  <select value={opType} onChange={e => setOpType(e.target.value as any)}
                    className="w-full bg-white border border-[#dec1af]/45 rounded-lg px-3 py-2 focus:ring-1 focus:ring-[#ff8200] outline-none">
                    <option value="BUY">Achat</option>
                    <option value="SELL">Vente</option>
                    <option value="DEPOSIT">Dépôt / Recharge Solde</option>
                  </select>
                </div>
                <div className="space-y-1.5">
                  <label className="block font-bold text-[11px] text-[#574235] uppercase">Quantité</label>
                  <input type="number" min="1" value={opQty} onChange={e => setOpQty(e.target.value)}
                    className="w-full border border-[#dec1af]/45 rounded-lg px-3 py-2 focus:ring-1 focus:ring-[#ff8200] outline-none" />
                </div>
                <div className="space-y-1.5">
                  <label className="block font-bold text-[11px] text-[#574235] uppercase">Prix unitaire (FCFA)</label>
                  <input type="number" min="1" value={opUnitPrice} onChange={e => setOpUnitPrice(e.target.value)}
                    className="w-full border border-[#dec1af]/45 rounded-lg px-3 py-2 focus:ring-1 focus:ring-[#ff8200] outline-none" />
                </div>
                <div className="space-y-1.5 col-span-2">
                  <label className="block font-bold text-[11px] text-[#574235] uppercase">Méthode de paiement</label>
                  <select value={opMethod} onChange={e => setOpMethod(e.target.value as any)}
                    className="w-full bg-white border border-[#dec1af]/45 rounded-lg px-3 py-2 focus:ring-1 focus:ring-[#ff8200] outline-none">
                    <option value="OM">Orange Money</option>
                    <option value="WV">Wave</option>
                    <option value="BANK">Virement Bancaire</option>
                  </select>
                </div>
              </div>
              <div className="bg-[#f8f9ff] rounded-xl p-4 border border-[#dec1af]/20">
                <p className="font-sans font-bold text-[13px] text-[#0b1c30]">
                  Total estimé :{' '}
                  <span className="text-[#ff8200]">
                    {((parseFloat(opUnitPrice) || 0) * (parseFloat(opQty) || 0)).toLocaleString('fr-FR')} FCFA
                  </span>
                </p>
              </div>
              <div className="pt-2 flex justify-end gap-3">
                <button type="button" onClick={() => setShowNewOpModal(false)}
                  className="px-4 py-2 text-[#574235] hover:bg-gray-100 rounded-lg font-semibold text-[13px]">
                  Annuler
                </button>
                <button type="submit"
                  className="px-6 py-2 bg-[#ff8200] text-white rounded-lg font-bold text-[13px] hover:opacity-90 active:scale-95 transition-all shadow-sm shadow-[#ff8200]/20">
                  Créer l'Opération
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Sidebar */}
      <Sidebar
        currentPage={currentPage}
        setCurrentPage={(page) => {
          setCurrentPage(page);
          setSelectedTransaction(null);
        }}
        onLogout={handleLogout}
        adminProfile={{
          name: 'M. Cissé',
          role: 'Admin Level 4',
          avatar: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150&auto=format&fit=crop&q=80',
        }}
      />

      {/* Header Bar */}
      <Header
        searchQuery={searchQuery}
        setSearchQuery={setSearchQuery}
        placeholderText="Rechercher une transaction, un client..."
        pendingTransactionsCount={transactions.filter(t => t.status === 'PENDING').length}
        pendingKycCount={users.filter(u => u.kycStatus === 'PENDING').length}
        openTicketsCount={tickets.filter(t => t.status === 'OUVERT').length}
        onSupportClick={(target) => {
          if (target === 'TRANSACTIONS') {
            setCurrentPage(Page.Transactions);
          } else if (target === 'CLIENTS' || target === 'USERS' || target === 'USER_MANAGEMENT') {
            setCurrentPage(Page.UserManagement);
          } else if (target === 'SUPPORT') {
            setCurrentPage(Page.Support);
          } else {
            setCurrentPage(Page.Support);
          }
        }}
      />

      {/* Main Content */}
      <main className="pl-[280px] pt-16 min-h-screen">
        <div className="p-8 max-w-7xl mx-auto">

          {currentPage === Page.Dashboard && (
            <DashboardView
              transactions={transactions}
              onSelectTransaction={(tx) => {
                setSelectedTransaction(tx);
                setCurrentPage(Page.Transactions);
              }}
              onApproveTransaction={handleApproveTransaction}
              onRejectTransaction={handleRejectTransaction}
              onNewTransactionClick={() => setShowNewOpModal(true)}
            />
          )}

          {currentPage === Page.Transactions && (
            <TransactionsView
              transactions={transactions}
              selectedTransaction={selectedTransaction}
              setSelectedTransaction={setSelectedTransaction}
              onApproveTransaction={handleApproveTransaction}
              onRejectTransaction={handleRejectTransaction}
              onNewTransactionClick={() => setShowNewOpModal(true)}
            />
          )}

          {currentPage === Page.UserManagement && (
            <UserManagementView
              users={users}
              onAddUser={handleAddUser}
              onUpdateKyc={handleUpdateKyc}
              onToggleSuspend={handleToggleSuspend}
            />
          )}

          {currentPage === Page.Settings && (
            <SettingsView
              onSave={() => triggerToast('Paramètres du système enregistrés avec succès !', 'success')}
            />
          )}

          {currentPage === Page.Support && (
            <SupportView
              tickets={tickets}
              onUpdateTicketStatus={handleUpdateTicketStatus}
            />
          )}

        </div>
      </main>

    </div>
  );
}
