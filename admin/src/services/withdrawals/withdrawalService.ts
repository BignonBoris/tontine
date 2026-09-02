import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type { PaginatedResponse } from "@/types/api";
import type { WithdrawalDetail, WithdrawalItem } from "@/types/platform";

export interface WithdrawalListParams {
  search?: string;
  reference?: string;
  status?: string;
  channel?: string;
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

  approve(withdrawalId: string, payload: { note?: string } = {}) {
    return unwrapEnvelope<WithdrawalDetail>(
      apiClient.post(`/admin/withdrawals/${withdrawalId}/approve`, payload)
    );
  },

  reject(
    withdrawalId: string,
    payload: { reason: string; note?: string }
  ) {
    return unwrapEnvelope<WithdrawalDetail>(
      apiClient.post(`/admin/withdrawals/${withdrawalId}/reject`, payload)
    );
  },

  markPaid(
    withdrawalId: string,
    payload: {
      paymentReference: string;
      paymentProofImageBase64: string;
      paymentProofImageMimeType: string;
      note?: string;
    }
  ) {
    return unwrapEnvelope<WithdrawalDetail>(
      apiClient.post(`/admin/withdrawals/${withdrawalId}/paid`, payload)
    );
  },
};
