<script setup lang="tsx">
import Form from '@/components/utilities/Form.vue';
import { ref } from 'vue';
import BaseBreadcrumb from '@/components/shared/BaseBreadcrumb.vue';


const page = ref({ title: " Forms " });
const breadcrumbs = ref([
  {
    text: "Forms",
    disabled: true,
    href: "#",
  },
]);


</script>
<template>


  <BaseBreadcrumb :title="page.title" :breadcrumbs="breadcrumbs"></BaseBreadcrumb>
  <Form />
</template>