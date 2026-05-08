import { createRouter, createWebHistory } from "vue-router";
import MainRoutes from "./MainRoutes";
import ModuleRoutes from "./ModuleRoutes";
export const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [

    {
      path: "/auth/login2",
      component: () => import("@/views/authentication/auth2/Login.vue"),
      meta: { requiresAuth: false },
    },

    {
      path: "/auth/register2",
      component: () => import("@/views/authentication/auth2/Register.vue"),
      meta: { requiresAuth: false },
    },
    {
      path: "/auth/admin-login",
      component: () => import("@/views/modules/auth/admin-login.vue"),
      meta: { requiresAuth: false },
    },





    ...MainRoutes,
    ...ModuleRoutes,

  ],
});
