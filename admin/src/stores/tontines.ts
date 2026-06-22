import { ref } from "vue";
import { defineStore } from "pinia";
import type { PaginatedResponse } from "@/types/api";
import type { TontineCycleItem } from "@/types/platform";
import {
  tontineService,
  type TontineCycleUpdatePayload,
  type TontineListParams,
} from "@/services/tontines/tontineService";

export const useTontineStore = defineStore("tontines", () => {
  const collection = ref<PaginatedResponse<TontineCycleItem> | null>(null);
  const isLoading = ref(false);

  async function fetchTontines(params: TontineListParams = {}) {
    isLoading.value = true;
    try {
      collection.value = await tontineService.list(params);
      return collection.value;
    } finally {
      isLoading.value = false;
    }
  }

  async function updateTontineCycle(
    cycleId: string,
    payload: TontineCycleUpdatePayload,
  ) {
    isLoading.value = true;
    try {
      const result = await tontineService.updateCycle(cycleId, payload);
      return result;
    } finally {
      isLoading.value = false;
    }
  }

  return {
    collection,
    isLoading,
    fetchTontines,
    updateTontineCycle,
  };
});
