import { ref } from "vue";
import { defineStore } from "pinia";
import { dashboardService } from "@/services/dashboard/dashboardService";
import type { OperationalAnomalies, OverviewData } from "@/types/platform";

export const useDashboardStore = defineStore("dashboard", () => {
  const overview = ref<OverviewData | null>(null);
  const anomalies = ref<OperationalAnomalies | null>(null);
  const isLoading = ref(false);
  const isAnomaliesLoading = ref(false);

  async function fetchOverview() {
    isLoading.value = true;
    try {
      overview.value = await dashboardService.getOverview();
      return overview.value;
    } finally {
      isLoading.value = false;
    }
  }

  async function fetchAnomalies() {
    isAnomaliesLoading.value = true;
    try {
      anomalies.value = await dashboardService.getAnomalies();
      return anomalies.value;
    } finally {
      isAnomaliesLoading.value = false;
    }
  }

  return {
    overview,
    anomalies,
    isLoading,
    isAnomaliesLoading,
    fetchOverview,
    fetchAnomalies,
  };
});
