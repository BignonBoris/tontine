<script setup lang="ts">
import { computed, onMounted, reactive, ref } from "vue";
import { RefreshCcw, Search } from "lucide-vue-next";
import Card from "@/components/ui/card/Card.vue";
import { useRecoveryStore } from "@/stores/recovery";
import { getErrorMessage } from "@/services/http/errors";
import type { RecoveryCycleItem } from "@/types/platform";
import { formatCurrency, formatDateTime } from "@/utils/formatters";

const recoveryStore = useRecoveryStore();
const recoveries = computed(() => recoveryStore.collection?.items || []);
const pagination = computed(
  () => recoveryStore.collection?.pagination || { page: 1, pageSize: 20, total: 0 },
);
const totals = computed(
  () =>
    recoveryStore.collection?.totals || {
      overdueCycles: 0,
      overdueClients: 0,
      totalExpectedAmount: 0,
      totalLateAmount: 0,
      totalLateDays: 0,
    },
);

const filters = reactive({
  search: "",
});

const currentPage = ref(1);
const pageSize = 20;
const errorMessage = ref("");

const totalPages = computed(() =>
  Math.max(1, Math.ceil(pagination.value.total / pagination.value.pageSize)),
);

const kpiCards = computed(() => [
  {
    label: "Cycles en retard",
    value: `${totals.value.overdueCycles}`,
    hint: "Cycles actifs suivis par le recouvrement.",
  },
  {
    label: "Clients concernes",
    value: `${totals.value.overdueClients}`,
    hint: "Clients distincts avec retard detecte.",
  },
  {
    label: "Montant attendu",
    value: `${formatCurrency(totals.value.totalExpectedAmount)} F`,
    hint: "Montant cumule attendu a date.",
  },
  {
    label: "Retard cumule",
    value: `${formatCurrency(totals.value.totalLateAmount)} F`,
    hint: `${totals.value.totalLateDays} jours de retard cumules`,
  },
]);

async function fetchRecovery(page = currentPage.value) {
  errorMessage.value = "";
  currentPage.value = page;

  try {
    await recoveryStore.fetchRecoveryCycles({
      page: currentPage.value,
      pageSize,
      search: filters.search.trim() || undefined,
    });
  } catch (error) {
    errorMessage.value = getErrorMessage(
      error,
      "Chargement du recouvrement impossible.",
    );
  }
}

function getLateSeverityClass(lateDays: number) {
  if (lateDays >= 6) {
    return "bg-red-100 text-red-700";
  }

  if (lateDays >= 3) {
    return "bg-orange-100 text-orange-700";
  }

  return "bg-amber-100 text-amber-700";
}

function getCycleStatusClass(status: string) {
  switch (status) {
    case "active":
      return "bg-sky-100 text-sky-700";
    case "enAttenteValidationFin":
      return "bg-amber-100 text-amber-700";
    case "terminee":
      return "bg-blue-100 text-blue-700";
    case "arretee":
      return "bg-red-100 text-red-700";
    default:
      return "bg-muted text-muted-foreground";
  }
}

function getCycleStatusLabel(status: string) {
  switch (status) {
    case "active":
      return "Active";
    case "enAttenteValidationFin":
      return "En attente reversement";
    case "terminee":
      return "Terminee";
    case "arretee":
      return "Arretee";
    default:
      return status;
  }
}

function getAgentLabel(cycle: RecoveryCycleItem) {
  if (!cycle.client.createdByAgent) {
    return "Non affecte";
  }

  return cycle.client.createdByAgent.fullName;
}

onMounted(() => {
  void fetchRecovery(1);
});
</script>

<template>
  <Card class="border border-border/60">
    <div class="p-6">
      <PageHeader
        title="Recouvrement"
        description="Cycles en cours avec retard de cotisation, calcules en jours calendaires depuis le debut du cycle."
      />

      <div class="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <div
          v-for="card in kpiCards"
          :key="card.label"
          class="rounded-2xl border border-border/60 bg-muted/20 p-4"
        >
          <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">
            {{ card.label }}
          </p>
          <p class="mt-2 text-2xl font-semibold">{{ card.value }}</p>
          <p class="mt-2 text-xs text-muted-foreground">{{ card.hint }}</p>
        </div>
      </div>

      <div class="mt-4 text-xs text-muted-foreground">
        Jours de retard cumules: {{ totals.totalLateDays }}
      </div>

      <div class="mt-6 flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <div class="flex min-w-0 flex-1 flex-col gap-3 sm:flex-row sm:items-center">
          <div class="relative w-full min-w-0 sm:flex-1">
            <input
              v-model="filters.search"
              type="text"
              placeholder="Nom ou telephone client"
              class="h-10 w-full min-w-0 rounded-xl border border-border bg-background pl-3 pr-10 text-sm"
              @keyup.enter="fetchRecovery(1)"
            />
            <Search class="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          </div>
          <button
            class="w-full rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted sm:w-auto"
            @click="fetchRecovery(1)"
          >
            Filtrer
          </button>
        </div>
        <button
          class="inline-flex w-full items-center justify-center gap-2 rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted disabled:opacity-50 sm:w-auto"
          :disabled="recoveryStore.isLoading"
          @click="fetchRecovery(currentPage)"
        >
          <RefreshCcw class="h-4 w-4" />
          Rafraichir
        </button>
      </div>

      <div
        v-if="errorMessage"
        class="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
      >
        {{ errorMessage }}
      </div>

      <div
        v-if="recoveryStore.isLoading && !recoveries.length"
        class="mt-6 text-sm text-muted-foreground"
      >
        Chargement des cycles en retard...
      </div>

      <div v-else class="mt-6 space-y-4">
        <div class="grid gap-4 xl:hidden">
          <article
            v-for="cycle in recoveries"
            :key="cycle.id"
            class="rounded-2xl border border-border/60 bg-background p-4 shadow-sm"
          >
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div class="min-w-0">
                <div class="break-words font-medium">
                  {{ cycle.client.displayName }}
                </div>
                <div class="text-xs text-muted-foreground">
                  {{ cycle.client.phoneNumber || "Non renseigne" }}
                </div>
              </div>
              <span
                class="shrink-0 rounded-full px-2.5 py-1 text-xs font-medium"
                :class="getCycleStatusClass(cycle.status)"
              >
                {{ getCycleStatusLabel(cycle.status) }}
              </span>
            </div>

            <div class="mt-4 grid gap-3 sm:grid-cols-2">
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">Agent</p>
                <p class="mt-1 break-words text-sm font-medium">{{ getAgentLabel(cycle) }}</p>
                <p v-if="cycle.client.createdByAgent" class="text-xs text-muted-foreground">
                  {{ cycle.client.createdByAgent.agentCode }}
                </p>
              </div>
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">Debut</p>
                <p class="mt-1 text-sm font-medium">{{ formatDateTime(cycle.startedAt) }}</p>
              </div>
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">Jours ecoules</p>
                <p class="mt-1 text-sm font-medium">
                  {{ cycle.daysElapsed }} jours
                </p>
                <p class="text-xs text-muted-foreground">
                  Couverts: {{ cycle.coveredDays }} jours
                </p>
              </div>
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">Mise</p>
                <p class="mt-1 text-sm font-medium text-sky-700">
                  {{ formatCurrency(cycle.stakeAmount) }} F
                </p>
              </div>
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">Cumule</p>
                <p class="mt-1 text-sm font-medium">
                  {{ formatCurrency(cycle.cumulativeAmount) }} F
                </p>
                <p class="text-xs text-muted-foreground">
                  Cible: {{ formatCurrency(cycle.targetAmount) }} F
                </p>
              </div>
              <div class="rounded-xl border border-border/60 p-3">
                <p class="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">Attendu a date</p>
                <p class="mt-1 text-sm font-medium">
                  {{ formatCurrency(cycle.expectedAmount) }} F
                </p>
                <p class="text-xs text-muted-foreground">
                  Progression: {{ Math.round(cycle.progress * 100) }}%
                </p>
              </div>
              <div class="rounded-xl border border-border/60 p-3 sm:col-span-2">
                <p class="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">Retard</p>
                <div class="mt-1 flex flex-wrap items-center gap-2">
                  <span class="text-sm font-medium text-red-700">
                    {{ formatCurrency(cycle.lateAmount) }} F
                  </span>
                  <span
                    class="rounded-full px-2.5 py-1 text-xs font-medium"
                    :class="getLateSeverityClass(cycle.lateDays)"
                  >
                    J+{{ cycle.lateDays }}
                  </span>
                </div>
              </div>
            </div>
          </article>

          <div
            v-if="!recoveries.length && !recoveryStore.isLoading"
            class="rounded-2xl border border-dashed border-border/60 bg-muted/20 px-4 py-12 text-center text-sm text-muted-foreground"
          >
            Aucun cycle en retard trouve.
          </div>
        </div>

        <div class="hidden xl:block">
          <div class="overflow-hidden rounded-2xl border border-border/60 bg-background">
            <table class="w-full table-fixed text-sm">
          <thead>
            <tr class="border-b text-muted-foreground">
              <th class="px-3 py-3 text-left font-medium">Client</th>
              <th class="px-3 py-3 text-left font-medium">Agent</th>
              <th class="px-3 py-3 text-left font-medium">Debut</th>
              <th class="px-3 py-3 text-left font-medium">Jours ecoules</th>
              <th class="px-3 py-3 text-left font-medium">Mise</th>
              <th class="px-3 py-3 text-left font-medium">Cumule</th>
              <th class="px-3 py-3 text-left font-medium">Attendu a date</th>
              <th class="px-3 py-3 text-left font-medium">Retard</th>
              <th class="px-3 py-3 text-left font-medium">Statut</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="cycle in recoveries"
              :key="cycle.id"
              class="border-b transition-colors hover:bg-muted/30"
            >
              <td class="px-3 py-3 align-top break-words">
                <div class="font-medium">{{ cycle.client.displayName }}</div>
                <div class="text-xs text-muted-foreground">
                  {{ cycle.client.phoneNumber || "Non renseigne" }}
                </div>
              </td>
              <td class="px-3 py-3 align-top break-words">
                <div class="font-medium">{{ getAgentLabel(cycle) }}</div>
                <div
                  v-if="cycle.client.createdByAgent"
                  class="text-xs text-muted-foreground"
                >
                  {{ cycle.client.createdByAgent.agentCode }}
                </div>
                <div v-else class="text-xs text-muted-foreground">
                  Aucun portefeuille agent
                </div>
              </td>
              <td class="px-3 py-3 align-top text-muted-foreground">
                {{ formatDateTime(cycle.startedAt) }}
              </td>
              <td class="px-3 py-3 align-top">
                <div class="font-medium">{{ cycle.daysElapsed }} jours</div>
                <div class="text-xs text-muted-foreground">
                  Couverts: {{ cycle.coveredDays }} jours
                </div>
              </td>
              <td class="px-3 py-3 align-top font-medium text-sky-700">
                {{ formatCurrency(cycle.stakeAmount) }} F
              </td>
              <td class="px-3 py-3 align-top">
                <div class="font-medium">{{ formatCurrency(cycle.cumulativeAmount) }} F</div>
                <div class="text-xs text-muted-foreground">
                  Cible: {{ formatCurrency(cycle.targetAmount) }} F
                </div>
              </td>
              <td class="px-3 py-3 align-top">
                <div class="font-medium">{{ formatCurrency(cycle.expectedAmount) }} F</div>
                <div class="text-xs text-muted-foreground">
                  Progression: {{ Math.round(cycle.progress * 100) }}%
                </div>
              </td>
              <td class="px-3 py-3 align-top">
                <div class="font-medium text-red-700">
                  {{ formatCurrency(cycle.lateAmount) }} F
                </div>
                <span
                  class="mt-2 inline-flex rounded-full px-2.5 py-1 text-xs font-medium"
                  :class="getLateSeverityClass(cycle.lateDays)"
                >
                  J+{{ cycle.lateDays }}
                </span>
              </td>
              <td class="px-3 py-3 align-top">
                <span
                  class="rounded-full px-2.5 py-1 text-xs font-medium"
                  :class="getCycleStatusClass(cycle.status)"
                >
                  {{ getCycleStatusLabel(cycle.status) }}
                </span>
              </td>
            </tr>
            <tr v-if="!recoveries.length && !recoveryStore.isLoading">
              <td colspan="9" class="px-3 py-12 text-center text-sm text-muted-foreground">
                Aucun cycle en retard trouve.
              </td>
            </tr>
          </tbody>
            </table>
          </div>
        </div>
      </div>

      <div class="mt-4 flex flex-wrap items-center justify-between gap-3 text-sm">
        <p class="text-muted-foreground">
          Page {{ pagination.page }} / {{ totalPages }} - {{ pagination.total }} cycles
        </p>
        <div class="flex items-center gap-2">
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="pagination.page <= 1 || recoveryStore.isLoading"
            @click="fetchRecovery(pagination.page - 1)"
          >
            Precedent
          </button>
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="pagination.page >= totalPages || recoveryStore.isLoading"
            @click="fetchRecovery(pagination.page + 1)"
          >
            Suivant
          </button>
        </div>
      </div>
    </div>
  </Card>
</template>
