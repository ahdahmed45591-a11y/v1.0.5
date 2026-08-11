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
  Calendar,
  AlertCircle
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
  const [showPolicyModal, setShowPolicyModal] = useState(false);

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
      {/* Policy Modal Overlay */}
      {showPolicyModal && (
        <div className="fixed inset-0 bg-[#0b1c30]/50 backdrop-blur-sm z-[100] flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl w-full max-w-lg shadow-2xl border border-[#dec1af]/30 overflow-hidden transform transition-all">
            <div className="p-6 border-b border-[#dec1af]/20 flex justify-between items-center">
              <h3 className="font-sans font-bold text-[18px] text-[#0b1c30] flex items-center gap-2">
                <AlertCircle className="text-[#ff8200] w-5 h-5" />
                Politiques de Validation
              </h3>
              <button 
                onClick={() => setShowPolicyModal(false)}
                className="text-[#574235] hover:bg-gray-100 rounded-full p-1.5 transition-colors"
              >
                <XCircle className="w-5 h-5" />
              </button>
            </div>
            <div className="p-6 space-y-4 font-sans text-[14px] text-[#574235]">
              <p className="font-semibold text-[#0b1c30]">Règles administratives d'Éléphant Bourse :</p>
              <div className="space-y-3">
                <div className="flex gap-3 items-start">
                  <div className="w-5 h-5 rounded-full bg-[#ffdcc6] flex items-center justify-center text-[#ff8200] shrink-0 font-bold text-[11px] mt-0.5">1</div>
                  <p>Les transactions dépassant <strong>50 000 000 FCFA</strong> nécessitent obligatoirement une double validation par un <strong>Manager de Niveau 5</strong>.</p>
                </div>
                <div className="flex gap-3 items-start">
                  <div className="w-5 h-5 rounded-full bg-[#ffdcc6] flex items-center justify-center text-[#ff8200] shrink-0 font-bold text-[11px] mt-0.5">2</div>
                  <p>Toutes les preuves de paiement (fichiers PDF, images de reçus) doivent présenter des références de transfert uniques et correspondre précisément au montant de l'ordre de bourse.</p>
                </div>
                <div className="flex gap-3 items-start">
                  <div className="w-5 h-5 rounded-full bg-[#ffdcc6] flex items-center justify-center text-[#ff8200] shrink-0 font-bold text-[11px] mt-0.5">3</div>
                  <p>Les délais de traitement cibles pour les comptes <strong>Premium</strong> sont de moins de 15 minutes, et de moins de 1 heure pour les comptes Standard.</p>
                </div>
              </div>
            </div>
            <div className="p-4 bg-[#f8f9ff] border-t border-[#dec1af]/20 flex justify-end">
              <button 
                onClick={() => setShowPolicyModal(false)}
                className="px-6 py-2 bg-[#ff8200] text-white rounded-lg font-sans font-bold text-[13px] hover:opacity-90 active:scale-95 transition-all"
              >
                Compris
              </button>
            </div>
          </div>
        </div>
      )}

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
          <button 
            onClick={onNewTransactionClick}
            className="bg-[#ff8200] text-white px-4 py-2 rounded-lg font-sans font-semibold text-[13px] flex items-center gap-2 hover:opacity-90 active:scale-95 transition-all shadow-sm shadow-[#ff8200]/20"
          >
            <Plus className="w-4 h-4" />
            Nouvelle Opération
          </button>
        </div>
      </div>


      {/* KPI Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Total Pending Orders */}
        <div className="bg-white border border-[#dec1af]/30 rounded-xl p-5 flex flex-col justify-between hover:shadow-md transition-all duration-200">
          <div className="flex justify-between items-start">
            <span className="font-sans text-[11px] font-bold text-[#574235]/80 uppercase tracking-wider">
              Total Pending Orders
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
              Total Transaction Value
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
              New KYC Requests
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
              Market Status
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
                OPEN
              </h3>
            </div>
            <p className="font-sans text-[11px] text-[#574235]/70 mt-1.5 font-medium">
              BRVM Closing in 3h 15m
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
                  <th className="px-6 py-3.5">Client Name</th>
                  <th className="px-6 py-3.5">Ticker</th>
                  <th className="px-6 py-3.5">Type</th>
                  <th className="px-6 py-3.5 text-right">Amount (FCFA)</th>
                  <th className="px-6 py-3.5">Date/Time</th>
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

      {/* Asymmetric Bottom Section: Market Analytics SVG Sparklines & Admin Advice Box */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* SVG Daily Trading Chart (Cols span 2) */}
        <div className="lg:col-span-2 bg-white border border-[#dec1af]/30 rounded-xl p-6 hover:shadow-sm transition-all">
          <div className="flex justify-between items-center mb-6">
            <div>
              <h4 className="font-sans font-bold text-[16px] text-[#0b1c30]">
                Aperçu du Marché
              </h4>
              <p className="font-sans text-[12px] text-[#574235]/70">
                Volume de trading journalier (M FCFA)
              </p>
            </div>
            <span className="font-sans font-bold text-[12px] text-[#006d31] bg-[#8bf6a1]/20 px-3 py-1 rounded-full flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-[#006d31] animate-pulse"></span>
              Temps réel
            </span>
          </div>

          {/* Dynamic Interactive SVG Bar Chart Replicating the mockup */}
          <div className="h-44 w-full bg-[#f8f9ff] rounded-lg relative overflow-hidden flex items-end p-4">
            <div className="absolute inset-0 flex items-center justify-center pointer-events-none opacity-20">
              <div className="w-full border-t border-[#dec1af]/30 border-dashed"></div>
            </div>
            <div className="w-full flex items-end gap-3 h-32 relative z-10">
              {/* Bar 1 */}
              <div className="flex-1 flex flex-col items-center h-full justify-end group">
                <div className="bg-[#006d31]/40 hover:bg-[#006d31] w-full rounded-t transition-all cursor-pointer" style={{ height: '40%' }}>
                  <div className="opacity-0 group-hover:opacity-100 absolute bottom-[45%] left-1/2 -translate-x-1/2 bg-[#0b1c30] text-white text-[10px] py-1 px-2 rounded pointer-events-none transition-opacity">
                    145.2M
                  </div>
                </div>
              </div>
              {/* Bar 2 */}
              <div className="flex-1 flex flex-col items-center h-full justify-end group">
                <div className="bg-[#006d31]/40 hover:bg-[#006d31] w-full rounded-t transition-all cursor-pointer" style={{ height: '60%' }}>
                  <div className="opacity-0 group-hover:opacity-100 absolute bottom-[65%] left-1/2 -translate-x-1/2 bg-[#0b1c30] text-white text-[10px] py-1 px-2 rounded pointer-events-none transition-opacity">
                    220.8M
                  </div>
                </div>
              </div>
              {/* Bar 3 */}
              <div className="flex-1 flex flex-col items-center h-full justify-end group">
                <div className="bg-[#006d31]/40 hover:bg-[#006d31] w-full rounded-t transition-all cursor-pointer" style={{ height: '35%' }}>
                  <div className="opacity-0 group-hover:opacity-100 absolute bottom-[40%] left-1/2 -translate-x-1/2 bg-[#0b1c30] text-white text-[10px] py-1 px-2 rounded pointer-events-none transition-opacity">
                    120.4M
                  </div>
                </div>
              </div>
              {/* Bar 4 */}
              <div className="flex-1 flex flex-col items-center h-full justify-end group">
                <div className="bg-[#006d31]/40 hover:bg-[#006d31] w-full rounded-t transition-all cursor-pointer" style={{ height: '80%' }}>
                  <div className="opacity-0 group-hover:opacity-100 absolute bottom-[85%] left-1/2 -translate-x-1/2 bg-[#0b1c30] text-white text-[10px] py-1 px-2 rounded pointer-events-none transition-opacity">
                    312.5M
                  </div>
                </div>
              </div>
              {/* Bar 5 */}
              <div className="flex-1 flex flex-col items-center h-full justify-end group">
                <div className="bg-[#954a00]/40 hover:bg-[#954a00] w-full rounded-t transition-all cursor-pointer" style={{ height: '95%' }}>
                  <div className="opacity-0 group-hover:opacity-100 absolute bottom-[100%] left-1/2 -translate-x-1/2 bg-[#0b1c30] text-white text-[10px] py-1 px-2 rounded pointer-events-none transition-opacity">
                    410.2M
                  </div>
                </div>
              </div>
              {/* Bar 6 */}
              <div className="flex-1 flex flex-col items-center h-full justify-end group">
                <div className="bg-[#006d31]/40 hover:bg-[#006d31] w-full rounded-t transition-all cursor-pointer" style={{ height: '70%' }}>
                  <div className="opacity-0 group-hover:opacity-100 absolute bottom-[75%] left-1/2 -translate-x-1/2 bg-[#0b1c30] text-white text-[10px] py-1 px-2 rounded pointer-events-none transition-opacity">
                    285.0M
                  </div>
                </div>
              </div>
              {/* Bar 7 */}
              <div className="flex-1 flex flex-col items-center h-full justify-end group">
                <div className="bg-[#006d31]/40 hover:bg-[#006d31] w-full rounded-t transition-all cursor-pointer" style={{ height: '50%' }}>
                  <div className="opacity-0 group-hover:opacity-100 absolute bottom-[55%] left-1/2 -translate-x-1/2 bg-[#0b1c30] text-white text-[10px] py-1 px-2 rounded pointer-events-none transition-opacity">
                    190.4M
                  </div>
                </div>
              </div>
              {/* Bar 8 */}
              <div className="flex-1 flex flex-col items-center h-full justify-end group">
                <div className="bg-[#006d31]/40 hover:bg-[#006d31] w-full rounded-t transition-all cursor-pointer" style={{ height: '85%' }}>
                  <div className="opacity-0 group-hover:opacity-100 absolute bottom-[90%] left-1/2 -translate-x-1/2 bg-[#0b1c30] text-white text-[10px] py-1 px-2 rounded pointer-events-none transition-opacity">
                    330.1M
                  </div>
                </div>
              </div>
              {/* Bar 9 */}
              <div className="flex-1 flex flex-col items-center h-full justify-end group">
                <div className="bg-[#ff8200] w-full rounded-t transition-all cursor-pointer animate-pulse" style={{ height: '100%' }}>
                  <div className="opacity-0 group-hover:opacity-100 absolute bottom-[105%] left-1/2 -translate-x-1/2 bg-[#0b1c30] text-white text-[10px] py-1 px-2 rounded pointer-events-none transition-opacity">
                    458.2M FCFA
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Admin Advice Box Card */}
        <div className="bg-[#ff8200]/10 border border-[#ff8200]/25 rounded-xl p-6 flex flex-col justify-between hover:shadow-sm transition-all">
          <div>
            <h4 className="font-sans font-bold text-[18px] text-[#954a00] mb-2">
              Conseil d'Admin
            </h4>
            <p className="font-sans text-[13px] text-[#574235]/90 leading-relaxed">
              Les transactions dépassant <strong>50,000,000 FCFA</strong> nécessitent une double validation réglementaire par un Manager de Niveau 5. Veuillez vérifier minutieusement les reçus associés.
            </p>
          </div>
          <div className="mt-6">
            <button 
              onClick={() => setShowPolicyModal(true)}
              className="w-full bg-[#ff8200] text-white py-2.5 rounded-lg font-sans font-bold text-[13px] hover:opacity-95 active:scale-95 transition-all shadow-sm shadow-[#ff8200]/25"
            >
              Voir les politiques
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
