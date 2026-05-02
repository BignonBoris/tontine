<script setup lang="ts">
import BaseBreadcrumb from '@/components/shared/BaseBreadcrumb.vue';
import ShadcnBasicTable from "@/components/shadcn-tables/BasicTable.vue";
import { ref } from 'vue';
const page = ref({ title: "Shadcn Basic Table" });
const breadcrumbs = ref([
    {
        text: "Shadcn Basic Table",
        disabled: true,
        href: "#",
    },
]);
</script>

<template>

    <BaseBreadcrumb :title="page.title" :breadcrumbs="breadcrumbs"></BaseBreadcrumb>

    <div class='grid grid-cols-12 gap-7'>
        <div class='col-span-12'>
            <ShadcnBasicTable />
        </div>
    </div>



</template>
