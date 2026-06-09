const MainRoutes = [
  {
    path: '/',
    component: () => import('../layouts/full/FullLayout.vue'),
    meta: { requiresAuth: true },
    children: [
      {
        path: '',
        name: 'Modern',
        component: () => import('../views/dashboards/Modern.vue'),
      },
      // {
      //   path: "",
      //   redirect: "/dashboard",
      // },
      {
        name: "Dashboard",
        path: "/dashboard",
        component: () => import("../views/platform/DashboardView.vue"),
      },
      {
        name: "Clients",
        path: "/clients",
        component: () => import("../views/platform/ClientsView.vue"),
      },
      {
        name: "Agents",
        path: "/agents",
        component: () => import("../views/platform/AgentsView.vue"),
      },
      {
        name: "Withdrawals",
        path: "/withdrawals",
        component: () => import("../views/platform/WithdrawalsView.vue"),
      },
      {
        name: "Marketplace",
        path: "/marketplace",
        component: () => import("../views/platform/MarketplaceView.vue"),
      },
      {
        name: "Audit",
        path: "/audit",
        component: () => import("../views/platform/AuditView.vue"),
      },
      {
        path: '/supervision/commissions',
        name: 'Commissions',
        component: () => import('../views/modules/commissions.vue'),
      },

      {
        name: 'Notes',
        path: '/apps/notes',
        component: () => import('../views/apps/notes/Notes.vue')
      },
      {
        name: 'Tickets',
        path: '/apps/tickets',
        component: () => import('../views/apps/tickets/Tickets.vue')
      },
      {
        name: 'Blog Posts',
        path: '/apps/blog/post',
        component: () => import('../views/apps/blog/Posts.vue')
      },
      {
        name: 'Blog Details',
        path: '/apps/blog/:slug',
        component: () => import('../views/apps/blog/[id].vue')
      },
      {
        name: 'Icon',
        path: '/icons/solar',
        component: () => import('../views/icons/Solar.vue')
      },
      {
        name: 'Shadcn Table',
        path: '/shadcn-table/basic',
        component: () => import('../views/shadcn-tables/BasicTable.vue')
      },
      {
        name: 'Shadcn Hover Table',
        path: '/shadcn-table/hover',
        component: () => import('../views/shadcn-tables/HoverTable.vue')
      },
      {
        name: 'Form',
        path: '/utilities/form',
        component: () => import('../views/utilities/Form.vue')
      },
      {
        name: 'User Profile',
        path: '/user-profile',
        component: () => import('../views/utilities/UserProfile.vue')
      },
    ],
  },
];

export default MainRoutes;
