import React, { useState } from 'react';
import { Transaction } from '../types';
import { exportTransactionsReportPdf } from '../lib/exportPdf';
import {
  Clock, 
  Coins, 
  UserCheck, 
  TrendingUp, 
  CheckCircle2, 
  XCircle, 
  ChevronRight,
  FileDown,
  Plus,
  Info,
  Calendar
} from 'lucide-react';

interface DashboardViewProps {
  transactions: Transaction[];
  onSelectTransaction: (tx: Transaction) => void;
  onApproveTransaction: (id: string) => void;
  onRejectTransaction: (id: string) => void;
  onNewTransactionClick: () => void;
}

export const DashboardView: React.FC<DashboardViewProps> = ({
  transactions,
  onSelectTransaction,
  onApproveTransaction,
  onRejectTransaction,
  onNewTransactionClick
}) => {
  const [filterType, setFilterType] = useState<'ALL' | 'BUY' | 'SELL'>('ALL');

  // Filter pending transactions to show in validation list
  const pendingTransactions = transactions.filter(tx => tx.status === 'PENDING');
  
  const filteredTransactions = pendingTransactions.filter(tx => {
    if (filterType === 'ALL') return true;
    return tx.type === filterType;
  });

  // Calculate high-level stats dynamically from current state!
  const pendingCount = pendingTransactions.length;
  
  // Total transaction value of approved transactions + some base amount
  const approvedTotalValue = transactions
    .filter(tx => tx.status === 'APPROVED')
    .reduce((sum, tx) => sum + tx.totalAmount, 0);
  
  const totalValueFCFA = approvedTotalValue;
  const totalValueFormatted = totalValueFCFA === 0 ? '0' : (totalValueFCFA / 1000000).toFixed(1) + 'M';

  // Format currency helpers
  const formatAmount = (num: number) => {
    return new Intl.NumberFormat('fr-FR').format(num);
  };

  return (
    <div className="space-y-6">
      {/* Page Heading & Action Buttons */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="font-sans font-extrabold text-[24px] text-[#0b1c30] tracking-tight">
            Tableau de bord
          </h2>
          <p className="font-sans text-[14px] text-[#574235]/80 mt-0.5">
            Bienvenue sur le portail d'administration d'Éléphant Bourse.
          </p>
        </div>
        <div className="flex gap-3 shrink-0">
          <button
            onClick={() => exportTransactionsReportPdf(transactions)}
            className="bg-white border border-[#dec1af] px-4 py-2 rounded-lg font-sans font-semibold text-[13px] text-[#954a00] flex items-center gap-2 hover:bg-[#eff4ff] active:scale-95 transition-all cursor-pointer"
          >
            <FileDown className="w-4 h-4" />
            Exporter Rapport PDF
          </button>
        </div>
      </div>


      {/* KPI Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Total Pending Orders */}
        <div className="bg-white border border-[#dec1af]/30 rounded-xl p-5 flex flex-col justify-between hover:shadow-md transition-all duration-200">
          <div className="flex justify-between items-start">
            <span className="font-sans text-[11px] font-bold text-[#574235]/80 uppercase tracking-wider">
              Commandes en attente
            </span>
            <div className="p-2 bg-[#ffdcc6]/40 text-[#ff8200] rounded-lg">
              <Clock className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4">
            <h3 className="font-sans font-black text-[28px] text-[#0b1c30] leading-none">
              {pendingCount}
            </h3>
            <div className="flex items-center gap-2 mt-1.5">
              <span className="text-[#574235]/65 font-sans text-[11px]">commandes en attente</span>
            </div>
          </div>
        </div>

        {/* Total Transaction Value */}
        <div className="bg-white border border-[#dec1af]/30 rounded-xl p-5 flex flex-col justify-between hover:shadow-md transition-all duration-200">
          <div className="flex justify-between items-start">
            <span className="font-sans text-[11px] font-bold text-[#574235]/80 uppercase tracking-wider">
              Valeur totale des transactions
            </span>
            <div className="p-2 bg-[#8bf6a1]/20 text-[#006d31] rounded-lg">
              <Coins className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4">
            <h3 className="font-sans font-black text-[28px] text-[#0b1c30] leading-none">
              {totalValueFormatted} <span className="text-[14px] font-bold text-[#574235]">FCFA</span>
            </h3>
            <div className="flex items-center gap-2 mt-1.5">
              <span className="text-[#574235]/65 font-sans text-[11px]">valeur totale validée</span>
            </div>
          </div>
        </div>

        {/* New KYC Requests */}
        <div className="bg-white border border-[#dec1af]/30 rounded-xl p-5 flex flex-col justify-between hover:shadow-md transition-all duration-200">
          <div className="flex justify-between items-start">
            <span className="font-sans text-[11px] font-bold text-[#574235]/80 uppercase tracking-wider">
              Nouvelles demandes KYC
            </span>
            <div className="p-2 bg-[#d6e3ff] text-[#005db6] rounded-lg">
              <UserCheck className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4">
            <h3 className="font-sans font-black text-[28px] text-[#0b1c30] leading-none">
              0
            </h3>
            <div className="flex items-center gap-2 mt-1.5">
              <span className="text-[#574235]/65 font-sans text-[11px]">aucune demande en attente</span>
            </div>
          </div>
        </div>

        {/* Market Status */}
        <div className="bg-white border border-[#dec1af]/30 rounded-xl p-5 flex flex-col justify-between hover:shadow-md transition-all duration-200">
          <div className="flex justify-between items-start">
            <span className="font-sans text-[11px] font-bold text-[#574235]/80 uppercase tracking-wider">
              Statut du marché
            </span>
            <div className="p-2 bg-[#e5eeff] text-[#0b1c30] rounded-lg">
              <Calendar className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4">
            <div className="flex items-center gap-2">
              <span className="relative flex h-3.5 w-3.5">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#006d31] opacity-75"></span>
                <span className="relative inline-flex rounded-full h-3.5 w-3.5 bg-[#006d31]"></span>
              </span>
              <h3 className="font-sans font-black text-[24px] text-[#0b1c30] leading-none">
                OUVERT
              </h3>
            </div>
            <p className="font-sans text-[11px] text-[#574235]/70 mt-1.5 font-medium">
              Clôture BRVM dans 3h 15
            </p>
          </div>
        </div>
      </div>

      {/* Main Validation Transactions List Section */}
      <section className="bg-white border border-[#dec1af]/30 rounded-xl shadow-sm overflow-hidden">
        <div className="p-6 border-b border-[#dec1af]/25 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h3 className="font-sans font-bold text-[18px] text-[#0b1c30]">
              Transactions en attente de validation
            </h3>
            <p className="font-sans text-[13px] text-[#574235]/85 mt-0.5">
              Vérifiez et validez les transactions boursières soumises par les clients.
            </p>
          </div>
          <div className="flex shrink-0">
            <div className="flex items-center border border-[#dec1af]/30 rounded-lg p-1 bg-[#eff4ff]/50">
              <button 
                onClick={() => setFilterType('ALL')}
                className={`px-3 py-1 rounded font-sans font-bold text-[11px] transition-all ${
                  filterType === 'ALL' 
                    ? 'bg-white shadow-sm text-[#954a00]' 
                    : 'text-[#574235] hover:text-[#954a00]'
                }`}
              >
                Tout
              </button>
              <button 
                onClick={() => setFilterType('BUY')}
                className={`px-3 py-1 rounded font-sans font-bold text-[11px] transition-all ${
                  filterType === 'BUY' 
                    ? 'bg-white shadow-sm text-[#954a00]' 
                    : 'text-[#574235] hover:text-[#954a00]'
                }`}
              >
                Achat
              </button>
              <button 
                onClick={() => setFilterType('SELL')}
                className={`px-3 py-1 rounded font-sans font-bold text-[11px] transition-all ${
                  filterType === 'SELL' 
                    ? 'bg-white shadow-sm text-[#954a00]' 
                    : 'text-[#574235] hover:text-[#954a00]'
                }`}
              >
                Vente
              </button>
            </div>
          </div>
        </div>

        {/* Data Table */}
        <div className="overflow-x-auto">
          {filteredTransactions.length === 0 ? (
            <div className="p-12 text-center text-[#574235]/60 font-sans">
              <CheckCircle2 className="w-12 h-12 text-[#006d31]/50 mx-auto mb-3" />
              <p className="font-bold">Aucune transaction en attente de validation</p>
              <p className="text-[12px] mt-1">Toutes les demandes de paiement ont été traitées.</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-[#eff4ff] text-[#574235] font-sans font-bold text-[11px] uppercase tracking-wider border-b border-[#dec1af]/30">
                  <th className="px-6 py-3.5">Nom du client</th>
                  <th className="px-6 py-3.5">Ticker</th>
                  <th className="px-6 py-3.5">Type</th>
                  <th className="px-6 py-3.5 text-right">Montant (FCFA)</th>
                  <th className="px-6 py-3.5">Date/Heure</th>
                  <th className="px-6 py-3.5 text-center">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#dec1af]/20">
                {filteredTransactions.map((tx) => (
                  <tr 
                    key={tx.id} 
                    className="hover:bg-[#f8f9ff] transition-colors group cursor-pointer"
                    onClick={() => onSelectTransaction(tx)}
                  >
                    {/* Client Information */}
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <img 
                          src={tx.clientAvatar} 
                          alt={tx.clientName} 
                          className="w-10 h-10 rounded-full object-cover border border-gray-100 shadow-sm"
                        />
                        <div>
                          <div className="font-sans font-bold text-[14px] text-[#0b1c30] group-hover:text-[#954a00] transition-colors">
                            {tx.clientName}
                          </div>
                          <div className="font-sans text-[12px] text-[#574235]/70">
                            ID: {tx.clientId}
                          </div>
                        </div>
                      </div>
                    </td>
                    {/* Financial Asset Ticker */}
                    <td className="px-6 py-4">
                      <span className="font-sans font-extrabold text-[14px] text-[#0b1c30] block">
                        {tx.ticker}
                      </span>
                      <span className="font-sans text-[12px] text-[#574235]/70 block">
                        {tx.companyName}
                      </span>
                    </td>
                    {/* BUY / SELL / DEPOSIT Action Pill */}
                    <td className="px-6 py-4">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold ${
                        tx.type === 'BUY'
                          ? 'bg-[#8bf6a1]/30 text-[#007234]'
                          : tx.type === 'DEPOSIT'
                          ? 'bg-[#d6e3ff] text-[#005db6]'
                          : 'bg-[#ffdad6] text-[#93000a]'
                      }`}>
                        {tx.type === 'DEPOSIT' ? 'DÉPÔT' : tx.type}
                      </span>
                    </td>
                    {/* Amount formatted */}
                    <td className="px-6 py-4 text-right font-sans font-extrabold text-[14px] text-[#0b1c30]">
                      {formatAmount(tx.totalAmount)}
                    </td>
                    {/* Date and Time */}
                    <td className="px-6 py-4 font-sans text-[13px] text-[#574235]/75">
                      {tx.dateString}
                    </td>
                    {/* Inline Quick Actions */}
                    <td className="px-6 py-4">
                      <div className="flex items-center justify-center gap-2" onClick={(e) => e.stopPropagation()}>
                        <button 
                          onClick={() => onApproveTransaction(tx.id)}
                          className="p-1.5 text-[#006d31] hover:bg-[#8bf6a1]/20 rounded-lg transition-colors"
                          title="Approuver la transaction"
                        >
                          <CheckCircle2 className="w-5 h-5" />
                        </button>
                        <button 
                          onClick={() => onRejectTransaction(tx.id)}
                          className="p-1.5 text-[#ba1a1a] hover:bg-[#ffdad6] rounded-lg transition-colors"
                          title="Rejeter la transaction"
                        >
                          <XCircle className="w-5 h-5" />
                        </button>
                        <button 
                          onClick={() => onSelectTransaction(tx)}
                          className="p-1.5 text-[#ff8200] hover:bg-[#ffdcc6]/30 rounded-lg transition-colors"
                          title="Voir les détails"
                        >
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

        {/* Footer info counts */}
        <div className="p-4 bg-[#eff4ff]/40 flex justify-between items-center text-[12px] text-[#574235]/70 font-sans font-medium border-t border-[#dec1af]/20">
          <span>Affichage de {filteredTransactions.length} sur {pendingCount} transactions en attente</span>
          <button 
            onClick={() => onSelectTransaction(transactions[0])}
            className="text-[#954a00] hover:underline font-bold"
          >
            Gérer toutes les validations &rarr;
          </button>
        </div>
      </section>
    </div>
  );
};
