import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";

export type AppKey = "client" | "agent";

export interface AppVersionInfo {
  app: AppKey;
  version: string;
  build: number;
  min_build: number;
  mandatory: boolean;
  download_url: string;
  release_notes: string;
  released_at: string;
}

export interface AppVersionPayload {
  version: string;
  build: number;
  min_build: number;
  mandatory: boolean;
  download_url: string;
  release_notes: string;
  released_at: string;
}

export const appVersionService = {
  list() {
    return unwrapEnvelope<Record<AppKey, AppVersionInfo>>(
      apiClient.get("/admin/app-versions")
    );
  },

  update(app: AppKey, payload: AppVersionPayload) {
    return unwrapEnvelope<AppVersionInfo>(
      apiClient.put(`/admin/app-versions/${app}`, payload)
    );
  },
};
