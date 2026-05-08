<script setup lang="tsx">
import FullLogo from "@/layouts/full/logo/Logo.vue";
import AuthLogin from "@/views/authentication/authforms/AuthLogin.vue";
import Card from "@/components/ui/card/Card.vue";
</script>

<template>
  <div class="relative h-screen overflow-hidden bg-lightprimary dark:bg-darkprimary">
    <div class="flex h-full items-center justify-center px-4">
      <Card class="w-full gap-0 border-none md:w-[450px]">
        <div class="flex items-center justify-center">
          <FullLogo />
        </div>
        <div class="mt-6 text-center">
          <h1 class="text-2xl font-semibold">
            Connexion VizioBox Admin
          </h1>
          <p class="mt-2 text-sm text-muted-foreground">
            Supervision des clients, agents, retraits et audit.
          </p>
        </div>
        <AuthLogin />
      </Card>
    </div>
  </div>
</template>
