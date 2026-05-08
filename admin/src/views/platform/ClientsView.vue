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
import type { ClientDetail } from "@/types/platform";
import { useClientStore } from "@/stores/clients";
import { clientService } from "@/services/clients/clientService";
import { getErrorMessage } from "@/services/http/errors";
import { formatCurrency, formatDateTime } from "@/utils/formatters";

const clientStore = useClientStore();
const clients = computed(() => clientStore.collection?.items || []);
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

async function toggleClientStatus(clientId: string, isActive: boolean) {
  mutationClientId.value = clientId;
  try {
    await clientService.updateStatus(clientId, !isActive);
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
  isDetailLoading.value = true;

  try {
    detailData.value = await clientService.getDetail(clientId);
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
}

onMounted(fetchClients);
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
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          @click="fetchClients(currentPage)"
        >
          Rafraichir
        </button>
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
    <DialogContent class="sm:max-w-[980px]">
      <DialogHeader>
        <DialogTitle>Detail client</DialogTitle>
        <DialogDescription>
          <span v-if="detailData">{{ detailData.client.displayName }}</span>
          <span v-else>Chargement du client.</span>
        </DialogDescription>
      </DialogHeader>

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
                <p class="text-sm">Actuel: {{ formatCurrency(entry.currentAmount) }} F / {{ formatCurrency(entry.targetAmount) }} F</p>
                <p class="text-xs text-muted-foreground">Statut: {{ entry.status }}</p>
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

      <DialogFooter>
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          @click="closeDetailDialog"
        >
          Fermer
        </button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
