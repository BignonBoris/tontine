import { env } from "@/config/env";
import type { AdminSession } from "@/types/platform";

export interface StoredAuthSession {
  token: string;
  admin: AdminSession;
}

function hasWindow() {
  return typeof window !== "undefined";
}

export function getStoredAuthSession(): StoredAuthSession | null {
  if (!hasWindow()) {
    return null;
  }

  const raw = window.localStorage.getItem(env.authStorageKey);
  if (!raw) {
    return null;
  }

  try {
    return JSON.parse(raw) as StoredAuthSession;
  } catch {
    window.localStorage.removeItem(env.authStorageKey);
    return null;
  }
}

export function setStoredAuthSession(session: StoredAuthSession) {
  if (!hasWindow()) {
    return;
  }

  window.localStorage.setItem(env.authStorageKey, JSON.stringify(session));
}

export function clearStoredAuthSession() {
  if (!hasWindow()) {
    return;
  }

  window.localStorage.removeItem(env.authStorageKey);
}

export function getAccessToken() {
  return getStoredAuthSession()?.token || null;
}
