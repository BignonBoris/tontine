import axios from "axios";
import { env } from "@/config/env";
import type { ApiEnvelope, ApiErrorPayload } from "@/types/api";
import { ApiError } from "./errors";
import { clearStoredAuthSession, getAccessToken } from "./tokenStorage";

export const apiClient = axios.create({
  baseURL: env.apiBaseUrl,
  timeout: 20000,
  headers: {
    "Content-Type": "application/json",
  },
});

apiClient.interceptors.request.use((config) => {
  const token = getAccessToken();
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }

  return config;
});

apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    const statusCode = error?.response?.status as number | undefined;
    const payload = error?.response?.data as ApiErrorPayload | undefined;
    const message =
      payload?.message ||
      (statusCode === 401
        ? "Session admin invalide ou expiree."
        : "Le serveur n'a pas pu traiter la requete.");

    if (statusCode === 401) {
      clearStoredAuthSession();
    }

    return Promise.reject(new ApiError(message, statusCode, payload?.details));
  }
);

export async function unwrapEnvelope<T>(promise: Promise<{ data: ApiEnvelope<T> }>): Promise<T> {
  const response = await promise;
  return response.data.data;
}
