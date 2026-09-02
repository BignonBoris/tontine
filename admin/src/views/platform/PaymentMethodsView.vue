<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { toast } from "vue-sonner";
import Card from "@/components/ui/card/Card.vue";
import { Switch } from "@/components/ui/switch";
import { paymentMethodService } from "@/services/payment-methods/paymentMethodService";
import { getErrorMessage } from "@/services/http/errors";
import type { PaymentMethodItem } from "@/types/platform";
import { formatDateTime } from "@/utils/formatters";

const methods = ref<PaymentMethodItem[]>([]);
const isLoading = ref(false);
const errorMessage = ref("");
const search = ref("");
const operationFilter = ref("all");
const savingMethodId = ref<string | null>(null);

const filteredMethods = computed(() => {
  const searchValue = search.value.trim().toLowerCase();
  return methods.value.filter((method) => {
    const matchesOperation =
      operationFilter.value === "all" ||
      method.operation === operationFilter.value;
    const matchesSearch =
      !searchValue ||
      method.label.toLowerCase().includes(searchValue) ||
      method.code.toLowerCase().includes(searchValue) ||
      (method.provider || "").toLowerCase().includes(searchValue);
    return matchesOperation && matchesSearch;
  });
});

const summaryCards = computed(() => {
  const total = filteredMethods.value.length;
  const enabled = filteredMethods.value.filter((method) => method.enabled).length;
  const deposit = filteredMethods.value.filter(
    (method) => method.operation === "tontine_deposit" && method.enabled,
  ).length;
  const withdrawal = filteredMethods.value.filter(
    (method) => method.operation === "withdrawal" && method.enabled,
  ).length;
  return { total, enabled, deposit, withdrawal };
});

async function fetchMethods() {
  errorMessage.value = "";
  isLoading.value = true;
  try {
    const payload = await paymentMethodService.list(
      operationFilter.value === "all"
        ? {}
        : { operation: operationFilter.value },
    );
    methods.value = payload.items || [];
  } catch (error) {
    errorMessage.value = getErrorMessage(
      error,
      "Chargement des moyens de paiement impossible.",
    );
  } finally {
    isLoading.value = false;
  }
}

function patchMethodEnabled(methodId: string, enabled: boolean) {
  methods.value = methods.value.map((method) =>
    method.id === methodId ? { ...method, enabled } : method,
  );
}

async function toggleMethod(method: PaymentMethodItem, enabled: boolean) {
  if (savingMethodId.value) {
    return;
  }

  const nextEnabled = Boolean(enabled);
  const previousEnabled = method.enabled;

  savingMethodId.value = method.id;
  errorMessage.value = "";
  patchMethodEnabled(method.id, nextEnabled);
  try {
    await paymentMethodService.toggle(method.id, nextEnabled);
    toast.success(
      `${method.label} ${nextEnabled ? "activé" : "désactivé"} avec succès.`,
    );
    await fetchMethods();
  } catch (error) {
    patchMethodEnabled(method.id, previousEnabled);
    const message = getErrorMessage(
      error,
      "Mise a jour du moyen de paiement impossible.",
    );
    errorMessage.value = message;
    toast.error(message);
  } finally {
    savingMethodId.value = null;
  }
}

function formatOperation(operation: string) {
  switch (operation) {
    case "tontine_deposit":
      return "Depot tontine";
    case "withdrawal":
      return "Retrait";
    default:
      return operation || "N/A";
  }
}

function formatFlowType(flowType: string) {
  switch (flowType) {
    case "internal_transfer":
      return "Transfert interne";
    case "external_checkout":
      return "Paiement externe";
    case "manual_review":
      return "Validation admin";
    default:
      return flowType || "N/A";
  }
}

function formatProvider(provider: string) {
  switch (provider) {
    case "internal":
      return "Interne";
    case "fedapay":
      return "FedaPay";
    case "mtn_momo":
      return "MTN MoMo";
    case "afrikmoney":
      return "Afrikmoney";
    case "mobile_money":
      return "Mobile money";
    case "bank_transfer":
      return "Virement";
    default:
      return provider || "N/A";
  }
}

onMounted(fetchMethods);
</script>

<template>
  <Card class="border border-border/60">
    <div class="p-6">
      <PageHeader
        title="Moyens de paiement"
        description="Activez ou desactivez les moyens de paiement disponibles dans l'application client et les retraits."
      />

      <div class="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <div class="rounded-2xl border border-border/60 bg-muted/20 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">
            Total visible
          </p>
          <p class="mt-2 text-2xl font-semibold">{{ summaryCards.total }}</p>
        </div>
        <div class="rounded-2xl border border-emerald-200 bg-emerald-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-emerald-700">
            Actifs
          </p>
          <p class="mt-2 text-2xl font-semibold text-emerald-700">
            {{ summaryCards.enabled }}
          </p>
        </div>
        <div class="rounded-2xl border border-blue-200 bg-blue-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-blue-700">
            Depots actifs
          </p>
          <p class="mt-2 text-2xl font-semibold text-blue-700">
            {{ summaryCards.deposit }}
          </p>
        </div>
        <div class="rounded-2xl border border-amber-200 bg-amber-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-amber-700">
            Retraits actifs
          </p>
          <p class="mt-2 text-2xl font-semibold text-amber-700">
            {{ summaryCards.withdrawal }}
          </p>
        </div>
      </div>

      <div class="mt-6 flex flex-wrap items-center gap-3">
        <input
          v-model="search"
          type="text"
          placeholder="Rechercher par code, label ou fournisseur"
          class="h-10 min-w-[260px] rounded-xl border border-border bg-background px-3 text-sm"
        />
        <select
          v-model="operationFilter"
          class="h-10 min-w-[200px] rounded-xl border border-border bg-background px-3 text-sm"
          @change="fetchMethods"
        >
          <option value="all">Toutes les operations</option>
          <option value="tontine_deposit">Depot tontine</option>
          <option value="withdrawal">Retrait</option>
        </select>
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          @click="fetchMethods"
        >
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
        v-if="isLoading && !filteredMethods.length"
        class="mt-6 text-sm text-muted-foreground"
      >
        Chargement des moyens de paiement...
      </div>

      <div v-else class="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        <Card
          v-for="method in filteredMethods"
          :key="method.id"
          class="border border-border/60"
        >
          <div class="space-y-4 p-5">
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="text-base font-semibold">{{ method.label }}</p>
                <p class="text-xs text-muted-foreground">{{ method.code }}</p>
              </div>
              <Switch
                :model-value="method.enabled"
                :disabled="savingMethodId === method.id"
                @update:modelValue="(value: boolean) => toggleMethod(method, value)"
              />
            </div>

            <p class="text-sm text-muted-foreground">
              {{ method.description || "Aucune description disponible." }}
            </p>

            <div class="flex flex-wrap gap-2">
              <span
                class="rounded-full bg-sky-100 px-2.5 py-1 text-xs font-medium text-sky-700"
              >
                {{ formatOperation(method.operation) }}
              </span>
              <span
                class="rounded-full bg-violet-100 px-2.5 py-1 text-xs font-medium text-violet-700"
              >
                {{ formatFlowType(method.flowType) }}
              </span>
              <span
                class="rounded-full bg-muted px-2.5 py-1 text-xs font-medium text-muted-foreground"
              >
                {{ formatProvider(method.provider) }}
              </span>
              <span
                :class="
                  method.enabled
                    ? 'bg-emerald-100 text-emerald-700'
                    : 'bg-rose-100 text-rose-700'
                "
                class="rounded-full px-2.5 py-1 text-xs font-medium"
              >
                {{ method.enabled ? "Actif" : "Inactif" }}
              </span>
            </div>

            <div class="flex items-center justify-between text-xs text-muted-foreground">
              <span>Ordre: {{ method.sortOrder }}</span>
              <span>{{ formatDateTime(method.updatedAt) }}</span>
            </div>
          </div>
        </Card>

        <div
          v-if="!filteredMethods.length && !isLoading"
          class="rounded-2xl border border-dashed border-border/70 p-8 text-center text-sm text-muted-foreground md:col-span-2 xl:col-span-3"
        >
          Aucun moyen de paiement ne correspond a ce filtre.
        </div>
      </div>
    </div>
  </Card>
</template>
