import { createRouter, createWebHistory } from "vue-router";
import MainRoutes from "./MainRoutes";
import { useAuthStore } from "@/stores/auth";

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
  ],
});

router.beforeEach(async (to) => {
  const authStore = useAuthStore();

  if (!to.meta.requiresAuth) {
    if (to.path === "/auth/login2" && authStore.isAuthenticated) {
      return { path: "/dashboard" };
    }
    return true;
  }

  if (!authStore.token) {
    return { path: "/auth/login2" };
  }

  if (!authStore.admin) {
    try {
      await authStore.hydrateSession();
    } catch {
      return { path: "/auth/login2" };
    }
  }

  return true;
});
