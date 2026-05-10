<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { adminLogin } from '@/lib/admin-api'

const router = useRouter()
const username = ref('admin')
const password = ref('')
const isSubmitting = ref(false)
const errorMessage = ref('')

async function submit() {
  errorMessage.value = ''
  isSubmitting.value = true

  try {
    await adminLogin(username.value, password.value)
    await router.push('/supervision/commissions')
  } catch (error) {
    errorMessage.value = error instanceof Error ? error.message : 'Connexion impossible.'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="flex min-h-screen items-center justify-center bg-slate-950 px-4">
    <div class="w-full max-w-md rounded-3xl bg-white p-8 shadow-xl">
      <p class="text-sm uppercase tracking-[0.2em] text-amber-600">VizioBox Admin</p>
      <h1 class="mt-3 text-3xl font-semibold text-slate-900">Connexion supervision</h1>
      <p class="mt-2 text-sm text-slate-500">
        Accès lecture et pilotage des commissions plateforme.
      </p>

      <div v-if="errorMessage" class="mt-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {{ errorMessage }}
      </div>

      <form class="mt-6 space-y-4" @submit.prevent="submit">
        <div>
          <label class="mb-2 block text-sm font-medium text-slate-700">Identifiant</label>
          <input
            v-model="username"
            class="w-full rounded-xl border border-slate-200 px-4 py-3 outline-none ring-0 transition focus:border-amber-400"
            type="text"
            autocomplete="username"
          />
        </div>

        <div>
          <label class="mb-2 block text-sm font-medium text-slate-700">Mot de passe</label>
          <input
            v-model="password"
            class="w-full rounded-xl border border-slate-200 px-4 py-3 outline-none ring-0 transition focus:border-amber-400"
            type="password"
            autocomplete="current-password"
          />
        </div>

        <button
          class="w-full rounded-xl bg-amber-400 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-amber-300 disabled:cursor-not-allowed disabled:opacity-60"
          type="submit"
          :disabled="isSubmitting"
        >
          {{ isSubmitting ? 'Connexion...' : 'Se connecter' }}
        </button>
      </form>
    </div>
  </div>
</template>
