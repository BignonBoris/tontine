<script setup lang="ts">
import { RouterView } from "vue-router";
import { Toaster } from "vue-sonner";
import "vue-sonner/style.css";
</script>

<template>
  <Toaster position="top-right" richColors closeButton />
  <RouterView></RouterView>
</template>
