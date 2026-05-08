<script setup lang="ts">
import { computed, onMounted, reactive, ref } from "vue";
import Card from "@/components/ui/card/Card.vue";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import type { AgentCashHistoryResponse } from "@/types/platform";
import { useAgentStore } from "@/stores/agents";
import { agentService } from "@/services/agents/agentService";
import { getErrorMessage } from "@/services/http/errors";
import { formatCurrency, formatDateTime } from "@/utils/formatters";

const agentStore = useAgentStore();
const agents = computed(() => agentStore.collection?.items || []);
const pagination = computed(() => agentStore.collection?.pagination || { page: 1, pageSize: 20, total: 0 });
const filters = reactive({
  search: "",
  status: "",
});

const currentPage = ref(1);
const pageSize = 20;
const mutationAgentId = ref<string | null>(null);
const topUpDialogOpen = ref(false);
const topUpAgentId = ref<string | null>(null);
const cashHistoryDialogOpen = ref(false);
const cashHistoryAgentId = ref<string | null>(null);
const cashHistoryPage = ref(1);
const errorMessage = ref("");
const topUpError = ref("");
const topUpSuccess = ref("");
const cashHistoryError = ref("");
const isCashHistoryLoading = ref(false);
const cashHistoryData = ref<AgentCashHistoryResponse | null>(null);
const topUpForm = reactive({
  amount: "",
  reason: "",
});

const totalPages = computed(() => Math.max(1, Math.ceil(pagination.value.total / pagination.value.pageSize)));
const selectedAgent = computed(() => agents.value.find((agent) => agent.id === topUpAgentId.value) || null);
const historyAgent = computed(() => cashHistoryData.value?.agent || null);
const historyItems = computed(() => cashHistoryData.value?.history.items || []);
const historyPagination = computed(() => cashHistoryData.value?.history.pagination || { page: 1, pageSize: 10, total: 0 });
const historyTotalPages = computed(() =>
  Math.max(1, Math.ceil(historyPagination.value.total / historyPagination.value.pageSize))
);
const summary = computed(() => {
  const activeCount = agents.value.filter((agent) => agent.isActive).length;
  const totalCash = agents.value.reduce((sum, agent) => sum + agent.agentBalance, 0);
  return {
    total: pagination.value.total,
    active: activeCount,
    inactive: Math.max(0, agents.value.length - activeCount),
    totalCash,
  };
});

async function fetchAgents(page = currentPage.value) {
  errorMessage.value = "";
  currentPage.value = page;
  try {
    await agentStore.fetchAgents({
      page: currentPage.value,
      pageSize,
      search: filters.search || undefined,
      status: filters.status || undefined,
    });
  } catch (error) {
    errorMessage.value = getErrorMessage(error, "Chargement des agents impossible.");
  }
}

async function toggleAgentStatus(agentId: string, isActive: boolean) {
  mutationAgentId.value = agentId;
  try {
    await agentService.updateStatus(agentId, !isActive);
    await fetchAgents(currentPage.value);
  } catch (error) {
    window.alert(getErrorMessage(error, "Mise a jour agent impossible."));
  } finally {
    mutationAgentId.value = null;
  }
}

function openTopUpDialog(agentId: string) {
  topUpAgentId.value = agentId;
  topUpForm.amount = "";
  topUpForm.reason = "";
  topUpError.value = "";
  topUpDialogOpen.value = true;
}

function closeTopUpDialog() {
  topUpDialogOpen.value = false;
  topUpAgentId.value = null;
  topUpError.value = "";
}

async function loadCashHistory(page = cashHistoryPage.value) {
  if (!cashHistoryAgentId.value) {
    return;
  }

  isCashHistoryLoading.value = true;
  cashHistoryError.value = "";
  cashHistoryPage.value = page;

  try {
    cashHistoryData.value = await agentService.getCashHistory(cashHistoryAgentId.value, {
      page: cashHistoryPage.value,
      pageSize: 10,
    });
  } catch (error) {
    cashHistoryError.value = getErrorMessage(error, "Chargement de l'historique impossible.");
  } finally {
    isCashHistoryLoading.value = false;
  }
}

async function openCashHistoryDialog(agentId: string) {
  cashHistoryAgentId.value = agentId;
  cashHistoryData.value = null;
  cashHistoryPage.value = 1;
  cashHistoryDialogOpen.value = true;
  await loadCashHistory(1);
}

function closeCashHistoryDialog() {
  cashHistoryDialogOpen.value = false;
  cashHistoryAgentId.value = null;
  cashHistoryData.value = null;
  cashHistoryError.value = "";
}

async function submitTopUp() {
  if (!selectedAgent.value) {
    topUpError.value = "Agent introuvable.";
    return;
  }

  mutationAgentId.value = selectedAgent.value.id;
  topUpError.value = "";
  topUpSuccess.value = "";

  try {
    const result = await agentService.topUp(selectedAgent.value.id, {
      amount: Number(topUpForm.amount),
      reason: topUpForm.reason.trim(),
    });
    topUpSuccess.value = `Approvisionnement confirme. Reference ${result.topUp.reference}. Nouvelle caisse: ${formatCurrency(result.topUp.agentBalanceAfter)} F`;
    await fetchAgents(currentPage.value);
    if (cashHistoryDialogOpen.value && cashHistoryAgentId.value === selectedAgent.value.id) {
      await loadCashHistory(1);
    }
    closeTopUpDialog();
  } catch (error) {
    topUpError.value = getErrorMessage(error, "Approvisionnement impossible.");
  } finally {
    mutationAgentId.value = null;
  }
}

onMounted(fetchAgents);
</script>

<template>
  <Card class="border border-border/60">
    <div class="p-6">
      <PageHeader
        title="Agents"
        description="Vue terrain et caisse agent, avec controle de l'activite, approvisionnement admin et historique de mouvements."
      />

      <div class="mt-6 grid gap-4 md:grid-cols-4">
        <div class="rounded-2xl border border-border bg-muted/30 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Total filtre</p>
          <p class="mt-2 text-2xl font-semibold">{{ summary.total }}</p>
        </div>
        <div class="rounded-2xl border border-emerald-200 bg-emerald-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-emerald-700">Actifs</p>
          <p class="mt-2 text-2xl font-semibold text-emerald-700">{{ summary.active }}</p>
        </div>
        <div class="rounded-2xl border border-red-200 bg-red-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-red-700">Inactifs</p>
          <p class="mt-2 text-2xl font-semibold text-red-700">{{ summary.inactive }}</p>
        </div>
        <div class="rounded-2xl border border-sky-200 bg-sky-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-sky-700">Caisse visible</p>
          <p class="mt-2 text-2xl font-semibold text-sky-700">{{ formatCurrency(summary.totalCash) }} F</p>
        </div>
      </div>

      <div class="mt-6 flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-1 flex-wrap items-center gap-3">
          <input
            v-model="filters.search"
            type="text"
            placeholder="Nom ou code agent"
            class="h-10 min-w-[240px] rounded-xl border border-border bg-background px-3 text-sm"
            @keyup.enter="fetchAgents(1)"
          />
          <select
            v-model="filters.status"
            class="h-10 min-w-[170px] rounded-xl border border-border bg-background px-3 text-sm"
          >
            <option value="">
              Tous statuts
            </option>
            <option value="active">
              Actifs
            </option>
            <option value="inactive">
              Inactifs
            </option>
          </select>
          <button
            class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
            @click="fetchAgents(1)"
          >
            Filtrer
          </button>
        </div>
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          @click="fetchAgents(currentPage)"
        >
          Rafraichir
        </button>
      </div>

      <div v-if="errorMessage" class="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {{ errorMessage }}
      </div>
      <div v-if="topUpSuccess" class="mt-4 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
        {{ topUpSuccess }}
      </div>

      <div v-if="agentStore.isLoading && !agents.length" class="mt-6 text-sm text-muted-foreground">
        Chargement des agents...
      </div>
      <div v-else class="mt-6 overflow-auto">
        <table class="w-full min-w-[1100px] text-sm">
          <thead>
            <tr class="border-b">
              <th class="px-3 py-3 text-left">Agent</th>
              <th class="px-3 py-3 text-left">Code</th>
              <th class="px-3 py-3 text-left">Caisse</th>
              <th class="px-3 py-3 text-left">Clients crees</th>
              <th class="px-3 py-3 text-left">Statut</th>
              <th class="px-3 py-3 text-left">Creation</th>
              <th class="px-3 py-3 text-left">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="agent in agents" :key="agent.id" class="border-b">
              <td class="px-3 py-3">
                <div class="font-medium">{{ agent.fullName }}</div>
                <div class="text-muted-foreground">{{ agent.phoneNumber || "N/A" }}</div>
              </td>
              <td class="px-3 py-3">{{ agent.agentCode }}</td>
              <td class="px-3 py-3">{{ formatCurrency(agent.agentBalance) }} F</td>
              <td class="px-3 py-3">{{ agent.createdClientsCount }}</td>
              <td class="px-3 py-3">
                <span
                  class="rounded-full px-2.5 py-1 text-xs font-medium"
                  :class="agent.isActive ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700'"
                >
                  {{ agent.isActive ? "Actif" : "Inactif" }}
                </span>
              </td>
              <td class="px-3 py-3">{{ formatDateTime(agent.createdAt) }}</td>
              <td class="px-3 py-3">
                <div class="flex flex-wrap gap-2">
                  <button
                    class="rounded-lg border border-border px-3 py-1.5 text-xs font-medium transition hover:bg-muted"
                    :disabled="mutationAgentId === agent.id"
                    @click="toggleAgentStatus(agent.id, agent.isActive)"
                  >
                    <span v-if="mutationAgentId === agent.id">Traitement...</span>
                    <span v-else>{{ agent.isActive ? "Suspendre" : "Reactiver" }}</span>
                  </button>
                  <button
                    class="rounded-lg border border-sky-200 bg-sky-50 px-3 py-1.5 text-xs font-medium text-sky-700 transition hover:bg-sky-100 disabled:cursor-not-allowed disabled:opacity-50"
                    :disabled="mutationAgentId === agent.id || !agent.isActive"
                    @click="openTopUpDialog(agent.id)"
                  >
                    Approvisionner
                  </button>
                  <button
                    class="rounded-lg border border-violet-200 bg-violet-50 px-3 py-1.5 text-xs font-medium text-violet-700 transition hover:bg-violet-100"
                    @click="openCashHistoryDialog(agent.id)"
                  >
                    Voir caisse
                  </button>
                </div>
              </td>
            </tr>
            <tr v-if="!agents.length && !agentStore.isLoading">
              <td colspan="7" class="px-3 py-8 text-center text-sm text-muted-foreground">
                Aucun agent a afficher.
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="mt-4 flex flex-wrap items-center justify-between gap-3 text-sm">
        <p class="text-muted-foreground">
          Page {{ pagination.page }} / {{ totalPages }} - {{ pagination.total }} agents
        </p>
        <div class="flex items-center gap-2">
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="pagination.page <= 1 || agentStore.isLoading"
            @click="fetchAgents(pagination.page - 1)"
          >
            Precedent
          </button>
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="pagination.page >= totalPages || agentStore.isLoading"
            @click="fetchAgents(pagination.page + 1)"
          >
            Suivant
          </button>
        </div>
      </div>
    </div>
  </Card>

  <Dialog :open="topUpDialogOpen" @update:open="topUpDialogOpen = $event">
    <DialogContent class="sm:max-w-[520px]">
      <DialogHeader>
        <DialogTitle>Approvisionner la caisse agent</DialogTitle>
        <DialogDescription>
          <span v-if="selectedAgent">
            {{ selectedAgent.fullName }} - {{ selectedAgent.agentCode }}
          </span>
          <span v-else>
            Selection de l'agent en cours.
          </span>
        </DialogDescription>
      </DialogHeader>

      <div class="space-y-4">
        <div v-if="selectedAgent" class="rounded-2xl border border-border bg-muted/30 p-4 text-sm">
          <p class="text-muted-foreground">Caisse actuelle</p>
          <p class="mt-1 text-xl font-semibold">{{ formatCurrency(selectedAgent.agentBalance) }} F</p>
        </div>

        <div v-if="topUpError" class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {{ topUpError }}
        </div>

        <div class="space-y-2">
          <label class="text-sm font-medium">Montant</label>
          <input
            v-model="topUpForm.amount"
            type="number"
            min="500"
            step="500"
            placeholder="Ex: 5000"
            class="h-11 w-full rounded-xl border border-border bg-background px-3 text-sm"
          />
        </div>

        <div class="space-y-2">
          <label class="text-sm font-medium">Motif</label>
          <textarea
            v-model="topUpForm.reason"
            rows="4"
            placeholder="Ex: Rechargement de caisse du matin"
            class="w-full rounded-xl border border-border bg-background px-3 py-3 text-sm"
          />
        </div>
      </div>

      <DialogFooter class="gap-2">
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          :disabled="mutationAgentId === topUpAgentId"
          @click="closeTopUpDialog"
        >
          Annuler
        </button>
        <button
          class="rounded-xl bg-primary px-4 py-2 text-sm font-medium text-white transition hover:bg-primaryemphasis disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="mutationAgentId === topUpAgentId"
          @click="submitTopUp"
        >
          <span v-if="mutationAgentId === topUpAgentId">Traitement...</span>
          <span v-else>Valider l'approvisionnement</span>
        </button>
      </DialogFooter>
    </DialogContent>
  </Dialog>

  <Dialog :open="cashHistoryDialogOpen" @update:open="cashHistoryDialogOpen = $event">
    <DialogContent class="sm:max-w-[900px]">
      <DialogHeader>
        <DialogTitle>Historique de caisse agent</DialogTitle>
        <DialogDescription>
          <span v-if="historyAgent">
            {{ historyAgent.fullName }} - {{ historyAgent.agentCode }}
          </span>
          <span v-else>
            Chargement du detail agent.
          </span>
        </DialogDescription>
      </DialogHeader>

      <div class="space-y-4">
        <div v-if="historyAgent" class="grid gap-4 md:grid-cols-3">
          <div class="rounded-2xl border border-border bg-muted/30 p-4">
            <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Caisse courante</p>
            <p class="mt-2 text-2xl font-semibold">{{ formatCurrency(historyAgent.agentBalance) }} F</p>
          </div>
          <div class="rounded-2xl border border-border bg-muted/30 p-4">
            <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Statut</p>
            <p class="mt-2 text-xl font-semibold">{{ historyAgent.isActive ? "Actif" : "Inactif" }}</p>
          </div>
          <div class="rounded-2xl border border-border bg-muted/30 p-4">
            <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Telephone</p>
            <p class="mt-2 text-xl font-semibold">{{ historyAgent.phoneNumber || "N/A" }}</p>
          </div>
        </div>

        <div v-if="cashHistoryError" class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {{ cashHistoryError }}
        </div>

        <div v-if="isCashHistoryLoading && !historyItems.length" class="text-sm text-muted-foreground">
          Chargement de l'historique de caisse...
        </div>
        <div v-else class="overflow-auto rounded-2xl border border-border">
          <table class="w-full min-w-[840px] text-sm">
            <thead>
              <tr class="border-b bg-muted/30">
                <th class="px-3 py-3 text-left">Reference</th>
                <th class="px-3 py-3 text-left">Type</th>
                <th class="px-3 py-3 text-left">Sens</th>
                <th class="px-3 py-3 text-left">Montant</th>
                <th class="px-3 py-3 text-left">Avant</th>
                <th class="px-3 py-3 text-left">Apres</th>
                <th class="px-3 py-3 text-left">Motif</th>
                <th class="px-3 py-3 text-left">Date</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="entry in historyItems" :key="entry.id" class="border-b">
                <td class="px-3 py-3 font-medium">{{ entry.reference }}</td>
                <td class="px-3 py-3">{{ entry.type }}</td>
                <td class="px-3 py-3">
                  <span
                    class="rounded-full px-2.5 py-1 text-xs font-medium"
                    :class="entry.isCredit ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700'"
                  >
                    {{ entry.isCredit ? "Credit" : "Debit" }}
                  </span>
                </td>
                <td class="px-3 py-3">{{ formatCurrency(entry.amount) }} F</td>
                <td class="px-3 py-3">{{ formatCurrency(entry.balanceBefore) }} F</td>
                <td class="px-3 py-3">{{ formatCurrency(entry.balanceAfter) }} F</td>
                <td class="px-3 py-3">
                  <div>{{ entry.label }}</div>
                  <div class="text-xs text-muted-foreground">{{ entry.note || "Aucune note" }}</div>
                </td>
                <td class="px-3 py-3">{{ formatDateTime(entry.occurredAt) }}</td>
              </tr>
              <tr v-if="!historyItems.length && !isCashHistoryLoading">
                <td colspan="8" class="px-3 py-8 text-center text-sm text-muted-foreground">
                  Aucun mouvement de caisse a afficher.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="flex flex-wrap items-center justify-between gap-3 text-sm">
          <p class="text-muted-foreground">
            Page {{ historyPagination.page }} / {{ historyTotalPages }} - {{ historyPagination.total }} mouvements
          </p>
          <div class="flex items-center gap-2">
            <button
              class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
              :disabled="historyPagination.page <= 1 || isCashHistoryLoading"
              @click="loadCashHistory(historyPagination.page - 1)"
            >
              Precedent
            </button>
            <button
              class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
              :disabled="historyPagination.page >= historyTotalPages || isCashHistoryLoading"
              @click="loadCashHistory(historyPagination.page + 1)"
            >
              Suivant
            </button>
          </div>
        </div>
      </div>

      <DialogFooter>
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          @click="closeCashHistoryDialog"
        >
          Fermer
        </button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
