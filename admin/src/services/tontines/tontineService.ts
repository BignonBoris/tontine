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
};
