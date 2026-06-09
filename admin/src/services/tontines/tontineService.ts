import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type { PaginatedResponse } from "@/types/api";
import type { TontineCycleCalendar, TontineCycleItem } from "@/types/platform";

export interface TontineListParams {
  page?: number;
  pageSize?: number;
  search?: string;
  status?: string;
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
};
