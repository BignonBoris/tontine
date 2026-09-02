<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from "vue";
import { CheckCircle2, Clock3, FileCheck2, Loader2, ShieldAlert, XCircle } from "lucide-vue-next";
import { useKycStore } from "@/stores/kyc";
import { kycService } from "@/services/kyc/kycService";
import { getErrorMessage } from "@/services/http/errors";
import { formatDateTime } from "@/utils/formatters";
import type { KycCase, KycStatus } from "@/types/kyc";

const store = useKycStore();
const selected = computed(() => store.selectedCase);
const filter = ref<KycStatus | "all">("pending_review");
const errorMessage = ref("");
const actionError = ref("");
const reason = ref("");
const documentUrl = ref<string | null>(null);
const isDocumentLoading = ref(false);

const visibleCases = computed(() => store.cases);
const statusLabel: Record<string, string> = { pending_review: "En revue", verified: "Verifie", rejected: "Rejete", suspended: "Suspendu", expired: "Expire", unverified: "Non verifie" };

async function loadCases() {
  errorMessage.value = "";
  try { await store.fetchCases(filter.value === "all" ? undefined : filter.value); } catch (error) { errorMessage.value = getErrorMessage(error, "Chargement des dossiers KYC impossible."); }
}

async function openCase(item: KycCase) {
  actionError.value = "";
  reason.value = "";
  try { await store.fetchCase(item.id); } catch (error) { actionError.value = getErrorMessage(error, "Detail KYC indisponible."); }
}

async function showDocument(documentId: string) {
  if (documentUrl.value) URL.revokeObjectURL(documentUrl.value);
  documentUrl.value = null;
  isDocumentLoading.value = true;
  try { documentUrl.value = await kycService.documentUrl(documentId); } catch (error) { actionError.value = getErrorMessage(error, "Document indisponible."); } finally { isDocumentLoading.value = false; }
}

async function review(decision: "verified" | "rejected" | "suspended") {
  if (!selected.value) return;
  if (decision === "rejected" && !reason.value.trim()) { actionError.value = "Un motif est obligatoire pour un rejet."; return; }
  actionError.value = "";
  try { await store.reviewCase(selected.value.id, decision, reason.value.trim() || undefined); reason.value = ""; } catch (error) { actionError.value = getErrorMessage(error, "La decision KYC a echoue."); }
}

function closeCase() { store.selectedCase = null; if (documentUrl.value) URL.revokeObjectURL(documentUrl.value); documentUrl.value = null; }
function statusClass(status: string) { return { "bg-amber-100 text-amber-800": status === "pending_review", "bg-emerald-100 text-emerald-800": status === "verified", "bg-red-100 text-red-800": status === "rejected" || status === "suspended", "bg-slate-100 text-slate-700": !["pending_review", "verified", "rejected", "suspended"].includes(status) }; }

onMounted(loadCases);
onUnmounted(() => { if (documentUrl.value) URL.revokeObjectURL(documentUrl.value); });
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div><p class="text-sm font-semibold uppercase tracking-[0.18em] text-emerald-700">Conformite</p><h1 class="text-3xl font-bold text-slate-900">Revue KYC</h1><p class="mt-1 text-sm text-slate-500">Validation manuelle des identites avant activation des privileges sensibles.</p></div>
      <select v-model="filter" class="rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-sm" @change="loadCases"><option value="pending_review">En revue</option><option value="rejected">Rejetes</option><option value="verified">Verifies</option><option value="all">Tous</option></select>
    </div>
    <div v-if="errorMessage" class="rounded-xl bg-red-50 p-4 text-sm text-red-700">{{ errorMessage }}</div>
    <div class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_420px]">
      <section class="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
        <div class="flex items-center justify-between border-b border-slate-100 px-5 py-4"><h2 class="font-semibold text-slate-900">Dossiers ({{ visibleCases.length }})</h2><span class="rounded-full bg-amber-50 px-3 py-1 text-xs font-semibold text-amber-700">{{ store.pendingCount }} en attente</span></div>
        <div v-if="store.isLoading" class="flex items-center gap-2 p-6 text-sm text-slate-500"><Loader2 class="h-4 w-4 animate-spin" /> Chargement...</div>
        <div v-else-if="!visibleCases.length" class="p-10 text-center text-sm text-slate-500">Aucun dossier dans cette vue.</div>
        <div v-else class="divide-y divide-slate-100">
          <button v-for="item in visibleCases" :key="item.id" class="flex w-full items-center justify-between gap-4 px-5 py-4 text-left transition hover:bg-slate-50" :class="selected?.id === item.id ? 'bg-emerald-50/60' : ''" @click="openCase(item)"><span class="min-w-0"><span class="block truncate font-semibold text-slate-900">{{ item.user?.displayName || 'Client sans nom' }}</span><span class="mt-1 block text-xs text-slate-500">{{ item.user?.phoneNumber || '-' }} · {{ item.documents[0]?.documentType || 'Document' }}</span></span><span class="shrink-0 rounded-full px-2.5 py-1 text-xs font-semibold" :class="statusClass(item.status)">{{ statusLabel[item.status] || item.status }}</span></button>
        </div>
      </section>
      <aside class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <div v-if="!selected" class="flex min-h-[360px] flex-col items-center justify-center text-center text-slate-400"><FileCheck2 class="mb-3 h-10 w-10" /><p class="font-medium">Selectionnez un dossier</p><p class="mt-1 text-xs">Les pieces seront accessibles uniquement depuis cette session admin.</p></div>
        <div v-else class="space-y-5">
          <div class="flex items-start justify-between gap-3"><div><p class="text-xs font-semibold uppercase tracking-wider text-slate-400">Dossier KYC</p><h2 class="mt-1 text-xl font-bold text-slate-900">{{ selected.user?.displayName }}</h2><p class="text-sm text-slate-500">{{ selected.user?.phoneNumber }}</p></div><span class="rounded-full px-2.5 py-1 text-xs font-semibold" :class="statusClass(selected.status)">{{ statusLabel[selected.status] }}</span></div>
          <div class="grid grid-cols-2 gap-3 rounded-xl bg-slate-50 p-3 text-sm"><div><p class="text-xs text-slate-400">Type</p><p class="font-medium text-slate-800">{{ selected.documents[0]?.documentType }}</p></div><div><p class="text-xs text-slate-400">Numero</p><p class="font-medium text-slate-800">{{ selected.documents[0]?.documentNumber || '-' }}</p></div><div><p class="text-xs text-slate-400">Soumis le</p><p class="font-medium text-slate-800">{{ selected.submittedAt ? formatDateTime(selected.submittedAt) : '-' }}</p></div><div><p class="text-xs text-slate-400">Pays</p><p class="font-medium text-slate-800">Benin</p></div></div>
          <button v-for="document in selected.documents" :key="document.id" class="flex w-full items-center justify-between rounded-xl border border-slate-200 px-4 py-3 text-sm font-medium text-slate-700 hover:border-emerald-400" @click="showDocument(document.id)"><span class="flex items-center gap-2"><ShieldAlert class="h-4 w-4 text-emerald-600" /> Voir la piece</span><Loader2 v-if="isDocumentLoading" class="h-4 w-4 animate-spin" /></button>
          <iframe v-if="documentUrl" :src="documentUrl" class="h-64 w-full rounded-xl border border-slate-200" title="Document KYC" />
          <div v-if="selected.status === 'pending_review'" class="space-y-3 border-t border-slate-100 pt-4"><textarea v-model="reason" rows="3" class="w-full rounded-xl border border-slate-200 px-3 py-2 text-sm" placeholder="Motif si rejet ou suspension" /><div class="grid grid-cols-3 gap-2"><button class="rounded-xl bg-emerald-600 px-3 py-2 text-xs font-semibold text-white hover:bg-emerald-700" :disabled="store.isMutating" @click="review('verified')"><CheckCircle2 class="mx-auto h-4 w-4" /></button><button class="rounded-xl bg-red-600 px-3 py-2 text-xs font-semibold text-white hover:bg-red-700" :disabled="store.isMutating" @click="review('rejected')"><XCircle class="mx-auto h-4 w-4" /></button><button class="rounded-xl bg-slate-700 px-3 py-2 text-xs font-semibold text-white hover:bg-slate-800" :disabled="store.isMutating" @click="review('suspended')"><Clock3 class="mx-auto h-4 w-4" /></button></div><div class="flex justify-between text-[11px] text-slate-400"><span>Valider</span><span>Rejeter</span><span>Suspendre</span></div></div>
          <div v-if="actionError" class="rounded-xl bg-red-50 p-3 text-xs text-red-700">{{ actionError }}</div><button class="text-xs font-semibold text-slate-500 underline" @click="closeCase">Fermer le detail</button>
        </div>
      </aside>
    </div>
  </div>
</template>
