<script setup lang="ts">
import { computed, onMounted, reactive, ref } from "vue";
import Card from "@/components/ui/card/Card.vue";
import { useAuditStore } from "@/stores/audit";
import { auditService } from "@/services/audit/auditService";
import { getErrorMessage } from "@/services/http/errors";
import { formatDateTime } from "@/utils/formatters";

const auditStore = useAuditStore();
const logs = computed(() => auditStore.collection?.items || []);
const pagination = computed(() => auditStore.collection?.pagination || { page: 1, pageSize: 20, total: 0 });

const filters = reactive({
  search: "",
  action: "",
  status: "",
  dateFrom: "",
  dateTo: "",
});
const currentPage = ref(1);
const pageSize = 20;
const errorMessage = ref("");
const exporting = ref(false);

const totalPages = computed(() =>
  Math.max(1, Math.ceil(pagination.value.total / pagination.value.pageSize))
);

const summary = computed(() => {
  const failedLogs = logs.value.filter((log) => log.status && log.status !== "success").length;
  return {
    total: pagination.value.total,
    failedLogs,
    uniqueActions: new Set(logs.value.map((l) => l.action)).size,
  };
});

const STATUS_OPTIONS = [
  { value: "", label: "Tous les statuts" },
  { value: "success", label: "✅ Succès" },
  { value: "failure", label: "❌ Échec" },
  { value: "suspicious", label: "⚠️ Suspect" },
  { value: "warning", label: "🟡 Avertissement" },
];

function statusBadgeClass(status: string) {
  switch (status) {
    case "success":    return "badge-success";
    case "failure":    return "badge-danger";
    case "suspicious": return "badge-warning";
    case "warning":    return "badge-warning";
    default:           return "badge-default";
  }
}

async function fetchAuditLogs(page = currentPage.value) {
  errorMessage.value = "";
  currentPage.value = page;
  try {
    await auditStore.fetchAuditLogs({
      page: currentPage.value,
      pageSize,
      search: filters.search || undefined,
      action: filters.action || undefined,
      status: filters.status || undefined,
      dateFrom: filters.dateFrom || undefined,
      dateTo: filters.dateTo || undefined,
    });
  } catch (error) {
    errorMessage.value = getErrorMessage(error, "Chargement des logs d'audit impossible.");
  }
}

async function exportCsv() {
  exporting.value = true;
  try {
    await auditService.exportCsv({
      search: filters.search || undefined,
      action: filters.action || undefined,
      status: filters.status || undefined,
      dateFrom: filters.dateFrom || undefined,
      dateTo: filters.dateTo || undefined,
    });
  } catch {
    errorMessage.value = "Export CSV impossible.";
  } finally {
    exporting.value = false;
  }
}

function resetFilters() {
  filters.search = "";
  filters.action = "";
  filters.status = "";
  filters.dateFrom = "";
  filters.dateTo = "";
  fetchAuditLogs(1);
}

onMounted(fetchAuditLogs);
</script>

<template>
  <Card class="border border-border/60">
    <div class="p-6">
      <!-- En-tête -->
      <div class="flex items-start justify-between gap-4">
        <div>
          <h1 class="text-xl font-bold tracking-tight">Journal d'Audit</h1>
          <p class="mt-1 text-sm text-muted-foreground">
            Traçabilité complète des actions sensibles et de supervision.
          </p>
        </div>
        <button
          class="flex items-center gap-2 rounded-xl border border-emerald-300 bg-emerald-50 px-4 py-2 text-sm font-semibold text-emerald-700 transition hover:bg-emerald-100 disabled:opacity-50"
          :disabled="exporting"
          @click="exportCsv"
        >
          <span v-if="exporting">Export…</span>
          <span v-else>⬇ Export CSV</span>
        </button>
      </div>

      <!-- KPI -->
      <div class="mt-6 grid gap-4 sm:grid-cols-3">
        <div class="rounded-2xl border border-border bg-muted/30 p-4">
          <p class="text-xs uppercase tracking-widest text-muted-foreground">Total</p>
          <p class="mt-2 text-2xl font-bold">{{ summary.total.toLocaleString() }}</p>
        </div>
        <div class="rounded-2xl border border-violet-200 bg-violet-50/70 p-4">
          <p class="text-xs uppercase tracking-widest text-violet-600">Actions distinctes</p>
          <p class="mt-2 text-2xl font-bold text-violet-700">{{ summary.uniqueActions }}</p>
        </div>
        <div class="rounded-2xl border border-red-200 bg-red-50/70 p-4">
          <p class="text-xs uppercase tracking-widest text-red-600">Statuts non-succès</p>
          <p class="mt-2 text-2xl font-bold text-red-700">{{ summary.failedLogs }}</p>
        </div>
      </div>

      <!-- Filtres -->
      <div class="mt-6 flex flex-wrap items-end gap-3">
        <div class="flex flex-col gap-1">
          <label class="text-xs text-muted-foreground">Recherche</label>
          <input
            v-model="filters.search"
            type="text"
            placeholder="Action, entité, utilisateur…"
            class="h-9 min-w-[200px] rounded-xl border border-border bg-background px-3 text-sm"
            @keyup.enter="fetchAuditLogs(1)"
          />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-xs text-muted-foreground">Statut</label>
          <select
            v-model="filters.status"
            class="h-9 rounded-xl border border-border bg-background px-3 text-sm"
            @change="fetchAuditLogs(1)"
          >
            <option v-for="opt in STATUS_OPTIONS" :key="opt.value" :value="opt.value">
              {{ opt.label }}
            </option>
          </select>
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-xs text-muted-foreground">Date début</label>
          <input
            v-model="filters.dateFrom"
            type="date"
            class="h-9 rounded-xl border border-border bg-background px-3 text-sm"
          />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-xs text-muted-foreground">Date fin</label>
          <input
            v-model="filters.dateTo"
            type="date"
            class="h-9 rounded-xl border border-border bg-background px-3 text-sm"
          />
        </div>
        <button
          class="h-9 rounded-xl border border-border px-4 text-sm font-medium transition hover:bg-muted"
          @click="fetchAuditLogs(1)"
        >
          Filtrer
        </button>
        <button
          class="h-9 rounded-xl border border-border px-4 text-sm text-muted-foreground transition hover:bg-muted"
          @click="resetFilters"
        >
          Réinitialiser
        </button>
      </div>

      <!-- Erreur -->
      <div
        v-if="errorMessage"
        class="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
      >
        {{ errorMessage }}
      </div>

      <!-- Chargement -->
      <div v-if="auditStore.isLoading && !logs.length" class="mt-10 text-center text-sm text-muted-foreground">
        Chargement…
      </div>

      <!-- Tableau -->
      <div v-else class="mt-6 overflow-auto rounded-xl border border-border">
        <table class="w-full min-w-[900px] text-sm">
          <thead class="bg-muted/40">
            <tr>
              <th class="px-4 py-3 text-left font-semibold">Action</th>
              <th class="px-4 py-3 text-left font-semibold">Entité</th>
              <th class="px-4 py-3 text-left font-semibold">Utilisateur</th>
              <th class="px-4 py-3 text-left font-semibold">Statut</th>
              <th class="px-4 py-3 text-left font-semibold">IP</th>
              <th class="px-4 py-3 text-left font-semibold">Date</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="log in logs"
              :key="log.id"
              class="border-t border-border/50 transition hover:bg-muted/20"
            >
              <td class="px-4 py-3 font-mono text-xs font-semibold">{{ log.action }}</td>
              <td class="px-4 py-3 text-muted-foreground">
                {{ log.entityType }}<span v-if="log.entityId" class="text-xs opacity-60"> / {{ log.entityId }}</span>
              </td>
              <td class="px-4 py-3">
                <div v-if="log.user">
                  <p class="font-medium">{{ log.user.displayName }}</p>
                  <p class="text-xs text-muted-foreground">{{ log.user.phoneNumber }}</p>
                </div>
                <span v-else class="text-xs text-muted-foreground">Système / Admin</span>
              </td>
              <td class="px-4 py-3">
                <span
                  class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold"
                  :class="statusBadgeClass(log.status)"
                >
                  {{ log.status }}
                </span>
              </td>
              <td class="px-4 py-3 font-mono text-xs text-muted-foreground">{{ log.ipAddress || "—" }}</td>
              <td class="px-4 py-3 text-xs text-muted-foreground">{{ formatDateTime(log.createdAt) }}</td>
            </tr>
            <tr v-if="!logs.length && !auditStore.isLoading">
              <td colspan="6" class="px-4 py-12 text-center text-sm text-muted-foreground">
                Aucun log à afficher.
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination -->
      <div class="mt-4 flex flex-wrap items-center justify-between gap-3 text-sm">
        <p class="text-muted-foreground">
          Page {{ pagination.page }} / {{ totalPages }} · {{ pagination.total.toLocaleString() }} logs
        </p>
        <div class="flex items-center gap-2">
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:opacity-40"
            :disabled="pagination.page <= 1 || auditStore.isLoading"
            @click="fetchAuditLogs(pagination.page - 1)"
          >
            ← Précédent
          </button>
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:opacity-40"
            :disabled="pagination.page >= totalPages || auditStore.isLoading"
            @click="fetchAuditLogs(pagination.page + 1)"
          >
            Suivant →
          </button>
        </div>
      </div>
    </div>
  </Card>
</template>

<style scoped>
.badge-success { @apply bg-emerald-100 text-emerald-700; }
.badge-danger  { @apply bg-red-100 text-red-700; }
.badge-warning { @apply bg-amber-100 text-amber-700; }
.badge-default { @apply bg-muted text-muted-foreground; }
</style>
