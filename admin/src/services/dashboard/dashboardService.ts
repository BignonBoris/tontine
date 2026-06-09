import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type {
  MarketplaceOverviewData,
  OperationalAnomalies,
  OverviewData,
} from "@/types/platform";

export const dashboardService = {
  getOverview() {
    return unwrapEnvelope<OverviewData>(apiClient.get("/admin/overview"));
  },

  getAnomalies() {
    return unwrapEnvelope<OperationalAnomalies>(apiClient.get("/admin/anomalies"));
  },

  getMarketplaceOverview() {
    return unwrapEnvelope<MarketplaceOverviewData>(
      apiClient.get("/admin/marketplace/overview")
    );
  },
};
