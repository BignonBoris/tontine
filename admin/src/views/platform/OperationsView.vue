<script setup lang="ts">
import { computed, onMounted, onScopeDispose, reactive, ref } from "vue";
import { RouterLink } from "vue-router";
import { AlertTriangle, ArrowDownLeft, ArrowUpRight, Loader2, RefreshCcw, RotateCcw, Search, X } from "lucide-vue-next";
import Card from "@/components/ui/card/Card.vue";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogClose,
} from "@/components/ui/dialog";
import { FINANCIAL_AMOUNT_STEP } from "@/constants/finance";
import { useOperationsStore } from "@/stores/operations";
import { clientService } from "@/services/clients/clientService";
import { getErrorMessage } from "@/services/http/errors";
import { formatCurrency, formatDateTime } from "@/utils/formatters";
import type { ClientDetail, ClientItem, OperationItem } from "@/types/platform";

const ongoingCycleStatuses = ["active", "enAttenteValidationFin"];

const operationsStore = useOperationsStore();
const operations = computed(() => operationsStore.collection?.items || []);
const pagination = computed(
  () => operationsStore.collection?.pagination || { page: 1, pageSize: 20, total: 0 },
);
const totals = computed(
  () =>
    operationsStore.collection?.totals || {
      totalDeposited: 0,
      totalWithdrawn: 0,
      totalCash: 0,
      totalCount: 0,
    },
);

const filters = reactive({
  clientSearch: "",
  type: "all",
  dateFrom: "",
  dateTo: "",
});

const currentPage = ref(1);
const pageSize = 20;
const errorMessage = ref("");

const depositDialogOpen = ref(false);
const withdrawalDialogOpen = ref(false);

const depositError = ref("");
const isRecordingDeposit = ref(false);
const depositAmount = ref<number | null>(null);
const withdrawalError = ref("");
const isRecordingWithdrawal = ref(false);
const withdrawalAmount = ref<number | null>(null);

const reverseDepositDialogOpen = ref(false);
const reverseDepositError = ref("");
const isReversingDeposit = ref(false);
const reverseDepositTarget = ref<OperationItem | null>(null);
const reverseDepositForm = reactive({
  reason: "",
});

type ClientPickerState = {
  search: string;
  results: ClientItem[];
  isOpen: boolean;
  isSearching: boolean;
  searchError: string;
  selectedClient: ClientItem | null;
  selectedDetail: ClientDetail | null;
  isDetailLoading: boolean;
  detailError: string;
};

function createClientPickerState() {
  const state = reactive<ClientPickerState>({
    search: "",
    results: [],
    isOpen: false,
    isSearching: false,
    searchError: "",
    selectedClient: null,
    selectedDetail: null,
    isDetailLoading: false,
    detailError: "",
  });

  let searchTimer: number | null = null;
  let searchRequestId = 0;
  let detailRequestId = 0;

  function clearSearchTimer() {
    if (searchTimer !== null) {
      window.clearTimeout(searchTimer);
      searchTimer = null;
    }
  }

  function formatSelectedLabel(client: ClientItem) {
    return client.displayName;
  }

  async function fetchSuggestions() {
    const requestId = ++searchRequestId;
    const term = state.search.trim();
    state.isSearching = true;
    state.searchError = "";

    try {
      const result = await clientService.list({
        search: term || undefined,
        pageSize: 8,
      });

      if (requestId !== searchRequestId) {
        return;
      }

      state.results = result.items;
    } catch (error) {
      if (requestId === searchRequestId) {
        state.searchError = getErrorMessage(error, "Recherche client impossible.");
        state.results = [];
      }
    } finally {
      if (requestId === searchRequestId) {
        state.isSearching = false;
      }
    }
  }

  function scheduleSuggestions() {
    clearSearchTimer();
    searchTimer = window.setTimeout(() => {
      void fetchSuggestions();
    }, 250);
  }

  function open() {
    state.isOpen = true;
    void fetchSuggestions();
  }

  function close() {
    state.isOpen = false;
  }

  function clear() {
    clearSearchTimer();
    searchRequestId += 1;
    detailRequestId += 1;
    state.search = "";
    state.results = [];
    state.isOpen = false;
    state.isSearching = false;
    state.searchError = "";
    state.selectedClient = null;
    state.selectedDetail = null;
    state.isDetailLoading = false;
    state.detailError = "";
  }

  function handleInput(value: string) {
    const normalizedValue = value;
    if (
      state.selectedClient &&
      normalizedValue !== formatSelectedLabel(state.selectedClient)
    ) {
      state.selectedClient = null;
      state.selectedDetail = null;
      state.detailError = "";
    }

    state.search = normalizedValue;
    state.isOpen = true;
    scheduleSuggestions();
  }

  async function selectClient(client: ClientItem) {
    clearSearchTimer();
    searchRequestId += 1;
    state.selectedClient = client;
    state.search = formatSelectedLabel(client);
    state.results = [];
    state.isOpen = false;
    state.searchError = "";
    state.detailError = "";
    state.isDetailLoading = true;

    const requestId = ++detailRequestId;
    try {
      state.selectedDetail = await clientService.getDetail(client.id);
    } catch (error) {
      if (requestId === detailRequestId) {
        state.detailError = getErrorMessage(error, "Chargement du client impossible.");
        state.selectedDetail = null;
      }
    } finally {
      if (requestId === detailRequestId) {
        state.isDetailLoading = false;
      }
    }
  }

  onScopeDispose(clearSearchTimer);

  return {
    state,
    open,
    close,
    clear,
    handleInput,
    selectClient,
  };
}

const depositPicker = createClientPickerState();
const withdrawalPicker = createClientPickerState();

const totalPages = computed(() =>
  Math.max(1, Math.ceil(pagination.value.total / pagination.value.pageSize)),
);

const depositCycle = computed(() => {
  const detail = depositPicker.state.selectedDetail;
  if (!detail) {
    return null;
  }

  return (
    detail.cycles.find((cycle) =>
      ongoingCycleStatuses.includes(cycle.status),
    ) || null
  );
});

const depositCycleMetrics = computed(() => {
  const cycle = depositCycle.value;
  if (!cycle) {
    return null;
  }

  const targetAmount = cycle.stakeAmount * 31;
  const cumulativeAmount = Math.max(cycle.cumulativeAmount || 0, 0);
  const remainingAmount = Math.max(targetAmount - cumulativeAmount, 0);
  const daysContributed = Math.min(
    31,
    Math.floor(cumulativeAmount / Math.max(cycle.stakeAmount, 1)),
  );
  const daysRemaining = Math.max(31 - daysContributed, 0);
  const currentHistory = depositPicker.state.selectedDetail?.tontineHistory || [];
  const lastDeposit = currentHistory.find(
    (entry) =>
      entry.cycleId === cycle.id &&
      entry.type === "deposit" &&
      !entry.isReversal,
  );

  return {
    targetAmount,
    cumulativeAmount,
    remainingAmount,
    daysContributed,
    daysRemaining,
    lastDepositAt: lastDeposit?.occurredAt || null,
  };
});

const canRecordDeposit = computed(() => {
  const detail = depositPicker.state.selectedDetail;
  const cycleMetrics = depositCycleMetrics.value;

  return Boolean(
    detail?.client.isActive &&
      cycleMetrics &&
      cycleMetrics.remainingAmount > 0,
  );
});

const withdrawalFinancialSnapshot = computed(() => {
  const detail = withdrawalPicker.state.selectedDetail;
  if (!detail) {
    return null;
  }

  return {
    availableBalance: detail.stats?.availableBalance ?? detail.client.wallet.availableBalance ?? 0,
    reservedWithdrawalBalance: detail.client.wallet.reservedWithdrawalBalance ?? 0,
    ongoingTontineAmount: detail.stats?.ongoingTontineAmount ?? detail.client.wallet.tontineBalance ?? 0,
    estimatedBalance: detail.stats?.estimatedBalance ?? 0,
    coffersAmount: detail.stats?.coffersAmount ?? 0,
  };
});

function formatOperationTypeLabel(operation: OperationItem) {
  if (operation.type === "depositReversal") {
    return "Annulation depot";
  }

  return operation.type === "deposit" ? "Depot" : "Retrait";
}

function formatOperationTypeClass(operation: OperationItem) {
  if (operation.type === "depositReversal") {
    return "bg-red-100 text-red-700";
  }

  return operation.type === "deposit"
    ? "bg-sky-100 text-sky-700"
    : "bg-violet-100 text-violet-700";
}

function formatOperationStatusLabel(operation: OperationItem) {
  if (operation.type === "depositReversal") {
    return "Annulation";
  }
  if (operation.isReversed) {
    return "Annulee";
  }

  switch (operation.status) {
    case "posted":
      return "Enregistre";
    case "requested":
      return "Demandee";
    case "paid":
      return "Payee";
    case "cancelled":
      return "Annulee";
    default:
      return operation.status;
  }
}

function formatOperationStatusClass(operation: OperationItem) {
  if (operation.type === "depositReversal") {
    return "bg-red-100 text-red-700";
  }
  if (operation.isReversed) {
    return "bg-amber-100 text-amber-700";
  }

  switch (operation.status) {
    case "posted":
      return "bg-emerald-100 text-emerald-700";
    case "paid":
      return "bg-emerald-100 text-emerald-700";
    case "requested":
      return "bg-amber-100 text-amber-700";
    case "cancelled":
      return "bg-red-100 text-red-700";
    default:
      return "bg-muted text-muted-foreground";
  }
}

function canReverseDeposit(operation: OperationItem) {
  return (
    operation.type === "deposit" &&
    !operation.isReversal &&
    !operation.isReversed &&
    Boolean(operation.client?.id)
  );
}

async function fetchOperations(page = currentPage.value) {
  errorMessage.value = "";
  currentPage.value = page;

  try {
    await operationsStore.fetchOperations({
      page: currentPage.value,
      pageSize,
      clientSearch: filters.clientSearch.trim() || undefined,
      type: filters.type as "all" | "deposit" | "withdrawal",
      dateFrom: filters.dateFrom || undefined,
      dateTo: filters.dateTo || undefined,
    });
  } catch (error) {
    errorMessage.value = getErrorMessage(
      error,
      "Chargement des operations impossible.",
    );
  }
}

function resetFilters() {
  filters.clientSearch = "";
  filters.type = "all";
  filters.dateFrom = "";
  filters.dateTo = "";
  void fetchOperations(1);
}

function openDepositDialog() {
  depositError.value = "";
  depositAmount.value = null;
  depositPicker.clear();
  depositPicker.open();
  depositDialogOpen.value = true;
}

function closeDepositDialog() {
  if (isRecordingDeposit.value) {
    return;
  }

  depositDialogOpen.value = false;
  depositError.value = "";
  depositAmount.value = null;
  depositPicker.clear();
}

function openWithdrawalDialog() {
  withdrawalError.value = "";
  withdrawalAmount.value = null;
  withdrawalPicker.clear();
  withdrawalPicker.open();
  withdrawalDialogOpen.value = true;
}

function closeWithdrawalDialog() {
  if (isRecordingWithdrawal.value) {
    return;
  }

  withdrawalDialogOpen.value = false;
  withdrawalError.value = "";
  withdrawalAmount.value = null;
  withdrawalPicker.clear();
}

async function handleRecordDeposit() {
  if (isRecordingDeposit.value) {
    return;
  }

  const client = depositPicker.state.selectedClient;
  const detail = depositPicker.state.selectedDetail;
  const cycle = depositCycle.value;
  const amount = Number(depositAmount.value);

  if (!client || !detail) {
    depositError.value = "Selectionnez un client valide.";
    return;
  }
  if (!detail.client.isActive) {
    depositError.value = "Ce client est inactif.";
    return;
  }
  if (!cycle || !depositCycleMetrics.value) {
    depositError.value = "Aucun cycle en cours pour ce client.";
    return;
  }
  if (depositCycleMetrics.value.remainingAmount <= 0) {
    depositError.value = "Ce cycle a deja atteint son objectif.";
    return;
  }
  if (
    !amount ||
    amount <= 0 ||
    amount % FINANCIAL_AMOUNT_STEP !== 0
  ) {
    depositError.value = `Le montant doit etre un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`;
    return;
  }
  if (amount > depositCycleMetrics.value.remainingAmount) {
    depositError.value = `Le montant depasse le reste a verser (${formatCurrency(depositCycleMetrics.value.remainingAmount)} F).`;
    return;
  }

  depositError.value = "";
  isRecordingDeposit.value = true;

  try {
    await operationsStore.recordDeposit(client.id, amount);
    closeDepositDialog();
    await fetchOperations(1);
  } catch (error) {
    depositError.value = getErrorMessage(
      error,
      "Enregistrement du depot impossible.",
    );
  } finally {
    isRecordingDeposit.value = false;
  }
}

async function handleRecordWithdrawal() {
  if (isRecordingWithdrawal.value) {
    return;
  }

  const client = withdrawalPicker.state.selectedClient;
  const detail = withdrawalPicker.state.selectedDetail;
  const amount = Number(withdrawalAmount.value);
  const availableBalance = withdrawalFinancialSnapshot.value?.availableBalance || 0;

  if (!client || !detail) {
    withdrawalError.value = "Selectionnez un client valide.";
    return;
  }
  if (
    !amount ||
    amount <= 0 ||
    amount % FINANCIAL_AMOUNT_STEP !== 0
  ) {
    withdrawalError.value = `Le montant doit etre un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`;
    return;
  }
  if (amount > availableBalance) {
    withdrawalError.value = `Le montant depasse le solde disponible (${formatCurrency(availableBalance)} F).`;
    return;
  }

  withdrawalError.value = "";
  isRecordingWithdrawal.value = true;

  try {
    await operationsStore.recordWithdrawal({
      userId: client.id,
      amount,
    });
    closeWithdrawalDialog();
    await fetchOperations(1);
  } catch (error) {
    withdrawalError.value = getErrorMessage(
      error,
      "Enregistrement du retrait impossible.",
    );
  } finally {
    isRecordingWithdrawal.value = false;
  }
}

function openReverseDepositDialog(operation: OperationItem) {
  if (!canReverseDeposit(operation)) {
    return;
  }

  reverseDepositError.value = "";
  reverseDepositTarget.value = operation;
  reverseDepositForm.reason = "";
  reverseDepositDialogOpen.value = true;
}

function closeReverseDepositDialog() {
  if (isReversingDeposit.value) {
    return;
  }

  reverseDepositDialogOpen.value = false;
  reverseDepositError.value = "";
  reverseDepositTarget.value = null;
  reverseDepositForm.reason = "";
}

function setReverseDepositDialogOpen(value: boolean) {
  if (value) {
    reverseDepositDialogOpen.value = true;
    return;
  }

  closeReverseDepositDialog();
}

async function handleReverseDeposit() {
  if (isReversingDeposit.value) {
    return;
  }

  const target = reverseDepositTarget.value;
  const reason = reverseDepositForm.reason.trim();

  if (!target?.client?.id) {
    reverseDepositError.value = "Selectionnez un depot valide.";
    return;
  }
  if (!canReverseDeposit(target)) {
    reverseDepositError.value =
      "Ce depot ne peut plus etre annule automatiquement.";
    return;
  }
  if (!reason) {
    reverseDepositError.value = "Le motif d'annulation est obligatoire.";
    return;
  }

  reverseDepositError.value = "";
  isReversingDeposit.value = true;

  try {
    await operationsStore.reverseDeposit(target.client.id, target.id, {
      reason,
    });
    closeReverseDepositDialog();
    await fetchOperations(currentPage.value);
  } catch (error) {
    reverseDepositError.value = getErrorMessage(
      error,
      "Annulation du depot impossible.",
    );
  } finally {
    isReversingDeposit.value = false;
  }
}

function onPickerInput(
  picker: ReturnType<typeof createClientPickerState>,
  event: Event,
) {
  picker.handleInput((event.target as HTMLInputElement).value);
}

function onPickerFocus(
  picker: ReturnType<typeof createClientPickerState>,
) {
  picker.open();
}

function onPickerClear(
  picker: ReturnType<typeof createClientPickerState>,
) {
  picker.clear();
  picker.open();
}

onScopeDispose(() => {
  depositPicker.close();
  withdrawalPicker.close();
});

onMounted(() => {
  void fetchOperations(1);
});
</script>

<template>
  <Card class="border border-border/60">
    <div class="p-6 space-y-6">
      <PageHeader
        title="Operations"
        description="Suivi des depots et retraits, avec filtres par client, date et type d'operation."
      />

      <div class="flex flex-wrap items-center justify-end gap-3">
        <RouterLink
          to="/recouvrement"
          class="inline-flex items-center gap-2 rounded-xl border border-amber-200 bg-amber-50 px-4 py-2 text-sm font-medium text-amber-700 transition hover:bg-amber-100"
        >
          <AlertTriangle class="h-4 w-4" />
          Recouvrement
        </RouterLink>
        <button
          class="inline-flex items-center gap-2 rounded-xl border border-sky-200 bg-sky-50 px-4 py-2 text-sm font-medium text-sky-700 transition hover:bg-sky-100"
          @click="openDepositDialog"
        >
          <ArrowDownLeft class="h-4 w-4" />
          Depot
        </button>
        <button
          class="inline-flex items-center gap-2 rounded-xl border border-violet-200 bg-violet-50 px-4 py-2 text-sm font-medium text-violet-700 transition hover:bg-violet-100"
          @click="openWithdrawalDialog"
        >
          <ArrowUpRight class="h-4 w-4" />
          Retrait
        </button>
        <button
          class="inline-flex items-center gap-2 rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          :disabled="operationsStore.isLoading"
          @click="fetchOperations(currentPage)"
        >
          <RefreshCcw class="h-4 w-4" />
          Rafraichir
        </button>
      </div>

      <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <div class="rounded-2xl border border-sky-200 bg-sky-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-sky-700">Total depose</p>
          <p class="mt-2 text-2xl font-semibold text-sky-700">{{ formatCurrency(totals.totalDeposited) }} F</p>
        </div>
        <div class="rounded-2xl border border-violet-200 bg-violet-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-violet-700">Total retire</p>
          <p class="mt-2 text-2xl font-semibold text-violet-700">{{ formatCurrency(totals.totalWithdrawn) }} F</p>
        </div>
        <div class="rounded-2xl border border-emerald-200 bg-emerald-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-emerald-700">Caisse nette</p>
          <p class="mt-2 text-2xl font-semibold text-emerald-700">{{ formatCurrency(totals.totalCash) }} F</p>
        </div>
        <div class="rounded-2xl border border-border bg-muted/30 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Operations filtrees</p>
          <p class="mt-2 text-2xl font-semibold">{{ totals.totalCount }}</p>
        </div>
      </div>

      <div class="grid gap-3 rounded-2xl border border-border/60 bg-muted/20 p-4 xl:grid-cols-4">
        <div class="grid gap-2">
          <label class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Client</label>
          <div class="relative">
            <input
              v-model="filters.clientSearch"
              type="text"
              placeholder="Nom ou telephone"
              class="h-10 w-full rounded-xl border border-border bg-background pl-3 pr-10 text-sm"
            />
            <Search class="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          </div>
        </div>
        <div class="grid gap-2">
          <label class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Type</label>
          <select
            v-model="filters.type"
            class="h-10 rounded-xl border border-border bg-white px-3 text-sm"
          >
            <option value="all">Toutes operations</option>
            <option value="deposit">Depots</option>
            <option value="withdrawal">Retraits</option>
          </select>
        </div>
        <div class="grid gap-2">
          <label class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Date operation debut</label>
          <input
            v-model="filters.dateFrom"
            type="date"
            class="h-10 rounded-xl border border-border bg-background px-3 text-sm"
            @change="fetchOperations(1)"
          />
        </div>
        <div class="grid gap-2">
          <label class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Date operation fin</label>
          <input
            v-model="filters.dateTo"
            type="date"
            class="h-10 rounded-xl border border-border bg-background px-3 text-sm"
            @change="fetchOperations(1)"
          />
        </div>
      </div>

      <div class="flex flex-wrap items-center justify-between gap-3">
        <p class="text-sm text-muted-foreground">
          Les indicateurs suivent le filtre actif et la date correspond a la date de l'operation.
        </p>
        <div class="flex items-center gap-2">
          <button
            class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
            @click="resetFilters"
          >
            Reinitialiser
          </button>
          <button
            class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
            @click="fetchOperations(1)"
          >
            Appliquer
          </button>
        </div>
      </div>

      <div v-if="errorMessage" class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {{ errorMessage }}
      </div>

      <div v-if="operationsStore.isLoading && !operations.length" class="text-sm text-muted-foreground">
        Chargement des operations...
      </div>

      <div v-else class="overflow-auto rounded-2xl border border-border/60">
        <table class="w-full min-w-[1180px] text-sm">
          <thead class="bg-muted/30">
            <tr class="border-b">
              <th class="px-3 py-3 text-left">Date</th>
              <th class="px-3 py-3 text-left">Type</th>
              <th class="px-3 py-3 text-left">Client</th>
              <th class="px-3 py-3 text-left">Reference</th>
              <th class="px-3 py-3 text-left">Libelle</th>
              <th class="px-3 py-3 text-left">Montant</th>
              <th class="px-3 py-3 text-left">Statut</th>
              <th class="px-3 py-3 text-left">Note</th>
              <th class="px-3 py-3 text-left">Action</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="operation in operations" :key="`${operation.type}-${operation.id}`" class="border-b">
              <td class="px-3 py-3 whitespace-nowrap">{{ formatDateTime(operation.occurredAt) }}</td>
              <td class="px-3 py-3">
                <span class="rounded-full px-2.5 py-1 text-xs font-medium" :class="formatOperationTypeClass(operation)">
                  {{ formatOperationTypeLabel(operation) }}
                </span>
              </td>
              <td class="px-3 py-3">
                <div class="font-medium">{{ operation.client?.displayName || "N/A" }}</div>
                <div class="text-xs text-muted-foreground">{{ operation.client?.phoneNumber || "N/A" }}</div>
              </td>
              <td class="px-3 py-3 font-medium">{{ operation.reference || operation.id }}</td>
              <td class="px-3 py-3">
                <div class="font-medium">{{ operation.label }}</div>
                <div class="text-xs text-muted-foreground">{{ operation.initiatorType || "N/A" }}</div>
              </td>
              <td class="px-3 py-3 font-medium">{{ formatCurrency(operation.amount) }} F</td>
              <td class="px-3 py-3">
                <span class="rounded-full px-2.5 py-1 text-xs font-medium" :class="formatOperationStatusClass(operation)">
                  {{ formatOperationStatusLabel(operation) }}
                </span>
              </td>
              <td class="px-3 py-3 text-xs text-muted-foreground">
                {{ operation.note || "N/A" }}
              </td>
              <td class="px-3 py-3">
                <button
                  v-if="canReverseDeposit(operation)"
                  type="button"
                  class="inline-flex items-center gap-2 rounded-lg border border-red-200 bg-red-50 px-3 py-1.5 text-xs font-medium text-red-700 transition hover:bg-red-100 disabled:cursor-not-allowed disabled:opacity-50"
                  :disabled="isReversingDeposit"
                  title="Annuler le depot"
                  aria-label="Annuler le depot"
                  @click="openReverseDepositDialog(operation)"
                >
                  <RotateCcw class="h-4 w-4" />
                  Annuler
                </button>
                <span v-else class="text-xs text-muted-foreground">
                  —
                </span>
              </td>
            </tr>
            <tr v-if="!operations.length && !operationsStore.isLoading">
              <td colspan="9" class="px-3 py-8 text-center text-sm text-muted-foreground">
                Aucune operation a afficher.
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="flex flex-wrap items-center justify-between gap-3 text-sm">
        <p class="text-muted-foreground">
          Page {{ pagination.page }} / {{ totalPages }} - {{ pagination.total }} operations
        </p>
        <div class="flex items-center gap-2">
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="pagination.page <= 1 || operationsStore.isLoading"
            @click="fetchOperations(pagination.page - 1)"
          >
            Precedent
          </button>
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="pagination.page >= totalPages || operationsStore.isLoading"
            @click="fetchOperations(pagination.page + 1)"
          >
            Suivant
          </button>
        </div>
      </div>
    </div>
  </Card>

  <Dialog :open="depositDialogOpen" @update:open="depositDialogOpen = $event">
    <DialogContent class="sm:max-w-[980px]" @interact-outside.prevent @escape-key-down.prevent>
      <DialogHeader>
        <div class="flex items-center justify-between gap-3">
          <DialogTitle>Depot</DialogTitle>
          <DialogClose class="rounded-lg p-1 opacity-70 transition hover:bg-muted hover:opacity-100" @click="closeDepositDialog">
            <X class="h-4 w-4" />
          </DialogClose>
        </div>
        <DialogDescription>
          Selectionnez un client, verifiez son cycle en cours puis enregistrez le depot.
        </DialogDescription>
      </DialogHeader>

      <div v-if="depositError" class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {{ depositError }}
      </div>

      <div class="grid gap-6 lg:grid-cols-[1.05fr_0.95fr]">
        <div class="space-y-4">
          <div class="grid gap-2">
            <label class="text-sm font-medium">Client</label>
            <div class="relative">
              <input
                :value="depositPicker.state.search"
                type="text"
                placeholder="Rechercher un client"
                class="h-10 w-full rounded-xl border border-border bg-background pl-3 pr-20 text-sm"
                @focus="onPickerFocus(depositPicker)"
                @input="onPickerInput(depositPicker, $event)"
              />
              <div class="absolute right-2 top-1/2 flex -translate-y-1/2 items-center gap-1">
                <button
                  v-if="depositPicker.state.search"
                  type="button"
                  class="rounded-lg p-1 text-muted-foreground transition hover:bg-muted hover:text-foreground"
                  title="Effacer"
                  @click="onPickerClear(depositPicker)"
                >
                  <X class="h-4 w-4" />
                </button>
                <Search class="h-4 w-4 text-muted-foreground" />
              </div>

              <div
                v-if="depositPicker.state.isOpen"
                class="absolute z-20 mt-2 w-full overflow-hidden rounded-2xl border border-border bg-background shadow-lg"
              >
                <div v-if="depositPicker.state.isSearching" class="flex items-center gap-2 px-4 py-3 text-sm text-muted-foreground">
                  <Loader2 class="h-4 w-4 animate-spin" />
                  Recherche clients...
                </div>
                <div v-else-if="depositPicker.state.searchError" class="px-4 py-3 text-sm text-red-700">
                  {{ depositPicker.state.searchError }}
                </div>
                <div v-else class="max-h-72 overflow-auto">
                  <button
                    v-for="client in depositPicker.state.results"
                    :key="client.id"
                    type="button"
                    class="w-full border-b border-border/60 px-4 py-3 text-left transition hover:bg-muted"
                    @click="depositPicker.selectClient(client)"
                  >
                    <div class="flex items-start justify-between gap-3">
                      <div>
                        <p class="font-medium">{{ client.displayName }}</p>
                        <p class="text-xs text-muted-foreground">{{ client.phoneNumber || "N/A" }}</p>
                      </div>
                      <span
                        class="rounded-full px-2.5 py-1 text-[11px] font-medium"
                        :class="client.isActive ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700'"
                      >
                        {{ client.isActive ? "Actif" : "Inactif" }}
                      </span>
                    </div>
                    <p class="mt-2 text-xs text-muted-foreground">
                      Solde disponible: {{ formatCurrency(client.availableBalance) }} F - Tontine: {{ formatCurrency(client.tontineBalance) }} F
                    </p>
                  </button>
                  <div v-if="!depositPicker.state.results.length" class="px-4 py-3 text-sm text-muted-foreground">
                    Aucun client trouve.
                  </div>
                </div>
              </div>
            </div>
            <p class="text-xs text-muted-foreground">
              La recherche est dynamique sur le nom ou le telephone.
            </p>
          </div>

          <div
            v-if="depositPicker.state.selectedClient"
            class="rounded-2xl border border-border/60 bg-muted/20 p-4"
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="font-medium">{{ depositPicker.state.selectedClient.displayName }}</p>
                <p class="text-sm text-muted-foreground">{{ depositPicker.state.selectedClient.phoneNumber || "N/A" }}</p>
              </div>
              <span
                class="rounded-full px-2.5 py-1 text-xs font-medium"
                :class="
                  depositPicker.state.isDetailLoading
                    ? 'bg-muted text-muted-foreground'
                    : depositPicker.state.selectedDetail?.client.isActive
                      ? 'bg-emerald-100 text-emerald-700'
                      : 'bg-red-100 text-red-700'
                "
              >
                {{
                  depositPicker.state.isDetailLoading
                    ? "Chargement"
                    : depositPicker.state.selectedDetail?.client.isActive
                      ? "Actif"
                      : "Inactif"
                }}
              </span>
            </div>
            <div v-if="depositPicker.state.isDetailLoading" class="mt-3 flex items-center gap-2 text-sm text-muted-foreground">
              <Loader2 class="h-4 w-4 animate-spin" />
              Chargement du detail client...
            </div>
            <div v-else-if="depositPicker.state.detailError" class="mt-3 text-sm text-red-700">
              {{ depositPicker.state.detailError }}
            </div>
          </div>
        </div>

        <div class="space-y-4">
          <div
            v-if="depositCycle && depositCycleMetrics"
            class="rounded-2xl border border-border/60 bg-background p-4"
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Cycle en cours</p>
                <h4 class="mt-1 text-lg font-semibold">
                  Mise {{ formatCurrency(depositCycle.stakeAmount) }} F
                </h4>
              </div>
              <span
                class="rounded-full px-2.5 py-1 text-xs font-medium"
                :class="depositCycle.status === 'active' ? 'bg-sky-100 text-sky-700' : 'bg-amber-100 text-amber-700'"
              >
                {{ depositCycle.status }}
              </span>
            </div>

            <div class="mt-4 grid gap-3 sm:grid-cols-2">
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Cumul</p>
                <p class="mt-2 text-lg font-semibold">{{ formatCurrency(depositCycleMetrics.cumulativeAmount) }} F</p>
              </div>
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Reste a verser</p>
                <p class="mt-2 text-lg font-semibold">{{ formatCurrency(depositCycleMetrics.remainingAmount) }} F</p>
              </div>
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Jours cotises</p>
                <p class="mt-2 text-lg font-semibold">{{ depositCycleMetrics.daysContributed }} / 31</p>
              </div>
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Jours restants</p>
                <p class="mt-2 text-lg font-semibold">{{ depositCycleMetrics.daysRemaining }}</p>
              </div>
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Debut</p>
                <p class="mt-2 text-sm font-medium">{{ formatDateTime(depositCycle.startedAt) }}</p>
              </div>
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Fin prevue</p>
                <p class="mt-2 text-sm font-medium">{{ formatDateTime(depositCycle.expectedEndAt) }}</p>
              </div>
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Dernier depot</p>
                <p class="mt-2 text-sm font-medium">{{ depositCycleMetrics.lastDepositAt ? formatDateTime(depositCycleMetrics.lastDepositAt) : 'Aucun depot' }}</p>
              </div>
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Objectif</p>
                <p class="mt-2 text-sm font-medium">{{ formatCurrency(depositCycleMetrics.targetAmount) }} F</p>
              </div>
            </div>
          </div>
          <div
            v-else
            class="rounded-2xl border border-dashed border-border/60 bg-muted/20 p-4 text-sm text-muted-foreground"
          >
            Aucun cycle en cours.
          </div>

          <div class="grid gap-2">
            <label class="text-sm font-medium">Montant du depot</label>
            <input
              v-model.number="depositAmount"
              type="number"
              :step="FINANCIAL_AMOUNT_STEP"
              :min="FINANCIAL_AMOUNT_STEP"
              :disabled="!canRecordDeposit"
              class="h-10 rounded-xl border border-border bg-background px-3 text-sm"
              placeholder="1000"
            />
            <p class="text-xs text-muted-foreground">
              Le montant doit etre un multiple de {{ FINANCIAL_AMOUNT_STEP }} F.
            </p>
          </div>

          <div class="rounded-2xl border border-sky-200 bg-sky-50/60 p-4 text-sm text-sky-700">
            Le depot sera ajoute au cycle en cours et l'operation apparaitra dans le tableau apres validation.
          </div>
        </div>
      </div>

      <DialogFooter>
        <button
          type="button"
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted disabled:opacity-50"
          :disabled="isRecordingDeposit"
          @click="closeDepositDialog"
        >
          Annuler
        </button>
        <button
          type="button"
          class="inline-flex items-center gap-2 rounded-xl bg-sky-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-sky-700 disabled:opacity-50"
          :disabled="isRecordingDeposit || !canRecordDeposit"
          @click="handleRecordDeposit"
        >
          <Loader2 v-if="isRecordingDeposit" class="h-4 w-4 animate-spin" />
          <ArrowDownLeft v-else class="h-4 w-4" />
          <span>{{ isRecordingDeposit ? "Enregistrement..." : "Enregistrer le depot" }}</span>
        </button>
      </DialogFooter>
    </DialogContent>
  </Dialog>

  <Dialog :open="withdrawalDialogOpen" @update:open="withdrawalDialogOpen = $event">
    <DialogContent class="sm:max-w-[980px]" @interact-outside.prevent @escape-key-down.prevent>
      <DialogHeader>
        <div class="flex items-center justify-between gap-3">
          <DialogTitle>Retrait</DialogTitle>
          <DialogClose class="rounded-lg p-1 opacity-70 transition hover:bg-muted hover:opacity-100" @click="closeWithdrawalDialog">
            <X class="h-4 w-4" />
          </DialogClose>
        </div>
        <DialogDescription>
          Enregistrer un retrait client depuis le solde disponible, puis suivre l'operation dans la liste.
        </DialogDescription>
      </DialogHeader>

      <div v-if="withdrawalError" class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {{ withdrawalError }}
      </div>

      <div class="grid gap-6 lg:grid-cols-[1.05fr_0.95fr]">
        <div class="space-y-4">
          <div class="grid gap-2">
            <label class="text-sm font-medium">Client</label>
            <div class="relative">
              <input
                :value="withdrawalPicker.state.search"
                type="text"
                placeholder="Rechercher un client"
                class="h-10 w-full rounded-xl border border-border bg-background pl-3 pr-20 text-sm"
                @focus="onPickerFocus(withdrawalPicker)"
                @input="onPickerInput(withdrawalPicker, $event)"
              />
              <div class="absolute right-2 top-1/2 flex -translate-y-1/2 items-center gap-1">
                <button
                  v-if="withdrawalPicker.state.search"
                  type="button"
                  class="rounded-lg p-1 text-muted-foreground transition hover:bg-muted hover:text-foreground"
                  title="Effacer"
                  @click="onPickerClear(withdrawalPicker)"
                >
                  <X class="h-4 w-4" />
                </button>
                <Search class="h-4 w-4 text-muted-foreground" />
              </div>

              <div
                v-if="withdrawalPicker.state.isOpen"
                class="absolute z-20 mt-2 w-full overflow-hidden rounded-2xl border border-border bg-background shadow-lg"
              >
                <div v-if="withdrawalPicker.state.isSearching" class="flex items-center gap-2 px-4 py-3 text-sm text-muted-foreground">
                  <Loader2 class="h-4 w-4 animate-spin" />
                  Recherche clients...
                </div>
                <div v-else-if="withdrawalPicker.state.searchError" class="px-4 py-3 text-sm text-red-700">
                  {{ withdrawalPicker.state.searchError }}
                </div>
                <div v-else class="max-h-72 overflow-auto">
                  <button
                    v-for="client in withdrawalPicker.state.results"
                    :key="client.id"
                    type="button"
                    class="w-full border-b border-border/60 px-4 py-3 text-left transition hover:bg-muted"
                    @click="withdrawalPicker.selectClient(client)"
                  >
                    <div class="flex items-start justify-between gap-3">
                      <div>
                        <p class="font-medium">{{ client.displayName }}</p>
                        <p class="text-xs text-muted-foreground">{{ client.phoneNumber || "N/A" }}</p>
                      </div>
                      <span
                        class="rounded-full px-2.5 py-1 text-[11px] font-medium"
                        :class="client.isActive ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700'"
                      >
                        {{ client.isActive ? "Actif" : "Inactif" }}
                      </span>
                    </div>
                    <p class="mt-2 text-xs text-muted-foreground">
                      Solde disponible: {{ formatCurrency(client.availableBalance) }} F - Tontine: {{ formatCurrency(client.tontineBalance) }} F
                    </p>
                  </button>
                  <div v-if="!withdrawalPicker.state.results.length" class="px-4 py-3 text-sm text-muted-foreground">
                    Aucun client trouve.
                  </div>
                </div>
              </div>
            </div>
            <p class="text-xs text-muted-foreground">
              La recherche est dynamique sur le nom ou le telephone.
            </p>
          </div>

          <div
            v-if="withdrawalPicker.state.selectedClient"
            class="rounded-2xl border border-border/60 bg-muted/20 p-4"
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="font-medium">{{ withdrawalPicker.state.selectedClient.displayName }}</p>
                <p class="text-sm text-muted-foreground">{{ withdrawalPicker.state.selectedClient.phoneNumber || "N/A" }}</p>
              </div>
              <span
                class="rounded-full px-2.5 py-1 text-xs font-medium"
                :class="
                  withdrawalPicker.state.isDetailLoading
                    ? 'bg-muted text-muted-foreground'
                    : withdrawalPicker.state.selectedDetail?.client.isActive
                      ? 'bg-emerald-100 text-emerald-700'
                      : 'bg-red-100 text-red-700'
                "
              >
                {{
                  withdrawalPicker.state.isDetailLoading
                    ? "Chargement"
                    : withdrawalPicker.state.selectedDetail?.client.isActive
                      ? "Actif"
                      : "Inactif"
                }}
              </span>
            </div>
            <div v-if="withdrawalPicker.state.isDetailLoading" class="mt-3 flex items-center gap-2 text-sm text-muted-foreground">
              <Loader2 class="h-4 w-4 animate-spin" />
              Chargement du detail client...
            </div>
            <div v-else-if="withdrawalPicker.state.detailError" class="mt-3 text-sm text-red-700">
              {{ withdrawalPicker.state.detailError }}
            </div>
          </div>
        </div>

        <div class="space-y-4">
          <div
            v-if="withdrawalFinancialSnapshot"
            class="rounded-2xl border border-border/60 bg-background p-4"
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Solde client</p>
                <h4 class="mt-1 text-lg font-semibold">
                  {{ formatCurrency(withdrawalFinancialSnapshot.availableBalance) }} F disponibles
                </h4>
              </div>
              <span class="rounded-full bg-sky-100 px-2.5 py-1 text-xs font-medium text-sky-700">
                Synthese
              </span>
            </div>

            <div class="mt-4 grid gap-3 sm:grid-cols-2">
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Reserve retrait</p>
                <p class="mt-2 text-lg font-semibold">{{ formatCurrency(withdrawalFinancialSnapshot.reservedWithdrawalBalance) }} F</p>
              </div>
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Tontine en cours</p>
                <p class="mt-2 text-lg font-semibold">{{ formatCurrency(withdrawalFinancialSnapshot.ongoingTontineAmount) }} F</p>
              </div>
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Solde estime</p>
                <p class="mt-2 text-lg font-semibold">{{ formatCurrency(withdrawalFinancialSnapshot.estimatedBalance) }} F</p>
              </div>
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Coffres</p>
                <p class="mt-2 text-lg font-semibold">{{ formatCurrency(withdrawalFinancialSnapshot.coffersAmount) }} F</p>
              </div>
            </div>
          </div>
          <div
            v-else
            class="rounded-2xl border border-dashed border-border/60 bg-muted/20 p-4 text-sm text-muted-foreground"
          >
            Selectionnez un client pour afficher sa synthese financiere.
          </div>

          <div class="grid gap-2">
            <label class="text-sm font-medium">Montant du retrait</label>
            <input
              v-model.number="withdrawalAmount"
              type="number"
              :step="FINANCIAL_AMOUNT_STEP"
              :min="FINANCIAL_AMOUNT_STEP"
              class="h-10 rounded-xl border border-border bg-background px-3 text-sm"
              placeholder="1000"
            />
            <p class="text-xs text-muted-foreground">
              Le montant doit etre un multiple de {{ FINANCIAL_AMOUNT_STEP }} F.
            </p>
          </div>

          <div class="rounded-2xl border border-violet-200 bg-violet-50/60 p-4 text-sm text-violet-700">
            Le retrait est enregistre avec le workflow de l'API et apparaitra ensuite dans l'historique.
          </div>
        </div>
      </div>

      <DialogFooter>
        <button
          type="button"
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted disabled:opacity-50"
          :disabled="isRecordingWithdrawal"
          @click="closeWithdrawalDialog"
        >
          Annuler
        </button>
        <button
          type="button"
          class="inline-flex items-center gap-2 rounded-xl bg-violet-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-violet-700 disabled:opacity-50"
          :disabled="isRecordingWithdrawal"
          @click="handleRecordWithdrawal"
        >
          <Loader2 v-if="isRecordingWithdrawal" class="h-4 w-4 animate-spin" />
          <ArrowUpRight v-else class="h-4 w-4" />
          <span>{{ isRecordingWithdrawal ? "Enregistrement..." : "Enregistrer le retrait" }}</span>
        </button>
      </DialogFooter>
    </DialogContent>
  </Dialog>

  <Dialog
    :open="reverseDepositDialogOpen"
    @update:open="setReverseDepositDialogOpen"
  >
    <DialogContent
      class="sm:max-w-[560px]"
      @interact-outside.prevent
      @escape-key-down.prevent
    >
      <DialogHeader>
        <div class="flex items-center justify-between gap-3">
          <DialogTitle>Annuler le depot</DialogTitle>
          <DialogClose
            class="rounded-lg p-1 opacity-70 transition hover:bg-muted hover:opacity-100"
            @click="closeReverseDepositDialog"
          >
            <X class="h-4 w-4" />
          </DialogClose>
        </div>
        <DialogDescription>
          La contrepassation cree une nouvelle operation liee au depot d'origine. Cette action est reservee a l'administrateur.
        </DialogDescription>
      </DialogHeader>

      <div
        v-if="reverseDepositError"
        class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
      >
        {{ reverseDepositError }}
      </div>

      <div
        v-if="reverseDepositTarget"
        class="rounded-2xl border border-border/60 bg-muted/20 p-4"
      >
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p class="font-medium">
              {{ reverseDepositTarget.client?.displayName || "N/A" }}
            </p>
            <p class="text-sm text-muted-foreground">
              {{ reverseDepositTarget.client?.phoneNumber || "N/A" }}
            </p>
          </div>
          <span class="text-sm font-semibold">
            {{ formatCurrency(reverseDepositTarget.amount) }} F
          </span>
        </div>
        <p class="mt-3 text-sm">
          {{ reverseDepositTarget.label }}
        </p>
        <p class="mt-1 text-xs text-muted-foreground">
          {{ formatDateTime(reverseDepositTarget.occurredAt) }}
        </p>
      </div>

      <div class="grid gap-2">
        <label for="reverseDepositReason" class="text-sm font-medium">
          Motif d'annulation
        </label>
        <textarea
          id="reverseDepositReason"
          v-model="reverseDepositForm.reason"
          rows="4"
          maxlength="255"
          class="min-h-[110px] rounded-xl border border-border bg-background px-3 py-2 text-sm outline-none transition focus:border-sky-500"
          placeholder="Ex: erreur de saisie, doublon, annulation autorisee"
        />
      </div>

      <DialogFooter>
        <button
          type="button"
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted disabled:opacity-50"
          :disabled="isReversingDeposit"
          @click="closeReverseDepositDialog"
        >
          Annuler
        </button>
        <button
          type="button"
          class="inline-flex items-center gap-2 rounded-xl bg-red-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-red-700 disabled:opacity-50"
          :disabled="isReversingDeposit"
          @click="handleReverseDeposit"
        >
          <Loader2 v-if="isReversingDeposit" class="h-4 w-4 animate-spin" />
          <RotateCcw v-else class="h-4 w-4" />
          <span>{{ isReversingDeposit ? "Annulation..." : "Confirmer l'annulation" }}</span>
        </button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
