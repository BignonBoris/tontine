<script setup lang="ts">
import { ref } from "vue";
import { useRouter } from "vue-router";
import Button from "@/components/ui/button/Button.vue";
import Checkbox from "@/components/ui/checkbox/Checkbox.vue";
import Label from "@/components/ui/label/Label.vue";
import { Input } from "@/components/ui/input";
import { useAuthStore } from "@/stores/auth";
import { getErrorMessage } from "@/services/http/errors";

const router = useRouter();
const authStore = useAuthStore();

const username = ref("admin");
const password = ref("admin1234");
const rememberDevice = ref(true);
const formError = ref("");

async function onSubmit(event: Event) {
  event.preventDefault();
  formError.value = "";

  try {
    await authStore.login(username.value, password.value);
    await router.push("/dashboard");
  } catch (error) {
    formError.value = getErrorMessage(
      error,
      "Impossible d'ouvrir la session admin."
    );
  }
}
</script>

<template>
  <form @submit="onSubmit" class="mt-6">
    <div class="mb-4">
      <div className="mb-2 block">
        <Label for="Username">Nom d'utilisateur</Label>
      </div>
      <Input id="username" v-model="username" class="form-control" />
    </div>

    <div class="mb-4">
      <div className="mb-2 block">
        <Label for="userpwd">Mot de passe</Label>
      </div>
      <Input id="userpwd" type="password" v-model="password" class="form-control" />
    </div>

    <div class="flex justify-between my-5 items-center">
      <div class="flex items-center gap-2">
        <Checkbox id="accept" v-model="rememberDevice" class="checkbox" />
        <Label for="accept" class="opacity-90 font-normal cursor-pointer">
          Garder cette session
        </Label>
      </div>
      <span class="text-primary text-sm font-medium">
        Supervision securisee
      </span>
    </div>

    <div v-if="formError" class="mb-4 rounded-lg bg-red-50 px-4 py-3 text-sm text-red-600">
      {{ formError }}
    </div>

    <Button class="w-full" :disabled="authStore.isLoading">
      {{ authStore.isLoading ? "Connexion..." : "Se connecter" }}
    </Button>
  </form>
</template>
