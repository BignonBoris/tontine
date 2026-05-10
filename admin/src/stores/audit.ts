import { ref } from "vue";
import { defineStore } from "pinia";
import type { PaginatedResponse } from "@/types/api";
import type { AuditLogItem } from "@/types/platform";
import { auditService, type AuditListParams } from "@/services/audit/auditService";

export const useAuditStore = defineStore("audit", () => {
  const collection = ref<PaginatedResponse<AuditLogItem> | null>(null);
  const isLoading = ref(false);

  async function fetchAuditLogs(params: AuditListParams = {}) {
    isLoading.value = true;
    try {
      collection.value = await auditService.list(params);
      return collection.value;
    } finally {
      isLoading.value = false;
    }
  }

  return {
    collection,
    isLoading,
    fetchAuditLogs,
  };
});
