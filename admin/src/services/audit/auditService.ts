import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type { PaginatedResponse } from "@/types/api";
import type { AuditLogItem } from "@/types/platform";

export interface AuditListParams {
  search?: string;
  action?: string;
  status?: string;
  dateFrom?: string;
  dateTo?: string;
  page?: number;
  pageSize?: number;
}

export const auditService = {
  list(params: AuditListParams = {}) {
    return unwrapEnvelope<PaginatedResponse<AuditLogItem>>(
      apiClient.get("/admin/audit-logs", { params })
    );
  },

  /** Télécharge les logs filtrés en CSV — retourne l'URL Blob. */
  async exportCsv(params: AuditListParams = {}): Promise<void> {
    const response = await apiClient.get("/admin/audit-logs/export", {
      params,
      responseType: "blob",
    });
    const blob = new Blob([response.data as BlobPart], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `audit-logs-${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  },

  /** Charge les anomalies opérationnelles. */
  getAnomalies() {
    return unwrapEnvelope<{
      multipleDeviceLogins: unknown[];
      suspiciousProvisionings: unknown[];
      expiredRequestedWithdrawals: unknown[];
      walletReservationMismatches: unknown[];
      inactiveAgentsWithCash: unknown[];
      overdueActiveCycles: unknown[];
    }>(apiClient.get("/admin/anomalies"));
  },
};
