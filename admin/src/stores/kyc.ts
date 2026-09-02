import { computed, ref } from "vue";
import { defineStore } from "pinia";
import { kycService } from "@/services/kyc/kycService";
import type { KycCase, KycStatus } from "@/types/kyc";

export const useKycStore = defineStore("kyc", () => {
  const cases = ref<KycCase[]>([]);
  const selectedCase = ref<KycCase | null>(null);
  const isLoading = ref(false);
  const isMutating = ref(false);
  const pendingCount = computed(() => cases.value.filter((item) => item.status === "pending_review").length);

  async function fetchCases(status?: KycStatus) {
    isLoading.value = true;
    try { cases.value = await kycService.list(status); return cases.value; } finally { isLoading.value = false; }
  }

  async function fetchCase(caseId: string) {
    isLoading.value = true;
    try { selectedCase.value = await kycService.get(caseId); return selectedCase.value; } finally { isLoading.value = false; }
  }

  async function reviewCase(caseId: string, decision: "verified" | "rejected" | "suspended", reason?: string) {
    isMutating.value = true;
    try {
      selectedCase.value = await kycService.review(caseId, decision, reason);
      await fetchCases();
      return selectedCase.value;
    } finally { isMutating.value = false; }
  }

  return { cases, selectedCase, isLoading, isMutating, pendingCount, fetchCases, fetchCase, reviewCase };
});
