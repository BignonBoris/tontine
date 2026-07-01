import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type { ClientDetail, OperationListResponse, WithdrawalItem } from "@/types/platform";

export interface OperationListParams {
  clientSearch?: string;
  type?: "all" | "deposit" | "withdrawal";
  dateFrom?: string;
  dateTo?: string;
  page?: number;
  pageSize?: number;
}

export interface OperationWithdrawalPayload {
  userId: string;
  amount: number;
}

export interface OperationReverseDepositPayload {
  reason: string;
}

export const operationsService = {
  list(params: OperationListParams = {}) {
    return unwrapEnvelope<OperationListResponse>(
      apiClient.get("/admin/operations", { params })
    );
  },

  createDeposit(userId: string, amount: number) {
    return unwrapEnvelope<ClientDetail>(
      apiClient.post(`/admin/clients/${userId}/contributions`, { amount })
    );
  },

  createWithdrawal(payload: OperationWithdrawalPayload) {
    return unwrapEnvelope<{
      withdrawal: WithdrawalItem;
      client: ClientDetail;
    }>(apiClient.post("/admin/operations/withdrawals", payload));
  },

  reverseDeposit(
    userId: string,
    historyId: string,
    payload: OperationReverseDepositPayload,
  ) {
    return unwrapEnvelope<ClientDetail>(
      apiClient.post(`/admin/clients/${userId}/contributions/${historyId}/reverse`, payload),
    );
  },
};
