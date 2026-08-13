import React from 'react';
import { Page } from '../types';
import {
  LayoutDashboard,
  Sparkles,
  ArrowLeftRight,
  Users,
  Settings,
  HelpCircle,
  LogOut,
  TrendingUp,
} from 'lucide-react';

interface SidebarProps {
  currentPage: Page;
  setCurrentPage: (page: Page) => void;
  onLogout?: () => void;
  adminProfile?: {
    name: string;
    role: string;
    avatar: string;
  };
}

export const Sidebar: React.FC<SidebarProps> = ({
  currentPage,
  setCurrentPage,
  onLogout = () => {},
  adminProfile = {
    name: 'M. Cissé',
    role: 'Administrateur Niveau 4',
    avatar: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150&auto=format&fit=crop&q=80'
  }
}) => {
  const menuItems = [
    { id: Page.Dashboard,       label: 'Tableau de bord', icon: LayoutDashboard },
    { id: Page.DashboardBaou,   label: 'Dashboard BAOU',  icon: Sparkles },
    { id: Page.Transactions,    label: 'Transactions',    icon: ArrowLeftRight },
    { id: Page.UserManagement,  label: 'Clients',         icon: Users },
    { id: Page.Settings,        label: 'Paramètres',      icon: Settings },
  ];

  return (
    <aside className="w-[280px] h-screen fixed left-0 top-0 flex flex-col py-6 z-50 sidebar-dark">
      {/* ── Brand Logo ─────────────────────────────────── */}
      <div className="px-5 mb-8 flex items-center gap-3">
        <div className="w-11 h-11 rounded-xl bg-[#ff8200]/20 border border-[#ff8200]/30 flex items-center justify-center shadow-md overflow-hidden">
          <img
            src="/baou_logo.jpg"
            alt="BAOU Logo"
            className="w-full h-full object-cover"
            onError={(e) => {
              (e.target as HTMLImageElement).style.display = 'none';
              (e.target as HTMLImageElement).parentElement!.innerHTML =
                '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="#ff8200"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22" fill="none" stroke="#ff8200" stroke-width="2"/></svg>';
            }}
          />
        </div>
        <div>
          <h1 className="font-bold text-[19px] text-white leading-none tracking-tight">
            BAOU Finance
          </h1>
          <p className="text-[10px] text-[#ff8200] font-bold mt-1 tracking-widest uppercase">
            Portail Admin
          </p>
        </div>
      </div>

      {/* ── Séparateur ──────────────────────────────────── */}
      <div className="mx-5 mb-5 border-t border-white/10" />

      {/* ── Section label ───────────────────────────────── */}
      <p className="px-5 mb-2 text-[10px] font-bold uppercase tracking-widest text-white/30">
        Navigation
      </p>

      {/* ── Navigation Links ────────────────────────────── */}
      <nav className="flex-1 flex flex-col gap-1 px-3">
        {menuItems.map((item) => {
          const Icon = item.icon;
          const isActive = currentPage === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setCurrentPage(item.id)}
              className={`sidebar-nav-item${isActive ? ' active' : ''}`}
            >
              <Icon className="w-[18px] h-[18px] shrink-0" />
              <span>{item.label}</span>
              {isActive && (
                <span className="ml-auto w-1.5 h-1.5 rounded-full bg-white/60" />
              )}
            </button>
          );
        })}
      </nav>

      {/* ── Séparateur bas ──────────────────────────────── */}
      <div className="mx-5 mt-4 mb-3 border-t border-white/10" />

      {/* ── Utilitaires ─────────────────────────────────── */}
      <div className="flex flex-col gap-1 px-3">
        <button
          onClick={() => setCurrentPage(Page.Support)}
          className={`sidebar-nav-item${currentPage === Page.Support ? ' active' : ''}`}
        >
          <HelpCircle className="w-[18px] h-[18px] shrink-0" />
          <span>Support</span>
        </button>

        <button
          onClick={onLogout}
          className="sidebar-nav-item danger"
        >
          <LogOut className="w-[18px] h-[18px] shrink-0" />
          <span>Déconnexion</span>
        </button>
      </div>

      {/* ── Profile Card ─────────────────────────────────── */}
      <div className="mx-3 mt-4 p-3 rounded-xl bg-white/8 border border-white/10 flex items-center gap-3" style={{ background: 'rgba(255,255,255,0.07)' }}>
        <img
          src={adminProfile.avatar}
          alt={adminProfile.name}
          className="w-10 h-10 rounded-full object-cover border-2 border-[#ff8200]/40 shrink-0"
        />
        <div className="overflow-hidden flex-1">
          <p className="text-[13px] font-bold text-white truncate leading-tight">
            {adminProfile.name}
          </p>
          <span className="inline-block mt-0.5 text-[10px] font-bold text-[#ff8200] bg-[#ff8200]/15 px-1.5 py-0.5 rounded-full">
            {adminProfile.role}
          </span>
        </div>
        <TrendingUp className="w-4 h-4 text-[#ff8200]/60 shrink-0" />
      </div>
    </aside>
  );
};
