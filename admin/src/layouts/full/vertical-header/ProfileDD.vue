<script setup lang="ts">
import { computed } from "vue";
import { useRouter } from "vue-router";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
} from "@/components/ui/dropdown-menu";
import { Button } from "@/components/ui/button";
import { Icon } from "@iconify/vue";
import SimpleBar from "simplebar-vue";
import user1 from "@/assets/images/profile/user-1.jpg";
import { useAuthStore } from "@/stores/auth";

const router = useRouter();
const authStore = useAuthStore();

const profileItems = computed(() => [
  {
    title: authStore.admin?.username || "Admin",
    subtitle: "Session de supervision",
    url: "/dashboard",
    img: "tabler:user",
  },
  {
    title: "Clients",
    subtitle: "Portefeuille plateforme",
    url: "/clients",
    img: "tabler:users",
  },
  {
    title: "Audit",
    subtitle: "Traçabilite des actions",
    url: "/audit",
    img: "tabler:list-details",
  },
]);

async function handleLogout() {
  authStore.logout();
  await router.push("/auth/login2");
}
</script>

<template>
  <div class="relative group/menu ps-4">
    <DropdownMenu>
      <DropdownMenuTrigger as-child>
        <span
          class="hover:text-primary hover:bg-lightprimary p-1 rounded-full flex justify-center items-center cursor-pointer group-hover/menu:bg-lightprimary group-hover/menu:text-primary transition"
        >
          <img :src="user1" alt="user" class="h-9 w-9 rounded-full object-cover" />
        </span>
      </DropdownMenuTrigger>

      <DropdownMenuContent class="w-screen rounded-sm py-6 sm:w-[240px]">
        <SimpleBar>
          <div>
            <RouterLink
              v-for="(item, index) in profileItems"
              :key="index"
              :to="item.url"
              class="px-4 py-2 flex items-center group hover:bg-lightprimary cursor-pointer"
            >
              <div class="w-full">
                <div class="ps-0 flex items-center gap-3 w-full">
                  <Icon :icon="item.img" class="text-lg text-ld group-hover:text-primary" />
                  <div class="w-3/4">
                    <h5 class="mb-0 text-sm text-ld group-hover:text-primary font-normal">
                      {{ item.title }}
                    </h5>
                    <p class="text-xs text-muted-foreground">
                      {{ item.subtitle }}
                    </p>
                  </div>
                </div>
              </div>
            </RouterLink>
          </div>
        </SimpleBar>

        <div class="px-4 pt-2">
          <Button variant="outline" class="w-full" @click="handleLogout">
            Logout
          </Button>
        </div>
      </DropdownMenuContent>
    </DropdownMenu>
  </div>
</template>
