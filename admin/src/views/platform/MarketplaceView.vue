<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref } from "vue";
import Card from "@/components/ui/card/Card.vue";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import Tabs from "@/components/ui/tabs/Tabs.vue";
import TabsContent from "@/components/ui/tabs/TabsContent.vue";
import TabsList from "@/components/ui/tabs/TabsList.vue";
import TabsTrigger from "@/components/ui/tabs/TabsTrigger.vue";
import { useDashboardStore } from "@/stores/dashboard";
import { getErrorMessage } from "@/services/http/errors";
import {
  marketplaceAdminService,
  type MarketplaceLineListParams,
} from "@/services/marketplace/marketplaceAdminService";
import type {
  MarketplaceGoalLineItem,
  MarketplaceOfferAdminItem,
  MarketplaceOrderLineItem,
} from "@/types/platform";
import { formatCurrency, formatDateTime } from "@/utils/formatters";

const dashboardStore = useDashboardStore();
const overview = computed(() => dashboardStore.marketplaceOverview);
const items = computed(() => overview.value?.items || []);

const offerFilters = reactive({
  search: "",
  status: "",
});
const orderFilters = reactive({
  search: "",
  status: "",
});
const goalFilters = reactive({
  search: "",
  status: "",
});

const offers = ref<MarketplaceOfferAdminItem[]>([]);
const orders = ref<MarketplaceOrderLineItem[]>([]);
const goals = ref<MarketplaceGoalLineItem[]>([]);

const offersPagination = ref({ page: 1, pageSize: 10, total: 0 });
const ordersPagination = ref({ page: 1, pageSize: 10, total: 0 });
const goalsPagination = ref({ page: 1, pageSize: 10, total: 0 });

const isOffersLoading = ref(false);
const isOrdersLoading = ref(false);
const isGoalsLoading = ref(false);

const offersError = ref("");
const ordersError = ref("");
const goalsError = ref("");

const offerDialogOpen = ref(false);
const editingOfferId = ref<string | null>(null);
const offerMutationId = ref<string | null>(null);
const offerFormError = ref("");
const offerSuccess = ref("");
const offerEditorRef = ref<HTMLElement | null>(null);
const selectedCategoryMode = ref<"existing" | "new">("existing");
const selectedExistingCategory = ref("");
const imagePreviewUrl = ref("");
let objectPreviewUrl: string | null = null;

const offerForm = reactive({
  title: "",
  description: "",
  category: "",
  descriptionHtml: "",
  imageUrl: "",
  imageBase64: "",
  imageMimeType: "",
  imageOriginalName: "",
  brand: "",
  price: "",
  newCategory: "",
});

const categoryOptions = computed(() =>
  [...new Set(offers.value.map((offer) => offer.category).filter(Boolean))]
    .sort((left, right) => left.localeCompare(right))
);

const summary = computed(() => ({
  offers: overview.value?.totals.offers || 0,
  activeOffers: overview.value?.totals.activeOffers || 0,
  inFlightOrderedQuantity: overview.value?.totals.inFlightOrderedQuantity || 0,
  activePlannedGoalQuantity:
    overview.value?.totals.activePlannedGoalQuantity || 0,
}));

const offerTotalPages = computed(() =>
  Math.max(1, Math.ceil(offersPagination.value.total / offersPagination.value.pageSize))
);
const orderTotalPages = computed(() =>
  Math.max(1, Math.ceil(ordersPagination.value.total / ordersPagination.value.pageSize))
);
const goalTotalPages = computed(() =>
  Math.max(1, Math.ceil(goalsPagination.value.total / goalsPagination.value.pageSize))
);

async function fetchOffers(page = offersPagination.value.page) {
  isOffersLoading.value = true;
  offersError.value = "";
  try {
    const response = await marketplaceAdminService.listOffers({
      page,
      pageSize: offersPagination.value.pageSize,
      search: offerFilters.search || undefined,
      status: offerFilters.status || undefined,
    });
    offers.value = response.items;
    offersPagination.value = response.pagination;
  } catch (error) {
    offersError.value = getErrorMessage(
      error,
      "Chargement des articles marketplace impossible."
    );
  } finally {
    isOffersLoading.value = false;
  }
}

async function fetchOrders(page = ordersPagination.value.page) {
  isOrdersLoading.value = true;
  ordersError.value = "";
  try {
    const params: MarketplaceLineListParams = {
      page,
      pageSize: ordersPagination.value.pageSize,
      search: orderFilters.search || undefined,
      status: orderFilters.status || undefined,
    };
    const response = await marketplaceAdminService.listOrders(params);
    orders.value = response.items;
    ordersPagination.value = response.pagination;
  } catch (error) {
    ordersError.value = getErrorMessage(
      error,
      "Chargement des commandes marketplace impossible."
    );
  } finally {
    isOrdersLoading.value = false;
  }
}

async function fetchGoals(page = goalsPagination.value.page) {
  isGoalsLoading.value = true;
  goalsError.value = "";
  try {
    const params: MarketplaceLineListParams = {
      page,
      pageSize: goalsPagination.value.pageSize,
      search: goalFilters.search || undefined,
      status: goalFilters.status || undefined,
    };
    const response = await marketplaceAdminService.listGoals(params);
    goals.value = response.items;
    goalsPagination.value = response.pagination;
  } catch (error) {
    goalsError.value = getErrorMessage(
      error,
      "Chargement des coffres marketplace impossible."
    );
  } finally {
    isGoalsLoading.value = false;
  }
}

function resetImagePreview() {
  if (objectPreviewUrl) {
    URL.revokeObjectURL(objectPreviewUrl);
    objectPreviewUrl = null;
  }
  imagePreviewUrl.value = "";
}

function plainTextFromHtml(value: string) {
  return value
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>/gi, "\n\n")
    .replace(/<\/li>/gi, "\n")
    .replace(/<li>/gi, "• ")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function escapeHtml(value: string) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function syncOfferDescriptionFromEditor() {
  const html = offerEditorRef.value?.innerHTML || "";
  offerForm.descriptionHtml = html.trim();
  offerForm.description = plainTextFromHtml(html);
}

async function syncEditorWithForm() {
  await nextTick();
  if (offerEditorRef.value) {
    offerEditorRef.value.innerHTML = offerForm.descriptionHtml || "";
  }
}

function resolveCategoryState(category: string) {
  if (category && categoryOptions.value.includes(category)) {
    selectedCategoryMode.value = "existing";
    selectedExistingCategory.value = category;
    offerForm.newCategory = "";
    offerForm.category = category;
    return;
  }

  selectedCategoryMode.value = "new";
  selectedExistingCategory.value = "";
  offerForm.newCategory = category;
  offerForm.category = category;
}

function openCreateOfferDialog() {
  editingOfferId.value = null;
  offerFormError.value = "";
  offerForm.title = "";
  offerForm.description = "";
  offerForm.category = "";
  offerForm.descriptionHtml = "<p></p>";
  offerForm.imageUrl = "";
  offerForm.imageBase64 = "";
  offerForm.imageMimeType = "";
  offerForm.imageOriginalName = "";
  offerForm.brand = "";
  offerForm.price = "";
  offerForm.newCategory = "";
  selectedCategoryMode.value = categoryOptions.value.length ? "existing" : "new";
  selectedExistingCategory.value = categoryOptions.value[0] || "";
  if (selectedCategoryMode.value === "existing" && selectedExistingCategory.value) {
    offerForm.category = selectedExistingCategory.value;
  }
  resetImagePreview();
  offerDialogOpen.value = true;
  void syncEditorWithForm();
}

function openEditOfferDialog(offer: MarketplaceOfferAdminItem) {
  editingOfferId.value = offer.id;
  offerFormError.value = "";
  offerForm.title = offer.title;
  offerForm.description = offer.description;
  offerForm.descriptionHtml = offer.descriptionHtml || `<p>${escapeHtml(offer.description)}</p>`;
  offerForm.imageUrl = offer.imageUrl;
  offerForm.imageBase64 = "";
  offerForm.imageMimeType = "";
  offerForm.imageOriginalName = "";
  offerForm.category = offer.category;
  offerForm.brand = offer.brand || "";
  offerForm.price = String(offer.price);
  resolveCategoryState(offer.category);
  resetImagePreview();
  imagePreviewUrl.value = offer.imageUrl;
  offerDialogOpen.value = true;
  void syncEditorWithForm();
}

function closeOfferDialog() {
  offerDialogOpen.value = false;
  editingOfferId.value = null;
  offerFormError.value = "";
  resetImagePreview();
}

function handleOfferDialogOpenChange(value: boolean) {
  if (value) {
    offerDialogOpen.value = true;
    return;
  }

  closeOfferDialog();
}

function applyEditorCommand(command: string) {
  offerEditorRef.value?.focus();
  document.execCommand(command, false);
  syncOfferDescriptionFromEditor();
}

async function handleOfferImageChange(event: Event) {
  const target = event.target as HTMLInputElement;
  const file = target.files?.[0];
  offerForm.imageBase64 = "";
  offerForm.imageMimeType = "";
  offerForm.imageOriginalName = "";
  resetImagePreview();

  if (!file) {
    imagePreviewUrl.value = offerForm.imageUrl;
    return;
  }
  if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
    offerFormError.value = "Le fichier image doit etre en JPG, PNG ou WEBP.";
    target.value = "";
    imagePreviewUrl.value = offerForm.imageUrl;
    return;
  }
  if (file.size > 5 * 1024 * 1024) {
    offerFormError.value = "L'image ne doit pas depasser 5 Mo.";
    target.value = "";
    imagePreviewUrl.value = offerForm.imageUrl;
    return;
  }

  offerFormError.value = "";
  offerForm.imageMimeType = file.type;
  offerForm.imageOriginalName = file.name;
  objectPreviewUrl = URL.createObjectURL(file);
  imagePreviewUrl.value = objectPreviewUrl;

  const dataUrl = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ""));
    reader.onerror = () => reject(new Error("Lecture image impossible"));
    reader.readAsDataURL(file);
  });
  offerForm.imageBase64 = dataUrl.split(",")[1] || "";
}

function handleCategoryModeChange() {
  if (selectedCategoryMode.value === "existing") {
    offerForm.newCategory = "";
    offerForm.category = selectedExistingCategory.value;
    return;
  }

  selectedExistingCategory.value = "";
  offerForm.category = offerForm.newCategory.trim().toUpperCase();
}

async function submitOffer() {
  offerFormError.value = "";
  offerSuccess.value = "";
  offerMutationId.value = editingOfferId.value || "__create__";

  try {
    syncOfferDescriptionFromEditor();
    offerForm.category =
      selectedCategoryMode.value === "existing"
        ? selectedExistingCategory.value
        : offerForm.newCategory.trim().toUpperCase();

    const payload = {
      title: offerForm.title.trim(),
      description: offerForm.description.trim(),
      descriptionHtml: offerForm.descriptionHtml.trim() || null,
      imageUrl: offerForm.imageUrl.trim() || undefined,
      imageBase64: offerForm.imageBase64 || undefined,
      imageMimeType: offerForm.imageMimeType || undefined,
      imageOriginalName: offerForm.imageOriginalName || undefined,
      category: offerForm.category.trim(),
      brand: offerForm.brand.trim() || null,
      price: Number(offerForm.price),
    };

    if (editingOfferId.value) {
      await marketplaceAdminService.updateOffer(editingOfferId.value, payload);
      offerSuccess.value = "Article marketplace mis a jour.";
    } else {
      await marketplaceAdminService.createOffer(payload);
      offerSuccess.value = "Article marketplace cree et publie.";
    }

    closeOfferDialog();
    await Promise.all([fetchOffers(1), dashboardStore.fetchMarketplaceOverview()]);
  } catch (error) {
    offerFormError.value = getErrorMessage(
      error,
      "Enregistrement de l'article impossible."
    );
  } finally {
    offerMutationId.value = null;
  }
}

onBeforeUnmount(() => {
  resetImagePreview();
});

async function toggleOfferStatus(offer: MarketplaceOfferAdminItem) {
  offerMutationId.value = offer.id;
  offerSuccess.value = "";
  offersError.value = "";
  try {
    await marketplaceAdminService.updateOfferStatus(offer.id, !offer.isActive);
    offerSuccess.value = !offer.isActive
      ? "Article active. Il est maintenant visible sur mobile client."
      : "Article desactive. Il n'est plus visible sur mobile client.";
    await Promise.all([
      fetchOffers(offersPagination.value.page),
      dashboardStore.fetchMarketplaceOverview(),
    ]);
  } catch (error) {
    offersError.value = getErrorMessage(
      error,
      "Mise a jour du statut impossible."
    );
  } finally {
    offerMutationId.value = null;
  }
}

onMounted(async () => {
  if (!dashboardStore.marketplaceOverview) {
    await dashboardStore.fetchMarketplaceOverview();
  }

  await Promise.all([fetchOffers(1), fetchOrders(1), fetchGoals(1)]);
});
</script>

<template>
  <Card class="border border-border/60">
    <div class="overflow-x-hidden p-6">
      <PageHeader
        title="Marketplace"
        description="Demandes actuelles par produit, commandes en cours et coffres relies avec leurs echeances."
      />

      <div class="mt-6 grid gap-4 md:grid-cols-4">
        <div class="rounded-2xl border border-border bg-muted/30 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Produits suivis</p>
          <p class="mt-2 text-2xl font-semibold">{{ summary.offers }}</p>
        </div>
        <div class="rounded-2xl border border-emerald-200 bg-emerald-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-emerald-700">Produits actifs</p>
          <p class="mt-2 text-2xl font-semibold text-emerald-700">{{ summary.activeOffers }}</p>
        </div>
        <div class="rounded-2xl border border-sky-200 bg-sky-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-sky-700">Quantite commandee en cours</p>
          <p class="mt-2 text-2xl font-semibold text-sky-700">{{ summary.inFlightOrderedQuantity }}</p>
        </div>
        <div class="rounded-2xl border border-violet-200 bg-violet-50/70 p-4">
          <p class="text-xs uppercase tracking-[0.2em] text-violet-700">Quantite planifiee via coffres</p>
          <p class="mt-2 text-2xl font-semibold text-violet-700">{{ summary.activePlannedGoalQuantity }}</p>
        </div>
      </div>

      <div class="mt-6 flex flex-wrap items-center justify-end gap-3">
        <button
          class="rounded-xl bg-primary px-4 py-2 text-sm font-medium text-white transition hover:bg-primary/90"
          @click="openCreateOfferDialog"
        >
          Ajouter un article
        </button>
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          @click="dashboardStore.fetchMarketplaceOverview"
        >
          Rafraichir
        </button>
      </div>

      <div class="mt-10">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h3 class="text-lg font-semibold">Catalogue admin</h3>
            <p class="text-sm text-muted-foreground">
              Un article actif devient automatiquement visible dans l'application mobile client.
            </p>
          </div>
        </div>

        <div class="mt-4 flex flex-wrap items-center gap-3">
          <input
            v-model="offerFilters.search"
            type="text"
            placeholder="Titre, marque ou description"
            class="h-10 min-w-[220px] rounded-xl border border-border bg-background px-3 text-sm"
            @keyup.enter="fetchOffers(1)"
          />
          <select
            v-model="offerFilters.status"
            class="h-10 min-w-[170px] rounded-xl border border-border bg-background px-3 text-sm"
          >
            <option value="">Tous statuts</option>
            <option value="active">Actifs</option>
            <option value="inactive">Inactifs</option>
          </select>
          <button
            class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
            @click="fetchOffers(1)"
          >
            Filtrer
          </button>
        </div>

        <div
          v-if="offerSuccess"
          class="mt-4 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700"
        >
          {{ offerSuccess }}
        </div>
        <div
          v-if="offersError"
          class="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
        >
          {{ offersError }}
        </div>

        <div v-if="isOffersLoading && !offers.length" class="mt-4 text-sm text-muted-foreground">
          Chargement des articles...
        </div>

        <div v-else class="mt-4 overflow-x-auto">
          <table class="w-full min-w-[1080px] text-sm">
            <thead>
              <tr class="border-b">
                <th class="px-3 py-3 text-left">Article</th>
                <th class="px-3 py-3 text-left">Categorie</th>
                <th class="px-3 py-3 text-left">Prix</th>
                <th class="px-3 py-3 text-left">Statut</th>
                <th class="px-3 py-3 text-left">Creation</th>
                <th class="px-3 py-3 text-left">Maj</th>
                <th class="px-3 py-3 text-left">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="offer in offers" :key="offer.id" class="border-b align-top">
                <td class="px-3 py-3">
                  <div class="font-medium">{{ offer.title }}</div>
                  <div class="text-muted-foreground">{{ offer.brand || "Sans marque" }}</div>
                  <div class="mt-1 line-clamp-2 text-xs text-muted-foreground">
                    {{ offer.description }}
                  </div>
                </td>
                <td class="px-3 py-3">{{ offer.category }}</td>
                <td class="px-3 py-3">{{ formatCurrency(offer.price) }} F</td>
                <td class="px-3 py-3">
                  <span
                    class="rounded-full px-2.5 py-1 text-xs font-medium"
                    :class="offer.isActive ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-200 text-slate-700'"
                  >
                    {{ offer.isActive ? "Actif" : "Inactif" }}
                  </span>
                </td>
                <td class="px-3 py-3">{{ formatDateTime(offer.createdAt) }}</td>
                <td class="px-3 py-3">{{ formatDateTime(offer.updatedAt) }}</td>
                <td class="px-3 py-3">
                  <div class="flex flex-wrap gap-2">
                    <button
                      class="rounded-lg border border-border px-3 py-1.5 text-xs font-medium transition hover:bg-muted"
                      :disabled="offerMutationId === offer.id"
                      @click="openEditOfferDialog(offer)"
                    >
                      Modifier
                    </button>
                    <button
                      class="rounded-lg px-3 py-1.5 text-xs font-medium transition disabled:cursor-not-allowed disabled:opacity-50"
                      :class="
                        offer.isActive
                          ? 'border border-red-200 bg-red-50 text-red-700 hover:bg-red-100'
                          : 'border border-emerald-200 bg-emerald-50 text-emerald-700 hover:bg-emerald-100'
                      "
                      :disabled="offerMutationId === offer.id"
                      @click="toggleOfferStatus(offer)"
                    >
                      <span v-if="offerMutationId === offer.id">Traitement...</span>
                      <span v-else>{{ offer.isActive ? "Desactiver" : "Activer" }}</span>
                    </button>
                  </div>
                </td>
              </tr>
              <tr v-if="!offers.length && !isOffersLoading">
                <td colspan="7" class="px-3 py-8 text-center text-sm text-muted-foreground">
                  Aucun article marketplace a afficher.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="mt-4 flex flex-wrap items-center justify-between gap-3 text-sm">
          <p class="text-muted-foreground">
            Page {{ offersPagination.page }} / {{ offerTotalPages }} - {{ offersPagination.total }} articles
          </p>
          <div class="flex items-center gap-2">
            <button
              class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
              :disabled="offersPagination.page <= 1 || isOffersLoading"
              @click="fetchOffers(offersPagination.page - 1)"
            >
              Precedent
            </button>
            <button
              class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
              :disabled="offersPagination.page >= offerTotalPages || isOffersLoading"
              @click="fetchOffers(offersPagination.page + 1)"
            >
              Suivant
            </button>
          </div>
        </div>
      </div>

      <Tabs default-value="overview" class="mt-10">
        <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div>
            <h3 class="text-lg font-semibold">Supervision marketplace</h3>
            <p class="text-sm text-muted-foreground">
              Basculer entre la vue produit, les commandes individuelles et les coffres lies.
            </p>
          </div>
          <div class="overflow-x-auto">
            <TabsList class="min-w-max">
              <TabsTrigger value="overview">Vue produit</TabsTrigger>
              <TabsTrigger value="orders">Commandes</TabsTrigger>
              <TabsTrigger value="goals">Coffres lies</TabsTrigger>
            </TabsList>
          </div>
        </div>

        <TabsContent value="overview" class="mt-4">
          <div
            v-if="dashboardStore.isMarketplaceLoading && !items.length"
            class="text-sm text-muted-foreground"
          >
            Chargement du marketplace...
          </div>

          <div v-else class="overflow-x-auto">
            <table class="w-full min-w-[1180px] text-sm">
              <thead>
                <tr class="border-b">
                  <th class="px-3 py-3 text-left">Produit</th>
                  <th class="px-3 py-3 text-left">Prix</th>
                  <th class="px-3 py-3 text-left">Commandes en cours</th>
                  <th class="px-3 py-3 text-left">Pipeline commande</th>
                  <th class="px-3 py-3 text-left">Coffres actifs</th>
                  <th class="px-3 py-3 text-left">Fin la plus proche</th>
                  <th class="px-3 py-3 text-left">Fin la plus lointaine</th>
                  <th class="px-3 py-3 text-left">Avancement coffres</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="item in items" :key="item.offerId" class="border-b align-top">
                  <td class="px-3 py-3">
                    <div class="font-medium">{{ item.title }}</div>
                    <div class="text-muted-foreground">
                      {{ item.brand || "Sans marque" }} · {{ item.category || "Sans categorie" }}
                    </div>
                    <div class="mt-2">
                      <span
                        class="rounded-full px-2.5 py-1 text-xs font-medium"
                        :class="item.isActive ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-200 text-slate-700'"
                      >
                        {{ item.isActive ? "Actif" : "Inactif" }}
                      </span>
                    </div>
                  </td>
                  <td class="px-3 py-3">{{ formatCurrency(item.unitPrice) }} F</td>
                  <td class="px-3 py-3">
                    <div class="font-medium">{{ item.directOrders.inFlightQuantity }}</div>
                    <div class="text-muted-foreground">
                      {{ item.directOrders.totalOrders }} commandes, {{ item.directOrders.totalOrderedQuantity }} unites cumulees
                    </div>
                    <div class="mt-2 text-xs text-muted-foreground">
                      Derniere commande:
                      {{ item.directOrders.lastOrderedAt ? formatDateTime(item.directOrders.lastOrderedAt) : "Aucune" }}
                    </div>
                  </td>
                  <td class="px-3 py-3">
                    <div>Pendings: {{ item.directOrders.pendingQuantity }}</div>
                    <div>Confirmed: {{ item.directOrders.confirmedQuantity }}</div>
                    <div>Ready: {{ item.directOrders.readyQuantity }}</div>
                    <div class="mt-2 text-xs text-muted-foreground">
                      Livrees: {{ item.directOrders.deliveredQuantity }} · Annulees: {{ item.directOrders.cancelledQuantity }}
                    </div>
                  </td>
                  <td class="px-3 py-3">
                    <div class="font-medium">{{ item.linkedGoals.activePlannedQuantity }}</div>
                    <div class="text-muted-foreground">
                      {{ item.linkedGoals.activeGoals }} coffres actifs · {{ item.linkedGoals.totalGoals }} au total
                    </div>
                    <div class="mt-2 text-xs text-muted-foreground">
                      Objectif: {{ formatCurrency(item.linkedGoals.targetAmount) }} F
                    </div>
                  </td>
                  <td class="px-3 py-3">
                    {{ item.linkedGoals.nearestEndDate ? formatDateTime(item.linkedGoals.nearestEndDate) : "Aucune" }}
                  </td>
                  <td class="px-3 py-3">
                    {{ item.linkedGoals.farthestEndDate ? formatDateTime(item.linkedGoals.farthestEndDate) : "Aucune" }}
                  </td>
                  <td class="px-3 py-3">
                    <div class="font-medium">{{ Math.round(item.linkedGoals.progressRate * 100) }}%</div>
                    <div class="text-muted-foreground">
                      {{ formatCurrency(item.linkedGoals.fundedAmount) }} F / {{ formatCurrency(item.linkedGoals.targetAmount) }} F
                    </div>
                  </td>
                </tr>
                <tr v-if="!items.length && !dashboardStore.isMarketplaceLoading">
                  <td colspan="8" class="px-3 py-8 text-center text-sm text-muted-foreground">
                    Aucune donnee marketplace a afficher.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </TabsContent>

        <TabsContent value="orders" class="mt-4">
          <div class="flex flex-wrap items-center gap-3">
            <input
              v-model="orderFilters.search"
              type="text"
              placeholder="Nom client ou telephone"
              class="h-10 min-w-[220px] rounded-xl border border-border bg-background px-3 text-sm"
              @keyup.enter="fetchOrders(1)"
            />
            <select
              v-model="orderFilters.status"
              class="h-10 min-w-[170px] rounded-xl border border-border bg-background px-3 text-sm"
            >
              <option value="">Tous statuts</option>
              <option value="pending">Pending</option>
              <option value="confirmed">Confirmed</option>
              <option value="ready">Ready</option>
              <option value="completed">Completed</option>
              <option value="cancelled">Cancelled</option>
            </select>
            <button
              class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
              @click="fetchOrders(1)"
            >
              Filtrer
            </button>
          </div>

          <div
            v-if="ordersError"
            class="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
          >
            {{ ordersError }}
          </div>

          <div v-if="isOrdersLoading && !orders.length" class="mt-4 text-sm text-muted-foreground">
            Chargement des commandes...
          </div>

          <div v-else class="mt-4 overflow-x-auto">
            <table class="w-full min-w-[1120px] text-sm">
              <thead>
                <tr class="border-b">
                  <th class="px-3 py-3 text-left">Produit</th>
                  <th class="px-3 py-3 text-left">Client</th>
                  <th class="px-3 py-3 text-left">Quantite</th>
                  <th class="px-3 py-3 text-left">Montant</th>
                  <th class="px-3 py-3 text-left">Statut</th>
                  <th class="px-3 py-3 text-left">Commande</th>
                  <th class="px-3 py-3 text-left">Maj statut</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="entry in orders" :key="entry.id" class="border-b">
                  <td class="px-3 py-3">
                    <div class="font-medium">{{ entry.title }}</div>
                    <div class="text-muted-foreground">
                      {{ entry.offer?.brand || "Sans marque" }} · {{ entry.offer?.category || "Sans categorie" }}
                    </div>
                  </td>
                  <td class="px-3 py-3">
                    <div>{{ entry.client?.displayName || "N/A" }}</div>
                    <div class="text-muted-foreground">{{ entry.client?.phoneNumber || "N/A" }}</div>
                  </td>
                  <td class="px-3 py-3">{{ entry.quantity }} · {{ formatCurrency(entry.unitPrice) }} F / u</td>
                  <td class="px-3 py-3">{{ formatCurrency(entry.amount) }} F</td>
                  <td class="px-3 py-3">
                    <span class="rounded-full bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-700">
                      {{ entry.status }}
                    </span>
                  </td>
                  <td class="px-3 py-3">{{ formatDateTime(entry.orderedAt) }}</td>
                  <td class="px-3 py-3">
                    {{ entry.updatedStatusAt ? formatDateTime(entry.updatedStatusAt) : "Aucune" }}
                  </td>
                </tr>
                <tr v-if="!orders.length && !isOrdersLoading">
                  <td colspan="7" class="px-3 py-8 text-center text-sm text-muted-foreground">
                    Aucune commande marketplace a afficher.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="mt-4 flex flex-wrap items-center justify-between gap-3 text-sm">
            <p class="text-muted-foreground">
              Page {{ ordersPagination.page }} / {{ orderTotalPages }} - {{ ordersPagination.total }} commandes
            </p>
            <div class="flex items-center gap-2">
              <button
                class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
                :disabled="ordersPagination.page <= 1 || isOrdersLoading"
                @click="fetchOrders(ordersPagination.page - 1)"
              >
                Precedent
              </button>
              <button
                class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
                :disabled="ordersPagination.page >= orderTotalPages || isOrdersLoading"
                @click="fetchOrders(ordersPagination.page + 1)"
              >
                Suivant
              </button>
            </div>
          </div>
        </TabsContent>

        <TabsContent value="goals" class="mt-4">
          <div class="flex flex-wrap items-center gap-3">
            <input
              v-model="goalFilters.search"
              type="text"
              placeholder="Nom client ou telephone"
              class="h-10 min-w-[220px] rounded-xl border border-border bg-background px-3 text-sm"
              @keyup.enter="fetchGoals(1)"
            />
            <select
              v-model="goalFilters.status"
              class="h-10 min-w-[170px] rounded-xl border border-border bg-background px-3 text-sm"
            >
              <option value="">Tous statuts</option>
              <option value="active">Active</option>
              <option value="closed">Closed</option>
            </select>
            <button
              class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
              @click="fetchGoals(1)"
            >
              Filtrer
            </button>
          </div>

          <div
            v-if="goalsError"
            class="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
          >
            {{ goalsError }}
          </div>

          <div v-if="isGoalsLoading && !goals.length" class="mt-4 text-sm text-muted-foreground">
            Chargement des coffres lies...
          </div>

          <div v-else class="mt-4 overflow-x-auto">
            <table class="w-full min-w-[1160px] text-sm">
              <thead>
                <tr class="border-b">
                  <th class="px-3 py-3 text-left">Produit</th>
                  <th class="px-3 py-3 text-left">Client</th>
                  <th class="px-3 py-3 text-left">Quantite planifiee</th>
                  <th class="px-3 py-3 text-left">Avancement</th>
                  <th class="px-3 py-3 text-left">Statut</th>
                  <th class="px-3 py-3 text-left">Debut</th>
                  <th class="px-3 py-3 text-left">Fin prevue</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="entry in goals" :key="entry.id" class="border-b">
                  <td class="px-3 py-3">
                    <div class="font-medium">{{ entry.linkedOffer?.title || entry.title }}</div>
                    <div class="text-muted-foreground">
                      {{ entry.linkedOffer?.brand || "Sans marque" }} · {{ entry.linkedOffer?.category || "Sans categorie" }}
                    </div>
                  </td>
                  <td class="px-3 py-3">
                    <div>{{ entry.client?.displayName || "N/A" }}</div>
                    <div class="text-muted-foreground">{{ entry.client?.phoneNumber || "N/A" }}</div>
                  </td>
                  <td class="px-3 py-3">{{ entry.quantity }} · {{ formatCurrency(entry.unitPrice) }} F / u</td>
                  <td class="px-3 py-3">
                    <div class="font-medium">{{ Math.round(entry.progress * 100) }}%</div>
                    <div class="text-muted-foreground">
                      {{ formatCurrency(entry.currentAmount) }} F / {{ formatCurrency(entry.targetAmount) }} F
                    </div>
                  </td>
                  <td class="px-3 py-3">
                    <span class="rounded-full bg-violet-100 px-2.5 py-1 text-xs font-medium text-violet-700">
                      {{ entry.status }}
                    </span>
                  </td>
                  <td class="px-3 py-3">{{ formatDateTime(entry.startDate) }}</td>
                  <td class="px-3 py-3">{{ formatDateTime(entry.endDate) }}</td>
                </tr>
                <tr v-if="!goals.length && !isGoalsLoading">
                  <td colspan="7" class="px-3 py-8 text-center text-sm text-muted-foreground">
                    Aucun coffre marketplace a afficher.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="mt-4 flex flex-wrap items-center justify-between gap-3 text-sm">
            <p class="text-muted-foreground">
              Page {{ goalsPagination.page }} / {{ goalTotalPages }} - {{ goalsPagination.total }} coffres lies
            </p>
            <div class="flex items-center gap-2">
              <button
                class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
                :disabled="goalsPagination.page <= 1 || isGoalsLoading"
                @click="fetchGoals(goalsPagination.page - 1)"
              >
                Precedent
              </button>
              <button
                class="rounded-xl border border-border px-4 py-2 transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
                :disabled="goalsPagination.page >= goalTotalPages || isGoalsLoading"
                @click="fetchGoals(goalsPagination.page + 1)"
              >
                Suivant
              </button>
            </div>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  </Card>

  <Dialog :open="offerDialogOpen" @update:open="handleOfferDialogOpenChange">
    <DialogContent class="sm:max-w-[720px]">
      <DialogHeader>
        <DialogTitle>{{ editingOfferId ? "Modifier l'article" : "Ajouter un article" }}</DialogTitle>
        <DialogDescription>
          Un article actif sera automatiquement disponible dans l'application mobile client.
        </DialogDescription>
      </DialogHeader>

      <div class="space-y-4">
        <div
          v-if="offerFormError"
          class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
        >
          {{ offerFormError }}
        </div>

        <div class="grid gap-4 md:grid-cols-2">
          <div class="space-y-2">
            <label class="text-sm font-medium">Titre</label>
            <input
              v-model="offerForm.title"
              type="text"
              class="h-11 w-full rounded-xl border border-border bg-background px-3 text-sm"
            />
          </div>
          <div class="space-y-2">
            <label class="text-sm font-medium">Categorie</label>
            <div class="grid gap-2">
              <select
                v-model="selectedCategoryMode"
                class="h-11 w-full rounded-xl border border-border bg-background px-3 text-sm"
                @change="handleCategoryModeChange"
              >
                <option value="existing">Choisir une categorie existante</option>
                <option value="new">Ajouter une nouvelle categorie</option>
              </select>

              <select
                v-if="selectedCategoryMode === 'existing'"
                v-model="selectedExistingCategory"
                class="h-11 w-full rounded-xl border border-border bg-background px-3 text-sm"
                @change="offerForm.category = selectedExistingCategory"
              >
                <option disabled value="">
                  {{ categoryOptions.length ? "Selectionner une categorie" : "Aucune categorie existante" }}
                </option>
                <option v-for="category in categoryOptions" :key="category" :value="category">
                  {{ category }}
                </option>
              </select>

              <input
                v-else
                v-model="offerForm.newCategory"
                type="text"
                class="h-11 w-full rounded-xl border border-border bg-background px-3 text-sm"
                placeholder="Ex: TECH"
                @input="offerForm.category = offerForm.newCategory.trim().toUpperCase()"
              />
            </div>
          </div>
          <div class="space-y-2">
            <label class="text-sm font-medium">Marque</label>
            <input
              v-model="offerForm.brand"
              type="text"
              class="h-11 w-full rounded-xl border border-border bg-background px-3 text-sm"
            />
          </div>
          <div class="space-y-2">
            <label class="text-sm font-medium">Prix</label>
            <input
              v-model="offerForm.price"
              type="number"
              min="1"
              class="h-11 w-full rounded-xl border border-border bg-background px-3 text-sm"
            />
          </div>
        </div>

        <div class="grid gap-4 md:grid-cols-[minmax(0,1fr)_220px]">
          <div class="space-y-2">
            <label class="text-sm font-medium">Image article</label>
            <input
              type="file"
              accept="image/png,image/jpeg,image/webp"
              class="block w-full rounded-xl border border-border bg-background px-3 py-2.5 text-sm file:mr-3 file:rounded-lg file:border-0 file:bg-muted file:px-3 file:py-2 file:text-sm file:font-medium"
              @change="handleOfferImageChange"
            />
            <p class="text-xs text-muted-foreground">
              Formats acceptes: JPG, PNG, WEBP. Taille max: 5 Mo.
            </p>
          </div>
          <div class="space-y-2">
            <label class="text-sm font-medium">Apercu</label>
            <div class="flex h-[140px] items-center justify-center overflow-hidden rounded-2xl border border-dashed border-border bg-muted/20">
              <img
                v-if="imagePreviewUrl || offerForm.imageUrl"
                :src="imagePreviewUrl || offerForm.imageUrl"
                alt="Apercu article"
                class="h-full w-full object-cover"
              />
              <span v-else class="px-4 text-center text-xs text-muted-foreground">
                Aucune image selectionnee
              </span>
            </div>
          </div>
        </div>

        <div class="space-y-2">
          <label class="text-sm font-medium">Description</label>
          <div class="rounded-2xl border border-border bg-background">
            <div class="flex flex-wrap gap-2 border-b border-border/80 px-3 py-2">
              <button
                type="button"
                class="rounded-lg border border-border px-2.5 py-1 text-xs font-medium transition hover:bg-muted"
                @click="applyEditorCommand('bold')"
              >
                Gras
              </button>
              <button
                type="button"
                class="rounded-lg border border-border px-2.5 py-1 text-xs font-medium transition hover:bg-muted"
                @click="applyEditorCommand('italic')"
              >
                Italique
              </button>
              <button
                type="button"
                class="rounded-lg border border-border px-2.5 py-1 text-xs font-medium transition hover:bg-muted"
                @click="applyEditorCommand('underline')"
              >
                Souligne
              </button>
              <button
                type="button"
                class="rounded-lg border border-border px-2.5 py-1 text-xs font-medium transition hover:bg-muted"
                @click="applyEditorCommand('insertUnorderedList')"
              >
                Liste
              </button>
              <button
                type="button"
                class="rounded-lg border border-border px-2.5 py-1 text-xs font-medium transition hover:bg-muted"
                @click="applyEditorCommand('insertOrderedList')"
              >
                Numerotee
              </button>
            </div>
            <div
              ref="offerEditorRef"
              contenteditable="true"
              class="min-h-[180px] w-full px-4 py-3 text-sm outline-none"
              @input="syncOfferDescriptionFromEditor"
            />
          </div>
          <p class="text-xs text-muted-foreground">
            Le formatage riche est conserve pour l'admin. Le mobile client garde un texte propre pour eviter toute regression d'affichage.
          </p>
        </div>
      </div>

      <DialogFooter class="gap-2">
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          :disabled="offerMutationId !== null"
          @click="closeOfferDialog"
        >
          Annuler
        </button>
        <button
          class="rounded-xl bg-primary px-4 py-2 text-sm font-medium text-white transition hover:bg-primary/90 disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="offerMutationId !== null"
          @click="submitOffer"
        >
          <span v-if="offerMutationId !== null">Traitement...</span>
          <span v-else>{{ editingOfferId ? "Enregistrer" : "Creer l'article" }}</span>
        </button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
