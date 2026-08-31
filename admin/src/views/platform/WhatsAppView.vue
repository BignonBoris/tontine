<script setup lang="ts">
import { onMounted, onUnmounted, ref } from "vue";
import { fetchWhatsAppStatus, refreshWhatsAppStatus, type WhatsAppStatus } from "@/lib/admin-api";
import { Loader2, RefreshCw, Smartphone, CheckCircle, AlertTriangle, LogOut } from "lucide-vue-next";

const status = ref<WhatsAppStatus | null>(null);
const isLoading = ref(true);
const isRefreshing = ref(false);
const errorMessage = ref("");
let pollInterval: any = null;

async function loadStatus(showLoader = false) {
  if (showLoader) isLoading.value = true;
  errorMessage.value = "";
  try {
    const res = await fetchWhatsAppStatus();
    status.value = res;
    
    // Auto-adjust polling: if initializing or qr_ready, we should keep polling
    if (res.status === 'initializing' || res.status === 'qr_ready' || res.status === 'disconnected') {
      startPolling();
    } else {
      stopPolling();
    }
  } catch (error: any) {
    errorMessage.value = error.message || "Erreur de chargement du statut.";
  } finally {
    if (showLoader) isLoading.value = false;
  }
}

async function triggerRefresh(forceNewSession = false) {
  isRefreshing.value = true;
  errorMessage.value = "";
  try {
    await refreshWhatsAppStatus(forceNewSession);
    // Wait a brief moment and reload
    setTimeout(() => {
      loadStatus(false);
      isRefreshing.value = false;
    }, 1500);
  } catch (error: any) {
    errorMessage.value = error.message || "Impossible de réinitialiser WhatsApp.";
    isRefreshing.value = false;
  }
}

function startPolling() {
  if (pollInterval) return;
  pollInterval = setInterval(() => {
    loadStatus(false);
  }, 5000);
}

function stopPolling() {
  if (pollInterval) {
    clearInterval(pollInterval);
    pollInterval = null;
  }
}

function statusClass(s?: string) {
  switch (s) {
    case 'ready':
      return 'bg-emerald-100 text-emerald-800 border-emerald-200';
    case 'initializing':
      return 'bg-amber-100 text-amber-800 border-amber-200';
    case 'qr_ready':
      return 'bg-blue-100 text-blue-800 border-blue-200';
    case 'auth_failure':
    case 'disconnected':
    default:
      return 'bg-red-100 text-red-800 border-red-200';
  }
}

const statusLabel: Record<string, string> = {
  disconnected: "Déconnecté",
  initializing: "Initialisation du navigateur...",
  qr_ready: "Prêt à scanner",
  ready: "Connecté et opérationnel",
  auth_failure: "Échec d'authentification",
};

onMounted(() => {
  loadStatus(true);
});

onUnmounted(() => {
  stopPolling();
});
</script>

<template>
  <div class="space-y-6">
    <div>
      <p class="text-sm font-semibold uppercase tracking-[0.18em] text-emerald-700">Paramètres Système</p>
      <h1 class="text-3xl font-bold text-slate-900">Configuration WhatsApp Gateway</h1>
      <p class="mt-1 text-sm text-slate-500">
        Gérez la passerelle d'envoi d'OTP et d'alertes via WhatsApp Web (Open-Source).
      </p>
    </div>

    <div v-if="errorMessage" class="rounded-xl bg-red-50 p-4 text-sm text-red-700">
      {{ errorMessage }}
    </div>

    <div class="grid gap-6 md:grid-cols-2">
      <!-- Card Status -->
      <section class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm space-y-6">
        <div class="flex items-center justify-between border-b border-slate-100 pb-4">
          <h2 class="font-semibold text-slate-900 flex items-center gap-2">
            <Smartphone class="h-5 w-5 text-slate-500" />
            Statut de la Passerelle
          </h2>
          <span v-if="status" class="rounded-full border px-3 py-1 text-xs font-semibold" :class="statusClass(status.status)">
            {{ statusLabel[status.status] || status.status }}
          </span>
        </div>

        <div v-if="isLoading" class="flex items-center gap-2 text-sm text-slate-500 py-6">
          <Loader2 class="h-5 w-5 animate-spin text-emerald-600" />
          Chargement du statut actuel...
        </div>

        <div v-else-if="status" class="space-y-6">
          <!-- Ready State -->
          <div v-if="status.status === 'ready'" class="flex flex-col items-center py-6 text-center space-y-3">
            <div class="rounded-full bg-emerald-100 p-4 text-emerald-600">
              <CheckCircle class="h-12 w-12" />
            </div>
            <h3 class="text-lg font-bold text-slate-900">Connexion Établie</h3>
            <p class="text-sm text-slate-500 max-w-sm">
              L'API WhatsApp Web fonctionne correctement. Les codes OTP d'inscription et de connexion sont acheminés en temps réel.
            </p>
          </div>

          <!-- Initializing State -->
          <div v-else-if="status.status === 'initializing'" class="flex flex-col items-center py-6 text-center space-y-3">
            <Loader2 class="h-12 w-12 animate-spin text-amber-600" />
            <h3 class="text-lg font-bold text-slate-900">Démarrage du Navigateur Virtuel...</h3>
            <p class="text-sm text-slate-500 max-w-sm">
              L'API démarre une instance Puppeteer en arrière-plan et charge WhatsApp Web. Veuillez patienter...
            </p>
          </div>

          <!-- Disconnected or failure State -->
          <div v-else-if="status.status === 'disconnected' || status.status === 'auth_failure'" class="flex flex-col items-center py-6 text-center space-y-3">
            <div class="rounded-full bg-red-100 p-4 text-red-600">
              <AlertTriangle class="h-12 w-12" />
            </div>
            <h3 class="text-lg font-bold text-slate-900">Passerelle Déconnectée</h3>
            <p class="text-sm text-slate-500 max-w-sm">
              Le service est actuellement déconnecté. Vous devez scanner le QR Code pour lier un compte WhatsApp.
            </p>
          </div>

          <!-- Error Message Log -->
          <div v-if="status.lastError" class="rounded-xl bg-amber-50 border border-amber-200 p-4 text-sm text-amber-800 space-y-1">
            <div class="font-semibold flex items-center gap-1.5">
              <AlertTriangle class="h-4 w-4" />
              Journal d'erreur ou avertissement
            </div>
            <pre class="text-xs font-mono whitespace-pre-wrap mt-1 opacity-90">{{ status.lastError }}</pre>
          </div>

          <!-- Quick Actions Button Group -->
          <div class="flex flex-wrap gap-3 border-t border-slate-100 pt-4">
            <button 
              @click="triggerRefresh(false)" 
              class="flex items-center gap-2 rounded-xl bg-slate-100 hover:bg-slate-200 px-4 py-2.5 text-sm font-semibold text-slate-700 transition"
              :disabled="isRefreshing"
            >
              <RefreshCw class="h-4 w-4" :class="isRefreshing ? 'animate-spin' : ''" />
              Rafraîchir
            </button>
            
            <button 
              @click="triggerRefresh(true)" 
              class="flex items-center gap-2 rounded-xl bg-red-50 hover:bg-red-100 border border-red-100 px-4 py-2.5 text-sm font-semibold text-red-700 transition ml-auto"
              :disabled="isRefreshing"
            >
              <LogOut class="h-4 w-4" />
              Réinitialiser la session
            </button>
          </div>
        </div>
      </section>

      <!-- Card QR Code -->
      <section class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm flex flex-col justify-between">
        <div class="border-b border-slate-100 pb-4">
          <h2 class="font-semibold text-slate-900">
            Liaison de Compte
          </h2>
          <p class="text-xs text-slate-400 mt-1">
            Associez le numéro de téléphone utilisé par l'API pour l'expédition des messages.
          </p>
        </div>

        <div v-if="status && status.status === 'qr_ready' && status.qrCode" class="flex flex-col items-center py-6 space-y-4">
          <div class="rounded-xl border-4 border-slate-900 bg-white p-2">
            <img 
              :src="`https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${encodeURIComponent(status.qrCode)}`" 
              alt="QR Code WhatsApp a scanner" 
              class="h-[230px] w-[230px]"
            />
          </div>
          <div class="text-center space-y-1">
            <p class="text-sm font-bold text-slate-800">Scan Requis</p>
            <p class="text-xs text-slate-400 max-w-[280px]">
              Ouvrez WhatsApp sur votre smartphone > Appareils connectés > Connecter un appareil, puis scannez ce code.
            </p>
          </div>
        </div>

        <div v-else-if="status && status.status === 'ready'" class="flex flex-col items-center justify-center py-12 text-slate-400 space-y-2">
          <CheckCircle class="h-16 w-16 text-emerald-500" />
          <p class="font-semibold text-slate-700 mt-2">Appareil lié</p>
          <p class="text-xs text-center max-w-[240px]">
            La session est enregistrée localement. Aucune action n'est requise.
          </p>
        </div>

        <div v-else class="flex flex-col items-center justify-center py-16 text-slate-300 space-y-3">
          <Loader2 class="h-10 w-10 animate-spin text-slate-300" v-if="status && status.status === 'initializing'" />
          <Smartphone class="h-16 w-16" v-else />
          <p class="text-sm font-medium text-slate-400">
            Attente du démarrage du navigateur...
          </p>
        </div>

        <div class="border-t border-slate-100 pt-4 text-center">
          <p class="text-[11px] text-slate-400">
            Les messages sont envoyés à un tarif de 0 FCFA en s'appuyant sur le protocole WhatsApp Web.
          </p>
        </div>
      </section>
    </div>
  </div>
</template>
