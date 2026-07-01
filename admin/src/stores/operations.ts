import { ref } from "vue";
import { defineStore } from "pinia";
import type { OperationListResponse } from "@/types/platform";
import {
  operationsService,
  type OperationListParams,
  type OperationReverseDepositPayload,
  type OperationWithdrawalPayload,
} from "@/services/operations/operationsService";

export const useOperationsStore = defineStore("operations", () => {
  const collection = ref<OperationListResponse | null>(null);
  const isLoading = ref(false);

  async function fetchOperations(params: OperationListParams = {}) {
    isLoading.value = true;
    try {
      collection.value = await operationsService.list(params);
      return collection.value;
    } finally {
      isLoading.value = false;
    }
  }

  async function recordDeposit(userId: string, amount: number) {
    isLoading.value = true;
    try {
      return await operationsService.createDeposit(userId, amount);
    } finally {
      isLoading.value = false;
    }
  }

  async function recordWithdrawal(payload: OperationWithdrawalPayload) {
    isLoading.value = true;
    try {
      return await operationsService.createWithdrawal(payload);
    } finally {
      isLoading.value = false;
    }
  }

  async function reverseDeposit(
    userId: string,
    historyId: string,
    payload: OperationReverseDepositPayload,
  ) {
    isLoading.value = true;
    try {
      return await operationsService.reverseDeposit(userId, historyId, payload);
    } finally {
      isLoading.value = false;
    }
  }

  return {
    collection,
    isLoading,
    fetchOperations,
    recordDeposit,
    recordWithdrawal,
    reverseDeposit,
  };
});
