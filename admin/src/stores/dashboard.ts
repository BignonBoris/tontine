import { ref } from "vue";
import { defineStore } from "pinia";
import { dashboardService } from "@/services/dashboard/dashboardService";
import type {
  MarketplaceOverviewData,
  OperationalAnomalies,
  OverviewData,
} from "@/types/platform";

export const useDashboardStore = defineStore("dashboard", () => {
  const overview = ref<OverviewData | null>(null);
  const anomalies = ref<OperationalAnomalies | null>(null);
  const marketplaceOverview = ref<MarketplaceOverviewData | null>(null);
  const isLoading = ref(false);
  const isAnomaliesLoading = ref(false);
  const isMarketplaceLoading = ref(false);

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

  async function fetchMarketplaceOverview() {
    isMarketplaceLoading.value = true;
    try {
      marketplaceOverview.value = await dashboardService.getMarketplaceOverview();
      return marketplaceOverview.value;
    } finally {
      isMarketplaceLoading.value = false;
    }
  }

  return {
    overview,
    anomalies,
    marketplaceOverview,
    isLoading,
    isAnomaliesLoading,
    isMarketplaceLoading,
    fetchOverview,
    fetchAnomalies,
    fetchMarketplaceOverview,
  };
});
