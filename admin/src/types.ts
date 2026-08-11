export enum Page {
  Dashboard = 'Dashboard',
  DashboardBaou = 'DashboardBaou',
  Transactions = 'Transactions',
  UserManagement = 'UserManagement',
  Settings = 'Settings',
  Support = 'Support'
}

export interface Transaction {
  id: string; // e.g. "EB-9021" or "#SN-8291"
  clientName: string;
  clientId: string;
  clientEmail: string;
  clientAvatar: string;
  accountType: string;
  balance: number; // Available balance
  ticker: string;
  companyName: string;
  type: 'BUY' | 'SELL' | 'DEPOSIT';
  quantity: number;
  unitPrice: number;
  totalAmount: number;
  market: string;
  dateString: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'ANONYMIZED';
  paymentMethod: string;
  paymentMethodCode: 'OM' | 'WV' | 'JK' | 'BANK';
  reference: string;
  proofFileName: string;
  proofFileSize: string;
  proofUploadTime: string;
  proofImage?: string;
  note?: string;
  recentHistory?: {
    id: string;
    type: 'deposit' | 'withdrawal' | 'buy' | 'sell';
    description: string;
    date: string;
    amount: number;
    amountString: string;
    isPositive: boolean;
  }[];
}

export interface User {
  id: string;
  name: string;
  email: string;
  avatar: string;
  accountType: 'Premium' | 'Standard';
  balance?: number;
  kycStatus: 'VERIFIED' | 'PENDING' | 'REJECTED';
  lastActivityDate: string;
  lastActivityPlatform: string;
  birthDate?: string;
  profession?: string;
  residence?: string;
  whatsapp?: string;
  identityDocStatus?: string;
  proofOfAddressStatus?: string;
  signatureStatus?: string;
  cniRectoUrl?: string;
  cniVersoUrl?: string;
  selfieUrl?: string;
  proofAddressUrl?: string;
  contractUrl?: string;
}

export interface SupportTicket {
  id: string;
  clientName: string;
  clientId: string;
  subject: string;
  description: string;
  priority: 'HAUTE' | 'MOYENNE' | 'BASSE';
  status: 'OUVERT' | 'EN_COURS' | 'RESOLU';
  dateString: string;
  timeString: string;
}

export interface MarketQuote {
  ticker: string;
  name: string;
  price: number;
  change: number; // percentage change
  volume: number; // volume in FCFA
  high: number;
  low: number;
  sparkline: number[];
}
