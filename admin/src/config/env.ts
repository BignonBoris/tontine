export const env = {
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:3000/api/v1",
  appName: import.meta.env.VITE_APP_NAME || "VizioBox Admin",
  authStorageKey: import.meta.env.VITE_AUTH_STORAGE_KEY || "viziobox_admin_auth",
};
