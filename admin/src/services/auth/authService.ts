import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type { AuthLoginPayload, AdminSession } from "@/types/platform";

interface AdminLoginResponse {
  token: string;
  admin: AdminSession;
}

export const authService = {
  login(payload: AuthLoginPayload) {
    return unwrapEnvelope<AdminLoginResponse>(
      apiClient.post("/admin/auth/login", payload)
    );
  },

  getSession() {
    return unwrapEnvelope<AdminSession>(apiClient.get("/admin/auth/session"));
  },
};
