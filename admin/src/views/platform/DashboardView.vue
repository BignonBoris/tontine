<script setup lang="ts">
import { computed, onMounted } from "vue";
import Card from "@/components/ui/card/Card.vue";
import { useDashboardStore } from "@/stores/dashboard";
import { formatCurrency, formatDateTime } from "@/utils/formatters";

const dashboardStore = useDashboardStore();
const overview = computed(() => dashboardStore.overview);
const anomalies = computed(() => dashboardStore.anomalies);

async function refreshAll() {
  await Promise.all([
    dashboardStore.fetchOverview(),
    dashboardStore.fetchAnomalies(),
  ]);
}

onMounted(async () => {
  if (!dashboardStore.overview || !dashboardStore.anomalies) {
    await refreshAll();
  }
});
</script>

<template>
  <div class="space-y-6">
    <PageHeader
      title="Dashboard"
      description="Vue globale de supervision des clients, des agents, des retraits et des alertes operationnelles."
    />

    <div class="rounded-3xl bg-[radial-gradient(circle_at_top_left,_rgba(16,185,129,0.25),_transparent_30%),linear-gradient(135deg,_#082f2c,_#0f4f4b)] p-8 text-white">
      <div class="flex flex-wrap items-start justify-between gap-6">
        <div>
          <p class="text-xs uppercase tracking-[0.25em] text-white/60">
            VizioBox Admin
          </p>
          <h2 class="mt-3 text-3xl font-semibold">
            Supervision temps reel des flux, agents, retraits et anomalies.
          </h2>
          <p class="mt-3 max-w-2xl text-sm leading-6 text-white/75">
            Le back-office lit l'etat de la plateforme depuis l'API, sans dupliquer la logique metier.
          </p>
        </div>
        <div class="flex items-center gap-3">
          <button
            class="rounded-xl border border-white/15 bg-white/10 px-4 py-2 text-sm font-medium transition hover:bg-white/15"
            @click="refreshAll"
          >
            Rafraichir
          </button>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-12 gap-6">
      <div
        v-for="item in [
          { label: 'Clients actifs', value: `${overview?.totals.activeClients || 0}`, hint: `${overview?.totals.totalClients || 0} clients au total` },
          { label: 'Agents actifs', value: `${overview?.totals.activeAgents || 0}`, hint: `${overview?.totals.totalAgents || 0} agents au total` },
          { label: 'Retraits en attente', value: `${overview?.totals.pendingWithdrawals || 0}`, hint: `${formatCurrency(overview?.totals.totalRequestedWithdrawals || 0)} F demandes` },
          { label: 'Caisse agents', value: `${formatCurrency(overview?.totals.totalAgentBalances || 0)} F`, hint: `${formatCurrency(overview?.totals.totalReservedWithdrawals || 0)} F reserves` },
        ]"
        :key="item.label"
        class="col-span-12 lg:col-span-3"
      >
        <Card class="border border-border/60">
          <div class="p-6">
            <p class="text-sm text-muted-foreground">{{ item.label }}</p>
            <h3 class="mt-3 text-3xl font-semibold">{{ item.value }}</h3>
            <p class="mt-2 text-xs text-muted-foreground">{{ item.hint }}</p>
          </div>
        </Card>
      </div>

      <div class="col-span-12 lg:col-span-7">
        <Card class="border border-border/60">
          <div class="p-6">
            <h3 class="text-lg font-semibold">Nouveaux clients sur 7 jours</h3>
            <p class="text-sm text-muted-foreground">Serie recuperee depuis l'overview admin.</p>
            <div v-if="dashboardStore.isLoading && !overview" class="mt-6 rounded-2xl bg-muted/40 p-8 text-sm text-muted-foreground">
              Chargement des KPI...
            </div>
            <div v-else class="mt-6 flex h-64 items-end gap-4 rounded-2xl bg-muted/40 px-4 pb-4 pt-8">
              <div
                v-for="point in overview?.charts.newClients || []"
                :key="point.label"
                class="flex min-w-0 flex-1 flex-col items-center gap-2"
              >
                <span class="text-xs text-muted-foreground">{{ point.value }}</span>
                <div class="flex h-full w-full items-end">
                  <div
                    class="w-full rounded-t-2xl bg-primary"
                    :style="{ height: `${Math.max(point.value * 16, point.value ? 10 : 0)}px` }"
                  />
                </div>
                <span class="text-xs text-muted-foreground">{{ point.label }}</span>
              </div>
            </div>
          </div>
        </Card>
      </div>

      <div class="col-span-12 lg:col-span-5">
        <Card class="border border-border/60">
          <div class="p-6">
            <h3 class="text-lg font-semibold">Audit recent</h3>
            <p class="text-sm text-muted-foreground">Dernieres actions sensibles tracees.</p>
            <div class="mt-6 space-y-4">
              <div
                v-for="entry in overview?.recentAuditLogs || []"
                :key="entry.id"
                class="rounded-2xl border border-border/60 p-4"
              >
                <div class="flex items-start justify-between gap-4">
                  <div>
                    <p class="font-medium">{{ entry.action }}</p>
                    <p class="text-sm text-muted-foreground">
                      {{ entry.user?.displayName || "Systeme / admin" }}
                    </p>
                  </div>
                  <span class="text-xs text-muted-foreground">
                    {{ formatDateTime(entry.createdAt) }}
                  </span>
                </div>
              </div>
              <div v-if="!overview?.recentAuditLogs?.length && !dashboardStore.isLoading" class="text-sm text-muted-foreground">
                Aucun log recent.
              </div>
            </div>
          </div>
        </Card>
      </div>

      <div class="col-span-12">
        <Card class="border border-border/60">
          <div class="p-6">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <div>
                <h3 class="text-lg font-semibold">Anomalies operationnelles</h3>
                <p class="text-sm text-muted-foreground">Points a traiter avant qu'ils deviennent des incidents terrain.</p>
              </div>
              <button
                class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
                @click="dashboardStore.fetchAnomalies"
              >
                Rafraichir les alertes
              </button>
            </div>

            <div class="mt-6 grid gap-4 md:grid-cols-5">
              <div class="rounded-2xl border border-amber-200 bg-amber-50/70 p-4">
                <p class="text-xs uppercase tracking-[0.2em] text-amber-700">Retraits lents</p>
                <p class="mt-2 text-2xl font-semibold text-amber-700">{{ anomalies?.counts.staleWithdrawals || 0 }}</p>
              </div>
              <div class="rounded-2xl border border-orange-200 bg-orange-50/70 p-4">
                <p class="text-xs uppercase tracking-[0.2em] text-orange-700">Codes expires</p>
                <p class="mt-2 text-2xl font-semibold text-orange-700">{{ anomalies?.counts.expiredRequestedWithdrawals || 0 }}</p>
              </div>
              <div class="rounded-2xl border border-red-200 bg-red-50/70 p-4">
                <p class="text-xs uppercase tracking-[0.2em] text-red-700">Reserves incoherentes</p>
                <p class="mt-2 text-2xl font-semibold text-red-700">{{ anomalies?.counts.walletReservationMismatches || 0 }}</p>
              </div>
              <div class="rounded-2xl border border-violet-200 bg-violet-50/70 p-4">
                <p class="text-xs uppercase tracking-[0.2em] text-violet-700">Agents inactifs avec caisse</p>
                <p class="mt-2 text-2xl font-semibold text-violet-700">{{ anomalies?.counts.inactiveAgentsWithCash || 0 }}</p>
              </div>
              <div class="rounded-2xl border border-sky-200 bg-sky-50/70 p-4">
                <p class="text-xs uppercase tracking-[0.2em] text-sky-700">Cycles actifs en retard</p>
                <p class="mt-2 text-2xl font-semibold text-sky-700">{{ anomalies?.counts.overdueActiveCycles || 0 }}</p>
              </div>
            </div>

            <div v-if="dashboardStore.isAnomaliesLoading && !anomalies" class="mt-6 text-sm text-muted-foreground">
              Chargement des anomalies...
            </div>

            <div class="mt-6 grid gap-6 lg:grid-cols-2">
              <div class="rounded-2xl border border-border/60 p-4">
                <h4 class="font-medium">Retraits demandes trop anciens</h4>
                <div class="mt-4 space-y-3">
                  <div
                    v-for="item in anomalies?.staleWithdrawals || []"
                    :key="item.id"
                    class="rounded-xl border border-border/60 p-3"
                  >
                    <div class="flex items-start justify-between gap-3">
                      <div>
                        <p class="font-medium">{{ item.reference }}</p>
                        <p class="text-sm text-muted-foreground">{{ item.client.displayName }} · {{ item.client.phoneNumber }}</p>
                      </div>
                      <span class="text-sm font-medium">{{ formatCurrency(item.amount) }} F</span>
                    </div>
                    <p class="mt-2 text-xs text-muted-foreground">{{ formatDateTime(item.requestedAt) }}</p>
                  </div>
                  <div v-if="!anomalies?.staleWithdrawals?.length" class="text-sm text-muted-foreground">
                    Aucun retrait ancien.
                  </div>
                </div>
              </div>

              <div class="rounded-2xl border border-border/60 p-4">
                <h4 class="font-medium">Reserves incoherentes</h4>
                <div class="mt-4 space-y-3">
                  <div
                    v-for="item in anomalies?.walletReservationMismatches || []"
                    :key="item.userId"
                    class="rounded-xl border border-border/60 p-3"
                  >
                    <p class="font-medium">{{ item.client?.displayName || "Client introuvable" }}</p>
                    <p class="mt-1 text-sm text-muted-foreground">{{ item.client?.phoneNumber || "N/A" }}</p>
                    <p class="mt-2 text-sm">
                      Reserve: {{ formatCurrency(item.reservedBalance) }} F · Demande: {{ formatCurrency(item.requestedAmount) }} F
                    </p>
                    <p class="mt-1 text-xs text-red-700">Ecart: {{ formatCurrency(item.gapAmount) }} F</p>
                  </div>
                  <div v-if="!anomalies?.walletReservationMismatches?.length" class="text-sm text-muted-foreground">
                    Aucune incoherence de reserve detectee.
                  </div>
                </div>
              </div>
            </div>
          </div>
        </Card>
      </div>
    </div>
  </div>
</template>
