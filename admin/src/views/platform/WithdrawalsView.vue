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
import type { WithdrawalDetail } from "@/types/platform";
import { useWithdrawalStore } from "@/stores/withdrawals";
import { withdrawalService } from "@/services/withdrawals/withdrawalService";
import { getErrorMessage } from "@/services/http/errors";
import { formatCurrency, formatDateTime } from "@/utils/formatters";

const withdrawalStore = useWithdrawalStore();
const withdrawals = computed(() => withdrawalStore.collection?.items || []);
const pagination = computed(() => withdrawalStore.collection?.pagination || { page: 1, pageSize: 20, total: 0 });
const filters = reactive({
  search: "",
  reference: "",
  status: "",
  channel: "",
});
const currentPage = ref(1);
const pageSize = 20;
const errorMessage = ref("");
const detailDialogOpen = ref(false);
const selectedWithdrawalId = ref<string | null>(null);
const detailError = ref("");
const isDetailLoading = ref(false);
const detailData = ref<WithdrawalDetail | null>(null);
const detailActionError = ref("");
const isDetailActionSubmitting = ref(false);
const adminNote = ref("");
const rejectionReason = ref("");
const paymentReference = ref("");
const paymentProofFileName = ref("");
const paymentProofImageBase64 = ref("");
const paymentProofImageMimeType = ref("");

const totalPages = computed(() => Math.max(1, Math.ceil(pagination.value.total / pagination.value.pageSize)));
const summary = computed(() => {
  const requested = withdrawals.value.filter((withdrawal) => withdrawal.status === "requested").length;
  const approved = withdrawals.value.filter((withdrawal) => withdrawal.status === "approved").length;
  const paid = withdrawals.value.filter((withdrawal) => withdrawal.status === "paid").length;
  const rejected = withdrawals.value.filter((withdrawal) => withdrawal.status === "rejected").length;
  const cancelled = withdrawals.value.filter((withdrawal) => withdrawal.status === "cancelled").length;
  const totalAmount = withdrawals.value.reduce((sum, withdrawal) => sum + withdrawal.amount, 0);
  return { requested, approved, paid, rejected, cancelled, totalAmount };
});

async function fetchWithdrawals(page = currentPage.value) {
  errorMessage.value = "";
  currentPage.value = page;
  try {
    await withdrawalStore.fetchWithdrawals({
      page: currentPage.value,
      pageSize,
      search: filters.search || undefined,
      reference: filters.reference || undefined,
      status: filters.status || undefined,
      channel: filters.channel || undefined,
    });
  } catch (error) {
    errorMessage.value = getErrorMessage(error, "Chargement des retraits impossible.");
  }
}

async function openDetailDialog(withdrawalId: string) {
  detailDialogOpen.value = true;
  selectedWithdrawalId.value = withdrawalId;
  detailData.value = null;
  detailError.value = "";
  detailActionError.value = "";
  isDetailActionSubmitting.value = false;
  adminNote.value = "";
  rejectionReason.value = "";
  paymentReference.value = "";
  paymentProofFileName.value = "";
  paymentProofImageBase64.value = "";
  paymentProofImageMimeType.value = "";
  isDetailLoading.value = true;

  try {
    detailData.value = await withdrawalService.getDetail(withdrawalId);
  } catch (error) {
    detailError.value = getErrorMessage(error, "Chargement du detail retrait impossible.");
  } finally {
    isDetailLoading.value = false;
  }
}

function closeDetailDialog() {
  detailDialogOpen.value = false;
  selectedWithdrawalId.value = null;
  detailData.value = null;
  detailError.value = "";
  detailActionError.value = "";
  isDetailActionSubmitting.value = false;
  adminNote.value = "";
  rejectionReason.value = "";
  paymentReference.value = "";
  paymentProofFileName.value = "";
  paymentProofImageBase64.value = "";
  paymentProofImageMimeType.value = "";
}

function formatWithdrawalChannel(channel: string) {
  switch (channel) {
    case "agent_cash":
      return "Agent / caisse";
    case "mobile_money":
      return "Mobile money";
    case "bank_transfer":
      return "Virement bancaire";
    default:
      return channel || "N/A";
  }
}

function formatWithdrawalStatus(status: string, channel: string) {
  switch (status) {
    case "requested":
      return channel === "agent_cash" ? "En attente paiement" : "En attente validation";
    case "approved":
      return "Approuve";
    case "paid":
      return "Paye";
    case "rejected":
      return "Refuse";
    case "cancelled":
      return "Annule";
    default:
      return status;
  }
}

function resetDetailActionState() {
  detailActionError.value = "";
  isDetailActionSubmitting.value = false;
}

async function readFileAsDataUrl(file: File) {
  return await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ""));
    reader.onerror = () => reject(new Error("Lecture du fichier impossible."));
    reader.readAsDataURL(file);
  });
}

async function onProofImageSelected(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) {
    paymentProofFileName.value = "";
    paymentProofImageBase64.value = "";
    paymentProofImageMimeType.value = "";
    return;
  }

  try {
    const dataUrl = await readFileAsDataUrl(file);
    const [, base64 = ""] = dataUrl.split(",");
    paymentProofFileName.value = file.name;
    paymentProofImageBase64.value = base64;
    paymentProofImageMimeType.value = file.type || "image/jpeg";
  } catch (error) {
    detailActionError.value = getErrorMessage(error, "Lecture de la preuve image impossible.");
    paymentProofFileName.value = "";
    paymentProofImageBase64.value = "";
    paymentProofImageMimeType.value = "";
  }
}

async function approveWithdrawal() {
  if (!selectedWithdrawalId.value) {
    return;
  }

  resetDetailActionState();
  isDetailActionSubmitting.value = true;
  try {
    detailData.value = await withdrawalService.approve(selectedWithdrawalId.value, {
      note: adminNote.value.trim() || undefined,
    });
    await fetchWithdrawals(currentPage.value);
  } catch (error) {
    detailActionError.value = getErrorMessage(error, "Approbation du retrait impossible.");
  } finally {
    isDetailActionSubmitting.value = false;
  }
}

async function rejectWithdrawal() {
  if (!selectedWithdrawalId.value) {
    return;
  }

  if (!rejectionReason.value.trim()) {
    detailActionError.value = "Le motif de refus est requis.";
    return;
  }

  resetDetailActionState();
  isDetailActionSubmitting.value = true;
  try {
    detailData.value = await withdrawalService.reject(selectedWithdrawalId.value, {
      reason: rejectionReason.value.trim(),
      note: adminNote.value.trim() || undefined,
    });
    await fetchWithdrawals(currentPage.value);
  } catch (error) {
    detailActionError.value = getErrorMessage(error, "Refus du retrait impossible.");
  } finally {
    isDetailActionSubmitting.value = false;
  }
}

async function markWithdrawalPaid() {
  if (!selectedWithdrawalId.value) {
    return;
  }

  if (!paymentReference.value.trim()) {
    detailActionError.value = "La reference de paiement est requise.";
    return;
  }
  if (!paymentProofImageBase64.value || !paymentProofImageMimeType.value) {
    detailActionError.value = "La preuve image de paiement est requise.";
    return;
  }

  resetDetailActionState();
  isDetailActionSubmitting.value = true;
  try {
    detailData.value = await withdrawalService.markPaid(selectedWithdrawalId.value, {
      paymentReference: paymentReference.value.trim(),
      paymentProofImageBase64: paymentProofImageBase64.value,
      paymentProofImageMimeType: paymentProofImageMimeType.value,
      note: adminNote.value.trim() || undefined,
    });
    await fetchWithdrawals(currentPage.value);
  } catch (error) {
    detailActionError.value = getErrorMessage(error, "Marquage comme paye impossible.");
  } finally {
    isDetailActionSubmitting.value = false;
  }
}

onMounted(fetchWithdrawals);
</script>

<template>
  <Card class="border border-border/60">
    <div class="p-6">
      <PageHeader
        title="Retraits"
        description="Suivi des retraits demandes, payes ou annules, avec detail unitaire et recherche par client ou reference."
      />

      <div class="mt-6 grid gap-4 md:grid-cols-5">
        <div class="rounded-2xl border border-amber-200 bg-amber-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-amber-700">Requested</p>
          <p class="mt-2 text-2xl font-semibold text-amber-700">{{ summary.requested }}</p>
        </div>
        <div class="rounded-2xl border border-blue-200 bg-blue-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-blue-700">Approved</p>
          <p class="mt-2 text-2xl font-semibold text-blue-700">{{ summary.approved }}</p>
        </div>
        <div class="rounded-2xl border border-emerald-200 bg-emerald-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-emerald-700">Paid</p>
          <p class="mt-2 text-2xl font-semibold text-emerald-700">{{ summary.paid }}</p>
        </div>
        <div class="rounded-2xl border border-rose-200 bg-rose-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-rose-700">Rejected</p>
          <p class="mt-2 text-2xl font-semibold text-rose-700">{{ summary.rejected }}</p>
        </div>
        <div class="rounded-2xl border border-sky-200 bg-sky-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-sky-700">Montant visible</p>
          <p class="mt-2 text-2xl font-semibold text-sky-700">{{ formatCurrency(summary.totalAmount) }} F</p>
        </div>
      </div>

      <div class="mt-6 flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-1 flex-wrap items-center gap-3">
          <input
            v-model="filters.search"
            type="text"
            placeholder="Nom client ou telephone"
            class="h-10 min-w-[220px] rounded-xl border border-border bg-background px-3 text-sm"
            @keyup.enter="fetchWithdrawals(1)"
          />
          <input
            v-model="filters.reference"
            type="text"
            placeholder="Reference retrait"
            class="h-10 min-w-[220px] rounded-xl border border-border bg-background px-3 text-sm"
            @keyup.enter="fetchWithdrawals(1)"
          />
          <select
            v-model="filters.status"
            class="h-10 min-w-[170px] rounded-xl border border-border bg-background px-3 text-sm"
          >
            <option value="">
              Tous statuts
            </option>
            <option value="requested">
              Requested
            </option>
            <option value="approved">
              Approved
            </option>
            <option value="paid">
              Paid
            </option>
            <option value="rejected">
              Rejected
            </option>
            <option value="cancelled">
              Cancelled
            </option>
          </select>
          <select
            v-model="filters.channel"
            class="h-10 min-w-[190px] rounded-xl border border-border bg-background px-3 text-sm"
          >
            <option value="">
              Toutes methodes
            </option>
            <option value="agent_cash">
              Agent / caisse
            </option>
            <option value="mobile_money">
              Mobile money
            </option>
            <option value="bank_transfer">
              Virement bancaire
            </option>
          </select>
          <button
            class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
            @click="fetchWithdrawals(1)"
          >
            Filtrer
          </button>
        </div>
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          @click="fetchWithdrawals(currentPage)"
        >
          Rafraichir
        </button>
      </div>

      <div v-if="errorMessage" class="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {{ errorMessage }}
      </div>
      <div v-if="withdrawalStore.isLoading && !withdrawals.length" class="mt-6 text-sm text-muted-foreground">
        Chargement des retraits...
      </div>
      <div v-else class="mt-6 overflow-auto">
        <table class="w-full min-w-[1160px] text-sm">
          <thead>
            <tr class="border-b">
              <th class="px-3 py-3 text-left">Reference</th>
              <th class="px-3 py-3 text-left">Client</th>
              <th class="px-3 py-3 text-left">Methode</th>
              <th class="px-3 py-3 text-left">Montant</th>
              <th class="px-3 py-3 text-left">Statut</th>
              <th class="px-3 py-3 text-left">Demande</th>
              <th class="px-3 py-3 text-left">Paiement / annulation</th>
              <th class="px-3 py-3 text-left">Action</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="withdrawal in withdrawals" :key="withdrawal.id" class="border-b">
              <td class="px-3 py-3 font-medium">{{ withdrawal.reference }}</td>
              <td class="px-3 py-3">
                <div>{{ withdrawal.client?.displayName || "N/A" }}</div>
                <div class="text-muted-foreground">{{ withdrawal.client?.phoneNumber || "N/A" }}</div>
              </td>
              <td class="px-3 py-3">{{ formatWithdrawalChannel(withdrawal.channel) }}</td>
              <td class="px-3 py-3">{{ formatCurrency(withdrawal.amount) }} F</td>
              <td class="px-3 py-3">
                <span
                  class="rounded-full px-2.5 py-1 text-xs font-medium"
                  :class="withdrawal.status === 'paid'
                    ? 'bg-emerald-100 text-emerald-700'
                    : withdrawal.status === 'approved'
                      ? 'bg-blue-100 text-blue-700'
                      : withdrawal.status === 'rejected'
                        ? 'bg-rose-100 text-rose-700'
                    : withdrawal.status === 'cancelled'
                      ? 'bg-red-100 text-red-700'
                      : 'bg-amber-100 text-amber-700'"
                >
                  {{ formatWithdrawalStatus(withdrawal.status, withdrawal.channel) }}
                </span>
              </td>
              <td class="px-3 py-3">{{ formatDateTime(withdrawal.requestedAt) }}</td>
              <td class="px-3 py-3">
                <span v-if="withdrawal.paidAt">{{ formatDateTime(withdrawal.paidAt) }}</span>
                <span v-else-if="withdrawal.cancelledAt">{{ formatDateTime(withdrawal.cancelledAt) }}</span>
                <span v-else class="text-muted-foreground">En attente</span>
              </td>
              <td class="px-3 py-3">
                <button
                  class="rounded-lg border border-border px-3 py-1.5 text-xs font-medium transition hover:bg-muted"
                  @click="openDetailDialog(withdrawal.id)"
                >
                  Voir detail
                </button>
              </td>
            </tr>
            <tr v-if="!withdrawals.length && !withdrawalStore.isLoading">
              <td colspan="8" class="px-3 py-8 text-center text-sm text-muted-foreground">
                Aucun retrait a afficher.
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="mt-4 flex flex-wrap items-center justify-between gap-3 text-sm">
        <p class="text-muted-foreground">
          Page {{ pagination.page }} / {{ totalPages }} - {{ pagination.total }} retraits
        </p>
        <div class="flex items-center gap-2">
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="pagination.page <= 1 || withdrawalStore.isLoading"
            @click="fetchWithdrawals(pagination.page - 1)"
          >
            Precedent
          </button>
          <button
            class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="pagination.page >= totalPages || withdrawalStore.isLoading"
            @click="fetchWithdrawals(pagination.page + 1)"
          >
            Suivant
          </button>
        </div>
      </div>
    </div>
  </Card>

  <Dialog :open="detailDialogOpen" @update:open="detailDialogOpen = $event">
    <DialogContent class="sm:max-w-[920px]">
      <DialogHeader>
        <DialogTitle>Detail retrait</DialogTitle>
        <DialogDescription>
          <span v-if="detailData">{{ detailData.withdrawal.reference }}</span>
          <span v-else>Chargement du retrait.</span>
        </DialogDescription>
      </DialogHeader>

      <div v-if="detailError" class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {{ detailError }}
      </div>
      <div v-else-if="isDetailLoading" class="text-sm text-muted-foreground">
        Chargement du detail retrait...
      </div>
      <div v-else-if="detailData" class="space-y-6">
        <div class="grid gap-4 md:grid-cols-4">
          <div class="rounded-2xl border border-border bg-muted/30 p-4">
            <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Montant</p>
            <p class="mt-2 text-2xl font-semibold">{{ formatCurrency(detailData.withdrawal.amount) }} F</p>
          </div>
          <div class="rounded-2xl border border-border bg-muted/30 p-4">
            <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Statut</p>
            <p class="mt-2 text-2xl font-semibold">{{ detailData.withdrawal.status }}</p>
          </div>
          <div class="rounded-2xl border border-border bg-muted/30 p-4">
            <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Code expire</p>
            <p class="mt-2 text-2xl font-semibold">{{ detailData.withdrawal.isConfirmationCodeExpired ? "Oui" : "Non" }}</p>
          </div>
          <div class="rounded-2xl border border-border bg-muted/30 p-4">
            <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Tentatives</p>
            <p class="mt-2 text-2xl font-semibold">{{ detailData.withdrawal.confirmationCodeAttempts }}</p>
          </div>
        </div>

        <div class="grid gap-4 md:grid-cols-2">
          <div class="rounded-2xl border border-border/60 p-4">
            <h4 class="font-medium">Client</h4>
            <p class="mt-3">{{ detailData.withdrawal.client?.displayName || "N/A" }}</p>
            <p class="text-sm text-muted-foreground">{{ detailData.withdrawal.client?.phoneNumber || "N/A" }}</p>
            <p class="mt-3 text-sm">Solde disponible: {{ formatCurrency(detailData.withdrawal.clientWalletSnapshot.availableBalance) }} F</p>
            <p class="text-sm">Reserve retrait: {{ formatCurrency(detailData.withdrawal.clientWalletSnapshot.reservedWithdrawalBalance) }} F</p>
          </div>
          <div class="rounded-2xl border border-border/60 p-4">
            <h4 class="font-medium">Paiement</h4>
            <p class="mt-3">
              Payeur:
              {{
                detailData.withdrawal.paidBy?.displayName
                  || detailData.withdrawal.paidByAdminUsername
                  || "Non paye"
              }}
            </p>
            <p class="text-sm text-muted-foreground">
              {{
                detailData.withdrawal.paidBy?.agentCode
                  ? detailData.withdrawal.paidBy.agentCode
                  : detailData.withdrawal.paidByAdminUsername
                    ? `Admin: ${detailData.withdrawal.paidByAdminUsername}`
                    : "Aucun code agent"
              }}
            </p>
            <p class="mt-3 text-sm">Demande: {{ formatDateTime(detailData.withdrawal.requestedAt) }}</p>
            <p class="text-sm">Paiement: {{ detailData.withdrawal.paidAt ? formatDateTime(detailData.withdrawal.paidAt) : "Non paye" }}</p>
            <p class="text-sm">Annulation: {{ detailData.withdrawal.cancelledAt ? formatDateTime(detailData.withdrawal.cancelledAt) : "Non annule" }}</p>
            <p class="text-sm">
              Expiration code:
              {{
                detailData.withdrawal.confirmationCodeExpiresAt
                  ? formatDateTime(detailData.withdrawal.confirmationCodeExpiresAt)
                  : "N/A"
              }}
            </p>
            <p class="text-sm">Methode: {{ formatWithdrawalChannel(detailData.withdrawal.channel) }}</p>
            <p class="text-sm">Approuve: {{ detailData.withdrawal.approvedAt ? formatDateTime(detailData.withdrawal.approvedAt) : "Non" }}</p>
            <p class="text-sm">Approuve par: {{ detailData.withdrawal.approvedByAdminUsername || "N/A" }}</p>
            <p class="text-sm">Paye par admin: {{ detailData.withdrawal.paidByAdminUsername || "N/A" }}</p>
            <p class="text-sm">Rejete: {{ detailData.withdrawal.rejectedAt ? formatDateTime(detailData.withdrawal.rejectedAt) : "Non" }}</p>
            <p class="text-sm">Reference paiement: {{ detailData.withdrawal.paymentReference || "N/A" }}</p>
            <p class="text-sm">Preuve: {{ detailData.withdrawal.paymentProofImageUrl || "N/A" }}</p>
            <a
              v-if="detailData.withdrawal.paymentProofImageUrl"
              :href="detailData.withdrawal.paymentProofImageUrl"
              target="_blank"
              class="mt-2 inline-flex text-sm font-medium text-primary underline-offset-4 hover:underline"
            >
              Ouvrir la preuve
            </a>
          </div>
        </div>

        <div v-if="detailData.withdrawal.channel !== 'agent_cash'" class="rounded-2xl border border-border/60 p-4">
          <h4 class="font-medium">Workflow admin</h4>
          <p class="mt-2 text-sm text-muted-foreground">
            Cette demande suit la validation admin avant paiement hors application.
          </p>

          <div v-if="detailData.withdrawal.status === 'requested'" class="mt-4 space-y-4">
            <textarea
              v-model="adminNote"
              rows="3"
              class="min-h-[96px] w-full rounded-xl border border-border bg-background px-3 py-2 text-sm"
              placeholder="Note admin optionnelle"
            />
            <textarea
              v-model="rejectionReason"
              rows="3"
              class="min-h-[96px] w-full rounded-xl border border-border bg-background px-3 py-2 text-sm"
              placeholder="Motif de refus si necessaire"
            />
            <div class="flex flex-wrap gap-3">
              <button
                class="rounded-xl bg-primary px-4 py-2 text-sm font-medium text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
                :disabled="isDetailActionSubmitting"
                @click="approveWithdrawal"
              >
                {{ isDetailActionSubmitting ? "Traitement..." : "Approuver" }}
              </button>
              <button
                class="rounded-xl border border-rose-200 bg-rose-50 px-4 py-2 text-sm font-medium text-rose-700 transition hover:bg-rose-100 disabled:cursor-not-allowed disabled:opacity-60"
                :disabled="isDetailActionSubmitting"
                @click="rejectWithdrawal"
              >
                Refuser
              </button>
            </div>
          </div>

          <div v-else-if="detailData.withdrawal.status === 'approved'" class="mt-4 space-y-4">
            <div class="rounded-xl border border-emerald-200 bg-emerald-50/60 p-4 text-sm text-emerald-800">
              Le retrait est approuve. Saisissez la reference de transfert et ajoutez la preuve image avant de le marquer paye.
            </div>
            <input
              v-model="paymentReference"
              type="text"
              class="h-10 w-full rounded-xl border border-border bg-background px-3 text-sm"
              placeholder="Reference de transfert"
            />
            <textarea
              v-model="adminNote"
              rows="3"
              class="min-h-[96px] w-full rounded-xl border border-border bg-background px-3 py-2 text-sm"
              placeholder="Note admin optionnelle"
            />
            <input
              type="file"
              accept="image/*"
              class="block w-full text-sm"
              @change="onProofImageSelected"
            />
            <p v-if="paymentProofFileName" class="text-xs text-muted-foreground">
              Fichier selectionne: {{ paymentProofFileName }}
            </p>
            <button
              class="rounded-xl bg-primary px-4 py-2 text-sm font-medium text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
              :disabled="isDetailActionSubmitting"
              @click="markWithdrawalPaid"
            >
              {{ isDetailActionSubmitting ? "Enregistrement..." : "Marquer comme paye" }}
            </button>
          </div>

          <div v-else class="mt-4 rounded-xl border border-border/60 p-4 text-sm text-muted-foreground">
            Aucune action disponible pour ce statut.
          </div>
        </div>

        <div v-if="detailActionError" class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {{ detailActionError }}
        </div>

        <div class="rounded-2xl border border-border/60 p-4">
          <h4 class="font-medium">Audit lie</h4>
          <div class="mt-4 space-y-3">
            <div
              v-for="entry in detailData.auditLogs"
              :key="entry.id"
              class="rounded-xl border border-border/60 p-3"
            >
              <div class="flex items-start justify-between gap-3">
                <div>
                  <p class="font-medium">{{ entry.action }}</p>
                  <p class="text-sm text-muted-foreground">{{ entry.user?.displayName || "Systeme / admin" }}</p>
                </div>
                <span class="text-xs text-muted-foreground">{{ formatDateTime(entry.createdAt) }}</span>
              </div>
            </div>
            <div v-if="!detailData.auditLogs.length" class="text-sm text-muted-foreground">
              Aucun log d'audit pour ce retrait.
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
