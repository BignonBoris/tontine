import { ref } from "vue";
import { defineStore } from "pinia";
import type { PaginatedResponse } from "@/types/api";
import type { WithdrawalItem } from "@/types/platform";
import { withdrawalService, type WithdrawalListParams } from "@/services/withdrawals/withdrawalService";

export const useWithdrawalStore = defineStore("withdrawals", () => {
  const collection = ref<PaginatedResponse<WithdrawalItem> | null>(null);
  const isLoading = ref(false);

  async function fetchWithdrawals(params: WithdrawalListParams = {}) {
    isLoading.value = true;
    try {
      collection.value = await withdrawalService.list(params);
      return collection.value;
    } finally {
      isLoading.value = false;
    }
  }

  return {
    collection,
    isLoading,
    fetchWithdrawals,
  };
});
