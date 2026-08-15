import React from 'react';
import { Transaction, User, SupportTicket, Page } from '../types';
import { exportTransactionsReportPdf } from '../lib/exportPdf';
import {
  Clock,
  Wallet,
  UserCheck,
  ShoppingCart,
  TrendingDown,
  LifeBuoy,
  Users,
  CheckCircle2,
  XCircle,
  ChevronRight,
  FileDown,
  Plus,
  MessageCircle,
  CalendarClock,
} from 'lucide-react';

// ponytail: couleurs reprises telles quelles de deel_wallet_app/lib/main.dart
// (brandGreen/brandOrange/brandDark) -- l'ancien Dashboard utilise une
// palette navy/orange "Elephant Bourse" qui ne correspond plus a l'appli.
const GREEN = '#16A34A';
const GREEN_DARK = '#0F7A38'; // degrade de la carte solde, Accueil mobile
const ORANGE = '#FF6B00';
const DARK = '#1A1A1A';
const ADMIN_WHATSAPP = '2250545591789';

function brvmMarketStatus() {
  // Meme regle que _brvmMarketStatus() cote Flutter : 9h-15h GMT, lun-ven.
  const now = new Date();
  const day = now.getUTCDay();
  const minutes = now.getUTCHours() * 60 + now.getUTCMinutes();
  const isWeekday = day >= 1 && day <= 5;
  const open = isWeekday && minutes >= 9 * 60 && minutes < 15 * 60;
  return { open, label: open ? 'Ouvert — ferme à 15h00 (GMT)' : 'Fermé — 9h-15h GMT, lun-ven' };
}

interface DashboardBaouViewProps {
  transactions: Transaction[];
  users: User[];
  tickets: SupportTicket[];
  onSelectTransaction: (tx: Transaction) => void;
  onApproveTransaction: (id: string) => void;
  onRejectTransaction: (id: string) => void;
  onNewTransactionClick: () => void;
  onNavigate: (page: Page) => void;
}

export const DashboardBaouView: React.FC<DashboardBaouViewProps> = ({
  transactions,
  users,
  tickets,
  onSelectTransaction,
  onApproveTransaction,
  onRejectTransaction,
  onNewTransactionClick,
  onNavigate,
}) => {
  const pending = transactions.filter(t => t.status === 'PENDING');
  const approved = transactions.filter(t => t.status === 'APPROVED');
  const buyVolume = approved.filter(t => t.type === 'BUY').reduce((s, t) => s + t.totalAmount, 0);
  const sellVolume = approved.filter(t => t.type === 'SELL').reduce((s, t) => s + t.totalAmount, 0);
  const depositVolume = approved.filter(t => t.type === 'DEPOSIT').reduce((s, t) => s + t.totalAmount, 0);

  // ponytail: l'ancien Dashboard affichait "New KYC Requests: 0" fige en dur
  // -- ici c'est le vrai compte (meme calcul que le badge du Header).
  const kycPending = users.filter(u => u.kycStatus === 'PENDING').length;
  const kycVerified = users.filter(u => u.kycStatus === 'VERIFIED').length;
  const kycRejected = users.filter(u => u.kycStatus === 'REJECTED').length;
  const aum = users.reduce((s, u) => s + (u.balance || 0), 0);

  const openTickets = tickets.filter(t => t.status !== 'RESOLU');
  const market = brvmMarketStatus();

  const fmt = (n: number) => new Intl.NumberFormat('fr-FR').format(Math.round(n));

  return (
    <div className="space-y-6">
      {/* En-tête */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="font-sans font-extrabold text-[24px] tracking-tight" style={{ color: DARK }}>
            Tableau de bord BAOU
          </h2>
          <p className="font-sans text-[14px] text-black/60 mt-0.5">
            Nouvelle version aux couleurs de l'application mobile.
          </p>
        </div>
        <div className="flex gap-3 shrink-0">
          <button
            onClick={() => exportTransactionsReportPdf(transactions)}
            className="bg-white border border-black/10 px-4 py-2 rounded-lg font-sans font-semibold text-[13px] flex items-center gap-2 hover:bg-gray-50 active:scale-95 transition-all"
            style={{ color: GREEN_DARK }}
          >
            <FileDown className="w-4 h-4" />
            Exporter rapport PDF
          </button>
          <button
            onClick={onNewTransactionClick}
            className="text-white px-4 py-2 rounded-lg font-sans font-semibold text-[13px] flex items-center gap-2 hover:opacity-90 active:scale-95 transition-all shadow-sm"
            style={{ background: ORANGE }}
          >
            <Plus className="w-4 h-4" />
            Nouvelle opération
          </button>
        </div>
      </div>

      {/* Carte héros dégradée — même signature visuelle que l'écran Accueil mobile */}
      <div
        className="rounded-[20px] p-6 text-white flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4"
        style={{ background: `linear-gradient(135deg, ${GREEN} 0%, ${GREEN_DARK} 100%)` }}
      >
        <div>
          <p className="font-sans text-[13px] font-bold uppercase tracking-wider opacity-80">Solde total clients</p>
          <p className="font-sans text-[32px] font-extrabold mt-1">{fmt(aum)} FCFA</p>
          <p className="font-sans text-[12px] opacity-80 mt-1">
            Cumul sur {users.length} compte{users.length > 1 ? 's' : ''}
          </p>
        </div>
        <a
          href={`https://wa.me/${ADMIN_WHATSAPP}`}
          target="_blank"
          rel="noreferrer"
          className="bg-white/15 hover:bg-white/25 transition-colors rounded-xl px-4 py-3 flex items-center gap-2 font-sans font-bold text-[13px] shrink-0"
        >
          <MessageCircle className="w-4 h-4" />
          WhatsApp admin (05 45 59 17 89)
        </a>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard icon={<Clock className="w-5 h-5" />} accent={ORANGE} label="Transactions en attente"
          value={`${pending.length}`} sub="commandes à valider" />
        <KpiCard icon={<ShoppingCart className="w-5 h-5" />} accent={GREEN} label="Volume achats validés"
          value={`${fmt(buyVolume)} FCFA`} sub={`${approved.filter(t => t.type === 'BUY').length} ordres`} />
        <KpiCard icon={<TrendingDown className="w-5 h-5" />} accent={GREEN_DARK} label="Volume ventes validées"
          value={`${fmt(sellVolume)} FCFA`} sub={`${approved.filter(t => t.type === 'SELL').length} ordres`} />
        <KpiCard icon={<UserCheck className="w-5 h-5" />} accent={ORANGE} label="Dossiers KYC en attente"
          value={`${kycPending}`} sub={`${kycVerified} vérifiés · ${kycRejected} rejetés/suspendus`}
          onClick={() => onNavigate(Page.UserManagement)} />
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard icon={<Wallet className="w-5 h-5" />} accent={GREEN} label="Dépôts validés"
          value={`${fmt(depositVolume)} FCFA`} sub="recharges de solde" />
        <KpiCard icon={<Users className="w-5 h-5" />} accent={DARK} label="Clients enregistrés"
          value={`${users.length}`} sub="tous statuts confondus" onClick={() => onNavigate(Page.UserManagement)} />
        <KpiCard icon={<LifeBuoy className="w-5 h-5" />} accent={ORANGE} label="Tickets support ouverts"
          value={`${openTickets.length}`} sub="à traiter" onClick={() => onNavigate(Page.Support)} />
        <KpiCard icon={<CalendarClock className="w-5 h-5" />} accent={market.open ? GREEN : DARK} label="Marché BRVM"
          value={market.open ? 'OUVERT' : 'FERMÉ'} sub={market.label} dot={market.open} />
      </div>

      {/* Transactions en attente */}
      <section className="bg-white border border-black/10 rounded-xl shadow-sm overflow-hidden">
        <div className="p-6 border-b border-black/10">
          <h3 className="font-sans font-bold text-[18px]" style={{ color: DARK }}>
            Transactions en attente de validation
          </h3>
          <p className="font-sans text-[13px] text-black/60 mt-0.5">
            Achats et ventes soumis par les clients (dépôts déjà crédités automatiquement).
          </p>
        </div>
        <div className="overflow-x-auto">
          {pending.length === 0 ? (
            <div className="p-12 text-center text-black/50 font-sans">
              <CheckCircle2 className="w-12 h-12 mx-auto mb-3" style={{ color: GREEN }} />
              <p className="font-bold">Aucune transaction en attente</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-[#f4f6fa] text-black/60 font-sans font-bold text-[11px] uppercase tracking-wider border-b border-black/10">
                  <th className="px-6 py-3.5">Client</th>
                  <th className="px-6 py-3.5">Ticker</th>
                  <th className="px-6 py-3.5">Type</th>
                  <th className="px-6 py-3.5 text-right">Montant (FCFA)</th>
                  <th className="px-6 py-3.5">Date</th>
                  <th className="px-6 py-3.5 text-center">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-black/5">
                {pending.map(tx => (
                  <tr key={tx.id} className="hover:bg-[#f4f6fa] transition-colors cursor-pointer"
                    onClick={() => onSelectTransaction(tx)}>
                    <td className="px-6 py-4">
                      <div className="font-sans font-bold text-[14px]" style={{ color: DARK }}>{tx.clientName}</div>
                      <div className="font-sans text-[12px] text-black/50">ID: {tx.clientId}</div>
                    </td>
                    <td className="px-6 py-4">
                      <span className="font-sans font-extrabold text-[14px] block" style={{ color: DARK }}>{tx.ticker}</span>
                      <span className="font-sans text-[12px] text-black/50">{tx.companyName}</span>
                    </td>
                    <td className="px-6 py-4">
                      <span
                        className="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold"
                        style={{
                          background: tx.type === 'BUY' ? `${GREEN}22` : tx.type === 'SELL' ? `${ORANGE}22` : '#e5eeff',
                          color: tx.type === 'BUY' ? GREEN_DARK : tx.type === 'SELL' ? ORANGE : '#005db6',
                        }}
                      >
                        {tx.type === 'DEPOSIT' ? 'DÉPÔT' : tx.type === 'SELL' ? 'VENTE' : 'ACHAT'}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-right font-sans font-extrabold text-[14px]" style={{ color: DARK }}>
                      {fmt(tx.totalAmount)}
                    </td>
                    <td className="px-6 py-4 font-sans text-[13px] text-black/60">{tx.dateString}</td>
                    <td className="px-6 py-4">
                      <div className="flex items-center justify-center gap-2" onClick={e => e.stopPropagation()}>
                        <button onClick={() => onApproveTransaction(tx.id)}
                          className="p-1.5 rounded-lg hover:bg-black/5 transition-colors" style={{ color: GREEN_DARK }}
                          title="Approuver la transaction">
                          <CheckCircle2 className="w-5 h-5" />
                        </button>
                        <button onClick={() => onRejectTransaction(tx.id)}
                          className="p-1.5 rounded-lg hover:bg-red-50 transition-colors text-red-600"
                          title="Rejeter la transaction">
                          <XCircle className="w-5 h-5" />
                        </button>
                        <button onClick={() => onSelectTransaction(tx)}
                          className="p-1.5 rounded-lg hover:bg-black/5 transition-colors" style={{ color: ORANGE }}
                          title="Voir les détails">
                          <ChevronRight className="w-5 h-5" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </section>

      {/* Support client — absent de l'ancien Dashboard */}
      <section className="bg-white border border-black/10 rounded-xl shadow-sm overflow-hidden">
        <div className="p-6 border-b border-black/10 flex items-center justify-between">
          <div>
            <h3 className="font-sans font-bold text-[18px]" style={{ color: DARK }}>Support client</h3>
            <p className="font-sans text-[13px] text-black/60 mt-0.5">Derniers tickets ouverts.</p>
          </div>
          <button onClick={() => onNavigate(Page.Support)}
            className="font-sans font-bold text-[13px] hover:underline" style={{ color: GREEN_DARK }}>
            Tout voir &rarr;
          </button>
        </div>
        {openTickets.length === 0 ? (
          <div className="p-8 text-center text-black/50 font-sans text-[13px]">Aucun ticket ouvert.</div>
        ) : (
          <div className="divide-y divide-black/5">
            {openTickets.slice(0, 4).map(t => (
              <div key={t.id} className="px-6 py-3.5 flex items-center justify-between">
                <div>
                  <p className="font-sans font-bold text-[13px]" style={{ color: DARK }}>{t.subject}</p>
                  <p className="font-sans text-[12px] text-black/50">{t.clientName} · {t.dateString}</p>
                </div>
                <span
                  className="text-[11px] font-bold px-2.5 py-0.5 rounded-full"
                  style={{
                    background: t.status === 'OUVERT' ? `${ORANGE}22` : '#e5eeff',
                    color: t.status === 'OUVERT' ? ORANGE : '#005db6',
                  }}
                >
                  {t.status === 'OUVERT' ? 'Ouvert' : 'En cours'}
                </span>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
};

function KpiCard({ icon, accent, label, value, sub, dot, onClick }: {
  icon: React.ReactNode;
  accent: string;
  label: string;
  value: string;
  sub: string;
  dot?: boolean;
  onClick?: () => void;
}) {
  return (
    <div
      onClick={onClick}
      className={`bg-white border border-black/10 rounded-xl p-5 flex flex-col justify-between hover:shadow-md transition-all duration-200 ${onClick ? 'cursor-pointer' : ''}`}
    >
      <div className="flex justify-between items-start">
        <span className="font-sans text-[11px] font-bold text-black/50 uppercase tracking-wider">{label}</span>
        <div className="p-2 rounded-lg" style={{ background: `${accent}1a`, color: accent }}>
          {icon}
        </div>
      </div>
      <div className="mt-4">
        <h3 className="font-sans font-black text-[24px] leading-none flex items-center gap-2" style={{ color: DARK }}>
          {dot && (
            <span className="relative flex h-3 w-3">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full opacity-75" style={{ background: accent }} />
              <span className="relative inline-flex rounded-full h-3 w-3" style={{ background: accent }} />
            </span>
          )}
          {value}
        </h3>
        <p className="font-sans text-[11px] text-black/50 mt-1.5">{sub}</p>
      </div>
    </div>
  );
}
