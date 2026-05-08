import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type { PaginatedResponse } from "@/types/api";
import type { AuditLogItem } from "@/types/platform";

export interface AuditListParams {
  search?: string;
  action?: string;
  page?: number;
  pageSize?: number;
}

export const auditService = {
  list(params: AuditListParams = {}) {
    return unwrapEnvelope<PaginatedResponse<AuditLogItem>>(
      apiClient.get("/admin/audit-logs", { params })
    );
  },
};
