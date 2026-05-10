import { ref } from "vue";
import { defineStore } from "pinia";
import type { PaginatedResponse } from "@/types/api";
import type { AgentItem } from "@/types/platform";
import { agentService, type AgentListParams } from "@/services/agents/agentService";

export const useAgentStore = defineStore("agents", () => {
  const collection = ref<PaginatedResponse<AgentItem> | null>(null);
  const isLoading = ref(false);

  async function fetchAgents(params: AgentListParams = {}) {
    isLoading.value = true;
    try {
      collection.value = await agentService.list(params);
      return collection.value;
    } finally {
      isLoading.value = false;
    }
  }

  return {
    collection,
    isLoading,
    fetchAgents,
  };
});
