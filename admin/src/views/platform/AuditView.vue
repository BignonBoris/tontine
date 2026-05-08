<script setup lang="ts">
import { computed, onMounted, reactive, ref } from "vue";
import Card from "@/components/ui/card/Card.vue";
import { useAuditStore } from "@/stores/audit";
import { getErrorMessage } from "@/services/http/errors";
import { formatDateTime } from "@/utils/formatters";

const auditStore = useAuditStore();
const logs = computed(() => auditStore.collection?.items || []);
const pagination = computed(() => auditStore.collection?.pagination || { page: 1, pageSize: 20, total: 0 });
const filters = reactive({
  search: "",
  action: "",
});
const currentPage = ref(1);
const pageSize = 20;
const errorMessage = ref("");

const totalPages = computed(() => Math.max(1, Math.ceil(pagination.value.total / pagination.value.pageSize)));
const summary = computed(() => {
  const uniqueActions = new Set(logs.value.map((log) => log.action)).size;
  const failedLogs = logs.value.filter((log) => log.status && log.status !== "success").length;
  return {
    total: pagination.value.total,
    uniqueActions,
    failedLogs,
  };
});

async function fetchAuditLogs(page = currentPage.value) {
  errorMessage.value = "";
  currentPage.value = page;
  try {
    await auditStore.fetchAuditLogs({
      page: currentPage.value,
      pageSize,
      search: filters.search || undefined,
      action: filters.action || undefined,
    });
  } catch (error) {
    errorMessage.value = getErrorMessage(error, "Chargement des logs d'audit impossible.");
  }
}

onMounted(fetchAuditLogs);
</script>

<template>
  <Card class="border border-border/60">
    <div class="p-6">
      <PageHeader
        title="Audit"
        description="Journal des actions sensibles et de supervision, filtrable par action ou utilisateur."
      />

      <div class="mt-6 grid gap-4 md:grid-cols-3">
        <div class="rounded-2xl border border-border bg-muted/30 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Lignes</p>
          <p class="mt-2 text-2xl font-semibold">{{ summary.total }}</p>
        </div>
        <div class="rounded-2xl border border-violet-200 bg-violet-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-violet-700">Actions distinctes</p>
          <p class="mt-2 text-2xl font-semibold text-violet-700">{{ summary.uniqueActions }}</p>
        </div>
        <div class="rounded-2xl border border-red-200 bg-red-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-red-700">Statuts non success</p>
          <p class="mt-2 text-2xl font-semibold text-red-700">{{ summary.failedLogs }}</p>
        </div>
      </div>

      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-1 flex-wrap items-center gap-3">
          <input
            v-model="filters.search"
            type="text"
            placeholder="Action, entite, utilisateur"
            class="h-10 min-w-[220px] rounded-xl border border-border bg-background px-3 text-sm"
            @keyup.enter="fetchAuditLogs(1)"
          />
          <input
            v-model="filters.action"
            type="text"
            placeholder="Filtrer par action"
            class="h-10 min-w-[220px] rounded-xl border border-border bg-background px-3 text-sm"
            @keyup.enter="fetchAuditLogs(1)"
          />
          <button
            class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
            @click="fetchAuditLogs(1)"
          >
            Filtrer
          </button>
        </div>
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          @click="fetchAuditLogs(currentPage)"
        >
          Rafraichir
        </button>
      </div>

      <div v-if="errorMessage" class="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {{ errorMessage }}
      </div>
      <div v-if="auditStore.isLoading && !logs.length" class="mt-6 text-sm text-muted-foreground">
        Chargement des logs d'audit...
      </div>
      <div v-else class="mt-6 overflow-auto">
        <table class="w-full min-w-[900px] text-sm">
          <thead>
            <tr class="border-b">
              <th class="px-3 py-3 text-left">Action</th>
              <th class="px-3 py-3 text-left">Entite</th>
              <th class="px-3 py-3 text-left">Utilisateur</th>
              <th class="px-3 py-3 text-left">IP</th>
              <th class="px-3 py-3 text-left">Date</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="log in logs" :key="log.id" class="border-b">
              <td class="px-3 py-3 font-medium">{{ log.action }}</td>
              <td class="px-3 py-3">{{ log.entityType }} / {{ log.entityId || "N/A" }}</td>
              <td class="px-3 py-3">{{ log.user?.displayName || "Systeme / admin" }}</td>
              <td class="px-3 py-3">{{ log.ipAddress || "N/A" }}</td>
              <td class="px-3 py-3">{{ formatDateTime(log.createdAt) }}</td>
            </tr>
            <tr v-if="!logs.length && !auditStore.isLoading">
              <td colspan="5" class="px-3 py-8 text-center text-sm text-muted-foreground">
                Aucun log a afficher.
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="mt-4 flex flex-wrap items-center justify-between gap-3 text-sm">
        <p class="text-muted-foreground">
          Page {{ pagination.page }} / {{ totalPages }} · {{ pagination.total }} logs
        </p>
        <div class="flex items-center gap-2">
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="pagination.page <= 1 || auditStore.isLoading"
            @click="fetchAuditLogs(pagination.page - 1)"
          >
            Precedent
          </button>
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="pagination.page >= totalPages || auditStore.isLoading"
            @click="fetchAuditLogs(pagination.page + 1)"
          >
            Suivant
          </button>
        </div>
      </div>
    </div>
  </Card>
</template>
