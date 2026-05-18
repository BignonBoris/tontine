import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type { PaginatedResponse } from "@/types/api";
import type {
  MarketplaceGoalLineItem,
  MarketplaceOfferAdminItem,
  MarketplaceOrderLineItem,
} from "@/types/platform";

export interface MarketplaceLineListParams {
  search?: string;
  status?: string;
  offerId?: string;
  page?: number;
  pageSize?: number;
}

export const marketplaceAdminService = {
  listOffers(params: MarketplaceLineListParams = {}) {
    return unwrapEnvelope<PaginatedResponse<MarketplaceOfferAdminItem>>(
      apiClient.get("/admin/marketplace/offers", { params })
    );
  },

  createOffer(payload: {
    title: string;
    description: string;
    descriptionHtml?: string | null;
    imageUrl?: string;
    imageBase64?: string;
    imageMimeType?: string;
    imageOriginalName?: string;
    category: string;
    brand?: string | null;
    price: number;
  }) {
    return unwrapEnvelope<MarketplaceOfferAdminItem>(
      apiClient.post("/admin/marketplace/offers", payload)
    );
  },

  updateOffer(
    offerId: string,
    payload: {
      title: string;
      description: string;
      descriptionHtml?: string | null;
      imageUrl?: string;
      imageBase64?: string;
      imageMimeType?: string;
      imageOriginalName?: string;
      category: string;
      brand?: string | null;
      price: number;
    }
  ) {
    return unwrapEnvelope<MarketplaceOfferAdminItem>(
      apiClient.patch(`/admin/marketplace/offers/${offerId}`, payload)
    );
  },

  updateOfferStatus(offerId: string, isActive: boolean) {
    return unwrapEnvelope<MarketplaceOfferAdminItem>(
      apiClient.patch(`/admin/marketplace/offers/${offerId}/status`, { isActive })
    );
  },

  listOrders(params: MarketplaceLineListParams = {}) {
    return unwrapEnvelope<PaginatedResponse<MarketplaceOrderLineItem>>(
      apiClient.get("/admin/marketplace/orders", { params })
    );
  },

  listGoals(params: MarketplaceLineListParams = {}) {
    return unwrapEnvelope<PaginatedResponse<MarketplaceGoalLineItem>>(
      apiClient.get("/admin/marketplace/goals", { params })
    );
  },
};
