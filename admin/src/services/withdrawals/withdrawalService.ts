import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type { PaginatedResponse } from "@/types/api";
import type { WithdrawalDetail, WithdrawalItem } from "@/types/platform";

export interface WithdrawalListParams {
  search?: string;
  reference?: string;
  status?: string;
  page?: number;
  pageSize?: number;
}

export const withdrawalService = {
  list(params: WithdrawalListParams = {}) {
    return unwrapEnvelope<PaginatedResponse<WithdrawalItem>>(
      apiClient.get("/admin/withdrawals", { params })
    );
  },

  getDetail(withdrawalId: string) {
    return unwrapEnvelope<WithdrawalDetail>(
      apiClient.get(`/admin/withdrawals/${withdrawalId}`)
    );
  },
};
