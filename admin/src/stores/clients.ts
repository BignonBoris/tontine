import { ref } from "vue";
import { defineStore } from "pinia";
import type { PaginatedResponse } from "@/types/api";
import type { ClientItem } from "@/types/platform";
import {
  clientService,
  type ClientListParams,
  type ClientUpdatePayload,
} from "@/services/clients/clientService";

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

  async function createClient(payload: {
    displayName: string;
    phoneNumber: string;
    address: string;
    stakeAmount: number;
    agentId?: string | null;
  }) {
    isLoading.value = true;
    try {
      const result = await clientService.create(payload);
      return result;
    } finally {
      isLoading.value = false;
    }
  }

  async function updateClient(userId: string, payload: ClientUpdatePayload) {
    isLoading.value = true;
    try {
      const result = await clientService.update(userId, payload);
      return result;
    } finally {
      isLoading.value = false;
    }
  }

  async function startTontine(userId: string, stakeAmount: number) {
    isLoading.value = true;
    try {
      const result = await clientService.startTontine(userId, stakeAmount);
      return result;
    } finally {
      isLoading.value = false;
    }
  }

  async function recordContribution(userId: string, amount: number) {
    isLoading.value = true;
    try {
      const result = await clientService.recordContribution(userId, amount);
      return result;
    } finally {
      isLoading.value = false;
    }
  }

  return {
    collection,
    isLoading,
    fetchClients,
    createClient,
    updateClient,
    startTontine,
    recordContribution,
  };
});
