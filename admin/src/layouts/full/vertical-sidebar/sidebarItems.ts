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
    title: "Clients",
    icon: "users-group-rounded-linear",
    to: "/clients",
    subCaption: "Portefeuille client",
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
    title: "Audit",
    icon: "document-text-linear",
    to: "/audit",
    subCaption: "Trace des actions",
  },
];

export default sidebarItem;
