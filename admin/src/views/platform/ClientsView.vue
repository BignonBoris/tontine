<script setup lang="ts">
import { computed, onMounted, onUnmounted, reactive, ref } from "vue";
import { X } from "lucide-vue-next";
import Card from "@/components/ui/card/Card.vue";
import { FINANCIAL_AMOUNT_STEP } from "@/constants/finance";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogClose,
} from "@/components/ui/dialog";
import type { ClientDetail } from "@/types/platform";
import { useClientStore } from "@/stores/clients";
import { useAgentStore } from "@/stores/agents";
import { clientService } from "@/services/clients/clientService";
import { getErrorMessage } from "@/services/http/errors";
import { formatCurrency, formatDateTime } from "@/utils/formatters";

const clientStore = useClientStore();
const agentStore = useAgentStore();
const clients = computed(() => clientStore.collection?.items || []);
const agents = computed(() => agentStore.collection?.items || []);
const pagination = computed(() => clientStore.collection?.pagination || { page: 1, pageSize: 20, total: 0 });
const filters = reactive({
  search: "",
  status: "",
});
const currentPage = ref(1);
const mutationClientId = ref<string | null>(null);
const pageSize = 20;
const errorMessage = ref("");
const detailDialogOpen = ref(false);
const selectedClientId = ref<string | null>(null);
const detailError = ref("");
const isDetailLoading = ref(false);
const detailData = ref<ClientDetail | null>(null);
const currentContributionCycle = computed(() => {
  const latestCycle = detailData.value?.cycles[0] || null;
  if (!detailData.value?.client.isActive || !latestCycle || latestCycle.status !== "active") {
    return null;
  }

  return latestCycle;
});
const contributionRemaining = computed(() => {
  if (!currentContributionCycle.value) {
    return 0;
  }

  return Math.max(
    currentContributionCycle.value.stakeAmount * 31 -
      currentContributionCycle.value.cumulativeAmount,
    0,
  );
});
const isRecordingContribution = ref(false);
const contributionError = ref("");
const contributionSuccess = ref("");
const contributionSuccessTimer = ref<number | null>(null);
const contributionForm = reactive<{ amount: number | null }>({
  amount: null,
});

const createDialogOpen = ref(false);
const isCreating = ref(false);
const createError = ref("");
const createForm = reactive<{
  displayName: string;
  phoneNumber: string;
  address: string;
  stakeAmount: number | null;
  agentId: string;
}>({
  displayName: "",
  phoneNumber: "",
  address: "",
  stakeAmount: null,
  agentId: "",
});

const startTontineDialogOpen = ref(false);
const isStartingTontine = ref(false);
const startTontineError = ref("");
const startTontineSuccess = ref("");
const startTontineSuccessTimer = ref<number | null>(null);
const startTontineAutoCloseTimer = ref<number | null>(null);
const startTontineForm = reactive({
  clientId: "",
  clientName: "",
  stakeAmount: 1000,
});

const totalPages = computed(() => Math.max(1, Math.ceil(pagination.value.total / pagination.value.pageSize)));
const summary = computed(() => {
  const activeCount = clients.value.filter((client) => client.isActive).length;
  return {
    total: pagination.value.total,
    active: activeCount,
    inactive: Math.max(0, clients.value.length - activeCount),
  };
});

async function fetchClients(page = currentPage.value) {
  errorMessage.value = "";
  currentPage.value = page;
  try {
    await clientStore.fetchClients({
      page: currentPage.value,
      pageSize,
      search: filters.search || undefined,
      status: filters.status || undefined,
    });
  } catch (error) {
    errorMessage.value = getErrorMessage(error, "Chargement des clients impossible.");
  }
}

function openCreateDialog() {
  createDialogOpen.value = true;
  createError.value = "";
  createForm.displayName = "";
  createForm.phoneNumber = "";
  createForm.address = "";
  createForm.stakeAmount = null;
  createForm.agentId = "";

  if (!agents.value.length) {
    agentStore.fetchAgents({ pageSize: 100 });
  }
}

function clearStartTontineSuccessTimer() {
  if (startTontineSuccessTimer.value !== null) {
    window.clearTimeout(startTontineSuccessTimer.value);
    startTontineSuccessTimer.value = null;
  }
}

function clearStartTontineAutoCloseTimer() {
  if (startTontineAutoCloseTimer.value !== null) {
    window.clearTimeout(startTontineAutoCloseTimer.value);
    startTontineAutoCloseTimer.value = null;
  }
}

function showStartTontineSuccess(message: string) {
  startTontineSuccess.value = message;
  clearStartTontineSuccessTimer();
  startTontineSuccessTimer.value = window.setTimeout(() => {
    startTontineSuccess.value = "";
    startTontineSuccessTimer.value = null;
  }, 4000);
}

function hasOngoingTontine(cycles: ClientDetail["cycles"]) {
  const latestCycle = cycles[0];
  if (!latestCycle) {
    return false;
  }

  return ["active", "enAttenteValidationFin"].includes(latestCycle.status);
}

function clearContributionSuccessTimer() {
  if (contributionSuccessTimer.value !== null) {
    window.clearTimeout(contributionSuccessTimer.value);
    contributionSuccessTimer.value = null;
  }
}

function syncContributionAmount(detail: ClientDetail | null) {
  const latestCycle = detail?.cycles[0] || null;
  if (!detail?.client.isActive || !latestCycle || latestCycle.status !== "active") {
    contributionForm.amount = null;
    return;
  }

  const remainingAmount = Math.max(
    latestCycle.stakeAmount * 31 - latestCycle.cumulativeAmount,
    0,
  );
  contributionForm.amount =
    remainingAmount > 0
      ? Math.min(latestCycle.stakeAmount, remainingAmount)
      : latestCycle.stakeAmount;
}

function resetContributionState(detail: ClientDetail | null) {
  contributionError.value = "";
  contributionSuccess.value = "";
  clearContributionSuccessTimer();
  syncContributionAmount(detail);
}

function showContributionSuccess(message: string) {
  contributionSuccess.value = message;
  clearContributionSuccessTimer();
  contributionSuccessTimer.value = window.setTimeout(() => {
    contributionSuccess.value = "";
    contributionSuccessTimer.value = null;
  }, 4000);
}

function openStartTontineDialog(client: { id: string; displayName: string }) {
  clearStartTontineAutoCloseTimer();
  clearStartTontineSuccessTimer();
  startTontineSuccess.value = "";
  startTontineDialogOpen.value = true;
  startTontineError.value = "";
  startTontineForm.clientId = client.id;
  startTontineForm.clientName = client.displayName;
  startTontineForm.stakeAmount =
    detailData.value?.client.id === client.id
      ? detailData.value.cycles[0]?.stakeAmount || 1000
      : 1000;
}

function closeStartTontineDialog() {
  if (isStartingTontine.value) {
    return;
  }

  clearStartTontineAutoCloseTimer();
  startTontineDialogOpen.value = false;
  startTontineError.value = "";
  startTontineForm.clientId = "";
  startTontineForm.clientName = "";
  startTontineForm.stakeAmount = 1000;
}

function setStartTontineDialogOpen(value: boolean) {
  if (value) {
    startTontineDialogOpen.value = true;
    return;
  }

  closeStartTontineDialog();
}

async function handleCreateClient() {
  if (isCreating.value) return;

  createError.value = "";
  isCreating.value = true;
  const stakeAmount = Number(createForm.stakeAmount);

  if (
    !stakeAmount ||
    stakeAmount <= 0 ||
    stakeAmount % FINANCIAL_AMOUNT_STEP !== 0
  ) {
    createError.value = `La mise doit etre un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`;
    isCreating.value = false;
    return;
  }

  try {
    await clientStore.createClient({
      displayName: createForm.displayName,
      phoneNumber: createForm.phoneNumber,
      address: createForm.address,
      stakeAmount,
      agentId: createForm.agentId || null,
    });
    createDialogOpen.value = false;
    await fetchClients(1);
  } catch (error) {
    createError.value = getErrorMessage(error, "Erreur lors de la creation du client.");
  } finally {
    isCreating.value = false;
  }
}

async function handleRecordContribution() {
  if (isRecordingContribution.value) return;

  const clientId = selectedClientId.value;
  const cycle = currentContributionCycle.value;
  const amount = Number(contributionForm.amount);

  if (!clientId || !detailData.value) {
    contributionError.value = "Selectionnez un client valide.";
    return;
  }
  if (!detailData.value.client.isActive) {
    contributionError.value = "Ce client est inactif.";
    return;
  }
  if (!cycle) {
    contributionError.value = "Aucun cycle actif ne permet une cotisation.";
    return;
  }
  if (
    !amount ||
    amount <= 0 ||
    amount % FINANCIAL_AMOUNT_STEP !== 0
  ) {
    contributionError.value = `La cotisation doit etre un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`;
    return;
  }
  if (amount > contributionRemaining.value) {
    contributionError.value = `Le montant depasse le reste a verser (${formatCurrency(contributionRemaining.value)} F).`;
    return;
  }

  contributionError.value = "";
  contributionSuccess.value = "";
  isRecordingContribution.value = true;

  try {
    const updatedDetail = await clientStore.recordContribution(clientId, amount);
    detailData.value = updatedDetail;
    syncContributionAmount(updatedDetail);
    showContributionSuccess(
      `Cotisation de ${formatCurrency(amount)} F enregistree avec succes.`,
    );
  } catch (error) {
    contributionError.value = getErrorMessage(
      error,
      "Enregistrement de la cotisation impossible.",
    );
  } finally {
    isRecordingContribution.value = false;
  }
}

async function handleStartTontine() {
  if (isStartingTontine.value) return;

  const clientId = startTontineForm.clientId;
  const stakeAmount = Number(startTontineForm.stakeAmount);
  if (!clientId) {
    startTontineError.value = "Selectionnez un client valide.";
    return;
  }
  if (
    !stakeAmount ||
    stakeAmount <= 0 ||
    stakeAmount % FINANCIAL_AMOUNT_STEP !== 0
  ) {
    startTontineError.value = `La mise doit etre un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`;
    return;
  }

  startTontineError.value = "";
  startTontineSuccess.value = "";
  isStartingTontine.value = true;

  try {
    await clientStore.startTontine(clientId, stakeAmount);
    isStartingTontine.value = false;

    if (detailDialogOpen.value && selectedClientId.value === clientId) {
      void openDetailDialog(clientId);
    } else {
      void fetchClients(currentPage.value);
    }

    showStartTontineSuccess(
      `La tontine de ${startTontineForm.clientName} a ete demarree avec succes.`,
    );
    clearStartTontineAutoCloseTimer();
    startTontineAutoCloseTimer.value = window.setTimeout(() => {
      closeStartTontineDialog();
    }, 1200);
  } catch (error) {
    startTontineError.value = getErrorMessage(
      error,
      "Demarrage de la tontine impossible.",
    );
  } finally {
    isStartingTontine.value = false;
  }
}

async function toggleClientStatus(userId: string, isActive: boolean) {
  mutationClientId.value = userId;
  try {
    await clientService.updateStatus(userId, !isActive);
    await fetchClients(currentPage.value);
  } catch (error) {
    window.alert(getErrorMessage(error, "Mise a jour client impossible."));
  } finally {
    mutationClientId.value = null;
  }
}

async function openDetailDialog(clientId: string) {
  detailDialogOpen.value = true;
  selectedClientId.value = clientId;
  detailData.value = null;
  detailError.value = "";
  resetContributionState(null);
  isDetailLoading.value = true;

  try {
    detailData.value = await clientService.getDetail(clientId);
    syncContributionAmount(detailData.value);
  } catch (error) {
    detailError.value = getErrorMessage(error, "Chargement du detail client impossible.");
  } finally {
    isDetailLoading.value = false;
  }
}

function closeDetailDialog() {
  detailDialogOpen.value = false;
  selectedClientId.value = null;
  detailData.value = null;
  detailError.value = "";
  resetContributionState(null);
}

onMounted(fetchClients);

onUnmounted(() => {
  clearStartTontineSuccessTimer();
  clearStartTontineAutoCloseTimer();
  clearContributionSuccessTimer();
});
</script>

<template>
  <Card class="border border-border/60">
    <div class="p-6">
      <PageHeader
        title="Clients"
        description="Portefeuille client, soldes principaux, origine de creation, statut d'activite et detail individuel."
      />

      <div class="mt-6 grid gap-4 md:grid-cols-3">
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
      </div>

      <div class="mt-6 flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-1 flex-wrap items-center gap-3">
          <input
            v-model="filters.search"
            type="text"
            placeholder="Nom ou telephone"
            class="h-10 min-w-[240px] rounded-xl border border-border bg-background px-3 text-sm"
            @keyup.enter="fetchClients(1)"
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
            @click="fetchClients(1)"
          >
            Filtrer
          </button>
        </div>
        <div class="flex items-center gap-3">
          <button
            class="rounded-xl bg-sky-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-sky-700"
            @click="openCreateDialog"
          >
            Nouveau client
          </button>
          <button
            class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
            @click="fetchClients(currentPage)"
          >
            Rafraichir
          </button>
        </div>
      </div>

      <div v-if="startTontineSuccess" class="mt-4 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
        {{ startTontineSuccess }}
      </div>
      <div v-if="errorMessage" class="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {{ errorMessage }}
      </div>
      <div v-if="clientStore.isLoading && !clients.length" class="mt-6 text-sm text-muted-foreground">
        Chargement des clients...
      </div>
      <div v-else class="mt-6 overflow-auto">
        <table class="w-full min-w-[1080px] text-sm">
          <thead>
            <tr class="border-b">
              <th class="px-3 py-3 text-left">Client</th>
              <th class="px-3 py-3 text-left">Disponible</th>
              <th class="px-3 py-3 text-left">Reserve</th>
              <th class="px-3 py-3 text-left">Tontine</th>
              <th class="px-3 py-3 text-left">Origine</th>
              <th class="px-3 py-3 text-left">Statut</th>
              <th class="px-3 py-3 text-left">Membre depuis</th>
              <th class="px-3 py-3 text-left">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="client in clients" :key="client.id" class="border-b">
              <td class="px-3 py-3">
                <div class="font-medium">{{ client.displayName }}</div>
                <div class="text-muted-foreground">{{ client.phoneNumber }}</div>
              </td>
              <td class="px-3 py-3">{{ formatCurrency(client.availableBalance) }} F</td>
              <td class="px-3 py-3">{{ formatCurrency(client.reservedWithdrawalBalance) }} F</td>
              <td class="px-3 py-3">{{ formatCurrency(client.tontineBalance) }} F</td>
              <td class="px-3 py-3">{{ client.createdByAgent?.fullName || "Canal direct" }}</td>
              <td class="px-3 py-3">
                <span
                  class="rounded-full px-2.5 py-1 text-xs font-medium"
                  :class="client.isActive ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700'"
                >
                  {{ client.isActive ? "Actif" : "Inactif" }}
                </span>
              </td>
              <td class="px-3 py-3">{{ formatDateTime(client.memberSince) }}</td>
              <td class="px-3 py-3">
                <div class="flex flex-wrap gap-2">
                  <button
                    class="rounded-lg border border-border px-3 py-1.5 text-xs font-medium transition hover:bg-muted"
                    :disabled="mutationClientId === client.id"
                    @click="toggleClientStatus(client.id, client.isActive)"
                  >
                    <span v-if="mutationClientId === client.id">Traitement...</span>
                    <span v-else>{{ client.isActive ? "Suspendre" : "Reactiver" }}</span>
                  </button>
                  <button
                    class="rounded-lg border border-sky-200 bg-sky-50 px-3 py-1.5 text-xs font-medium text-sky-700 transition hover:bg-sky-100"
                    @click="openDetailDialog(client.id)"
                  >
                    Voir detail
                  </button>
                  <button
                    v-if="client.isActive && !client.hasActiveTontine"
                    class="rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-xs font-medium text-emerald-700 transition hover:bg-emerald-100"
                    title="Demarrer une nouvelle tontine"
                    @click="openStartTontineDialog(client)"
                  >
                    Demarrer Tontine
                  </button>
                  <span
                    v-else-if="client.isActive && client.hasActiveTontine"
                    class="rounded-lg border border-amber-200 bg-amber-50 px-3 py-1.5 text-xs font-medium text-amber-700"
                    title="Une tontine active ou en attente bloque un nouveau cycle"
                  >
                    Tontine en cours
                  </span>
                </div>
              </td>
            </tr>
            <tr v-if="!clients.length && !clientStore.isLoading">
              <td colspan="8" class="px-3 py-8 text-center text-sm text-muted-foreground">
                Aucun client a afficher.
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="mt-4 flex flex-wrap items-center justify-between gap-3 text-sm">
        <p class="text-muted-foreground">
          Page {{ pagination.page }} / {{ totalPages }} - {{ pagination.total }} clients
        </p>
        <div class="flex items-center gap-2">
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="pagination.page <= 1 || clientStore.isLoading"
            @click="fetchClients(pagination.page - 1)"
          >
            Precedent
          </button>
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="pagination.page >= totalPages || clientStore.isLoading"
            @click="fetchClients(pagination.page + 1)"
          >
            Suivant
          </button>
        </div>
      </div>
    </div>
  </Card>

  <Dialog :open="detailDialogOpen" @update:open="detailDialogOpen = $event">
    <DialogContent
      class="sm:max-w-[980px] !flex !flex-col h-[86vh] overflow-hidden"
      @interact-outside.prevent
      @escape-key-down.prevent
    >
      <DialogHeader class="relative shrink-0 border-b border-border/60 pb-4 pr-10">
        <DialogTitle>Detail client</DialogTitle>
        <DialogDescription>
          <span v-if="detailData">{{ detailData.client.displayName }}</span>
          <span v-else>Chargement du client.</span>
        </DialogDescription>
        <DialogClose class="absolute right-0 top-0 rounded-lg p-2 opacity-70 transition hover:bg-muted hover:opacity-100">
          <X class="h-4 w-4" />
          <span class="sr-only">Fermer</span>
        </DialogClose>
      </DialogHeader>

      <div class="min-h-0 flex-1 overflow-y-auto pr-2">

      <div v-if="detailError" class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {{ detailError }}
      </div>
      <div v-else-if="isDetailLoading" class="text-sm text-muted-foreground">
        Chargement du detail client...
      </div>
      <div v-else-if="detailData" class="space-y-6">
        <div class="grid gap-4 md:grid-cols-4">
          <div class="rounded-2xl border border-border bg-muted/30 p-4">
            <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Disponible</p>
            <p class="mt-2 text-2xl font-semibold">{{ formatCurrency(detailData.client.wallet.availableBalance) }} F</p>
          </div>
          <div class="rounded-2xl border border-border bg-muted/30 p-4">
            <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Reserve</p>
            <p class="mt-2 text-2xl font-semibold">{{ formatCurrency(detailData.client.wallet.reservedWithdrawalBalance) }} F</p>
          </div>
          <div class="rounded-2xl border border-border bg-muted/30 p-4">
            <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Tontine</p>
            <p class="mt-2 text-2xl font-semibold">{{ formatCurrency(detailData.client.wallet.tontineBalance) }} F</p>
          </div>
          <div class="rounded-2xl border border-border bg-muted/30 p-4">
            <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Statut</p>
            <p class="mt-2 text-2xl font-semibold">{{ detailData.client.isActive ? "Actif" : "Inactif" }}</p>
          </div>
        </div>

        <div
          v-if="contributionError"
          class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
        >
          {{ contributionError }}
        </div>
        <div
          v-if="contributionSuccess"
          class="rounded-2xl border border-emerald-200 bg-emerald-100/70 px-4 py-3 text-sm text-emerald-700"
        >
          {{ contributionSuccess }}
        </div>

        <div
          v-if="currentContributionCycle"
          class="rounded-2xl border border-emerald-200 bg-emerald-50/70 p-4"
        >
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h4 class="font-medium text-emerald-800">Encaisser une cotisation</h4>
              <p class="mt-1 text-sm text-emerald-700">
                Cycle actif. Reste a verser:
                {{ formatCurrency(contributionRemaining) }} F.
              </p>
            </div>
            <span class="rounded-full bg-emerald-100 px-2.5 py-1 text-xs font-medium text-emerald-700">
              Mise du cycle: {{ formatCurrency(currentContributionCycle.stakeAmount) }} F
            </span>
          </div>

          <div class="mt-4 flex flex-wrap items-end gap-3">
            <div class="grid flex-1 gap-2 min-w-[220px]">
              <label for="contributionAmount" class="text-sm font-medium">Montant (F CFA)</label>
              <input
                id="contributionAmount"
                v-model.number="contributionForm.amount"
                type="number"
                :min="FINANCIAL_AMOUNT_STEP"
                :step="FINANCIAL_AMOUNT_STEP"
                class="h-10 rounded-xl border border-border bg-background px-3 text-sm"
                :placeholder="String(currentContributionCycle.stakeAmount)"
              />
            </div>
            <button
              class="rounded-xl bg-emerald-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-emerald-700 disabled:opacity-50"
              :disabled="isRecordingContribution"
              @click="handleRecordContribution"
            >
              <span v-if="isRecordingContribution">Enregistrement...</span>
              <span v-else>Enregistrer la cotisation</span>
            </button>
          </div>
          <p class="mt-3 text-xs text-emerald-700/80">
            Le montant doit rester un multiple de {{ FINANCIAL_AMOUNT_STEP }} F et ne peut pas depasser le reste a verser.
          </p>
        </div>

        <div class="grid gap-4 md:grid-cols-2">
          <div class="rounded-2xl border border-border/60 p-4">
            <h4 class="font-medium">Profil</h4>
            <p class="mt-3">{{ detailData.client.displayName }}</p>
            <p class="text-sm text-muted-foreground">{{ detailData.client.phoneNumber }}</p>
            <p class="mt-3 text-sm">Adresse: {{ detailData.client.address || "N/A" }}</p>
            <p class="text-sm">Origine: {{ detailData.client.createdByAgent?.fullName || "Canal direct" }}</p>
            <p class="text-sm">Membre depuis: {{ formatDateTime(detailData.client.memberSince) }}</p>
          </div>
          <div class="rounded-2xl border border-border/60 p-4">
            <h4 class="font-medium">Retraits recents</h4>
            <div class="mt-3 space-y-2">
              <div v-for="entry in detailData.withdrawals" :key="entry.id" class="rounded-xl border border-border/60 p-3">
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <p class="font-medium">{{ entry.reference }}</p>
                    <p class="text-xs text-muted-foreground">{{ entry.status }}</p>
                  </div>
                  <span class="text-sm font-medium">{{ formatCurrency(entry.amount) }} F</span>
                </div>
              </div>
              <div v-if="!detailData.withdrawals.length" class="text-sm text-muted-foreground">
                Aucun retrait recent.
              </div>
            </div>
          </div>
        </div>

        <div class="grid gap-4 lg:grid-cols-2">
          <div class="rounded-2xl border border-border/60 p-4">
            <h4 class="font-medium">Cycles tontine</h4>
            <div class="mt-3 space-y-2">
              <div v-for="entry in detailData.cycles" :key="entry.id" class="rounded-xl border border-border/60 p-3">
                <p class="font-medium">{{ entry.status }}</p>
                <p class="text-sm">Mise: {{ formatCurrency(entry.stakeAmount) }} F · Cumule: {{ formatCurrency(entry.cumulativeAmount) }} F</p>
                <p class="text-xs text-muted-foreground">Fin attendue: {{ formatDateTime(entry.expectedEndAt) }}</p>
              </div>
              <div v-if="!detailData.cycles.length" class="text-sm text-muted-foreground">
                Aucun cycle a afficher.
              </div>
            </div>
          </div>
          <div class="rounded-2xl border border-border/60 p-4">
            <h4 class="font-medium">Coffres</h4>
            <div class="mt-3 space-y-2">
              <div v-for="entry in detailData.goals" :key="entry.id" class="rounded-xl border border-border/60 p-3">
                <p class="font-medium">{{ entry.title }}</p>
                <p v-if="entry.linkedOffer" class="text-sm">
                  Produit lie: {{ entry.linkedOffer.title }} · Quantite {{ entry.quantity }}
                </p>
                <p class="text-sm">Actuel: {{ formatCurrency(entry.currentAmount) }} F / {{ formatCurrency(entry.targetAmount) }} F</p>
                <p class="text-sm">Prix unitaire: {{ formatCurrency(entry.unitPrice) }} F</p>
                <p class="text-xs text-muted-foreground">
                  Statut: {{ entry.status }} · Fin prevue: {{ formatDateTime(entry.endDate) }} · Avancement: {{ Math.round(entry.progress * 100) }}%
                </p>
              </div>
              <div v-if="!detailData.goals.length" class="text-sm text-muted-foreground">
                Aucun coffre a afficher.
              </div>
            </div>
          </div>
        </div>

        <div class="grid gap-4 lg:grid-cols-2">
          <div class="rounded-2xl border border-border/60 p-4">
            <h4 class="font-medium">Historique solde disponible</h4>
            <div class="mt-3 space-y-2">
              <div v-for="entry in detailData.balanceHistory" :key="entry.id" class="rounded-xl border border-border/60 p-3">
                <p class="font-medium">{{ entry.label }}</p>
                <p class="text-sm">{{ entry.isCredit ? "+" : "-" }}{{ formatCurrency(entry.amount) }} F</p>
                <p class="text-xs text-muted-foreground">{{ formatDateTime(entry.occurredAt) }}</p>
              </div>
              <div v-if="!detailData.balanceHistory.length" class="text-sm text-muted-foreground">
                Aucun mouvement de disponible.
              </div>
            </div>
          </div>
        <div class="rounded-2xl border border-border/60 p-4">
          <h4 class="font-medium">Historique tontine</h4>
          <div class="mt-3 space-y-2">
            <div v-for="entry in detailData.tontineHistory" :key="entry.id" class="rounded-xl border border-border/60 p-3">
              <p class="font-medium">{{ entry.label }}</p>
                <p class="text-sm">{{ formatCurrency(entry.amount) }} F</p>
                <p class="text-xs text-muted-foreground">{{ formatDateTime(entry.occurredAt) }}</p>
              </div>
              <div v-if="!detailData.tontineHistory.length" class="text-sm text-muted-foreground">
                Aucun historique tontine.
              </div>
            </div>
          </div>
        </div>
      </div>

      </div>

      <DialogFooter class="shrink-0 border-t border-border/60 pt-4">
        <button
          v-if="detailData && !hasOngoingTontine(detailData.cycles)"
          class="rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-2 text-sm font-medium text-emerald-700 transition hover:bg-emerald-100"
          :disabled="isStartingTontine"
          @click="openStartTontineDialog(detailData.client)"
        >
          Ouvrir un nouveau cycle
        </button>
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          @click="closeDetailDialog"
        >
          Fermer
        </button>
      </DialogFooter>
    </DialogContent>
  </Dialog>

  <Dialog :open="createDialogOpen" @update:open="createDialogOpen = $event">
    <DialogContent
      class="sm:max-w-[540px]"
      @interact-outside.prevent
      @escape-key-down.prevent
    >
      <DialogHeader>
        <div class="flex items-center justify-between">
          <DialogTitle>Nouveau client</DialogTitle>
          <DialogClose class="rounded-lg p-1 opacity-70 transition hover:bg-muted hover:opacity-100">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
          </DialogClose>
        </div>
        <DialogDescription>
          Remplissez les informations pour creer un nouveau compte client.
        </DialogDescription>
      </DialogHeader>

      <div v-if="createError" class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {{ createError }}
      </div>

      <div class="grid gap-4 py-4">
        <div class="grid gap-2">
          <label for="displayName" class="text-sm font-medium">Nom complet</label>
          <input
            id="displayName"
            v-model="createForm.displayName"
            type="text"
            placeholder="Ex: Jean Dupont"
            class="h-10 rounded-xl border border-border bg-background px-3 text-sm"
          />
        </div>
        <div class="grid gap-2">
          <label for="phoneNumber" class="text-sm font-medium">Numero de telephone</label>
          <input
            id="phoneNumber"
            v-model="createForm.phoneNumber"
            type="text"
            placeholder="Ex: 0102030405"
            class="h-10 rounded-xl border border-border bg-background px-3 text-sm"
          />
        </div>
        <div class="grid gap-2">
          <label for="address" class="text-sm font-medium">Adresse</label>
          <input
            id="address"
            v-model="createForm.address"
            type="text"
            placeholder="Quartier, Ville"
            class="h-10 rounded-xl border border-border bg-background px-3 text-sm"
          />
        </div>
        <div class="grid gap-2">
          <label for="stakeAmount" class="text-sm font-medium">Mise journaliere (F CFA)</label>
          <input
            id="stakeAmount"
            v-model.number="createForm.stakeAmount"
            type="number"
            :step="FINANCIAL_AMOUNT_STEP"
            :min="FINANCIAL_AMOUNT_STEP"
            placeholder="1000"
            class="h-10 rounded-xl border border-border bg-background px-3 text-sm"
          />
          <p class="text-[10px] text-muted-foreground">La mise doit etre un multiple de {{ FINANCIAL_AMOUNT_STEP }} F.</p>
        </div>
        <div class="grid gap-2">
          <label for="agentId" class="text-sm font-medium">Agent affecte (Optionnel)</label>
          <select
            id="agentId"
            v-model="createForm.agentId"
            class="h-10 rounded-xl border border-border bg-background px-3 text-sm"
          >
            <option value="">Aucun (Canal direct)</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.fullName }} ({{ agent.agentCode }})
            </option>
          </select>
        </div>
      </div>

      <DialogFooter>
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          :disabled="isCreating"
          @click="createDialogOpen = false"
        >
          Annuler
        </button>
        <button
          class="rounded-xl bg-sky-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-sky-700 disabled:opacity-50"
          :disabled="isCreating"
          @click="handleCreateClient"
        >
          <span v-if="isCreating">Creation...</span>
          <span v-else>Creer le client</span>
        </button>
      </DialogFooter>
    </DialogContent>
  </Dialog>

  <Dialog :open="startTontineDialogOpen" @update:open="setStartTontineDialogOpen">
    <DialogContent
      class="sm:max-w-[480px]"
      @interact-outside.prevent
      @escape-key-down.prevent
    >
      <DialogHeader>
        <div class="flex items-center justify-between">
          <DialogTitle>Demarrer une tontine</DialogTitle>
          <DialogClose class="rounded-lg p-1 opacity-70 transition hover:bg-muted hover:opacity-100">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
          </DialogClose>
        </div>
        <DialogDescription>
          Vous allez demarrer un nouveau cycle de 31 jours pour <strong>{{ startTontineForm.clientName }}</strong>.
          Le lancement sera refuse si une tontine active ou en attente existe deja.
        </DialogDescription>
      </DialogHeader>

      <div v-if="startTontineError" class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {{ startTontineError }}
      </div>
      <div v-if="startTontineSuccess" class="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
        {{ startTontineSuccess }}
      </div>

      <div class="grid gap-4 py-4">
        <div class="grid gap-2">
          <label for="stakeAmountStart" class="text-sm font-medium">Mise journaliere (F CFA)</label>
          <input
            id="stakeAmountStart"
            v-model.number="startTontineForm.stakeAmount"
            type="number"
            :step="FINANCIAL_AMOUNT_STEP"
            :min="FINANCIAL_AMOUNT_STEP"
            class="h-10 rounded-xl border border-border bg-background px-3 text-sm"
          />
          <p class="text-[10px] text-muted-foreground">La mise doit etre un multiple de {{ FINANCIAL_AMOUNT_STEP }} F.</p>
        </div>
      </div>

      <DialogFooter>
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          :disabled="isStartingTontine"
          @click="closeStartTontineDialog"
        >
          Annuler
        </button>
        <button
          class="rounded-xl bg-sky-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-sky-700 disabled:opacity-50"
          :disabled="isStartingTontine || Boolean(startTontineSuccess)"
          @click="handleStartTontine"
        >
          <span v-if="isStartingTontine">Demarrage...</span>
          <span v-else>Demarrer le cycle</span>
        </button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
