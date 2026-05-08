const MainRoutes = [
  {
    path: "/",
    component: () => import("../layouts/full/FullLayout.vue"),
    meta: { requiresAuth: true },
    children: [
      {
        path: "",
        redirect: "/dashboard",
      },
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
        name: "Audit",
        path: "/audit",
        component: () => import("../views/platform/AuditView.vue"),
      },
    ],
  },
];

export default MainRoutes;
