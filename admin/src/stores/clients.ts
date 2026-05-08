import { ref } from "vue";
import { defineStore } from "pinia";
import type { PaginatedResponse } from "@/types/api";
import type { ClientItem } from "@/types/platform";
import { clientService, type ClientListParams } from "@/services/clients/clientService";

export const useClientStore = defineStore("clients", () => {
  const collection = ref<PaginatedResponse<ClientItem> | null>(null);
  const isLoading = ref(false);

  async function fetchClients(params: ClientListParams = {}) {
    isLoading.value = true;
    try {
      collection.value = await clientService.list(params);
      return collection.value;
    } finally {
      isLoading.value = false;
    }
  }

  return {
    collection,
    isLoading,
    fetchClients,
  };
});
