import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type { RecoveryListResponse } from "@/types/platform";

export interface RecoveryListParams {
  search?: string;
  page?: number;
  pageSize?: number;
}

export const recoveryService = {
  list(params: RecoveryListParams = {}) {
    return unwrapEnvelope<RecoveryListResponse>(
      apiClient.get("/admin/recouvrement", { params })
    );
  },
};
