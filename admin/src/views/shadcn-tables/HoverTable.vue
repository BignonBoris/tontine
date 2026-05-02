<script setup lang="ts">
import { ref } from "vue";

// template breadcrumb
import BaseBreadcrumb from "@/components/shared/BaseBreadcrumb.vue";

import HoverTable from "@/components/shadcn-tables/HoverTable.vue";
const page = ref({ title: "Shadcn Hover Table" });
const breadcrumbs = ref([
    {
        text: "Shadcn Hover Table",
        disabled: true,
        href: "#",
    },
]);
</script>

<template>
    <BaseBreadcrumb :title="page.title" :breadcrumbs="breadcrumbs"></BaseBreadcrumb>



    <HoverTable />



</template>
