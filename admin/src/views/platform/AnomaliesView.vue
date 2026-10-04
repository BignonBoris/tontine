<script setup lang="ts">
import { onMounted, ref } from "vue";
import Card from "@/components/ui/card/Card.vue";
import { auditService } from "@/services/audit/auditService";
import { getErrorMessage } from "@/services/http/errors";
import { formatDateTime } from "@/utils/formatters";

// ─── Types ─────────────────────────────────────────────────────────────────

interface SimpleAgent {
  id: string;
  agentCode?: string;
  fullName?: string;
  phoneNumber?: string | null;
  agentBalance?: number;
}

interface SimpleClient {
  id: string;
  displayName?: string;
  phoneNumber?: string | null;
}

interface SuspiciousProvisioning {
  id: string;
  reference?: string;
  amount: number;
  secureTimestamp?: string;
  offlineHash?: string;
  createdAt: string;
  client: SimpleClient;
}

interface ExpiredWithdrawal {
  id: string;
  reference?: string;
  amount: number;
  confirmationCodeExpiresAt: string;
  confirmationCodeAttempts: number;
  client: SimpleClient;
}

interface OverdueCycle {
  id: string;
  status: string;
  cumulativeAmount: number;
  expectedEndAt: string;
  client: SimpleClient | null;
}

interface Anomalies {
  multipleDeviceLogins: SimpleClient[];
  suspiciousProvisionings: SuspiciousProvisioning[];
  expiredRequestedWithdrawals: ExpiredWithdrawal[];
  walletReservationMismatches: unknown[];
  inactiveAgentsWithCash: SimpleAgent[];
  overdueActiveCycles: OverdueCycle[];
}

// ─── State ─────────────────────────────────────────────────────────────────

const loading = ref(false);
const error = ref("");
const data = ref<Anomalies | null>(null);

const totalAnomalies = ref(0);

async function refresh() {
  loading.value = true;
  error.value = "";
  try {
    data.value = await auditService.getAnomalies();
    totalAnomalies.value =
      (data.value.multipleDeviceLogins?.length ?? 0) +
      (data.value.suspiciousProvisionings?.length ?? 0) +
      (data.value.expiredRequestedWithdrawals?.length ?? 0) +
      (data.value.walletReservationMismatches?.length ?? 0) +
      (data.value.inactiveAgentsWithCash?.length ?? 0) +
      (data.value.overdueActiveCycles?.length ?? 0);
  } catch (e) {
    error.value = getErrorMessage(e, "Chargement des anomalies impossible.");
  } finally {
    loading.value = false;
  }
}

onMounted(refresh);
</script>

<template>
  <Card class="border border-border/60">
    <div class="p-6">

      <!-- En-tête -->
      <div class="flex items-start justify-between gap-4">
        <div>
          <h1 class="text-xl font-bold tracking-tight">Anomalies & Alertes</h1>
          <p class="mt-1 text-sm text-muted-foreground">
            Détection automatique des situations opérationnelles anormales.
          </p>
        </div>
        <button
          class="flex items-center gap-2 rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted disabled:opacity-50"
          :disabled="loading"
          @click="refresh"
        >
          <span v-if="loading">⟳ Actualisation…</span>
          <span v-else>⟳ Actualiser</span>
        </button>
      </div>

      <!-- Badge global -->
      <div v-if="!loading && data" class="mt-4">
        <span
          class="inline-flex items-center gap-2 rounded-full px-4 py-1.5 text-sm font-semibold"
          :class="totalAnomalies > 0 ? 'bg-red-100 text-red-700' : 'bg-emerald-100 text-emerald-700'"
        >
          <span v-if="totalAnomalies > 0">⚠ {{ totalAnomalies }} anomalie(s) détectée(s)</span>
          <span v-else>✅ Aucune anomalie détectée</span>
        </span>
      </div>

      <!-- Erreur -->
      <div v-if="error" class="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {{ error }}
      </div>

      <!-- Chargement -->
      <div v-if="loading" class="mt-10 text-center text-sm text-muted-foreground">Chargement…</div>

      <div v-else-if="data" class="mt-8 space-y-8">

        <!-- 1. Connexions multi-appareils -->
        <section>
          <h2 class="flex items-center gap-2 text-base font-semibold">
            <span class="rounded-lg bg-orange-100 px-2 py-0.5 text-xs font-bold text-orange-700">
              {{ data.multipleDeviceLogins?.length ?? 0 }}
            </span>
            Connexions multi-appareils suspects
          </h2>
          <p class="mt-1 text-xs text-muted-foreground">Agents ayant des sessions actives sur plusieurs appareils.</p>
          <div v-if="data.multipleDeviceLogins?.length" class="mt-3 overflow-auto rounded-xl border border-border">
            <table class="w-full text-sm">
              <thead class="bg-muted/40">
                <tr>
                  <th class="px-4 py-2 text-left">Utilisateur</th>
                  <th class="px-4 py-2 text-left">Téléphone</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="client in data.multipleDeviceLogins" :key="(client as SimpleClient).id" class="border-t border-border/50">
                  <td class="px-4 py-2 font-medium">{{ (client as SimpleClient).displayName }}</td>
                  <td class="px-4 py-2 text-muted-foreground">{{ (client as SimpleClient).phoneNumber ?? "—" }}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p v-else class="mt-2 text-xs text-muted-foreground">Aucune</p>
        </section>

        <!-- 2. Provisionnements suspects -->
        <section>
          <h2 class="flex items-center gap-2 text-base font-semibold">
            <span class="rounded-lg bg-red-100 px-2 py-0.5 text-xs font-bold text-red-700">
              {{ data.suspiciousProvisionings?.length ?? 0 }}
            </span>
            Provisionnements suspects (timestamp offline anormal)
          </h2>
          <div v-if="data.suspiciousProvisionings?.length" class="mt-3 overflow-auto rounded-xl border border-border">
            <table class="w-full text-sm">
              <thead class="bg-muted/40">
                <tr>
                  <th class="px-4 py-2 text-left">Référence</th>
                  <th class="px-4 py-2 text-left">Client</th>
                  <th class="px-4 py-2 text-right">Montant</th>
                  <th class="px-4 py-2 text-left">Timestamp offline</th>
                  <th class="px-4 py-2 text-left">Enregistré le</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="p in data.suspiciousProvisionings" :key="p.id" class="border-t border-border/50">
                  <td class="px-4 py-2 font-mono text-xs">{{ p.reference ?? p.id.slice(0, 8) }}</td>
                  <td class="px-4 py-2">{{ p.client?.displayName }}</td>
                  <td class="px-4 py-2 text-right font-semibold">{{ p.amount?.toLocaleString() }}</td>
                  <td class="px-4 py-2 text-xs text-amber-700">{{ p.secureTimestamp ? formatDateTime(p.secureTimestamp) : "—" }}</td>
                  <td class="px-4 py-2 text-xs text-muted-foreground">{{ formatDateTime(p.createdAt) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p v-else class="mt-2 text-xs text-muted-foreground">Aucun</p>
        </section>

        <!-- 3. Retraits expirés -->
        <section>
          <h2 class="flex items-center gap-2 text-base font-semibold">
            <span class="rounded-lg bg-amber-100 px-2 py-0.5 text-xs font-bold text-amber-700">
              {{ data.expiredRequestedWithdrawals?.length ?? 0 }}
            </span>
            Retraits en attente expirés
          </h2>
          <div v-if="data.expiredRequestedWithdrawals?.length" class="mt-3 overflow-auto rounded-xl border border-border">
            <table class="w-full text-sm">
              <thead class="bg-muted/40">
                <tr>
                  <th class="px-4 py-2 text-left">Référence</th>
                  <th class="px-4 py-2 text-left">Client</th>
                  <th class="px-4 py-2 text-right">Montant</th>
                  <th class="px-4 py-2 text-left">Expiré le</th>
                  <th class="px-4 py-2 text-center">Tentatives</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="w in data.expiredRequestedWithdrawals" :key="w.id" class="border-t border-border/50">
                  <td class="px-4 py-2 font-mono text-xs">{{ w.reference ?? w.id.slice(0, 8) }}</td>
                  <td class="px-4 py-2">{{ w.client?.displayName }}</td>
                  <td class="px-4 py-2 text-right font-semibold">{{ w.amount?.toLocaleString() }}</td>
                  <td class="px-4 py-2 text-xs text-red-700">{{ formatDateTime(w.confirmationCodeExpiresAt) }}</td>
                  <td class="px-4 py-2 text-center">{{ w.confirmationCodeAttempts }}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p v-else class="mt-2 text-xs text-muted-foreground">Aucun</p>
        </section>

        <!-- 4. Agents inactifs avec solde -->
        <section>
          <h2 class="flex items-center gap-2 text-base font-semibold">
            <span class="rounded-lg bg-violet-100 px-2 py-0.5 text-xs font-bold text-violet-700">
              {{ data.inactiveAgentsWithCash?.length ?? 0 }}
            </span>
            Agents inactifs avec solde caisse non nul
          </h2>
          <div v-if="data.inactiveAgentsWithCash?.length" class="mt-3 overflow-auto rounded-xl border border-border">
            <table class="w-full text-sm">
              <thead class="bg-muted/40">
                <tr>
                  <th class="px-4 py-2 text-left">Code agent</th>
                  <th class="px-4 py-2 text-left">Nom</th>
                  <th class="px-4 py-2 text-left">Téléphone</th>
                  <th class="px-4 py-2 text-right">Solde</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="agent in data.inactiveAgentsWithCash" :key="agent.id" class="border-t border-border/50">
                  <td class="px-4 py-2 font-mono text-xs">{{ agent.agentCode }}</td>
                  <td class="px-4 py-2 font-medium">{{ agent.fullName }}</td>
                  <td class="px-4 py-2 text-muted-foreground">{{ agent.phoneNumber ?? "—" }}</td>
                  <td class="px-4 py-2 text-right font-semibold text-red-700">{{ agent.agentBalance?.toLocaleString() }}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p v-else class="mt-2 text-xs text-muted-foreground">Aucun</p>
        </section>

        <!-- 5. Cycles tontine en retard -->
        <section>
          <h2 class="flex items-center gap-2 text-base font-semibold">
            <span class="rounded-lg bg-rose-100 px-2 py-0.5 text-xs font-bold text-rose-700">
              {{ data.overdueActiveCycles?.length ?? 0 }}
            </span>
            Cycles tontine actifs en retard
          </h2>
          <div v-if="data.overdueActiveCycles?.length" class="mt-3 overflow-auto rounded-xl border border-border">
            <table class="w-full text-sm">
              <thead class="bg-muted/40">
                <tr>
                  <th class="px-4 py-2 text-left">ID Cycle</th>
                  <th class="px-4 py-2 text-left">Statut</th>
                  <th class="px-4 py-2 text-left">Client</th>
                  <th class="px-4 py-2 text-right">Montant cumulé</th>
                  <th class="px-4 py-2 text-left">Fin prévue</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="cycle in data.overdueActiveCycles" :key="cycle.id" class="border-t border-border/50">
                  <td class="px-4 py-2 font-mono text-xs">{{ cycle.id.slice(0, 8) }}</td>
                  <td class="px-4 py-2">
                    <span class="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-700">{{ cycle.status }}</span>
                  </td>
                  <td class="px-4 py-2">{{ cycle.client?.displayName ?? "—" }}</td>
                  <td class="px-4 py-2 text-right font-semibold">{{ cycle.cumulativeAmount?.toLocaleString() }}</td>
                  <td class="px-4 py-2 text-xs text-red-700">{{ formatDateTime(cycle.expectedEndAt) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <p v-else class="mt-2 text-xs text-muted-foreground">Aucun</p>
        </section>

        <!-- 6. Écarts réservations wallet -->
        <section>
          <h2 class="flex items-center gap-2 text-base font-semibold">
            <span class="rounded-lg bg-slate-100 px-2 py-0.5 text-xs font-bold text-slate-700">
              {{ data.walletReservationMismatches?.length ?? 0 }}
            </span>
            Écarts de réservation wallet
          </h2>
          <p v-if="!data.walletReservationMismatches?.length" class="mt-2 text-xs text-muted-foreground">Aucun</p>
          <p v-else class="mt-2 text-xs text-amber-700">
            {{ data.walletReservationMismatches.length }} incohérence(s) détectée(s). Contactez un administrateur technique.
          </p>
        </section>

      </div>
    </div>
  </Card>
</template>
