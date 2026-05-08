import { computed, ref } from "vue";
import { defineStore } from "pinia";
import { authService } from "@/services/auth/authService";
import {
  clearStoredAuthSession,
  getStoredAuthSession,
  setStoredAuthSession,
} from "@/services/http/tokenStorage";
import type { AdminSession } from "@/types/platform";

export const useAuthStore = defineStore("auth", () => {
  const storedSession = getStoredAuthSession();
  const admin = ref<AdminSession | null>(storedSession?.admin || null);
  const token = ref<string | null>(storedSession?.token || null);
  const isLoading = ref(false);

  const isAuthenticated = computed(() => Boolean(token.value && admin.value));

  function setSession(nextToken: string, nextAdmin: AdminSession) {
    token.value = nextToken;
    admin.value = nextAdmin;
    setStoredAuthSession({
      token: nextToken,
      admin: nextAdmin,
    });
  }

  async function login(username: string, password: string) {
    isLoading.value = true;
    try {
      const response = await authService.login({ username, password });
      setSession(response.token, response.admin);
      return response.admin;
    } finally {
      isLoading.value = false;
    }
  }

  async function hydrateSession() {
    if (!token.value) {
      return null;
    }

    isLoading.value = true;
    try {
      const session = await authService.getSession();
      admin.value = session;
      setStoredAuthSession({
        token: token.value,
        admin: session,
      });
      return session;
    } catch (error) {
      logout();
      throw error;
    } finally {
      isLoading.value = false;
    }
  }

  function logout() {
    token.value = null;
    admin.value = null;
    clearStoredAuthSession();
  }

  return {
    admin,
    token,
    isLoading,
    isAuthenticated,
    login,
    hydrateSession,
    logout,
  };
});
