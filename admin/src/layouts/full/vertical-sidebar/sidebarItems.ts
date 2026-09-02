export interface menu {
  header?: string;
  title?: string;
  icon?: any;
  to?: string;
  chip?: string;
  chipBgColor?: string;
  chipColor?: string;
  chipVariant?: string;
  chipIcon?: string;
  children?: menu[];
  disabled?: boolean;
  type?: string;
  subCaption?: string;
  isPro?: boolean;
}

const sidebarItem: menu[] = [
  { header: "Pilotage" },
  {
    title: "Dashboard",
    icon: "home-smile-linear",
    to: "/dashboard",
    subCaption: "KPI et tendances",
    // to: "/",
    isPro: false,
  },
  {
    title: "Commissions",
    icon: "wallet-money-linear",
    to: "/supervision/commissions",
    isPro: false,
  },
  {
    title: "Coffres par défaut",
    icon: "box-linear",
    to: "/goal-templates",
    subCaption: "Onboarding clients",
    isPro: false,
  },


  { header: "PAGES" },
  {
    title: "Tables",
    icon: "tablet-linear",
    to: "#",

    children: [
      {
        title: 'Basic Table',
        to: '/shadcn-table/basic',
        isPro: false,
      },
      {
        title: 'Hover Table',
        to: '/shadcn-table/hover',
        isPro: false,
      },

    ]

  },
  {
    title: "Operations",
    icon: "receipt-2-linear",
    to: "/operations",
    subCaption: "Depots et retraits",
  },
  {
    title: "Recouvrement",
    icon: "clock-circle-linear",
    to: "/recouvrement",
    subCaption: "Cycles en retard",
  },
  {
    title: "Clients",
    icon: "users-group-rounded-linear",
    to: "/clients",
    subCaption: "Portefeuille client",
  },
  {
    title: "Tontines",
    icon: "restart-square-linear",
    to: "/tontines",
    subCaption: "Suivi des cycles",
  },
  {
    title: "Agents",
    icon: "user-id-linear",
    to: "/agents",
    subCaption: "Terrain et caisse",
  },
  {
    title: "Retraits",
    icon: "card-recive-linear",
    to: "/withdrawals",
    subCaption: "Suivi decaissements",
  },
  {
    title: "Verification KYC",
    icon: "shield-check-linear",
    to: "/kyc",
    subCaption: "Revue des identites",
  },
  {
    title: "Paiements",
    icon: "wallet-money-linear",
    to: "/payment-methods",
    subCaption: "Activation des moyens",
  },
  {
    title: "Marketplace",
    icon: "bag-smile-linear",
    to: "/marketplace",
    subCaption: "Demandes produits et coffres",
  },
  {
    title: "Audit",
    icon: "document-text-linear",
    to: "/audit",
    subCaption: "Trace des actions",
  },
  {
    title: "Configuration WhatsApp",
    icon: "settings-linear",
    to: "/whatsapp",
    subCaption: "OTP et alertes",
  },
];

export default sidebarItem;
