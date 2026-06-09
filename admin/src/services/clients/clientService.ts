import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type { PaginatedResponse } from "@/types/api";
import type { ClientDetail, ClientItem } from "@/types/platform";

export interface ClientListParams {
  search?: string;
  status?: string;
  page?: number;
  pageSize?: number;
}

export const clientService = {
  list(params: ClientListParams = {}) {
    return unwrapEnvelope<PaginatedResponse<ClientItem>>(
      apiClient.get("/admin/clients", { params })
    );
  },

  create(payload: {
    displayName: string;
    phoneNumber: string;
    address: string;
    stakeAmount: number;
    agentId?: string | null;
  }) {
    return unwrapEnvelope<ClientDetail>(
      apiClient.post("/admin/clients", payload)
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
