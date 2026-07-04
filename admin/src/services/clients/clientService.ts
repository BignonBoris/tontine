import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type { PaginatedResponse } from "@/types/api";
import type { ClientDetail, ClientItem } from "@/types/platform";

export interface ClientListParams {
  search?: string;
  status?: string;
  tontineStatus?: "all" | "ongoing" | "none";
  page?: number;
  pageSize?: number;
}

export interface ClientUpdatePayload {
  displayName: string;
  phoneNumber?: string | null;
  address: string;
  agentId?: string | null;
}

export interface ReverseContributionPayload {
  reason: string;
}

export const clientService = {
  list(params: ClientListParams = {}) {
    return unwrapEnvelope<PaginatedResponse<ClientItem>>(
      apiClient.get("/admin/clients", { params })
    );
  },

  create(payload: {
    displayName: string;
    phoneNumber?: string | null;
    address: string;
    stakeAmount: number;
    agentId?: string | null;
  }) {
    return unwrapEnvelope<ClientDetail>(
      apiClient.post("/admin/clients", payload)
    );
  },

  update(userId: string, payload: ClientUpdatePayload) {
    return unwrapEnvelope<ClientDetail>(
      apiClient.patch(`/admin/clients/${userId}`, payload)
    );
  },

  startTontine(userId: string, stakeAmount: number) {
    return unwrapEnvelope<{ id: string }>(
      apiClient.post(`/admin/clients/${userId}/start-tontine`, { stakeAmount })
    );
  },

  recordContribution(userId: string, amount: number) {
    return unwrapEnvelope<ClientDetail>(
      apiClient.post(`/admin/clients/${userId}/contributions`, { amount })
    );
  },

  reverseContribution(
    userId: string,
    historyId: string,
    payload: ReverseContributionPayload
  ) {
    return unwrapEnvelope<ClientDetail>(
      apiClient.post(
        `/admin/clients/${userId}/contributions/${historyId}/reverse`,
        payload
      )
    );
  },

  updateStatus(userId: string, isActive: boolean) {
    return unwrapEnvelope<{ id: string; isActive: boolean }>(
      apiClient.patch(`/admin/clients/${userId}/status`, { isActive })
    );
  },

  getDetail(userId: string) {
    return unwrapEnvelope<ClientDetail>(
      apiClient.get(`/admin/clients/${userId}`)
    );
  },
};
