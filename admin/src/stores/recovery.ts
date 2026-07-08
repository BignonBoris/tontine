import { ref } from "vue";
import { defineStore } from "pinia";
import type { RecoveryListResponse } from "@/types/platform";
import {
  recoveryService,
  type RecoveryListParams,
} from "@/services/recovery/recoveryService";

export const useRecoveryStore = defineStore("recovery", () => {
  const collection = ref<RecoveryListResponse | null>(null);
  const isLoading = ref(false);

  async function fetchRecoveryCycles(params: RecoveryListParams = {}) {
    isLoading.value = true;
    try {
      collection.value = await recoveryService.list(params);
      return collection.value;
    } finally {
      isLoading.value = false;
    }
  }

  return {
    collection,
    isLoading,
    fetchRecoveryCycles,
  };
});
