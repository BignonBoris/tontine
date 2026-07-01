<script setup lang="ts">
import { computed, onMounted, reactive, ref } from "vue";
import { RouterLink } from "vue-router";
import {
  Ban,
  CheckCircle2,
  Lock,
  Loader2,
  PencilLine,
  X,
} from "lucide-vue-next";
import { FINANCIAL_AMOUNT_STEP } from "@/constants/finance";
import Card from "@/components/ui/card/Card.vue";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { useTontineStore } from "@/stores/tontines";
import { tontineService } from "@/services/tontines/tontineService";
import { getErrorMessage } from "@/services/http/errors";
import type {
  TontineCycleCalendar,
  TontineCycleItem,
} from "@/types/platform";
import { formatCurrency, formatDateTime } from "@/utils/formatters";

const tontineStore = useTontineStore();
const tontines = computed(() => tontineStore.collection?.items || []);
const pagination = computed(() => tontineStore.collection?.pagination || { page: 1, pageSize: 20, total: 0 });
const filters = reactive({
  search: "",
  status: "",
});
const currentPage = ref(1);
const pageSize = 20;
const errorMessage = ref("");
const selectedTontinePreview = ref<TontineCycleItem | null>(null);
const selectedTontineCalendar = ref<TontineCycleCalendar | null>(null);
const calendarDialogOpen = ref(false);
const calendarLoadingId = ref<string | null>(null);
const calendarError = ref("");
const cycleEditDialogOpen = ref(false);
const editingCycleId = ref<string | null>(null);
const editingCycleLabel = ref("");
const isUpdatingCycle = ref(false);
const closingCycleId = ref<string | null>(null);
const cycleEditError = ref("");
const cycleEditForm = reactive({
  stakeAmount: null as number | null,
});

type CardCellStatus = "paid" | "partial" | "remaining";

interface CardCellItem {
  cellNumber: number;
  status: CardCellStatus;
  filledAmount: number;
  isPartial: boolean;
}

const calendarCycle = computed(() => selectedTontineCalendar.value?.cycle || selectedTontinePreview.value);
const calendarDays = computed<CardCellItem[]>(() => buildCardCells(selectedTontineCalendar.value));
const calendarSummary = computed(() => {
  const cycle = calendarCycle.value;
  const stakeAmount = Number(cycle?.stakeAmount || 0);
  const cumulativeAmount = Number(cycle?.cumulativeAmount || 0);
  const paidCells = stakeAmount > 0 ? Math.min(31, Math.floor(cumulativeAmount / stakeAmount)) : 0;
  const partialAmount = stakeAmount > 0 ? cumulativeAmount % stakeAmount : 0;
  const totalDeposits = selectedTontineCalendar.value?.deposits.length || 0;
  const remainingAmount = cycle ? Math.max(cycle.targetAmount - cumulativeAmount, 0) : 0;

  return {
    paidCells,
    partialAmount,
    totalDeposits,
    remainingAmount,
    cumulativeAmount,
    targetAmount: cycle?.targetAmount || 0,
    progress: cycle?.progress || 0,
  };
});

const totalPages = computed(() => Math.max(1, Math.ceil(pagination.value.total / pagination.value.pageSize)));

function isEditableTontineCycle(cycle: TontineCycleItem) {
  return ["nonConfiguree", "active"].includes(cycle.status) && cycle.cumulativeAmount <= 0;
}

function canCloseTontineCycle(cycle: TontineCycleItem) {
  return ["active", "enAttenteValidationFin"].includes(cycle.status) && cycle.cumulativeAmount > 0;
}

function getTontineActionClasses(cycle: TontineCycleItem, action: "edit" | "close" | "lock") {
  if (action === "edit") {
    return "inline-flex h-9 w-9 items-center justify-center rounded-lg border border-amber-200 bg-amber-50 text-amber-700 transition hover:bg-amber-100 disabled:cursor-not-allowed disabled:opacity-50";
  }

  if (action === "close") {
    return cycle.status === "enAttenteValidationFin"
      ? "inline-flex h-9 w-9 items-center justify-center rounded-lg border border-emerald-200 bg-emerald-50 text-emerald-700 transition hover:bg-emerald-100 disabled:cursor-not-allowed disabled:opacity-50"
      : "inline-flex h-9 w-9 items-center justify-center rounded-lg border border-rose-200 bg-rose-50 text-rose-700 transition hover:bg-rose-100 disabled:cursor-not-allowed disabled:opacity-50";
  }

  return "inline-flex h-9 w-9 items-center justify-center rounded-lg border border-border bg-muted text-muted-foreground";
}

function getCloseTontineActionLabel(cycle: TontineCycleItem) {
  return cycle.status === "enAttenteValidationFin"
    ? "Confirmer la cloture"
    : "Cloturer la tontine";
}

function getCardCellClasses(status: CardCellStatus) {
  switch (status) {
    case "paid":
      return "bg-emerald-200 text-emerald-900";
    case "partial":
      return "bg-amber-200 text-amber-900";
    default:
      return "bg-white text-slate-900";
  }
}

function buildCardCells(calendar: TontineCycleCalendar | null): CardCellItem[] {
  if (!calendar) {
    return [];
  }

  const stakeAmount = Number(calendar.cycle.stakeAmount || 0);
  const cumulativeAmount = Number(calendar.cycle.cumulativeAmount || 0);
  const fullCells = stakeAmount > 0 ? Math.min(31, Math.floor(cumulativeAmount / stakeAmount)) : 0;
  const partialAmount = stakeAmount > 0 ? cumulativeAmount % stakeAmount : 0;

  return Array.from({ length: 31 }, (_, index) => {
    const cellNumber = index + 1;

    if (cellNumber <= fullCells) {
      return {
        cellNumber,
        status: "paid" as const,
        filledAmount: stakeAmount,
        isPartial: false,
      };
    }

    if (cellNumber === fullCells + 1 && partialAmount > 0 && fullCells < 31) {
      return {
        cellNumber,
        status: "partial" as const,
        filledAmount: partialAmount,
        isPartial: true,
      };
    }

    return {
      cellNumber,
      status: "remaining" as const,
      filledAmount: 0,
      isPartial: false,
    };
  });
}

async function fetchTontines(page = currentPage.value) {
  errorMessage.value = "";
  currentPage.value = page;
  try {
    await tontineStore.fetchTontines({
      page: currentPage.value,
      pageSize,
      search: filters.search || undefined,
      status: filters.status || undefined,
    });
  } catch (error) {
    errorMessage.value = getErrorMessage(error, "Chargement des tontines impossible.");
  }
}

function closeTontineCalendar() {
  calendarDialogOpen.value = false;
  calendarLoadingId.value = null;
  calendarError.value = "";
  selectedTontinePreview.value = null;
  selectedTontineCalendar.value = null;
}

function setTontineCalendarOpen(value: boolean) {
  if (value) {
    calendarDialogOpen.value = true;
    return;
  }

  closeTontineCalendar();
}

function openCycleEditDialog(cycle: TontineCycleItem) {
  editingCycleId.value = cycle.id;
  editingCycleLabel.value = cycle.client.displayName;
  cycleEditForm.stakeAmount = cycle.stakeAmount;
  cycleEditError.value = "";
  cycleEditDialogOpen.value = true;
}

function closeCycleEditDialog() {
  if (isUpdatingCycle.value) {
    return;
  }

  cycleEditDialogOpen.value = false;
  editingCycleId.value = null;
  editingCycleLabel.value = "";
  cycleEditError.value = "";
  cycleEditForm.stakeAmount = null;
}

function setCycleEditDialogOpen(value: boolean) {
  if (value) {
    cycleEditDialogOpen.value = true;
    return;
  }

  closeCycleEditDialog();
}

async function openTontineCalendar(tontine: TontineCycleItem) {
  const requestedId = tontine.id;
  selectedTontinePreview.value = tontine;
  selectedTontineCalendar.value = null;
  calendarError.value = "";
  calendarDialogOpen.value = true;
  calendarLoadingId.value = requestedId;

  try {
    const result = await tontineService.getCalendar(requestedId);
    if (calendarLoadingId.value === requestedId) {
      selectedTontineCalendar.value = result;
    }
  } catch (error) {
    if (calendarLoadingId.value === requestedId) {
      calendarError.value = getErrorMessage(error, "Chargement de la carte impossible.");
    }
  } finally {
    if (calendarLoadingId.value === requestedId) {
      calendarLoadingId.value = null;
    }
  }
}

async function handleUpdateCycle() {
  if (isUpdatingCycle.value) return;

  const cycleId = editingCycleId.value;
  const stakeAmount = Number(cycleEditForm.stakeAmount);

  if (!cycleId) {
    cycleEditError.value = "Selectionnez un cycle valide.";
    return;
  }
  if (
    !stakeAmount ||
    stakeAmount <= 0 ||
    stakeAmount % FINANCIAL_AMOUNT_STEP !== 0
  ) {
    cycleEditError.value = `La mise doit etre un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`;
    return;
  }

  cycleEditError.value = "";
  isUpdatingCycle.value = true;

  try {
    const updatedCycle = await tontineStore.updateTontineCycle(cycleId, {
      stakeAmount,
    });

    if (calendarDialogOpen.value && selectedTontinePreview.value?.id === cycleId) {
      await openTontineCalendar(updatedCycle);
    } else if (selectedTontinePreview.value?.id === cycleId) {
      selectedTontinePreview.value = {
        ...selectedTontinePreview.value,
        ...updatedCycle,
      };
    }

    closeCycleEditDialog();
    await fetchTontines(currentPage.value);
  } catch (error) {
    cycleEditError.value = getErrorMessage(error, "Mise a jour du cycle impossible.");
  } finally {
    isUpdatingCycle.value = false;
  }
}

async function handleCloseTontineCycle(cycle: TontineCycleItem) {
  if (closingCycleId.value || tontineStore.isLoading || !canCloseTontineCycle(cycle)) {
    return;
  }

  const confirmMessage =
    cycle.status === "enAttenteValidationFin"
      ? `Confirmer le reversement et cloturer la tontine de ${cycle.client.displayName} ?`
      : `Cloturer de facon anticipee la tontine de ${cycle.client.displayName} ? Les regles de penalite existantes s'appliqueront.`;

  if (!window.confirm(confirmMessage)) {
    return;
  }

  closingCycleId.value = cycle.id;
  try {
    await tontineStore.closeTontineCycle(cycle.id);

    if (calendarDialogOpen.value && selectedTontinePreview.value?.id === cycle.id) {
      closeTontineCalendar();
    }

    await fetchTontines(currentPage.value);
  } catch (error) {
    window.alert(getErrorMessage(error, "Cloture du cycle impossible."));
  } finally {
    closingCycleId.value = null;
  }
}

function getStatusClass(status: string) {
  switch (status) {
    case 'active':
      return 'bg-emerald-100 text-emerald-700';
    case 'enAttenteValidationFin':
      return 'bg-amber-100 text-amber-700';
    case 'terminee':
      return 'bg-blue-100 text-blue-700';
    case 'arretee':
      return 'bg-red-100 text-red-700';
    default:
      return 'bg-muted text-muted-foreground';
  }
}

function getStatusLabel(status: string) {
  switch (status) {
    case 'active':
      return 'Active';
    case 'enAttenteValidationFin':
      return 'En attente reversement';
    case 'terminee':
      return 'Terminee';
    case 'arretee':
      return 'Arretee';
    default:
      return status;
  }
}

onMounted(fetchTontines);
</script>

<template>
  <Card class="border border-border/60">
    <div class="p-6">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 class="text-xl font-semibold">Gestion des Tontines</h2>
          <p class="text-sm text-muted-foreground">Liste globale des cycles de tontine, suivi des cumuls et progression.</p>
        </div>
        <RouterLink
          to="/clients"
          class="rounded-xl border border-sky-200 bg-sky-50 px-4 py-2 text-sm font-medium text-sky-700 transition hover:bg-sky-100"
        >
          Ouvrir depuis Clients
        </RouterLink>
      </div>

      <div class="mt-6 flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-1 flex-wrap items-center gap-3">
          <input
            v-model="filters.search"
            type="text"
            placeholder="Nom ou telephone client"
            class="h-10 min-w-[240px] rounded-xl border border-border bg-background px-3 text-sm"
            @keyup.enter="fetchTontines(1)"
          />
          <select
            v-model="filters.status"
            class="h-10 min-w-[170px] rounded-xl border border-border bg-background px-3 text-sm"
          >
            <option value="">Tous statuts</option>
            <option value="active">Active</option>
            <option value="enAttenteValidationFin">En attente reversement</option>
            <option value="terminee">Terminee</option>
            <option value="arretee">Arretee</option>
          </select>
          <button
            class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
            @click="fetchTontines(1)"
          >
            Filtrer
          </button>
        </div>
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          @click="fetchTontines(currentPage)"
        >
          Rafraichir
        </button>
      </div>

      <div v-if="errorMessage" class="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {{ errorMessage }}
      </div>
      
      <div v-if="tontineStore.isLoading && !tontines.length" class="mt-6 text-sm text-muted-foreground">
        Chargement des tontines...
      </div>
      
      <div v-else class="mt-6 overflow-auto">
        <table class="w-full min-w-[1000px] text-sm">
          <thead>
            <tr class="border-b text-muted-foreground">
              <th class="px-3 py-3 text-left font-medium">Client</th>
              <th class="px-3 py-3 text-left font-medium">Mise</th>
              <th class="px-3 py-3 text-left font-medium">Cumul actuel</th>
              <th class="px-3 py-3 text-left font-medium">Progression</th>
              <th class="px-3 py-3 text-left font-medium">Statut</th>
              <th class="px-3 py-3 text-left font-medium">Debut</th>
              <th class="px-3 py-3 text-left font-medium">Fin prevue</th>
              <th class="px-3 py-3 text-left font-medium">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="tontine in tontines" :key="tontine.id" class="border-b transition-colors hover:bg-muted/30">
              <td class="px-3 py-3">
                <div class="font-medium">{{ tontine.client.displayName }}</div>
                <div class="text-xs text-muted-foreground">{{ tontine.client.phoneNumber || "Non renseigne" }}</div>
              </td>
              <td class="px-3 py-3 font-medium text-sky-700">{{ formatCurrency(tontine.stakeAmount) }} F</td>
              <td class="px-3 py-3">
                <div class="font-medium">{{ formatCurrency(tontine.cumulativeAmount) }} F</div>
                <div class="text-[10px] text-muted-foreground">Objectif: {{ formatCurrency(tontine.targetAmount) }} F</div>
              </td>
              <td class="px-3 py-3">
                <div class="space-y-2">
                  <div class="flex w-32 items-center gap-2">
                    <div class="h-1.5 flex-1 overflow-hidden rounded-full bg-muted">
                      <div
                        class="h-full bg-sky-500 transition-all duration-500"
                        :style="{ width: `${tontine.progress * 100}%` }"
                      ></div>
                    </div>
                    <span class="text-[10px] font-medium">{{ Math.round(tontine.progress * 100) }}%</span>
                  </div>
                  <button
                    type="button"
                    class="rounded-lg border border-sky-200 bg-sky-50 px-3 py-1.5 text-[11px] font-medium text-sky-700 transition hover:bg-sky-100 disabled:cursor-not-allowed disabled:opacity-50"
                    :disabled="calendarLoadingId === tontine.id"
                    @click="openTontineCalendar(tontine)"
                  >
                    <span v-if="calendarLoadingId === tontine.id">Chargement...</span>
                    <span v-else>Carte 31 jours</span>
                  </button>
                </div>
              </td>
              <td class="px-3 py-3">
                <span
                  class="rounded-full px-2.5 py-1 text-xs font-medium"
                  :class="getStatusClass(tontine.status)"
                >
                  {{ getStatusLabel(tontine.status) }}
                </span>
              </td>
              <td class="px-3 py-3 text-muted-foreground">{{ formatDateTime(tontine.startedAt) }}</td>
              <td class="px-3 py-3 text-muted-foreground">{{ formatDateTime(tontine.expectedEndAt) }}</td>
              <td class="px-3 py-3">
                <div class="flex flex-wrap gap-2">
                  <button
                    v-if="isEditableTontineCycle(tontine)"
                    type="button"
                    :class="getTontineActionClasses(tontine, 'edit')"
                    @click="openCycleEditDialog(tontine)"
                    :title="'Modifier le cycle'"
                    :aria-label="'Modifier le cycle'"
                  >
                    <PencilLine class="h-4 w-4" />
                    <span class="sr-only">Modifier le cycle</span>
                  </button>
                  <button
                    v-else-if="canCloseTontineCycle(tontine)"
                    type="button"
                    :class="getTontineActionClasses(tontine, 'close')"
                    :disabled="closingCycleId === tontine.id || tontineStore.isLoading"
                    @click="handleCloseTontineCycle(tontine)"
                    :title="getCloseTontineActionLabel(tontine)"
                    :aria-label="getCloseTontineActionLabel(tontine)"
                  >
                    <Loader2
                      v-if="closingCycleId === tontine.id"
                      class="h-4 w-4 animate-spin"
                    />
                    <CheckCircle2 v-else-if="tontine.status === 'enAttenteValidationFin'" class="h-4 w-4" />
                    <Ban v-else class="h-4 w-4" />
                    <span class="sr-only">{{ getCloseTontineActionLabel(tontine) }}</span>
                  </button>
                  <button
                    v-else
                    type="button"
                    :class="getTontineActionClasses(tontine, 'lock')"
                    disabled
                    title="Ce cycle est verrouille"
                    aria-label="Ce cycle est verrouille"
                  >
                    <Lock class="h-4 w-4" />
                    <span class="sr-only">Ce cycle est verrouille</span>
                  </button>
                </div>
              </td>
            </tr>
            <tr v-if="!tontines.length && !tontineStore.isLoading">
              <td colspan="8" class="px-3 py-12 text-center text-sm text-muted-foreground">
                Aucune tontine trouvee.
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="mt-4 flex flex-wrap items-center justify-between gap-3 text-sm">
        <p class="text-muted-foreground">
          Page {{ pagination.page }} / {{ totalPages }} - {{ pagination.total }} tontines
        </p>
        <div class="flex items-center gap-2">
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="pagination.page <= 1 || tontineStore.isLoading"
            @click="fetchTontines(pagination.page - 1)"
          >
            Precedent
          </button>
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="pagination.page >= totalPages || tontineStore.isLoading"
            @click="fetchTontines(pagination.page + 1)"
          >
            Suivant
          </button>
        </div>
      </div>
    </div>
  </Card>

  <Dialog :open="cycleEditDialogOpen" @update:open="setCycleEditDialogOpen">
    <DialogContent
      class="sm:max-w-[520px]"
      @interact-outside.prevent
      @escape-key-down.prevent
    >
      <DialogHeader>
        <div class="flex items-center justify-between">
          <DialogTitle>Modifier le cycle</DialogTitle>
          <DialogClose class="rounded-lg p-1 opacity-70 transition hover:bg-muted hover:opacity-100">
            <X class="h-4 w-4" />
            <span class="sr-only">Fermer</span>
          </DialogClose>
        </div>
        <DialogDescription>
          <span v-if="editingCycleLabel">Client: {{ editingCycleLabel }}</span>
          <span v-else>Cycle selectionne.</span>
          <span class="block">Seuls les cycles sans cotisation recue peuvent etre modifies.</span>
        </DialogDescription>
      </DialogHeader>

      <div v-if="cycleEditError" class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {{ cycleEditError }}
      </div>

      <div class="grid gap-4 py-4">
        <div class="grid gap-2">
          <label for="stakeAmountEdit" class="text-sm font-medium">Mise journaliere (F CFA)</label>
          <input
            id="stakeAmountEdit"
            v-model.number="cycleEditForm.stakeAmount"
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
          :disabled="isUpdatingCycle"
          @click="closeCycleEditDialog"
        >
          Annuler
        </button>
        <button
          class="rounded-xl bg-amber-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-amber-700 disabled:opacity-50"
          :disabled="isUpdatingCycle"
          @click="handleUpdateCycle"
        >
          <span v-if="isUpdatingCycle">Mise a jour...</span>
          <span v-else>Enregistrer les modifications</span>
        </button>
      </DialogFooter>
    </DialogContent>
  </Dialog>

  <Dialog :open="calendarDialogOpen" @update:open="setTontineCalendarOpen">
    <DialogContent
      class="sm:max-w-[1120px] !flex !flex-col h-[90vh] overflow-hidden"
      @interact-outside.prevent
      @escape-key-down.prevent
    >
      <DialogHeader class="relative shrink-0 border-b border-border/60 pb-4 pr-10">
        <DialogTitle>Carte de tontine - 31 cases</DialogTitle>
        <DialogDescription>
          <span v-if="calendarCycle">
            {{ calendarCycle.client.displayName }} - {{ formatCurrency(calendarCycle.stakeAmount) }} F par cellule
          </span>
          <span v-else>Chargement de la carte.</span>
        </DialogDescription>
        <DialogClose class="absolute right-0 top-0 rounded-lg p-2 opacity-70 transition hover:bg-muted hover:opacity-100">
          <X class="h-4 w-4" />
          <span class="sr-only">Fermer</span>
        </DialogClose>
      </DialogHeader>

      <div class="min-h-0 flex-1 overflow-y-auto pr-2">
        <div
          v-if="calendarError"
          class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
        >
          {{ calendarError }}
        </div>
        <div v-else-if="!calendarCycle || calendarLoadingId" class="text-sm text-muted-foreground">
          Chargement de la carte 31 jours...
        </div>
        <div v-else class="space-y-6">
          <div class="grid gap-4 md:grid-cols-4">
            <div class="rounded-2xl border border-border bg-muted/30 p-4">
              <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Cellules payees</p>
              <p class="mt-2 text-2xl font-semibold">{{ calendarSummary.paidCells }}/31</p>
            </div>
            <div class="rounded-2xl border border-border bg-muted/30 p-4">
              <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Cumul</p>
              <p class="mt-2 text-2xl font-semibold">{{ formatCurrency(calendarSummary.cumulativeAmount) }} F</p>
            </div>
            <div class="rounded-2xl border border-border bg-muted/30 p-4">
              <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Reste</p>
              <p class="mt-2 text-2xl font-semibold">{{ formatCurrency(calendarSummary.remainingAmount) }} F</p>
            </div>
            <div class="rounded-2xl border border-border bg-muted/30 p-4">
              <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Statut</p>
              <p class="mt-2 text-2xl font-semibold">{{ getStatusLabel(calendarCycle.status) }}</p>
            </div>
          </div>

          <div class="grid gap-3 rounded-2xl border border-border/60 bg-muted/20 p-4 text-sm sm:grid-cols-2 lg:grid-cols-4">
            <div>
              <p class="text-xs uppercase tracking-[0.18em] text-muted-foreground">Client</p>
              <p class="mt-1 font-medium">{{ calendarCycle.client.displayName }}</p>
              <p class="text-xs text-muted-foreground">{{ calendarCycle.client.phoneNumber || "Non renseigne" }}</p>
            </div>
            <div>
              <p class="text-xs uppercase tracking-[0.18em] text-muted-foreground">Mise par cellule</p>
              <p class="mt-1 font-medium">{{ formatCurrency(calendarCycle.stakeAmount) }} F</p>
            </div>
            <div>
              <p class="text-xs uppercase tracking-[0.18em] text-muted-foreground">Versements</p>
              <p class="mt-1 font-medium">{{ calendarSummary.totalDeposits }}</p>
            </div>
            <div>
              <p class="text-xs uppercase tracking-[0.18em] text-muted-foreground">Partiel</p>
              <p class="mt-1 font-medium">
                <span v-if="calendarSummary.partialAmount > 0">{{ formatCurrency(calendarSummary.partialAmount) }} F</span>
                <span v-else>Aucun</span>
              </p>
            </div>
          </div>

          <div class="rounded-2xl border border-black bg-black p-px shadow-sm">
            <div class="grid grid-cols-7 gap-px bg-black">
              <div
                v-for="cell in calendarDays"
                :key="cell.cellNumber"
                class="flex aspect-square items-center justify-center text-lg font-semibold sm:text-xl"
                :class="getCardCellClasses(cell.status)"
                :title="cell.status === 'paid' ? `Cellule payee` : cell.status === 'partial' ? `Cellule partiellement payee` : `Cellule disponible`"
              >
                {{ cell.cellNumber }}
              </div>
            </div>
          </div>

          <div class="flex flex-wrap gap-2 text-xs">
            <span class="rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 font-medium text-emerald-700">Payee</span>
            <span class="rounded-full border border-amber-200 bg-amber-50 px-3 py-1 font-medium text-amber-700">Partielle</span>
            <span class="rounded-full border border-slate-200 bg-white px-3 py-1 font-medium text-slate-700">Disponible</span>
          </div>
        </div>
      </div>

      <DialogFooter class="shrink-0 border-t border-border/60 pt-4">
        <button
          type="button"
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          @click="closeTontineCalendar"
        >
          Fermer
        </button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
