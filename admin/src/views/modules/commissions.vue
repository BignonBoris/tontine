<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import {
  adminTokenStorage,
  fetchAgentCommissionDetail,
  fetchCommissionOverview,
} from '@/lib/admin-api'

type Wallet = {
  id: string
  balance: number
  payableBalance: number
  blockedBalance: number
  currency: string
}

type AgentWallet = Wallet & {
  walletType: string
  ownerId: string
  agent: {
    id: string
    agentCode: string
    fullName: string
    phoneNumber: string | null
  } | null
}

type Entry = {
  id: string
  reference: string
  entryType: string
  commissionBucket: string
  amount: number
  direction: string
  sourceType: string
  sourceId: string | null
  createdAt: string
}

type AgentDetail = {
  agent: {
    id: string
    userId: string
    agentCode: string
    fullName: string
    phoneNumber: string | null
    isActive: boolean
  }
  wallet: Wallet | null
  totalsByBucket: Array<{ bucket: string; amount: number }>
  activity: {
    provisioningsCount: number
    provisioningsAmount: number
    paidWithdrawalsCount: number
    paidWithdrawalsAmount: number
  }
  recentEntries: Entry[]
}

const isLoading = ref(true)
const errorMessage = ref('')
const platformWallet = ref<Wallet | null>(null)
const floatingWallet = ref<Wallet | null>(null)
const totalsByBucket = ref<Array<{ bucket: string; amount: number }>>([])
const agentWallets = ref<AgentWallet[]>([])
const recentEntries = ref<Entry[]>([])
const selectedAgentDetail = ref<AgentDetail | null>(null)
const isAgentDetailLoading = ref(false)
const agentDetailError = ref('')
const router = useRouter()

const totalAgentCommission = computed(() =>
  agentWallets.value.reduce((sum, wallet) => sum + Number(wallet.balance || 0), 0),
)

function formatFcfa(value: number | null | undefined) {
  const amount = Number(value || 0)
  return new Intl.NumberFormat('fr-FR', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  }).format(amount)
}

function formatDate(value: string | null | undefined) {
  if (!value) {
    return '-'
  }

  const parsed = new Date(value)
  if (Number.isNaN(parsed.getTime())) {
    return '-'
  }

  return new Intl.DateTimeFormat('fr-FR', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(parsed)
}

async function loadOverview() {
  if (!adminTokenStorage.get()) {
    await router.push('/auth/admin-login')
    return
  }

  isLoading.value = true
  errorMessage.value = ''

  try {
    const data = await fetchCommissionOverview()
    platformWallet.value = data.platformWallet || null
    floatingWallet.value = data.floatingWallet || null
    totalsByBucket.value = data.totalsByBucket || []
    agentWallets.value = data.agentWallets || []
    recentEntries.value = data.recentEntries || []
  } catch (error) {
    errorMessage.value = error instanceof Error ? error.message : 'Chargement impossible.'
  } finally {
    isLoading.value = false
  }
}

async function openAgentDetail(agentId: string) {
  isAgentDetailLoading.value = true
  agentDetailError.value = ''
  selectedAgentDetail.value = null

  try {
    const data = await fetchAgentCommissionDetail(agentId)
    selectedAgentDetail.value = data
  } catch (error) {
    agentDetailError.value =
      error instanceof Error ? error.message : 'Chargement du détail impossible.'
  } finally {
    isAgentDetailLoading.value = false
  }
}

function closeAgentDetail() {
  selectedAgentDetail.value = null
  agentDetailError.value = ''
  isAgentDetailLoading.value = false
}

onMounted(loadOverview)
</script>

<template>
  <div class="space-y-6">
    <div class="rounded-3xl bg-slate-950 p-6 text-white shadow-sm">
      <p class="text-sm uppercase tracking-[0.2em] text-amber-300">VizioBox Supervision</p>
      <div class="mt-3 flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 class="text-3xl font-semibold">Commissions</h1>
          <p class="mt-2 max-w-2xl text-sm text-slate-300">
            Vue de lecture sur le revenu plateforme, le flottant et les commissions
            terrain des agents.
          </p>
        </div>
        <button
          class="rounded-xl bg-amber-400 px-4 py-2 text-sm font-semibold text-slate-950 transition hover:bg-amber-300"
          type="button"
          @click="loadOverview"
        >
          Actualiser
        </button>
      </div>
    </div>

    <div
      v-if="errorMessage"
      class="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700"
    >
      {{ errorMessage }}
    </div>

    <div
      v-if="isLoading"
      class="rounded-2xl border border-slate-200 bg-white p-6 text-sm text-slate-500"
    >
      Chargement des commissions...
    </div>

    <template v-else>
      <div class="grid gap-4 md:grid-cols-3">
        <div class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <p class="text-sm text-slate-500">Plateforme</p>
          <p class="mt-3 text-2xl font-semibold text-slate-900">
            {{ formatFcfa(platformWallet?.balance) }} FCFA
          </p>
          <p class="mt-2 text-xs text-slate-500">
            Payable: {{ formatFcfa(platformWallet?.payableBalance) }} FCFA
          </p>
        </div>

        <div class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <p class="text-sm text-slate-500">Flottant</p>
          <p class="mt-3 text-2xl font-semibold text-slate-900">
            {{ formatFcfa(floatingWallet?.balance) }} FCFA
          </p>
          <p class="mt-2 text-xs text-slate-500">
            Suivi statistique séparé du revenu plateforme
          </p>
        </div>

        <div class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <p class="text-sm text-slate-500">Commissions agents</p>
          <p class="mt-3 text-2xl font-semibold text-slate-900">
            {{ formatFcfa(totalAgentCommission) }} FCFA
          </p>
          <p class="mt-2 text-xs text-slate-500">
            {{ agentWallets.length }} wallet(s) agent suivis
          </p>
        </div>
      </div>

      <div class="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <div class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold text-slate-900">Agents commissionnés</h2>
            <span class="text-xs text-slate-500">Top par solde</span>
          </div>

          <div class="mt-4 overflow-x-auto">
            <table class="min-w-full text-sm">
              <thead class="text-left text-slate-500">
                <tr>
                  <th class="pb-3 pr-4 font-medium">Agent</th>
                  <th class="pb-3 pr-4 font-medium">Code</th>
                  <th class="pb-3 pr-4 font-medium">Solde</th>
                  <th class="pb-3 pr-4 font-medium">Payable</th>
                  <th class="pb-3 pr-4 font-medium">Action</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="wallet in agentWallets"
                  :key="wallet.id"
                  class="border-t border-slate-100"
                >
                  <td class="py-3 pr-4">
                    <div class="font-medium text-slate-900">
                      {{ wallet.agent?.fullName || 'Agent inconnu' }}
                    </div>
                    <div class="text-xs text-slate-500">
                      {{ wallet.agent?.phoneNumber || 'Telephone indisponible' }}
                    </div>
                  </td>
                  <td class="py-3 pr-4 text-slate-600">
                    {{ wallet.agent?.agentCode || '-' }}
                  </td>
                  <td class="py-3 pr-4 font-medium text-slate-900">
                    {{ formatFcfa(wallet.balance) }}
                  </td>
                  <td class="py-3 pr-4 text-slate-600">
                    {{ formatFcfa(wallet.payableBalance) }}
                  </td>
                  <td class="py-3 pr-4">
                    <button
                      class="rounded-lg border border-slate-200 px-3 py-2 text-xs font-medium text-slate-700 transition hover:border-amber-300 hover:text-slate-950"
                      type="button"
                      :disabled="!wallet.agent?.id"
                      @click="wallet.agent?.id && openAgentDetail(wallet.agent.id)"
                    >
                      Voir détail
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold text-slate-900">Buckets</h2>
            <span class="text-xs text-slate-500">Ledger posté</span>
          </div>

          <div class="mt-4 space-y-3">
            <div
              v-for="bucket in totalsByBucket"
              :key="bucket.bucket"
              class="rounded-xl bg-slate-50 px-4 py-3"
            >
              <div class="flex items-center justify-between gap-3">
                <span class="text-sm font-medium text-slate-700">{{ bucket.bucket }}</span>
                <span class="text-sm font-semibold text-slate-900">
                  {{ formatFcfa(bucket.amount) }} FCFA
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <div class="flex items-center justify-between">
          <h2 class="text-lg font-semibold text-slate-900">Dernières écritures</h2>
          <span class="text-xs text-slate-500">Ledger commission</span>
        </div>

        <div class="mt-4 overflow-x-auto">
          <table class="min-w-full text-sm">
            <thead class="text-left text-slate-500">
              <tr>
                <th class="pb-3 pr-4 font-medium">Référence</th>
                <th class="pb-3 pr-4 font-medium">Bucket</th>
                <th class="pb-3 pr-4 font-medium">Type</th>
                <th class="pb-3 pr-4 font-medium">Montant</th>
                <th class="pb-3 pr-4 font-medium">Source</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="entry in recentEntries"
                :key="entry.id"
                class="border-t border-slate-100"
              >
                <td class="py-3 pr-4 font-medium text-slate-900">{{ entry.reference }}</td>
                <td class="py-3 pr-4 text-slate-600">{{ entry.commissionBucket }}</td>
                <td class="py-3 pr-4 text-slate-600">{{ entry.entryType }}</td>
                <td class="py-3 pr-4 font-medium text-slate-900">
                  {{ formatFcfa(entry.amount) }}
                </td>
                <td class="py-3 pr-4 text-slate-600">
                  {{ entry.sourceType }}<span v-if="entry.sourceId"> / {{ entry.sourceId }}</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <div
      v-if="selectedAgentDetail || isAgentDetailLoading || agentDetailError"
      class="fixed inset-0 z-50 bg-slate-950/50 px-4 py-8"
    >
      <div class="mx-auto h-full max-w-5xl overflow-hidden rounded-3xl bg-white shadow-2xl">
        <div class="flex items-center justify-between border-b border-slate-100 px-6 py-4">
          <div>
            <h2 class="text-xl font-semibold text-slate-900">Détail commission agent</h2>
            <p class="mt-1 text-sm text-slate-500">
              Historique et activité opérationnelle de l’agent.
            </p>
          </div>
          <button
            class="rounded-lg border border-slate-200 px-3 py-2 text-sm font-medium text-slate-700 transition hover:bg-slate-50"
            type="button"
            @click="closeAgentDetail"
          >
            Fermer
          </button>
        </div>

        <div class="h-[calc(100%-81px)] overflow-y-auto px-6 py-5">
          <div
            v-if="isAgentDetailLoading"
            class="rounded-2xl border border-slate-200 bg-slate-50 p-4 text-sm text-slate-500"
          >
            Chargement du détail agent...
          </div>

          <div
            v-else-if="agentDetailError"
            class="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700"
          >
            {{ agentDetailError }}
          </div>

          <template v-else-if="selectedAgentDetail">
            <div class="grid gap-4 md:grid-cols-3">
              <div class="rounded-2xl border border-slate-200 bg-white p-5">
                <p class="text-xs uppercase tracking-wide text-slate-500">Agent</p>
                <h3 class="mt-2 text-lg font-semibold text-slate-900">
                  {{ selectedAgentDetail.agent.fullName }}
                </h3>
                <p class="mt-1 text-sm text-slate-500">
                  {{ selectedAgentDetail.agent.agentCode }}<span v-if="selectedAgentDetail.agent.phoneNumber">
                    · {{ selectedAgentDetail.agent.phoneNumber }}
                  </span>
                </p>
              </div>

              <div class="rounded-2xl border border-slate-200 bg-white p-5">
                <p class="text-xs uppercase tracking-wide text-slate-500">Solde commission</p>
                <h3 class="mt-2 text-lg font-semibold text-slate-900">
                  {{ formatFcfa(selectedAgentDetail.wallet?.balance) }} FCFA
                </h3>
                <p class="mt-1 text-sm text-slate-500">
                  Payable: {{ formatFcfa(selectedAgentDetail.wallet?.payableBalance) }} FCFA
                </p>
              </div>

              <div class="rounded-2xl border border-slate-200 bg-white p-5">
                <p class="text-xs uppercase tracking-wide text-slate-500">Activité</p>
                <p class="mt-2 text-sm text-slate-700">
                  Dépôts: {{ selectedAgentDetail.activity.provisioningsCount }} /
                  {{ formatFcfa(selectedAgentDetail.activity.provisioningsAmount) }} FCFA
                </p>
                <p class="mt-1 text-sm text-slate-700">
                  Retraits payés: {{ selectedAgentDetail.activity.paidWithdrawalsCount }} /
                  {{ formatFcfa(selectedAgentDetail.activity.paidWithdrawalsAmount) }} FCFA
                </p>
              </div>
            </div>

            <div class="mt-6 grid gap-6 xl:grid-cols-[0.8fr_1.2fr]">
              <div class="rounded-2xl border border-slate-200 bg-white p-5">
                <h3 class="text-lg font-semibold text-slate-900">Buckets agent</h3>
                <div class="mt-4 space-y-3">
                  <div
                    v-for="bucket in selectedAgentDetail.totalsByBucket"
                    :key="bucket.bucket"
                    class="rounded-xl bg-slate-50 px-4 py-3"
                  >
                    <div class="flex items-center justify-between gap-3">
                      <span class="text-sm font-medium text-slate-700">{{ bucket.bucket }}</span>
                      <span class="text-sm font-semibold text-slate-900">
                        {{ formatFcfa(bucket.amount) }} FCFA
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              <div class="rounded-2xl border border-slate-200 bg-white p-5">
                <h3 class="text-lg font-semibold text-slate-900">Écritures récentes</h3>
                <div class="mt-4 overflow-x-auto">
                  <table class="min-w-full text-sm">
                    <thead class="text-left text-slate-500">
                      <tr>
                        <th class="pb-3 pr-4 font-medium">Date</th>
                        <th class="pb-3 pr-4 font-medium">Référence</th>
                        <th class="pb-3 pr-4 font-medium">Bucket</th>
                        <th class="pb-3 pr-4 font-medium">Type</th>
                        <th class="pb-3 pr-4 font-medium">Montant</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr
                        v-for="entry in selectedAgentDetail.recentEntries"
                        :key="entry.id"
                        class="border-t border-slate-100"
                      >
                        <td class="py-3 pr-4 text-slate-600">{{ formatDate(entry.createdAt) }}</td>
                        <td class="py-3 pr-4 font-medium text-slate-900">{{ entry.reference }}</td>
                        <td class="py-3 pr-4 text-slate-600">{{ entry.commissionBucket }}</td>
                        <td class="py-3 pr-4 text-slate-600">{{ entry.entryType }}</td>
                        <td class="py-3 pr-4 font-medium text-slate-900">
                          {{ formatFcfa(entry.amount) }}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </template>
        </div>
      </div>
    </div>
  </div>
</template>
