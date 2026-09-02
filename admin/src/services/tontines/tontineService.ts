import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type { PaginatedResponse } from "@/types/api";
import type { TontineCycleCalendar, TontineCycleItem } from "@/types/platform";

export interface TontineListParams {
  page?: number;
  pageSize?: number;
  search?: string;
  status?: string;
}

export interface TontineCycleUpdatePayload {
  stakeAmount: number;
}

export interface TontineKycLimitItem {
  id: string;
  kycStatus: "unverified" | "pending_review" | "verified";
  tierLevel: string;
  label: string;
  description?: string;
  maxDailyStake: number;
  maxCycleCumulative: number;
  allowMultipleCycles: boolean;
  enabled: boolean;
  updatedAt?: string;
  updatedBy?: string;
}

export const tontineService = {
  list(params: TontineListParams = {}) {
    return unwrapEnvelope<PaginatedResponse<TontineCycleItem>>(
      apiClient.get("/admin/tontines", { params })
    );
  },

  getCalendar(cycleId: string) {
    return unwrapEnvelope<TontineCycleCalendar>(
      apiClient.get(`/admin/tontines/${cycleId}/calendar`)
    );
  },

  updateCycle(cycleId: string, payload: TontineCycleUpdatePayload) {
    return unwrapEnvelope<TontineCycleItem>(
      apiClient.patch(`/admin/tontines/${cycleId}`, payload)
    );
  },

  closeCycle(cycleId: string) {
    return unwrapEnvelope<TontineCycleItem>(
      apiClient.post(`/admin/tontines/${cycleId}/close`)
    );
  },

  getKycLimits() {
    return unwrapEnvelope<{ items: TontineKycLimitItem[] }>(
      apiClient.get("/admin/tontines/kyc-limits")
    );
  },

  updateKycLimits(items: Partial<TontineKycLimitItem>[]) {
    return unwrapEnvelope<{ items: TontineKycLimitItem[] }>(
      apiClient.put("/admin/tontines/kyc-limits", { items })
    );
  },
};
