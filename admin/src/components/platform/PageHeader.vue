<script setup lang="ts">
defineProps<{
  title: string;
  description: string;
}>();
</script>

<template>
  <div class="mb-6">
    <h1 class="text-2xl font-semibold text-foreground">
      {{ title }}
    </h1>
    <p class="mt-2 max-w-3xl text-sm leading-6 text-muted-foreground">
      {{ description }}
    </p>
  </div>
</template>
