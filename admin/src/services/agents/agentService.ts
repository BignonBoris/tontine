import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type { PaginatedResponse } from "@/types/api";
import type { AgentCashHistoryResponse, AgentItem, AgentTopUpResult } from "@/types/platform";

export interface AgentListParams {
  search?: string;
  status?: string;
  page?: number;
  pageSize?: number;
}

export interface AgentTopUpPayload {
  amount: number;
  reason: string;
}

export interface AgentCashHistoryParams {
  page?: number;
  pageSize?: number;
}

export interface AgentCreatePayload {
  fullName: string;
  phoneNumber: string;
  agentCode: string;
  pin: string;
  maxFloatLimit: number;
}

export const agentService = {
  create(payload: AgentCreatePayload) {
    return unwrapEnvelope<AgentItem>(
      apiClient.post("/admin/agents", payload)
    );
  },

  list(params: AgentListParams = {}) {
    return unwrapEnvelope<PaginatedResponse<AgentItem>>(
      apiClient.get("/admin/agents", { params })
    );
  },

  updateStatus(agentId: string, isActive: boolean) {
    return unwrapEnvelope<{ id: string; isActive: boolean }>(
      apiClient.patch(`/admin/agents/${agentId}/status`, { isActive })
    );
  },

  updateProfile(agentId: string, payload: { maxFloatLimit?: number }) {
    return unwrapEnvelope<{ id: string; maxFloatLimit: number }>(
      apiClient.put(`/admin/agents/${agentId}/profile`, payload)
    );
  },

  topUp(agentId: string, payload: AgentTopUpPayload) {
    return unwrapEnvelope<AgentTopUpResult>(
      apiClient.post(`/admin/agents/${agentId}/top-up`, payload)
    );
  },

  getCashHistory(agentId: string, params: AgentCashHistoryParams = {}) {
    return unwrapEnvelope<AgentCashHistoryResponse>(
      apiClient.get(`/admin/agents/${agentId}/cash-history`, { params })
    );
  },

  resetDevice(agentId: string) {
    return unwrapEnvelope<{ message: string }>(
      apiClient.post(`/admin/agents/${agentId}/reset-device`)
    );
  },

  killSwitch(agentId: string) {
    return unwrapEnvelope<{ message: string }>(
      apiClient.post(`/admin/agents/${agentId}/kill-switch`)
    );
  },
};
