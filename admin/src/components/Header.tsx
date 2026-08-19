import React from 'react';
import { Search, Bell, HelpCircle } from 'lucide-react';

interface HeaderProps {
  searchQuery: string;
  setSearchQuery: (query: string) => void;
  placeholderText?: string;
  adminProfile?: {
    name: string;
    role: string;
    avatar: string;
  };
  pendingTransactionsCount?: number;
  pendingKycCount?: number;
  openTicketsCount?: number;
  onSupportClick?: (targetPage?: string) => void;
}

export const Header: React.FC<HeaderProps> = ({
  searchQuery,
  setSearchQuery,
  placeholderText = 'Rechercher une transaction, un client...',
  adminProfile = {
    name: 'M. Cissé',
    role: 'Administrateur Niveau 4',
    avatar: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 24 24" fill="%23ff8200"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 4c1.93 0 3.5 1.57 3.5 3.5S13.93 13 12 13s-3.5-1.57-3.5-3.5S10.07 6 12 6zm0 14c-2.03 0-3.8-1.04-4.83-2.61.03-1.6 3.22-2.47 4.83-2.47s4.8 1.87 4.83 2.47C15.8 18.96 14.03 20 12 20z"/></svg>'
  },
  pendingTransactionsCount = 0,
  pendingKycCount = 0,
  openTicketsCount = 0,
  // ponytail: pas de valeur par defaut ici -- `= () => {}` faisait inferer a
  // TypeScript le type union `((t?: string) => void) | (() => void)`, dont
  // l'appel n'accepte que 0 argument : les 3 onSupportClick('TRANSACTIONS'|
  // 'CLIENTS'|'SUPPORT') ci-dessous ne compilaient plus. Tous les appels
  // utilisent deja `?.()`, le defaut ne servait a rien.
  onSupportClick
}) => {
  const [showNotifications, setShowNotifications] = React.useState(false);
  const totalNotifications = pendingTransactionsCount + pendingKycCount + openTicketsCount;

  return (
    <header
      className="h-16 fixed top-0 right-0 left-[280px] z-40 flex justify-between items-center px-6"
      style={{
        background: 'rgba(255,255,255,0.92)',
        backdropFilter: 'blur(12px)',
        WebkitBackdropFilter: 'blur(12px)',
        borderBottom: '1px solid rgba(222,193,175,0.25)',
        boxShadow: '0 1px 16px rgba(11,28,48,0.05)',
      }}
    >
      {/* ── Search Bar ──────────────────────────────────── */}
      <div className="flex items-center gap-4 flex-1 max-w-xl">
        <div className="relative w-full">
          <Search className="w-4 h-4 absolute left-4 top-1/2 -translate-y-1/2 text-[#6b7280]" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full rounded-full pl-11 pr-5 py-2.5 text-[13.5px] font-sans text-[#0b1c30] placeholder-[#9ca3af] focus:outline-none transition-all"
            style={{
              background: '#f4f6fa',
              border: '1.5px solid transparent',
            }}
            onFocus={(e) => {
              e.target.style.background = '#ffffff';
              e.target.style.border = '1.5px solid rgba(255,130,0,0.4)';
              e.target.style.boxShadow = '0 0 0 3px rgba(255,130,0,0.08)';
            }}
            onBlur={(e) => {
              e.target.style.background = '#f4f6fa';
              e.target.style.border = '1.5px solid transparent';
              e.target.style.boxShadow = 'none';
            }}
            placeholder={placeholderText}
          />
        </div>
      </div>

      {/* ── Actions & Profile ───────────────────────────── */}
      <div className="flex items-center gap-2">

        {/* Notifications */}
        <div className="relative">
          <button
            onClick={() => setShowNotifications(!showNotifications)}
            className="relative w-9 h-9 rounded-full flex items-center justify-center text-[#6b7280] hover:bg-[#f4f6fa] hover:text-[#0b1c30] transition-colors"
          >
            <Bell className="w-[18px] h-[18px]" />
            {totalNotifications > 0 && (
              <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-[#ff8200] rounded-full border-2 border-white animate-pulse" />
            )}
          </button>

          {showNotifications && (
            <div
              className="absolute right-0 top-12 w-80 rounded-2xl p-4 z-50 animate-slide-in"
              style={{
                background: '#ffffff',
                border: '1px solid rgba(222,193,175,0.3)',
                boxShadow: 'var(--shadow-dropdown)',
              }}
            >
              <div className="flex justify-between items-center pb-3 border-b border-[#f3f4f6]">
                <h4 className="font-bold text-[14px] text-[#0b1c30]">Notifications</h4>
                <span className="text-[11px] font-bold text-white bg-[#ff8200] px-2 py-0.5 rounded-full">
                  {totalNotifications}
                </span>
              </div>

              <div className="mt-3 space-y-2 max-h-60 overflow-y-auto">
                {totalNotifications === 0 ? (
                  <p className="text-xs text-[#9ca3af] text-center py-4">
                    Aucune nouvelle notification
                  </p>
                ) : (
                  <>
                    {pendingTransactionsCount > 0 && (
                      <NotifItem
                        onClick={() => { onSupportClick?.('TRANSACTIONS'); setShowNotifications(false); }}
                        color="#ff8200"
                        title="Transactions en attente"
                        desc={`${pendingTransactionsCount} transaction(s) à valider`}
                      />
                    )}
                    {pendingKycCount > 0 && (
                      <NotifItem
                        onClick={() => { onSupportClick?.('CLIENTS'); setShowNotifications(false); }}
                        color="#f59e0b"
                        title="Dossiers KYC"
                        desc={`${pendingKycCount} demande(s) à vérifier`}
                      />
                    )}
                    {openTicketsCount > 0 && (
                      <NotifItem
                        onClick={() => { onSupportClick?.('SUPPORT'); setShowNotifications(false); }}
                        color="#3b82f6"
                        title="Tickets Support"
                        desc={`${openTicketsCount} ticket(s) ouvert(s)`}
                      />
                    )}
                  </>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Help */}
        <button
          onClick={() => onSupportClick?.()}
          className="w-9 h-9 rounded-full flex items-center justify-center text-[#6b7280] hover:bg-[#f4f6fa] hover:text-[#0b1c30] transition-colors"
        >
          <HelpCircle className="w-[18px] h-[18px]" />
        </button>

        {/* Divider */}
        <div className="h-7 w-px bg-[#e5e7eb] mx-1" />

        {/* Admin Profile */}
        <div className="flex items-center gap-2.5 pl-1 cursor-pointer group">
          <div className="text-right">
            <p className="font-bold text-[13.5px] text-[#0b1c30] group-hover:text-[#ff8200] transition-colors leading-none">
              {adminProfile.name}
            </p>
            <p className="text-[11px] text-[#9ca3af] leading-tight mt-0.5">
              {adminProfile.role}
            </p>
          </div>
          <div className="relative">
            <img
              src={adminProfile.avatar}
              alt={adminProfile.name}
              className="w-9 h-9 rounded-full object-cover border-2 border-[#ff8200]/30 group-hover:border-[#ff8200]/60 transition-colors"
            />
            <span className="absolute bottom-0 right-0 w-2.5 h-2.5 bg-[#10b981] rounded-full border-2 border-white" />
          </div>
        </div>
      </div>
    </header>
  );
};

/* ── Helper : Notification Item ────────────────────────── */
const NotifItem: React.FC<{
  onClick: () => void;
  color: string;
  title: string;
  desc: string;
}> = ({ onClick, color, title, desc }) => (
  <div
    onClick={onClick}
    className="flex items-start gap-3 p-2.5 rounded-xl hover:bg-[#f4f6fa] transition-colors cursor-pointer"
  >
    <div className="w-2 h-2 rounded-full mt-1.5 shrink-0" style={{ background: color }} />
    <div>
      <p className="text-[13px] font-semibold text-[#0b1c30]">{title}</p>
      <p className="text-[11px] text-[#6b7280] mt-0.5">{desc}</p>
    </div>
  </div>
);
