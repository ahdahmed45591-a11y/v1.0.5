import React, { useState } from 'react';
import {
  Shield,
  Save
} from 'lucide-react';

interface SettingsViewProps {
  onSave: () => void;
}

export const SettingsView: React.FC<SettingsViewProps> = ({ onSave }) => {
  // Configurable thresholds & preferences
  const [doubleValidationThreshold, setDoubleValidationThreshold] = useState('50000000');
  const [requireKycForWithdrawal, setRequireKycForWithdrawal] = useState(true);
  const [auditLogLevel, setAuditLogLevel] = useState('DETAILED');

  const handleFormSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSave();
  };

  return (
    <div className="space-y-6">

      {/* View Header */}
      <div>
        <h2 className="font-sans font-extrabold text-[24px] text-[#0b1c30] tracking-tight">
          Paramètres du Système
        </h2>
        <p className="font-sans text-[14px] text-[#574235]/80 mt-0.5">
          Gérez les seuils de validation réglementaires et configurez les alertes d'audit.
        </p>
      </div>

      <form onSubmit={handleFormSubmit} className="grid grid-cols-12 gap-6">

        {/* Left Column: Settings panels (Span 8) */}
        <div className="col-span-12 lg:col-span-8 space-y-6">

          {/* Rules & Thresholds Setting Card */}
          <div className="bg-white border border-[#dec1af]/30 rounded-xl p-6 hover:shadow-xs transition-all">
            <h3 className="font-sans font-bold text-[16px] text-[#0b1c30] flex items-center gap-2 mb-6 border-b border-[#dec1af]/15 pb-3">
              <Shield className="text-[#ff8200] w-5 h-5" />
              Règles d'Audit & Seuils Réglementaires
            </h3>

            <div className="space-y-5">
              {/* Threshold inputs */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-1.5">
                  <label className="block font-sans font-bold text-[11px] text-[#574235] uppercase">
                    Seuil de Double Validation (FCFA)
                  </label>
                  <div className="relative">
                    <input
                      type="number"
                      value={doubleValidationThreshold}
                      onChange={(e) => setDoubleValidationThreshold(e.target.value)}
                      className="w-full border border-[#dec1af]/45 rounded-lg px-3 py-2 text-[14px] font-sans text-[#0b1c30] focus:ring-1 focus:ring-[#ff8200] outline-none font-bold"
                    />
                    <span className="absolute right-3 top-1/2 -translate-y-1/2 text-[11px] font-sans font-bold text-[#574235]/70">
                      FCFA
                    </span>
                  </div>
                  <p className="text-[11px] text-[#574235]/65 font-sans mt-0.5">
                    Toute transaction dépassant ce montant nécessitera la validation de deux administrateurs de niveau supérieur.
                  </p>
                </div>

                <div className="space-y-1.5">
                  <label className="block font-sans font-bold text-[11px] text-[#574235] uppercase">
                    Niveau d'audit requis (Logs)
                  </label>
                  <select
                    value={auditLogLevel}
                    onChange={(e) => setAuditLogLevel(e.target.value)}
                    className="w-full bg-white border border-[#dec1af]/45 rounded-lg px-3 py-2 text-[14px] font-sans text-[#0b1c30] focus:ring-1 focus:ring-[#ff8200] outline-none"
                  >
                    <option value="MINIMAL">Minimal (Erreurs uniquement)</option>
                    <option value="STANDARD">Standard (Activités & Validations)</option>
                    <option value="DETAILED">Détaillé (Tous les clics administrateur)</option>
                  </select>
                  <p className="text-[11px] text-[#574235]/65 font-sans mt-0.5">
                    Configure le degré de finesse de l'enregistrement des actions d'audit pour la conformité.
                  </p>
                </div>
              </div>

              {/* KYC Checkbox Switch */}
              <div className="flex items-start gap-3 pt-3 border-t border-[#dec1af]/10">
                <input
                  type="checkbox"
                  id="requireKyc"
                  checked={requireKycForWithdrawal}
                  onChange={(e) => setRequireKycForWithdrawal(e.target.checked)}
                  className="w-4.5 h-4.5 text-[#ff8200] border-[#dec1af] rounded mt-0.5 focus:ring-[#ff8200]"
                />
                <div>
                  <label htmlFor="requireKyc" className="font-sans font-bold text-[13px] text-[#0b1c30] block cursor-pointer select-none">
                    Exiger obligatoirement le statut KYC vérifié pour les transactions
                  </label>
                  <p className="text-[11px] text-[#574235]/70 font-sans mt-0.5">
                    Bloque automatiquement la soumission de tout ordre d'achat ou demande de retrait si les pièces d'identité du client ne sont pas validées.
                  </p>
                </div>
              </div>
            </div>
          </div>

        </div>

        {/* Right Column: Submission Panel (Span 4) */}
        <div className="col-span-12 lg:col-span-4 space-y-6">

          {/* Action Trigger Card */}
          <div className="bg-white border border-[#dec1af]/30 rounded-xl p-5 shadow-xs">
            <h4 className="font-sans font-bold text-[15px] text-[#0b1c30] mb-3">Enregistrer les Modifications</h4>
            <p className="font-sans text-[12px] text-[#574235]/80 leading-relaxed mb-6">
              Assurez-vous de vérifier les impacts de ces seuils sur la fluidité opérationnelle avant de valider. Les managers de niveau inférieur seront immédiatement informés de tout changement réglementaire.
            </p>
            <button
              type="submit"
              className="w-full bg-[#ff8200] hover:bg-[#ff8200]/95 text-white py-3 rounded-lg font-sans font-bold text-[13px] flex items-center justify-center gap-2 hover:opacity-95 active:scale-95 transition-all shadow-sm shadow-[#ff8200]/20"
            >
              <Save className="w-4.5 h-4.5" />
              Sauvegarder les Paramètres
            </button>
          </div>

        </div>

      </form>

    </div>
  );
};
