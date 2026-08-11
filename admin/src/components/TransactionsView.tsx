import React, { useState } from 'react';
import { Transaction } from '../types';
import { 
  ArrowLeft, 
  Clock, 
  Calendar, 
  Download, 
  Search, 
  History, 
  CheckCircle2, 
  XCircle, 
  Plus, 
  TrendingUp, 
  MoreVertical, 
  ChevronLeft, 
  ChevronRight, 
  Info,
  QrCode,
  FileText,
  AlertTriangle
} from 'lucide-react';

interface TransactionsViewProps {
  transactions: Transaction[];
  selectedTransaction: Transaction | null;
  setSelectedTransaction: (tx: Transaction | null) => void;
  onApproveTransaction: (id: string) => void;
  onRejectTransaction: (id: string, reason?: string) => void;
  onNewTransactionClick: () => void;
}

export const TransactionsView: React.FC<TransactionsViewProps> = ({
  transactions,
  selectedTransaction,
  setSelectedTransaction,
  onApproveTransaction,
  onRejectTransaction,
  onNewTransactionClick
}) => {
  // Dynamic calculations
  const approvedTransactions = transactions.filter(t => t.status === 'APPROVED');
  const approvedVolume = approvedTransactions.reduce((sum, t) => sum + t.totalAmount, 0);
  const approvedVolumeFormatted = new Intl.NumberFormat('fr-FR').format(approvedVolume);
  const avgDelayText = approvedTransactions.length === 0 ? '0s' : '2m 15s';

  // Main view state filters
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<'ALL' | 'PENDING' | 'APPROVED' | 'ANONYMIZED'>('ALL');
  const [typeFilter, setTypeFilter] = useState<'ALL' | 'BUY' | 'SELL' | 'DEPOSIT'>('ALL');
  const [period, setPeriod] = useState('01/10/2023 - 31/10/2023');

  // Rejection modal state
  const [showRejectionModal, setShowRejectionModal] = useState(false);
  const [rejectionReason, setRejectionReason] = useState('');

  // Filtering logic
  const filteredTransactions = transactions.filter(tx => {
    const matchesSearch = 
      tx.clientName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      tx.clientId.toLowerCase().includes(searchTerm.toLowerCase()) ||
      tx.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
      tx.ticker.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesStatus = statusFilter === 'ALL' ? true : tx.status === statusFilter;
    const matchesType = typeFilter === 'ALL' ? true : tx.type === typeFilter;

    return matchesSearch && matchesStatus && matchesType;
  });

  const formatAmount = (num: number) => {
    return new Intl.NumberFormat('fr-FR').format(num);
  };

  const getStatusBadge = (status: Transaction['status']) => {
    switch (status) {
      case 'PENDING':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-red-50 text-red-700 font-sans font-bold text-[11px]">
            <span className="w-1.5 h-1.5 rounded-full bg-red-600 animate-pulse"></span>
            En attente
          </span>
        );
      case 'APPROVED':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-50 text-emerald-700 font-sans font-bold text-[11px]">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-600"></span>
            Vérifié
          </span>
        );
      case 'ANONYMIZED':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-gray-100 text-gray-600 font-sans font-bold text-[11px]">
            <span className="w-1.5 h-1.5 rounded-full bg-gray-500"></span>
            Anonymisé
          </span>
        );
      case 'REJECTED':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-rose-100 text-rose-700 font-sans font-bold text-[11px]">
            <span className="w-1.5 h-1.5 rounded-full bg-rose-600"></span>
            Rejeté
          </span>
        );
    }
  };

  const handleRejectSubmit = () => {
    if (selectedTransaction) {
      onRejectTransaction(selectedTransaction.id, rejectionReason || 'Rejet administratif');
      setShowRejectionModal(false);
      setRejectionReason('');
      setSelectedTransaction(null); // Return to list view
    }
  };

  const handleApproveSubmit = () => {
    if (selectedTransaction) {
      onApproveTransaction(selectedTransaction.id);
      setSelectedTransaction(null); // Return to list view
    }
  };

  // --- SUBVIEW 1: TRANSACTION DETAIL VIEW ---
  if (selectedTransaction) {
    const tx = selectedTransaction;
    return (
      <div className="space-y-6">
        {/* Rejection Modal */}
        {showRejectionModal && (
          <div className="fixed inset-0 bg-[#0b1c30]/50 backdrop-blur-sm z-[100] flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl w-full max-w-lg shadow-2xl border border-[#dec1af]/30 overflow-hidden transform transition-all">
              <div className="p-6 border-b border-[#dec1af]/25 flex justify-between items-center bg-red-50/20">
                <h3 className="font-sans font-bold text-[18px] text-[#ba1a1a] flex items-center gap-2">
                  <AlertTriangle className="w-5 h-5" />
                  Rejeter la transaction {tx.id}
                </h3>
                <button 
                  onClick={() => setShowRejectionModal(false)}
                  className="text-[#574235] hover:bg-gray-100 rounded-full p-1.5 transition-colors"
                >
                  <XCircle className="w-5 h-5" />
                </button>
              </div>
              <div className="p-6 space-y-4">
                <p className="font-sans text-[14px] text-[#574235]">
                  Veuillez spécifier le motif du rejet de la preuve de paiement soumise par <strong>{tx.clientName}</strong>. Ce motif lui sera immédiatement communiqué.
                </p>
                <div className="space-y-1.5">
                  <label className="block font-sans font-bold text-[11px] text-[#574235] uppercase">Motif du Rejet</label>
                  <textarea
                    rows={4}
                    value={rejectionReason}
                    onChange={(e) => setRejectionReason(e.target.value)}
                    placeholder="Ex: Montant transféré insuffisant, référence invalide ou document illisible..."
                    className="w-full border border-[#dec1af]/45 rounded-lg p-3 font-sans text-[14px] focus:outline-none focus:ring-1 focus:ring-[#ff8200] outline-none bg-[#f8f9ff]"
                  ></textarea>
                </div>
              </div>
              <div className="p-4 bg-[#f8f9ff] border-t border-[#dec1af]/20 flex justify-end gap-3">
                <button 
                  onClick={() => setShowRejectionModal(false)}
                  className="px-4 py-2 text-[#574235] hover:bg-gray-100 rounded-lg font-sans font-semibold text-[13px] transition-all"
                >
                  Annuler
                </button>
                <button 
                  onClick={handleRejectSubmit}
                  className="px-5 py-2 bg-red-600 text-white rounded-lg font-sans font-bold text-[13px] hover:bg-red-700 active:scale-95 transition-all shadow-sm"
                >
                  Confirmer le rejet
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Subheader Navigation */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mt-2">
          <div className="flex items-center gap-4">
            <button 
              onClick={() => setSelectedTransaction(null)}
              className="w-10 h-10 flex items-center justify-center rounded-full bg-white border border-[#dec1af]/30 hover:bg-[#eff4ff] active:scale-95 transition-all"
            >
              <ArrowLeft className="w-5 h-5 text-[#574235]" />
            </button>
            <div>
              <h2 className="font-sans font-extrabold text-[22px] text-[#0b1c30] tracking-tight">
                Détails de la Transaction - {tx.id}
              </h2>
            </div>
          </div>
          <div className="flex gap-2 shrink-0">
            <span className="bg-[#e5eeff] text-[#005db6] px-3.5 py-1 rounded-full text-[12px] font-bold flex items-center gap-1.5 border border-[#d3e4fe]">
              <Clock className="w-4 h-4" /> En attente
            </span>
            <span className="bg-[#ffdcc6] text-[#723700] px-3.5 py-1 rounded-full text-[12px] font-bold flex items-center gap-1.5 border border-[#dec1af]/40">
              <FileText className="w-4 h-4" /> Actions
            </span>
          </div>
        </div>

        {/* Columns Grid */}
        <div className="grid grid-cols-12 gap-6">
          
          {/* Left Column: User Profile Details (Span 4) */}
          <div className="col-span-12 lg:col-span-4 space-y-6">
            <div className="bg-white border border-[#dec1af]/30 rounded-xl p-6 hover:shadow-sm transition-all duration-200">
              {/* Profile Card Header */}
              <div className="flex flex-col items-center text-center pb-6 border-b border-[#dec1af]/20 mb-6">
                <div className="relative mb-4">
                  <img 
                    src={tx.clientAvatar} 
                    alt={tx.clientName} 
                    className="w-24 h-24 rounded-full border-4 border-[#e5eeff] object-cover shadow-sm"
                  />
                  <span className="absolute bottom-1 right-1 bg-[#006d31] text-white rounded-full p-1.5 border-2 border-white shadow">
                    <CheckCircle2 className="w-4 h-4" />
                  </span>
                </div>
                <h3 className="font-sans font-extrabold text-[18px] text-[#0b1c30]">
                  {tx.clientName}
                </h3>
                <p className="text-[#574235]/75 font-sans text-[13px] mb-3">
                  {tx.clientEmail}
                </p>
                <div className="inline-flex items-center bg-[#8bf6a1]/25 text-[#007234] px-3.5 py-0.5 rounded-full text-[11px] font-black tracking-wider">
                  KYC: VERIFIED
                </div>
              </div>

              {/* Account Metadata */}
              <div className="space-y-4">
                <div className="flex justify-between items-center text-[13px]">
                  <span className="text-[#574235]/70 font-sans font-bold uppercase tracking-wider">ID Client</span>
                  <span className="font-sans font-black text-[#0b1c30]">{tx.clientId}</span>
                </div>
                <div className="flex justify-between items-center text-[13px]">
                  <span className="text-[#574235]/70 font-sans font-bold uppercase tracking-wider">Type de Compte</span>
                  <span className="font-sans font-black text-[#0b1c30]">{tx.accountType}</span>
                </div>

                {/* Available Balance Box */}
                <div className="bg-[#eff4ff] p-4 rounded-xl border border-[#dec1af]/20 mt-4">
                  <span className="text-[#574235]/70 font-sans font-bold text-[11px] uppercase tracking-wider block mb-1">
                    Solde Disponible
                  </span>
                  <p className="text-[24px] font-sans font-black text-[#954a00] leading-none">
                    {formatAmount(tx.balance)} <span className="text-[14px] font-bold text-[#574235]">FCFA</span>
                  </p>
                </div>
              </div>
            </div>

            {/* Recent History Component */}
            {tx.recentHistory && (
              <div className="bg-white border border-[#dec1af]/30 rounded-xl p-6">
                <h4 className="font-sans font-bold text-[14px] text-[#0b1c30] mb-4 flex items-center gap-2">
                  <History className="text-[#006d31] w-4 h-4" />
                  Historique Récent
                </h4>
                <div className="space-y-4">
                  {tx.recentHistory.map((historyItem) => (
                    <div key={historyItem.id} className="flex items-start gap-3">
                      <div className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 ${
                        historyItem.isPositive 
                          ? 'bg-[#8bf6a1]/20 text-[#006d31]' 
                          : 'bg-red-50 text-red-600'
                      }`}>
                        <span className="font-bold text-[16px]">{historyItem.isPositive ? '+' : '-'}</span>
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="font-sans font-bold text-[13px] text-[#0b1c30] truncate">
                          {historyItem.description}
                        </p>
                        <p className="text-[11px] text-[#574235]/75 font-sans font-medium mt-0.5">
                          {historyItem.date}
                        </p>
                      </div>
                      <div className={`font-sans font-black text-[13px] shrink-0 ${
                        historyItem.isPositive ? 'text-[#006d31]' : 'text-red-600'
                      }`}>
                        {historyItem.amountString}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          {/* Right Column: Transaction detail & Payment verification (Span 8) */}
          <div className="col-span-12 lg:col-span-8 space-y-6">
            
            {/* Asset Transaction Details */}
            <div className="bg-white border border-[#dec1af]/30 rounded-xl overflow-hidden hover:shadow-sm transition-all duration-200">
              <div className="bg-[#eff4ff]/60 px-6 py-4 flex flex-col sm:flex-row sm:items-center justify-between border-b border-[#dec1af]/20 gap-3">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-white rounded-lg flex items-center justify-center border border-[#dec1af]/30 font-black text-[#954a00] shadow-sm">
                    {tx.ticker.slice(0, 2)}
                  </div>
                  <div>
                    <h4 className="font-sans font-bold text-[16px] text-[#0b1c30]">{tx.companyName}</h4>
                    <p className="text-[11px] text-[#574235]/70 font-sans">
                      Ticker: <span className="font-black text-[#0b1c30]">{tx.ticker}</span>
                    </p>
                  </div>
                </div>
                <span className="bg-[#ff8200] text-white px-4 py-1 rounded-full text-[11px] font-black uppercase tracking-wider self-start sm:self-center">
                  Ordre d'Achat
                </span>
              </div>
              <div className="p-6 grid grid-cols-2 sm:grid-cols-4 gap-6">
                <div>
                  <span className="text-[#574235]/60 font-sans font-bold text-[11px] block mb-1 uppercase tracking-wider">Quantité</span>
                  <p className="font-sans font-black text-[16px] text-[#0b1c30]">{tx.quantity} Shares</p>
                </div>
                <div>
                  <span className="text-[#574235]/60 font-sans font-bold text-[11px] block mb-1 uppercase tracking-wider">Prix Unitaire</span>
                  <p className="font-sans font-black text-[16px] text-[#0b1c30]">{formatAmount(tx.unitPrice)} <span className="text-[12px] font-bold text-[#574235]/80">FCFA</span></p>
                </div>
                <div>
                  <span className="text-[#574235]/60 font-sans font-bold text-[11px] block mb-1 uppercase tracking-wider">Marché</span>
                  <p className="font-sans font-black text-[16px] text-[#0b1c30]">{tx.market}</p>
                </div>
                <div className="bg-[#ffdcc6]/20 p-2.5 rounded-xl text-right">
                  <span className="text-[#954a00] font-sans font-bold text-[11px] block mb-1 uppercase tracking-wider">Total Ordre</span>
                  <p className="font-sans font-black text-[18px] text-[#ff8200]">
                    {formatAmount(tx.totalAmount)} <span className="text-[11px] font-bold text-[#954a00]">FCFA</span>
                  </p>
                </div>
              </div>
            </div>

            {/* Proof of Payment Section with interactive Mobile Money Receipt */}
            <div className="bg-white border border-[#dec1af]/30 rounded-xl p-6 hover:shadow-sm transition-all duration-200">
              <h4 className="font-sans font-bold text-[16px] text-[#0b1c30] mb-6 flex items-center gap-2">
                <FileText className="text-[#ff8200] w-5 h-5" />
                Preuve de paiement
              </h4>

              <div className="grid md:grid-cols-2 gap-8">
                {/* PDF File Dropzone Display */}
                <div className="space-y-4">
                  <div className="bg-[#eff4ff]/30 rounded-xl p-6 border-2 border-dashed border-[#dec1af]/40 flex flex-col items-center justify-center aspect-[4/3] cursor-pointer hover:border-[#ff8200] hover:bg-[#ffdcc6]/10 transition-all group">
                    <div className="w-16 h-16 rounded-full bg-white flex items-center justify-center shadow-sm mb-4 group-hover:scale-110 transition-transform border border-gray-100">
                      <Download className="text-[#ff8200] w-7 h-7" />
                    </div>
                    <p className="font-sans font-bold text-[14px] text-[#0b1c30] group-hover:text-[#954a00] transition-colors">
                      {tx.proofFileName}
                    </p>
                    <p className="text-[11px] text-[#574235]/70 font-sans font-medium mt-1">
                      {tx.proofFileSize} • Uploadé à {tx.proofUploadTime}
                    </p>
                  </div>
                </div>

                {/* Simulated Smartphone orange money CI receipt */}
                <div className="bg-white rounded-xl border border-[#dec1af]/35 shadow-md flex flex-col relative overflow-hidden">
                  <div className="absolute top-0 left-0 w-full h-1 bg-[#ff8200]"></div>
                  
                  {/* Receipt Header */}
                  <div className="p-4 border-b border-[#dec1af]/20 flex justify-between items-start">
                    <div>
                      <p className="font-sans font-black text-[#ff8200] text-[13px] tracking-wide">
                        CONFIRMATION DE TRANSFERT
                      </p>
                      <p className="text-[11px] text-[#574235]/80 font-sans font-medium">
                        Orange Money Côte d'Ivoire
                      </p>
                    </div>
                    <div className="w-9 h-6 bg-[#ff8200]/20 rounded flex items-center justify-center font-sans font-black text-[10px] text-[#ff8200]">
                      OM
                    </div>
                  </div>

                  {/* Receipt Meta Fields */}
                  <div className="p-4 flex-grow space-y-3">
                    <div className="flex justify-between text-[12px] font-sans">
                      <span className="text-[#574235]/70 font-medium">Référence:</span>
                      <span className="font-mono font-bold text-[#0b1c30]">{tx.reference}</span>
                    </div>
                    <div className="flex justify-between text-[12px] font-sans">
                      <span className="text-[#574235]/70 font-medium">Expéditeur:</span>
                      <span className="font-bold text-[#0b1c30]">{tx.clientName}</span>
                    </div>
                    <div className="flex justify-between text-[12px] font-sans">
                      <span className="text-[#574235]/70 font-medium">Destinataire:</span>
                      <span className="font-bold text-[#0b1c30]">Éléphant Bourse SARL</span>
                    </div>
                    
                    <div className="flex justify-between text-[12px] font-sans border-t border-dashed border-[#dec1af]/30 pt-3">
                      <span className="text-[#574235]/80 font-extrabold uppercase">Montant:</span>
                      <span className="font-black text-[16px] text-[#0b1c30]">
                        {formatAmount(tx.totalAmount)} FCFA
                      </span>
                    </div>
                  </div>

                  {/* QR Code */}
                  <div className="p-4 bg-[#f8f9ff] border-t border-[#dec1af]/15 flex justify-center items-center">
                    <div className="p-1.5 bg-white border border-[#dec1af]/25 rounded-lg shadow-sm">
                      <QrCode className="w-12 h-12 text-[#0b1c30]" />
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Bottom Actions footer with double verification safeguard warning */}
            <div className="bg-[#f8f9ff] border border-[#dec1af]/30 rounded-xl p-5 flex flex-col md:flex-row gap-4 items-center justify-between">
              <div className="flex items-center gap-3">
                <Info className="text-[#574235]/60 w-5 h-5 shrink-0" />
                <p className="font-sans text-[13px] text-[#574235]/80 leading-relaxed max-w-md">
                  En validant cette transaction, vous confirmez officiellement la réception des fonds et autorisez l'exécution de l'ordre de bourse par nos courtiers partenaires.
                </p>
              </div>
              <div className="flex gap-3 w-full md:w-auto shrink-0">
                <button 
                  onClick={() => setShowRejectionModal(true)}
                  className="flex-1 md:flex-none px-6 py-2.5 bg-white border border-[#ba1a1a] text-[#ba1a1a] font-sans font-bold text-[13px] rounded-lg hover:bg-red-50 active:scale-95 transition-all flex items-center justify-center gap-2"
                >
                  <XCircle className="w-4 h-4" />
                  Rejeter avec motif
                </button>
                <button 
                  onClick={handleApproveSubmit}
                  className="flex-1 md:flex-none px-8 py-2.5 bg-[#006d31] text-white font-sans font-bold text-[13px] rounded-lg hover:opacity-90 active:scale-95 transition-all flex items-center justify-center gap-2 shadow-sm"
                >
                  <CheckCircle2 className="w-4 h-4" />
                  Valider le paiement
                </button>
              </div>
            </div>

          </div>
        </div>
      </div>
    );
  }

  // --- SUBVIEW 2: PAYMENT VALIDATIONS LIST VIEW ---
  return (
    <div className="space-y-6">
      {/* View Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="font-sans font-extrabold text-[24px] text-[#0b1c30] tracking-tight">
            Validations de Paiements
          </h2>
          <p className="font-sans text-[14px] text-[#574235]/80 mt-0.5">
            Gérez et validez les preuves de paiement téléchargées par vos clients pour les transactions de bourse.
          </p>
        </div>
        <div className="flex gap-3 shrink-0">
          <button className="flex items-center gap-2 px-4 py-2 bg-white border border-[#dec1af] text-[#574235] font-sans font-bold text-[13px] rounded-lg hover:bg-gray-50 active:scale-95 transition-all">
            <Download className="w-4 h-4" />
            Exporter .CSV
          </button>
          <button 
            onClick={onNewTransactionClick}
            className="flex items-center gap-2 px-4 py-2 bg-[#ff8200] text-white font-sans font-bold text-[13px] rounded-lg hover:opacity-90 active:scale-95 transition-all shadow-sm"
          >
            <Plus className="w-4 h-4" />
            Nouvel Audit
          </button>
        </div>
      </div>

      {/* Filter and query settings bar */}
      <div className="bg-[#eff4ff]/60 border border-[#dec1af]/30 rounded-xl p-4 flex flex-wrap items-center gap-4">
        <div className="flex flex-col gap-1">
          <label className="font-sans font-bold text-[10px] text-[#574235]/70 uppercase tracking-wider">Période</label>
          <div className="flex items-center bg-white border border-[#dec1af]/40 rounded-lg px-3 py-1.5 shadow-sm">
            <span className="material-symbols-outlined text-[#574235]/60 mr-2 text-[18px]">calendar_today</span>
            <input 
              type="text" 
              value={period}
              onChange={(e) => setPeriod(e.target.value)}
              className="border-none p-0 text-[13px] font-sans text-[#0b1c30] focus:ring-0 w-44 outline-none"
            />
          </div>
        </div>

        <div className="flex flex-col gap-1">
          <label className="font-sans font-bold text-[10px] text-[#574235]/70 uppercase tracking-wider">Type de Transaction</label>
          <select 
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value as any)}
            className="bg-white border border-[#dec1af]/40 rounded-lg px-3 py-1.5 text-[13px] font-sans text-[#0b1c30] focus:outline-none focus:ring-1 focus:ring-[#ff8200] outline-none shadow-sm min-w-[160px]"
          >
            <option value="ALL">Tous Types</option>
            <option value="DEPOSIT">💰 Dépôt (Jèko)</option>
            <option value="BUY">📈 Achat (Stock)</option>
            <option value="SELL">📉 Vente (Liquidation)</option>
          </select>
        </div>

        <div className="flex flex-col gap-1">
          <label className="font-sans font-bold text-[10px] text-[#574235]/70 uppercase tracking-wider">Statut</label>
          <div className="flex bg-white border border-[#dec1af]/40 rounded-lg p-1 shadow-sm">
            <button 
              onClick={() => setStatusFilter('ALL')}
              className={`px-4 py-1.5 text-[11px] font-sans font-bold rounded-md ${
                statusFilter === 'ALL' ? 'bg-[#ff8200] text-white' : 'text-[#574235] hover:bg-[#eff4ff]'
              }`}
            >
              Tous
            </button>
            <button 
              onClick={() => setStatusFilter('PENDING')}
              className={`px-4 py-1.5 text-[11px] font-sans font-bold rounded-md ${
                statusFilter === 'PENDING' ? 'bg-[#ff8200] text-white' : 'text-[#574235] hover:bg-[#eff4ff]'
              }`}
            >
              En attente
            </button>
            <button 
              onClick={() => setStatusFilter('APPROVED')}
              className={`px-4 py-1.5 text-[11px] font-sans font-bold rounded-md ${
                statusFilter === 'APPROVED' ? 'bg-[#ff8200] text-white' : 'text-[#574235] hover:bg-[#eff4ff]'
              }`}
            >
              Complété
            </button>
          </div>
        </div>

        <div className="flex-1"></div>

        {/* Dynamic Search Box */}
        <div className="relative pt-3 sm:pt-0">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-[#574235]/50" />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Rechercher..."
            className="bg-white border border-[#dec1af]/40 rounded-lg pl-9 pr-4 py-1.5 text-[13px] font-sans focus:outline-none focus:ring-1 focus:ring-[#ff8200] outline-none shadow-sm w-48"
          />
        </div>
      </div>

      {/* Main Validation Table */}
      <div className="bg-white border border-[#dec1af]/30 rounded-xl overflow-hidden shadow-sm">
        <div className="overflow-x-auto">
          {filteredTransactions.length === 0 ? (
            <div className="p-16 text-center text-[#574235]/60 font-sans">
              <CheckCircle2 className="w-12 h-12 text-[#006d31]/50 mx-auto mb-3" />
              <p className="font-bold">Aucune transaction trouvée</p>
              <p className="text-[12px] mt-1">Essayez d'ajuster les filtres ou le terme de recherche.</p>
            </div>
          ) : (
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-[#f8f9ff] border-b border-[#dec1af]/30 text-[#574235] font-sans font-bold text-[11px] uppercase tracking-wider">
                  <th className="px-6 py-4">Client</th>
                  <th className="px-6 py-4">N° Commande</th>
                  <th className="px-6 py-4">Date</th>
                  <th className="px-6 py-4">Type</th>
                  <th className="px-6 py-4">Méthode</th>
                  <th className="px-6 py-4 text-right">Montant</th>
                  <th className="px-6 py-4">Statut</th>
                  <th className="px-6 py-4 text-center">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#dec1af]/20">
                {filteredTransactions.map((tx) => (
                  <tr 
                    key={tx.id} 
                    className="hover:bg-[#f8f9ff] transition-colors group cursor-pointer"
                    onClick={() => setSelectedTransaction(tx)}
                  >
                    {/* Client cell */}
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <img 
                          src={tx.clientAvatar} 
                          alt={tx.clientName} 
                          className="w-8 h-8 rounded-full object-cover border border-gray-100 shadow-xs"
                        />
                        <div>
                          <p className="font-sans font-bold text-[14px] text-[#0b1c30] group-hover:text-[#954a00] transition-colors leading-tight">
                            {tx.clientName}
                          </p>
                          <p className="font-sans text-[11px] text-[#574235]/65">
                            {tx.clientEmail}
                          </p>
                        </div>
                      </div>
                    </td>
                    {/* Order reference */}
                    <td className="px-6 py-4 font-mono font-bold text-[13px] text-[#0b1c30]">
                      {tx.id}
                    </td>
                    {/* Date/time of upload */}
                    <td className="px-6 py-4 font-sans text-[13px] text-[#574235]/80">
                      {tx.dateString}
                    </td>
                    {/* Type Badge */}
                    <td className="px-6 py-4">
                      {tx.type === 'DEPOSIT' ? (
                        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-blue-50 text-blue-700 font-bold text-[11px] border border-blue-200">
                          💰 Dépôt
                        </span>
                      ) : tx.type === 'SELL' ? (
                        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-red-50 text-red-700 font-bold text-[11px] border border-red-200">
                          📉 Vente
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-emerald-50 text-emerald-700 font-bold text-[11px] border border-emerald-200">
                          📈 Achat
                        </span>
                      )}
                    </td>
                    {/* Payment Method Badge */}
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        {tx.paymentMethodCode === 'JK' ? (
                          <div className="w-6 h-6 rounded bg-[#0b1c30] flex items-center justify-center text-[10px] text-white font-extrabold shadow-sm shrink-0">
                            JK
                          </div>
                        ) : tx.paymentMethodCode === 'OM' ? (
                          <div className="w-6 h-6 rounded bg-[#F79E1B] flex items-center justify-center text-[10px] text-white font-extrabold shadow-sm shrink-0">
                            OM
                          </div>
                        ) : tx.paymentMethodCode === 'WV' ? (
                          <div className="w-6 h-6 rounded bg-[#21C5F0] flex items-center justify-center text-[10px] text-white font-extrabold shadow-sm shrink-0">
                            WV
                          </div>
                        ) : (
                          <div className="w-6 h-6 rounded bg-gray-500 flex items-center justify-center text-[10px] text-white font-extrabold shadow-sm shrink-0">
                            BK
                          </div>
                        )}
                        <span className="font-sans text-[13px] font-medium text-[#0b1c30]">
                          {tx.paymentMethodCode === 'JK' ? 'Jèko' : tx.paymentMethodCode === 'OM' ? 'Orange Money' : tx.paymentMethodCode === 'WV' ? 'Wave' : 'Virement Bank'}
                        </span>
                      </div>
                    </td>
                    {/* Total formatted amount */}
                    <td className="px-6 py-4 font-sans font-extrabold text-[14px] text-[#0b1c30] text-right">
                      {formatAmount(tx.totalAmount)} FCFA
                    </td>
                    {/* Status Column */}
                    <td className="px-6 py-4">
                      {getStatusBadge(tx.status)}
                    </td>
                    {/* Action button */}
                    <td className="px-6 py-4 text-center" onClick={(e) => e.stopPropagation()}>
                      {tx.status === 'PENDING' ? (
                        <button 
                          onClick={() => setSelectedTransaction(tx)}
                          className="bg-[#ff8200] hover:bg-[#ff8200]/95 text-white px-4 py-1.5 rounded-lg font-sans font-bold text-[12px] shadow-sm active:scale-95 transition-all"
                        >
                          Review
                        </button>
                      ) : (
                        <button 
                          onClick={() => setSelectedTransaction(tx)}
                          className="text-[#954a00] hover:underline font-sans font-bold text-[12px] px-4 py-1.5"
                        >
                          Détails
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {/* Footer/pagination */}
        <div className="px-6 py-4 bg-[#f8f9ff] flex flex-col sm:flex-row items-center justify-between border-t border-[#dec1af]/20 gap-4">
          <p className="font-sans text-[12px] text-[#574235]/75 font-medium">
            Affichage de 1 à {filteredTransactions.length} sur {filteredTransactions.length} transactions
          </p>
          <div className="flex items-center gap-1">
            <button className="p-1.5 rounded-lg border border-[#dec1af]/30 bg-white hover:bg-[#eff4ff] text-[#574235] disabled:opacity-50" disabled>
              <ChevronLeft className="w-4 h-4" />
            </button>
            <button className="w-8 h-8 rounded-lg bg-[#ff8200] text-white font-sans font-bold text-[12px]">1</button>
            <button className="w-8 h-8 rounded-lg bg-white border border-[#dec1af]/20 hover:bg-[#eff4ff] text-[#574235] font-sans font-bold text-[12px]">2</button>
            <button className="w-8 h-8 rounded-lg bg-white border border-[#dec1af]/20 hover:bg-[#eff4ff] text-[#574235] font-sans font-bold text-[12px]">3</button>
            <span className="px-1 text-[#574235]/60 font-sans font-bold text-[12px]">...</span>
            <button className="w-8 h-8 rounded-lg bg-white border border-[#dec1af]/20 hover:bg-[#eff4ff] text-[#574235] font-sans font-bold text-[12px]">31</button>
            <button className="p-1.5 rounded-lg border border-[#dec1af]/30 bg-white hover:bg-[#eff4ff] text-[#574235]">
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>

      {/* Audit Stats Dashboard Summary Row at bottom */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 pt-4">
        <div className="p-5 bg-white border border-[#dec1af]/30 rounded-xl shadow-xs border-l-4 border-l-[#ff8200] hover:shadow-sm transition-all">
          <p className="font-sans font-bold text-[11px] text-[#574235]/70 uppercase tracking-wider">Paiements en Attente</p>
          <div className="mt-2 flex items-end justify-between">
            <h3 className="font-sans font-black text-[24px] text-[#0b1c30]">
              {transactions.filter(t => t.status === 'PENDING').length}
            </h3>
            <span className="text-red-600 font-sans font-bold text-[12px] flex items-center gap-0.5">
              <TrendingUp className="w-3.5 h-3.5" /> +3 today
            </span>
          </div>
        </div>

        <div className="p-5 bg-white border border-[#dec1af]/30 rounded-xl shadow-xs border-l-4 border-l-[#006d31] hover:shadow-sm transition-all">
          <p className="font-sans font-bold text-[11px] text-[#574235]/70 uppercase tracking-wider">Volume Validé (24h)</p>
          <div className="mt-2 flex items-end justify-between">
            <h3 className="font-sans font-black text-[24px] text-[#0b1c30]">
              {approvedVolumeFormatted} <span className="text-[12px] font-bold text-[#574235]/70">FCFA</span>
            </h3>
            <span className="text-[#006d31] font-sans font-bold text-[12px] flex items-center gap-0.5">
              <CheckCircle2 className="w-3.5 h-3.5" /> Temps réel
            </span>
          </div>
        </div>

        <div className="p-5 bg-white border border-[#dec1af]/30 rounded-xl shadow-xs border-l-4 border-l-[#005db6] hover:shadow-sm transition-all">
          <p className="font-sans font-bold text-[11px] text-[#574235]/70 uppercase tracking-wider">Délai Moyen de Validation</p>
          <div className="mt-2 flex items-end justify-between">
            <h3 className="font-sans font-black text-[24px] text-[#0b1c30]">{avgDelayText}</h3>
            <span className="text-[#005db6] font-sans font-bold text-[12px] flex items-center gap-0.5">
              <TrendingUp className="w-3.5 h-3.5" /> {approvedTransactions.length > 0 ? 'Actif' : 'En attente'}
            </span>
          </div>
        </div>
      </div>

    </div>
  );
};
