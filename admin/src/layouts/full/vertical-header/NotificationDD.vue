<script setup lang="ts">
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent } from "@/components/ui/dropdown-menu";
import { Icon } from "@iconify/vue";
</script>

<template>
  <div class="relative group/menu px-4">
    <DropdownMenu>
      <DropdownMenuTrigger as-child>
        <div class="relative">
          <span
            class="relative after:absolute after:w-10 after:h-10 after:rounded-full hover:text-primary after:-top-1/2 hover:after:bg-lightprimary text-link dark:text-darklink rounded-full flex justify-center items-center cursor-pointer group-hover/menu:after:bg-lightprimary group-hover/menu:text-primary"
          >
            <Icon icon="tabler:bell-ringing" height="20" />
          </span>
          <span class="absolute -top-[5px] -end-[6px] h-2 w-2 bg-primary rounded-full"></span>
        </div>
      </DropdownMenuTrigger>

      <DropdownMenuContent class="z-50 w-screen rounded-md py-6 shadow-lg sm:w-[300px]">
        <div class="flex items-center justify-between px-6 rtl:flex-row-reverse rtl:text-end">
          <h3 class="text-lg font-semibold text-ld">
            Notifications
          </h3>
        </div>

        <div class="px-6 pt-6">
          <div class="rounded-2xl border border-dashed border-border bg-muted/30 px-4 py-6 text-center">
            <p class="text-sm font-medium text-foreground">
              Aucune notification admin
            </p>
            <p class="mt-2 text-xs text-muted-foreground">
              Le centre de notification sera branche quand le module supervision sera finalise.
            </p>
          </div>
        </div>
      </DropdownMenuContent>
    </DropdownMenu>
  </div>
</template>
