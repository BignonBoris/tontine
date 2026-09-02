<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import {
  adminTokenStorage,
  createGoalTemplate,
  deleteGoalTemplate,
  fetchGoalTemplates,
  updateGoalTemplate,
  type GoalTemplate,
} from '@/lib/admin-api'

// Icônes Material proposées aux administrateurs (code points stables Material Icons).
const iconPresets = [
  { codePoint: 0xe80c, label: 'École (chapeau)', icon: '🎓' },
  { codePoint: 0xe8d1, label: 'Commerce (magasin)', icon: '🏪' },
  { codePoint: 0xe8f6, label: 'Cadeau / Fêtes', icon: '🎁' },
  { codePoint: 0xe88a, label: 'Maison / Construction', icon: '🏠' },
  { codePoint: 0xe8f3, label: 'Santé / Urgences', icon: '🏥' },
  { codePoint: 0xe87d, label: 'Épargne / Général', icon: '⭐' },
  { codePoint: 0xe531, label: 'Transport / Véhicule', icon: '🛵' },
  { codePoint: 0xe30a, label: 'Projets / Tech', icon: '💼' },
]

// Couleurs prédéfinies VizioBox
const colorPresets = [
  { hex: '#1565c0', label: 'Bleu Royal' },
  { hex: '#6a1b9a', label: 'Violet Profond' },
  { hex: '#b45309', label: 'Ambre Doré' },
  { hex: '#2e7d32', label: 'Vert Émeraude' },
  { hex: '#c62828', label: 'Rouge Sécurité' },
  { hex: '#00838f', label: 'Teal Turquoise' },
  { hex: '#ad1457', label: 'Rose Cérémonie' },
  { hex: '#0a192f', label: 'Bleu Nuit Vizio' },
]

const isLoading = ref(true)
const errorMessage = ref('')
const noticeMessage = ref('')
const templates = ref<GoalTemplate[]>([])
const router = useRouter()

const isDialogOpen = ref(false)
const isSaving = ref(false)
const isDeletingId = ref<string | null>(null)
const editingId = ref<string | null>(null)

// Formulaire
const formLabel = ref('')
const formDescription = ref('')
const formIconCodePoint = ref<number>(iconPresets[0].codePoint)
const formColorHex = ref('#1565c0')
const formTargetAmount = ref<number | null>(null)
const formSortOrder = ref<number>(1)
const formIsActive = ref(true)

const activeCount = computed(() => templates.value.filter((t) => t.isActive).length)
const inactiveCount = computed(() => templates.value.filter((t) => !t.isActive).length)

function formatFcfa(value: number | null | undefined) {
  const amount = Number(value || 0)
  return new Intl.NumberFormat('fr-FR', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount)
}

function colorHexToValue(hex: string): number {
  const parsed = Number.parseInt(hex.replace('#', ''), 16)
  if (!Number.isFinite(parsed)) {
    return 0xff1565c0
  }
  return 0xff000000 + parsed
}

function colorValueToHex(value: number): string {
  const rgb = Number(value) & 0xffffff
  return `#${rgb.toString(16).padStart(6, '0')}`
}

function getIconEmoji(codePoint: number): string {
  const match = iconPresets.find((p) => p.codePoint === codePoint)
  return match?.icon || '🎯'
}

async function loadTemplates() {
  if (!adminTokenStorage.get()) {
    await router.push('/auth/admin-login')
    return
  }

  isLoading.value = true
  errorMessage.value = ''

  try {
    templates.value = await fetchGoalTemplates()
  } catch (error) {
    errorMessage.value =
      error instanceof Error ? error.message : 'Chargement des coffres impossible.'
  } finally {
    isLoading.value = false
  }
}

function openCreateDialog() {
  editingId.value = null
  formLabel.value = ''
  formDescription.value = ''
  formIconCodePoint.value = iconPresets[0].codePoint
  formColorHex.value = colorPresets[0].hex
  formTargetAmount.value = 50000
  formSortOrder.value = (templates.value.length + 1)
  formIsActive.value = true
  errorMessage.value = ''
  isDialogOpen.value = true
}

function openEditDialog(template: GoalTemplate) {
  editingId.value = template.id
  formLabel.value = template.label
  formDescription.value = template.description || ''
  formIconCodePoint.value = Number(template.iconCodePoint)
  formColorHex.value = colorValueToHex(Number(template.colorValue))
  formTargetAmount.value =
    template.defaultTargetAmount == null
      ? null
      : Number(template.defaultTargetAmount)
  formSortOrder.value = Number(template.sortOrder || 1)
  formIsActive.value = Boolean(template.isActive)
  errorMessage.value = ''
  isDialogOpen.value = true
}

function closeDialog() {
  isDialogOpen.value = false
  isSaving.value = false
}

async function submitForm() {
  if (formLabel.value.trim().length < 3) {
    errorMessage.value = 'Le libellé doit contenir au moins 3 caractères.'
    return
  }

  isSaving.value = true
  errorMessage.value = ''
  noticeMessage.value = ''

  const payload = {
    label: formLabel.value.trim(),
    description: formDescription.value.trim() || null,
    iconCodePoint: formIconCodePoint.value,
    colorValue: colorHexToValue(formColorHex.value),
    defaultTargetAmount:
      formTargetAmount.value == null ? null : Number(formTargetAmount.value),
    sortOrder: Number(formSortOrder.value || 0),
    isActive: formIsActive.value,
  }

  try {
    if (editingId.value) {
      await updateGoalTemplate(editingId.value, payload)
      noticeMessage.value = 'Modèle de box mis à jour avec succès.'
    } else {
      await createGoalTemplate(payload)
      noticeMessage.value = 'Nouveau modèle de box créé avec succès.'
    }
    isDialogOpen.value = false
    await loadTemplates()
  } catch (error) {
    errorMessage.value =
      error instanceof Error ? error.message : 'Enregistrement impossible.'
  } finally {
    isSaving.value = false
  }
}

async function handleToggleActive(template: GoalTemplate) {
  try {
    await updateGoalTemplate(template.id, {
      label: template.label,
      description: template.description,
      iconCodePoint: template.iconCodePoint,
      colorValue: template.colorValue,
      defaultTargetAmount: template.defaultTargetAmount,
      sortOrder: template.sortOrder,
      isActive: !template.isActive,
    })
    noticeMessage.value = `Modèle "${template.label}" ${!template.isActive ? 'activé' : 'désactivé'}.`
    await loadTemplates()
  } catch (error) {
    errorMessage.value = 'Impossible de modifier le statut.'
  }
}

async function handleDeleteTemplate(template: GoalTemplate) {
  if (!confirm(`Supprimer définitivement le modèle "${template.label}" ?`)) {
    return
  }

  isDeletingId.value = template.id
  errorMessage.value = ''
  noticeMessage.value = ''

  try {
    await deleteGoalTemplate(template.id)
    noticeMessage.value = `Modèle "${template.label}" supprimé.`
    await loadTemplates()
  } catch (error) {
    errorMessage.value =
      error instanceof Error ? error.message : 'Suppression impossible.'
  } finally {
    isDeletingId.value = null
  }
}

onMounted(loadTemplates)
</script>

<template>
  <div class="space-y-6">
    <!-- En-tête / Bannière Principale -->
    <div class="rounded-3xl bg-slate-950 p-6 text-white shadow-sm">
      <p class="text-sm uppercase tracking-[0.2em] text-amber-300">
        VizioBox Configuration • Onboarding Client
      </p>
      <div class="mt-3 flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 class="text-3xl font-semibold">Coffres par défaut (Boxs)</h1>
          <p class="mt-2 max-w-2xl text-sm text-slate-300">
            Gérez les modèles de projets proposés aux nouveaux clients lors de l'onboarding mobile (1 à 3 choix max).
            Les clients retrouvent ces boxs pré-créées sur leur tableau de bord dès leur première visite.
          </p>
        </div>
        <div class="flex items-center gap-3">
          <button
            class="rounded-xl border border-slate-700 bg-slate-900 px-4 py-2.5 text-sm font-semibold text-slate-200 transition hover:bg-slate-800"
            type="button"
            @click="loadTemplates"
          >
            Actualiser
          </button>
          <button
            class="flex items-center gap-2 rounded-xl bg-amber-400 px-5 py-2.5 text-sm font-bold text-slate-950 shadow-sm transition hover:bg-amber-300"
            type="button"
            @click="openCreateDialog"
          >
            <span class="text-base">+</span> Nouveau modèle
          </button>
        </div>
      </div>
    </div>

    <!-- Notifications & Alertes -->
    <div
      v-if="noticeMessage"
      class="flex items-center justify-between rounded-2xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-800"
    >
      <div class="flex items-center gap-2">
        <span>✓</span>
        <span>{{ noticeMessage }}</span>
      </div>
      <button
        class="text-xs font-semibold text-emerald-600 hover:underline"
        @click="noticeMessage = ''"
      >
        Fermer
      </button>
    </div>

    <div
      v-if="errorMessage"
      class="flex items-center justify-between rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700"
    >
      <div class="flex items-center gap-2">
        <span>⚠️</span>
        <span>{{ errorMessage }}</span>
      </div>
      <button
        class="text-xs font-semibold text-red-600 hover:underline"
        @click="errorMessage = ''"
      >
        Fermer
      </button>
    </div>

    <!-- KPIs Synthétiques -->
    <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <div class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <p class="text-xs font-medium text-slate-500">Total Modèles</p>
        <p class="mt-2 text-2xl font-bold text-slate-900">{{ templates.length }}</p>
        <p class="mt-1 text-xs text-slate-400">Modèles configurés</p>
      </div>

      <div class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <p class="text-xs font-medium text-slate-500">Modèles Actifs</p>
        <p class="mt-2 text-2xl font-bold text-emerald-600">{{ activeCount }}</p>
        <p class="mt-1 text-xs text-slate-400">Visibles dans l'application mobile</p>
      </div>

      <div class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <p class="text-xs font-medium text-slate-500">Modèles Inactifs</p>
        <p class="mt-2 text-2xl font-bold text-slate-400">{{ inactiveCount }}</p>
        <p class="mt-1 text-xs text-slate-400">Désactivés du flux onboarding</p>
      </div>

      <div class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <p class="text-xs font-medium text-slate-500">Règle d'Onboarding</p>
        <p class="mt-2 text-2xl font-bold text-amber-500">1 à 3 boxs</p>
        <p class="mt-1 text-xs text-slate-400">Choix par nouveau membre</p>
      </div>
    </div>

    <!-- Chargement -->
    <div
      v-if="isLoading"
      class="flex items-center justify-center rounded-2xl border border-slate-200 bg-white p-12 text-sm text-slate-500"
    >
      <div class="flex items-center gap-3">
        <div class="h-5 w-5 animate-spin rounded-full border-2 border-slate-300 border-t-amber-500"></div>
        <span>Chargement des modèles de coffres...</span>
      </div>
    </div>

    <!-- Liste / Tableau des Modèles -->
    <div v-else class="rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div class="flex items-center justify-between border-b border-slate-100 p-5">
        <div>
          <h2 class="text-lg font-bold text-slate-900">Catalogue des Boxs par Défaut</h2>
          <p class="text-xs text-slate-500">
            L'ordre d'affichage détermine la position des cartes sur l'écran mobile.
          </p>
        </div>
      </div>

      <div v-if="templates.length === 0" class="p-8 text-center text-slate-500">
        <p class="text-base font-semibold">Aucun modèle de coffre configuré.</p>
        <p class="mt-1 text-xs text-slate-400">Cliquez sur « + Nouveau modèle » pour créer le premier.</p>
      </div>

      <div v-else class="overflow-x-auto">
        <table class="min-w-full text-left text-sm">
          <thead class="bg-slate-50 text-xs uppercase tracking-wider text-slate-500">
            <tr>
              <th class="px-6 py-3.5 font-semibold">Ordre</th>
              <th class="px-6 py-3.5 font-semibold">Aperçu</th>
              <th class="px-6 py-3.5 font-semibold">Libellé & Description</th>
              <th class="px-6 py-3.5 font-semibold">Montant Cible Suggéré</th>
              <th class="px-6 py-3.5 font-semibold">Statut</th>
              <th class="px-6 py-3.5 text-right font-semibold">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr
              v-for="template in templates"
              :key="template.id"
              class="transition hover:bg-slate-50/75"
            >
              <!-- Ordre -->
              <td class="px-6 py-4 font-mono text-xs font-semibold text-slate-400">
                #{{ template.sortOrder }}
              </td>

              <!-- Aperçu Icône & Couleur -->
              <td class="px-6 py-4">
                <div
                  class="flex h-11 w-11 items-center justify-center rounded-xl text-xl shadow-inner"
                  :style="{
                    backgroundColor: colorValueToHex(template.colorValue) + '1A',
                    borderColor: colorValueToHex(template.colorValue) + '40',
                    borderWidth: '1.5px',
                  }"
                >
                  <span>{{ getIconEmoji(template.iconCodePoint) }}</span>
                </div>
              </td>

              <!-- Libellé & Description -->
              <td class="px-6 py-4">
                <p class="font-semibold text-slate-900">{{ template.label }}</p>
                <p class="mt-0.5 max-w-md text-xs text-slate-500 line-clamp-1">
                  {{ template.description || 'Aucune description' }}
                </p>
              </td>

              <!-- Montant Cible -->
              <td class="px-6 py-4">
                <span
                  v-if="template.defaultTargetAmount"
                  class="inline-flex items-center rounded-lg bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-800"
                >
                  {{ formatFcfa(template.defaultTargetAmount) }} FCFA
                </span>
                <span v-else class="text-xs text-slate-400">Libre (non défini)</span>
              </td>

              <!-- Statut Switch -->
              <td class="px-6 py-4">
                <button
                  type="button"
                  class="inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-semibold transition"
                  :class="
                    template.isActive
                      ? 'bg-emerald-100 text-emerald-800 hover:bg-emerald-200'
                      : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                  "
                  @click="handleToggleActive(template)"
                >
                  <span
                    class="h-1.5 w-1.5 rounded-full"
                    :class="template.isActive ? 'bg-emerald-600' : 'bg-slate-400'"
                  ></span>
                  {{ template.isActive ? 'Actif' : 'Inactif' }}
                </button>
              </td>

              <!-- Actions -->
              <td class="px-6 py-4 text-right">
                <div class="flex items-center justify-end gap-2">
                  <button
                    type="button"
                    class="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-semibold text-slate-700 shadow-sm transition hover:bg-slate-50 hover:text-slate-900"
                    @click="openEditDialog(template)"
                  >
                    Modifier
                  </button>
                  <button
                    type="button"
                    class="rounded-lg border border-red-200 bg-white px-3 py-1.5 text-xs font-semibold text-red-600 shadow-sm transition hover:bg-red-50"
                    :disabled="isDeletingId === template.id"
                    @click="handleDeleteTemplate(template)"
                  >
                    {{ isDeletingId === template.id ? '...' : 'Supprimer' }}
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- MODAL / DIALOG DE CRÉATION & MODIFICATION -->
    <div
      v-if="isDialogOpen"
      class="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/60 p-4 backdrop-blur-sm"
    >
      <div class="w-full max-w-lg rounded-3xl bg-white p-6 shadow-2xl">
        <div class="flex items-center justify-between border-b border-slate-100 pb-4">
          <h3 class="text-lg font-bold text-slate-900">
            {{ editingId ? 'Modifier le modèle de box' : 'Créer un modèle de box' }}
          </h3>
          <button
            type="button"
            class="text-slate-400 hover:text-slate-600"
            @click="closeDialog"
          >
            ✕
          </button>
        </div>

        <form class="mt-4 space-y-4" @submit.prevent="submitForm">
          <!-- Libellé -->
          <div>
            <label class="block text-xs font-bold uppercase tracking-wider text-slate-600">
              Libellé du projet *
            </label>
            <input
              v-model="formLabel"
              type="text"
              required
              placeholder="Ex: École & Rentrée scolaire"
              class="mt-1.5 w-full rounded-xl border border-slate-200 px-3.5 py-2.5 text-sm text-slate-900 focus:border-amber-500 focus:outline-none focus:ring-1 focus:ring-amber-500"
            />
          </div>

          <!-- Description -->
          <div>
            <label class="block text-xs font-bold uppercase tracking-wider text-slate-600">
              Description synthétique
            </label>
            <textarea
              v-model="formDescription"
              rows="2"
              placeholder="Ex: Frais de scolarité, fournitures et tenues scolaires..."
              class="mt-1.5 w-full rounded-xl border border-slate-200 px-3.5 py-2 text-sm text-slate-900 focus:border-amber-500 focus:outline-none focus:ring-1 focus:ring-amber-500"
            ></textarea>
          </div>

          <!-- Choix d'icône -->
          <div>
            <label class="block text-xs font-bold uppercase tracking-wider text-slate-600">
              Icône représentative
            </label>
            <div class="mt-2 grid grid-cols-4 gap-2">
              <button
                v-for="preset in iconPresets"
                :key="preset.codePoint"
                type="button"
                class="flex flex-col items-center rounded-xl border p-2 text-center text-xs transition"
                :class="
                  formIconCodePoint === preset.codePoint
                    ? 'border-amber-500 bg-amber-50 font-bold text-amber-900'
                    : 'border-slate-200 bg-white text-slate-600 hover:bg-slate-50'
                "
                @click="formIconCodePoint = preset.codePoint"
              >
                <span class="text-xl">{{ preset.icon }}</span>
                <span class="mt-1 text-[10px] line-clamp-1">{{ preset.label.split(' ')[0] }}</span>
              </button>
            </div>
          </div>

          <!-- Choix de couleur -->
          <div>
            <label class="block text-xs font-bold uppercase tracking-wider text-slate-600">
              Couleur d'accentuation
            </label>
            <div class="mt-2 flex flex-wrap gap-2.5">
              <button
                v-for="color in colorPresets"
                :key="color.hex"
                type="button"
                class="h-8 w-8 rounded-full border-2 transition hover:scale-110"
                :style="{ backgroundColor: color.hex }"
                :class="formColorHex.toLowerCase() === color.hex.toLowerCase() ? 'border-slate-950 ring-2 ring-amber-400' : 'border-white'"
                :title="color.label"
                @click="formColorHex = color.hex"
              ></button>
            </div>
          </div>

          <!-- Montant & Ordre -->
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-bold uppercase tracking-wider text-slate-600">
                Cible suggérée (FCFA)
              </label>
              <input
                v-model.number="formTargetAmount"
                type="number"
                min="0"
                step="1000"
                placeholder="50000"
                class="mt-1.5 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm text-slate-900 focus:border-amber-500 focus:outline-none"
              />
            </div>
            <div>
              <label class="block text-xs font-bold uppercase tracking-wider text-slate-600">
                Ordre d'affichage
              </label>
              <input
                v-model.number="formSortOrder"
                type="number"
                min="1"
                placeholder="1"
                class="mt-1.5 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm text-slate-900 focus:border-amber-500 focus:outline-none"
              />
            </div>
          </div>

          <!-- Actif / Inactif -->
          <div class="flex items-center gap-2 pt-1">
            <input
              id="isActiveCheckbox"
              v-model="formIsActive"
              type="checkbox"
              class="h-4 w-4 rounded border-slate-300 text-amber-600 focus:ring-amber-500"
            />
            <label for="isActiveCheckbox" class="text-xs font-medium text-slate-700">
              Activer ce modèle dès maintenant pour les nouveaux clients
            </label>
          </div>

          <!-- Boutons Modal -->
          <div class="flex items-center justify-end gap-3 border-t border-slate-100 pt-4">
            <button
              type="button"
              class="rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-600 hover:bg-slate-50"
              @click="closeDialog"
            >
              Annuler
            </button>
            <button
              type="submit"
              class="rounded-xl bg-amber-400 px-5 py-2 text-sm font-bold text-slate-950 shadow-sm hover:bg-amber-300 disabled:opacity-50"
              :disabled="isSaving"
            >
              {{ isSaving ? 'Enregistrement...' : editingId ? 'Mettre à jour' : 'Créer le modèle' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>
