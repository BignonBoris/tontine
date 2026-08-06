import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type { PaymentMethodItem } from "@/types/platform";

export interface PaymentMethodListParams {
  operation?: string;
}

export const paymentMethodService = {
  list(params: PaymentMethodListParams = {}) {
    return unwrapEnvelope<{
      items: PaymentMethodItem[];
      totals: {
        total: number;
        enabled: number;
        disabled: number;
      };
      operation: string | null;
    }>(apiClient.get("/admin/payment-methods", { params }));
  },

  toggle(methodId: string, enabled: boolean) {
    return unwrapEnvelope<PaymentMethodItem>(
      apiClient.patch(`/admin/payment-methods/${methodId}`, { enabled })
    );
  },
};
