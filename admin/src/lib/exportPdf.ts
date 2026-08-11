import type { Transaction } from '../types';

/** ponytail: window.print() sur une fenetre HTML generee -- pas de lib PDF
 * cote client pour un besoin aussi simple. Partage entre les deux dashboards
 * (ancien et BAOU) pour eviter de dupliquer le HTML du rapport. */
export function exportTransactionsReportPdf(transactions: Transaction[]) {
  const printWindow = window.open('', '_blank');
  if (!printWindow) return;
  const dateStr = new Date().toLocaleDateString('fr-FR', { year: 'numeric', month: 'long', day: 'numeric' });
  const totalVolume = transactions.reduce((sum, tx) => sum + tx.totalAmount, 0);
  const rows = transactions.map(tx => `
    <tr>
      <td style="padding: 10px; border-bottom: 1px solid #eee;">${tx.id}</td>
      <td style="padding: 10px; border-bottom: 1px solid #eee;">${tx.clientName}</td>
      <td style="padding: 10px; border-bottom: 1px solid #eee;">${tx.ticker}</td>
      <td style="padding: 10px; border-bottom: 1px solid #eee;">${tx.type === 'BUY' ? 'ACHAT' : tx.type === 'SELL' ? 'VENTE' : 'DÉPÔT'}</td>
      <td style="padding: 10px; border-bottom: 1px solid #eee; text-align: right; font-family: monospace; font-weight: bold;">${tx.totalAmount.toLocaleString('fr-FR')} FCFA</td>
      <td style="padding: 10px; border-bottom: 1px solid #eee; text-align: center;">${tx.status}</td>
    </tr>
  `).join('');

  printWindow.document.write(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>BAOU Finance — Rapport PDF (${dateStr})</title>
      <style>
        body { font-family: Arial, sans-serif; padding: 30px; color: #0b1c30; }
        .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 3px solid #ff8200; padding-bottom: 15px; margin-bottom: 25px; }
        .title { font-size: 24px; font-weight: bold; }
        .subtitle { color: #ff8200; font-size: 14px; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th { background: #0b1c30; color: white; padding: 12px; text-align: left; font-size: 13px; }
        .total-box { margin-top: 25px; padding: 15px; background: #f4f6fa; border-radius: 8px; font-size: 16px; font-weight: bold; text-align: right; }
      </style>
    </head>
    <body>
      <div class="header">
        <div>
          <div class="title">BAOU Finance</div>
          <div class="subtitle">RAPPORT FINANCIER ÉLÉPHANT BOURSE</div>
        </div>
        <div style="text-align: right;">
          <div>Date : ${dateStr}</div>
          <div style="font-size: 12px; color: #666;">Portail d'Administration</div>
        </div>
      </div>
      <h2>Synthèse des Transactions Récentes</h2>
      <table>
        <thead>
          <tr>
            <th>ID Transaction</th>
            <th>Client</th>
            <th>Ticker</th>
            <th>Type</th>
            <th style="text-align: right;">Montant Total</th>
            <th style="text-align: center;">Statut</th>
          </tr>
        </thead>
        <tbody>
          ${rows}
        </tbody>
      </table>
      <div class="total-box">
        Volume Total : ${totalVolume.toLocaleString('fr-FR')} FCFA
      </div>
    </body>
    </html>
  `);
  printWindow.document.close();
  printWindow.focus();
  setTimeout(() => { printWindow.print(); }, 400);
}
