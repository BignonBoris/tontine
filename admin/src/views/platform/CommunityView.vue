<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from "vue";
import { toast } from "vue-sonner";
import Card from "@/components/ui/card/Card.vue";
import {
  communityService,
  type BrandProfile,
  type CommunityLanguage,
  type CommunityNetwork,
  type CommunityOptions,
  type CommunityPost,
  type CommunityStatus,
  type PostFilters,
} from "@/services/community/communityService";
import { getErrorMessage } from "@/services/http/errors";

type Tab = "generate" | "reply" | "drafts" | "brand";

const TABS: { key: Tab; label: string }[] = [
  { key: "generate", label: "Créer des publications" },
  { key: "reply", label: "Répondre à un commentaire" },
  { key: "drafts", label: "Brouillons" },
  { key: "brand", label: "Fiche de marque" },
];

const STATUS_LABELS: Record<CommunityStatus, string> = {
  draft: "Brouillon",
  approved: "Validé",
  published: "Publié",
  archived: "Archivé",
};

const STATUS_CLASSES: Record<CommunityStatus, string> = {
  draft: "bg-amber-100 text-amber-700",
  approved: "bg-sky-100 text-sky-700",
  published: "bg-emerald-100 text-emerald-700",
  archived: "bg-slate-100 text-slate-600",
};

const CATEGORY_LABELS: Record<string, string> = {
  question_produit: "Question produit",
  question_compte: "Question sur un compte",
  probleme_paiement: "Problème de paiement",
  plainte: "Plainte",
  compliment: "Compliment",
  spam: "Spam",
  autre: "Autre",
};

const TOPIC_IDEAS = [
  "Nouveau : payez par Mobile Money sans quitter l'application",
  "Pourquoi épargner chaque jour, même une petite somme",
  "La tontine traditionnelle, en plus simple et plus sûre",
  "Comment installer l'application VizioBox",
  "Préparer la rentrée scolaire avec un coffre",
];

const activeTab = ref<Tab>("generate");
const options = ref<CommunityOptions | null>(null);
const optionsError = ref("");

// --- Génération ---------------------------------------------------------
const generateForm = reactive({
  networks: ["facebook", "whatsapp"] as CommunityNetwork[],
  languages: ["fr"] as CommunityLanguage[],
  topic: "",
  goal: "",
  count: 1,
});
const isGenerating = ref(false);
const generateError = ref("");
const generated = ref<CommunityPost[]>([]);

const plannedCount = computed(
  () => generateForm.networks.length * generateForm.languages.length * generateForm.count
);
const maxPosts = computed(() => options.value?.maxPostsPerGeneration || 20);

function toggle<T>(list: T[], value: T) {
  const index = list.indexOf(value);
  if (index >= 0) list.splice(index, 1);
  else list.push(value);
}

async function generate() {
  generateError.value = "";
  if (!generateForm.networks.length) {
    generateError.value = "Choisissez au moins un réseau.";
    return;
  }
  if (!generateForm.languages.length) {
    generateError.value = "Choisissez au moins une langue.";
    return;
  }
  if (generateForm.topic.trim().length < 3) {
    generateError.value = "Indiquez le sujet des publications.";
    return;
  }
  if (plannedCount.value > maxPosts.value) {
    generateError.value = `Trop de publications (${plannedCount.value}). Maximum ${maxPosts.value} à la fois.`;
    return;
  }
  isGenerating.value = true;
  try {
    generated.value = await communityService.generate({
      networks: generateForm.networks,
      languages: generateForm.languages,
      topic: generateForm.topic.trim(),
      goal: generateForm.goal.trim() || undefined,
      count: generateForm.count,
    });
    toast.success(`${generated.value.length} brouillon(s) prêt(s) à relire.`);
  } catch (error) {
    generateError.value = getErrorMessage(error, "Génération impossible.");
  } finally {
    isGenerating.value = false;
  }
}

// --- Réponse à un commentaire --------------------------------------------
const replyForm = reactive({
  network: "facebook" as CommunityNetwork,
  comment: "",
  postContext: "",
});
const isReplying = ref(false);
const replyError = ref("");
const replyResult = ref<CommunityPost | null>(null);

async function suggestReply() {
  replyError.value = "";
  if (replyForm.comment.trim().length < 2) {
    replyError.value = "Collez le commentaire ou le message reçu.";
    return;
  }
  isReplying.value = true;
  try {
    replyResult.value = await communityService.suggestReply({
      network: replyForm.network,
      comment: replyForm.comment.trim(),
      postContext: replyForm.postContext.trim() || undefined,
    });
  } catch (error) {
    replyError.value = getErrorMessage(error, "Proposition de réponse impossible.");
  } finally {
    isReplying.value = false;
  }
}

// --- Brouillons -----------------------------------------------------------
const filters = reactive<PostFilters>({ status: "", kind: "", network: "", needsSupport: false, page: 1 });
const drafts = ref<CommunityPost[]>([]);
const pagination = ref({ page: 1, pages: 1, total: 0 });
const isLoadingDrafts = ref(false);
const draftsError = ref("");

async function loadDrafts() {
  draftsError.value = "";
  isLoadingDrafts.value = true;
  try {
    const page = await communityService.list({ ...filters });
    drafts.value = page.items;
    pagination.value = page.pagination;
  } catch (error) {
    draftsError.value = getErrorMessage(error, "Chargement des brouillons impossible.");
  } finally {
    isLoadingDrafts.value = false;
  }
}

watch(
  () => [filters.status, filters.kind, filters.network, filters.needsSupport],
  () => {
    filters.page = 1;
    loadDrafts();
  }
);

function goToPage(page: number) {
  filters.page = page;
  loadDrafts();
}

// --- Actions sur un brouillon (partagées) --------------------------------
const editingId = ref<string | null>(null);
const editForm = reactive({ content: "", hashtags: "" });
const busyId = ref<string | null>(null);

function replacePost(updated: CommunityPost) {
  for (const list of [generated, drafts]) {
    const index = list.value.findIndex((post) => post.id === updated.id);
    if (index >= 0) list.value[index] = updated;
  }
  if (replyResult.value?.id === updated.id) replyResult.value = updated;
}

function startEdit(post: CommunityPost) {
  editingId.value = post.id;
  editForm.content = post.content;
  editForm.hashtags = post.hashtags.join(" ");
}

async function saveEdit(post: CommunityPost) {
  busyId.value = post.id;
  try {
    const updated = await communityService.update(post.id, {
      content: editForm.content,
      hashtags: editForm.hashtags.split(/\s+/).filter(Boolean),
    });
    replacePost(updated);
    editingId.value = null;
    toast.success("Brouillon modifié.");
  } catch (error) {
    toast.error(getErrorMessage(error, "Modification impossible."));
  } finally {
    busyId.value = null;
  }
}

async function setStatus(post: CommunityPost, status: CommunityStatus) {
  busyId.value = post.id;
  try {
    const updated = await communityService.update(post.id, { status });
    replacePost(updated);
    toast.success(`${post.reference} : ${STATUS_LABELS[status].toLowerCase()}.`);
  } catch (error) {
    toast.error(getErrorMessage(error, "Changement de statut impossible."));
  } finally {
    busyId.value = null;
  }
}

function fullText(post: CommunityPost) {
  const tags = post.hashtags.length && !post.content.includes(post.hashtags[0]) ? `\n\n${post.hashtags.join(" ")}` : "";
  return `${post.content}${tags}`;
}

async function copyPost(post: CommunityPost) {
  try {
    await navigator.clipboard.writeText(fullText(post));
    toast.success("Texte copié. Collez-le sur le réseau.");
  } catch {
    toast.error("Copie impossible : sélectionnez le texte à la main.");
  }
}

function formatDate(value: string | null) {
  return value ? new Date(value).toLocaleString("fr-FR", { dateStyle: "short", timeStyle: "short" }) : "—";
}

// --- Fiche de marque ------------------------------------------------------
const brand = reactive({
  brandName: "",
  description: "",
  audience: "",
  tone: "",
  keyFacts: "",
  forbiddenClaims: "",
  supportContact: "",
  defaultHashtags: "",
  isDefault: false,
});
const isSavingBrand = ref(false);
const brandError = ref("");

function fillBrand(profile: BrandProfile) {
  brand.brandName = profile.brandName;
  brand.description = profile.description;
  brand.audience = profile.audience;
  brand.tone = profile.tone;
  brand.keyFacts = profile.keyFacts.join("\n");
  brand.forbiddenClaims = profile.forbiddenClaims.join("\n");
  brand.supportContact = profile.supportContact;
  brand.defaultHashtags = profile.defaultHashtags.join(" ");
  brand.isDefault = Boolean(profile.isDefault);
}

async function loadBrand() {
  try {
    fillBrand(await communityService.getBrandProfile());
  } catch (error) {
    brandError.value = getErrorMessage(error, "Chargement de la fiche impossible.");
  }
}

async function saveBrand() {
  brandError.value = "";
  if (!brand.description.trim()) {
    brandError.value = "La description de la marque est obligatoire.";
    return;
  }
  isSavingBrand.value = true;
  try {
    const saved = await communityService.updateBrandProfile({
      brandName: brand.brandName,
      description: brand.description,
      audience: brand.audience,
      tone: brand.tone,
      keyFacts: brand.keyFacts.split("\n"),
      forbiddenClaims: brand.forbiddenClaims.split("\n"),
      supportContact: brand.supportContact,
      defaultHashtags: brand.defaultHashtags.split(/\s+/).filter(Boolean),
    });
    fillBrand(saved);
    toast.success("Fiche de marque enregistrée. Elle s'applique aux prochaines générations.");
  } catch (error) {
    brandError.value = getErrorMessage(error, "Enregistrement impossible.");
  } finally {
    isSavingBrand.value = false;
  }
}

watch(activeTab, (tab) => {
  if (tab === "drafts") loadDrafts();
});

onMounted(async () => {
  try {
    options.value = await communityService.options();
  } catch (error) {
    optionsError.value = getErrorMessage(error, "Chargement de l'assistant impossible.");
  }
  loadBrand();
});

const inputClass = "w-full rounded-xl border border-border bg-background px-3 text-sm";
const chipClass = (active: boolean) =>
  active
    ? "border-primary bg-primary text-white"
    : "border-border bg-background text-foreground hover:bg-muted";
</script>

<template>
  <Card class="border border-border/60">
    <div class="p-6">
      <div>
        <h1 class="text-xl font-semibold">Community Manager</h1>
        <p class="mt-1 text-sm text-muted-foreground">
          L'assistant rédige vos publications et vos réponses. Rien n'est publié automatiquement :
          vous relisez, validez, puis publiez vous-même sur le réseau.
        </p>
      </div>

      <div
        v-if="optionsError"
        class="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
      >
        {{ optionsError }}
      </div>
      <div
        v-else-if="options && !options.aiConfigured"
        class="mt-4 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800"
      >
        L'assistant n'est pas encore activé : ajoutez la variable
        <code class="rounded bg-white px-1">GEMINI_API_KEY</code> (gratuite sur aistudio.google.com) ou
        <code class="rounded bg-white px-1">ANTHROPIC_API_KEY</code> sur le serveur (Railway), puis redéployez.
      </div>

      <div class="mt-6 flex flex-wrap gap-2 border-b border-border/60 pb-3">
        <button
          v-for="tab in TABS"
          :key="tab.key"
          class="rounded-xl px-4 py-2 text-sm font-medium transition"
          :class="activeTab === tab.key ? 'bg-primary text-white' : 'hover:bg-muted'"
          @click="activeTab = tab.key"
        >
          {{ tab.label }}
        </button>
      </div>

      <!-- Créer des publications -->
      <div v-if="activeTab === 'generate'" class="mt-6 grid gap-6 xl:grid-cols-[minmax(0,380px)_1fr]">
        <div class="space-y-4">
          <div class="space-y-2">
            <p class="text-sm font-medium">Réseaux</p>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="network in options?.networks || []"
                :key="network.key"
                class="rounded-full border px-3 py-1.5 text-sm transition"
                :class="chipClass(generateForm.networks.includes(network.key))"
                @click="toggle(generateForm.networks, network.key)"
              >
                {{ network.label }}
              </button>
            </div>
          </div>

          <div class="space-y-2">
            <p class="text-sm font-medium">Langues</p>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="language in options?.languages || []"
                :key="language.key"
                class="rounded-full border px-3 py-1.5 text-sm transition"
                :class="chipClass(generateForm.languages.includes(language.key))"
                @click="toggle(generateForm.languages, language.key)"
              >
                {{ language.label }}
              </button>
            </div>
            <p v-if="generateForm.languages.includes('fon')" class="text-xs text-amber-700">
              Le fongbe écrit par l'IA est moins fiable que le français : faites-le relire par un
              locuteur natif avant publication.
            </p>
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium">Sujet</label>
            <textarea
              v-model="generateForm.topic"
              rows="3"
              maxlength="500"
              placeholder="Ex. : Nouveau, payez par Mobile Money sans quitter l'application"
              :class="[inputClass, 'py-2']"
            />
            <div class="flex flex-wrap gap-1.5">
              <button
                v-for="idea in TOPIC_IDEAS"
                :key="idea"
                class="rounded-full border border-border px-2.5 py-1 text-xs transition hover:bg-muted/20"
                @click="generateForm.topic = idea"
              >
                {{ idea }}
              </button>
            </div>
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium">Objectif (facultatif)</label>
            <input
              v-model="generateForm.goal"
              type="text"
              maxlength="300"
              placeholder="Ex. : faire télécharger l'application"
              :class="[inputClass, 'h-10']"
            />
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium">Variantes par réseau et par langue</label>
            <input
              v-model.number="generateForm.count"
              type="number"
              min="1"
              max="5"
              :class="[inputClass, 'h-10']"
            />
            <p class="text-xs text-muted-foreground">
              {{ plannedCount }} publication(s) au total (maximum {{ maxPosts }}).
            </p>
          </div>

          <div
            v-if="generateError"
            class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
          >
            {{ generateError }}
          </div>

          <button
            class="w-full rounded-xl bg-primary px-4 py-2.5 text-sm font-medium text-white transition hover:bg-primaryemphasis disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="isGenerating || !options?.aiConfigured"
            @click="generate"
          >
            <span v-if="isGenerating">Rédaction en cours… (jusqu'à une minute)</span>
            <span v-else>Générer les brouillons</span>
          </button>
        </div>

        <div class="space-y-4">
          <p v-if="!generated.length && !isGenerating" class="text-sm text-muted-foreground">
            Les brouillons générés apparaîtront ici. Ils sont aussi enregistrés dans l'onglet
            « Brouillons ».
          </p>
          <template v-for="post in generated" :key="post.id">
            <Card class="border border-border/60">
              <div class="space-y-3 p-4">
                <div class="flex flex-wrap items-center gap-2">
                  <span class="rounded-full border border-border px-2.5 py-1 text-xs font-medium">{{ post.networkLabel }}</span>
                  <span class="rounded-full border border-border px-2.5 py-1 text-xs font-medium">{{ post.languageLabel }}</span>
                  <span :class="STATUS_CLASSES[post.status]" class="rounded-full px-2.5 py-1 text-xs font-medium">
                    {{ STATUS_LABELS[post.status] }}
                  </span>
                  <span class="ml-auto text-xs text-muted-foreground">{{ post.reference }}</span>
                </div>
                <p v-if="post.title" class="text-sm font-semibold">{{ post.title }}</p>

                <template v-if="editingId === post.id">
                  <textarea v-model="editForm.content" rows="8" :class="[inputClass, 'py-2']" />
                  <input v-model="editForm.hashtags" type="text" placeholder="#VizioBox #Tontine" :class="[inputClass, 'h-10']" />
                </template>
                <template v-else>
                  <p class="whitespace-pre-line text-sm">{{ post.content }}</p>
                  <p v-if="post.hashtags.length" class="text-sm text-primary">{{ post.hashtags.join(" ") }}</p>
                </template>

                <div v-if="post.visualIdea" class="rounded-xl border border-border/60 bg-muted/20 p-3 text-xs">
                  <span class="font-medium">Visuel : </span>{{ post.visualIdea }}
                </div>
                <p v-if="post.callToAction" class="text-xs text-muted-foreground">
                  Appel à l'action : {{ post.callToAction }}
                </p>

                <div class="flex flex-wrap gap-2">
                  <template v-if="editingId === post.id">
                    <button class="rounded-xl bg-primary px-3 py-1.5 text-xs font-medium text-white" :disabled="busyId === post.id" @click="saveEdit(post)">Enregistrer</button>
                    <button class="rounded-xl border border-border px-3 py-1.5 text-xs font-medium" @click="editingId = null">Annuler</button>
                  </template>
                  <template v-else>
                    <button class="rounded-xl border border-border px-3 py-1.5 text-xs font-medium hover:bg-muted" @click="copyPost(post)">Copier</button>
                    <button v-if="['draft', 'approved'].includes(post.status)" class="rounded-xl border border-border px-3 py-1.5 text-xs font-medium hover:bg-muted" @click="startEdit(post)">Modifier</button>
                    <button v-if="post.status === 'draft'" class="rounded-xl bg-sky-600 px-3 py-1.5 text-xs font-medium text-white" :disabled="busyId === post.id" @click="setStatus(post, 'approved')">Valider</button>
                    <button v-if="post.status === 'approved'" class="rounded-xl bg-emerald-600 px-3 py-1.5 text-xs font-medium text-white" :disabled="busyId === post.id" @click="setStatus(post, 'published')">Marquer publié</button>
                    <button v-if="post.status !== 'archived'" class="rounded-xl border border-border px-3 py-1.5 text-xs font-medium text-muted-foreground hover:bg-muted" :disabled="busyId === post.id" @click="setStatus(post, 'archived')">Archiver</button>
                  </template>
                </div>
              </div>
            </Card>
          </template>
        </div>
      </div>

      <!-- Répondre à un commentaire -->
      <div v-if="activeTab === 'reply'" class="mt-6 grid gap-6 xl:grid-cols-2">
        <div class="space-y-4">
          <div class="space-y-2">
            <p class="text-sm font-medium">Réseau</p>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="network in options?.networks || []"
                :key="network.key"
                class="rounded-full border px-3 py-1.5 text-sm transition"
                :class="chipClass(replyForm.network === network.key)"
                @click="replyForm.network = network.key"
              >
                {{ network.label }}
              </button>
            </div>
          </div>
          <div class="space-y-2">
            <label class="text-sm font-medium">Commentaire ou message reçu</label>
            <textarea
              v-model="replyForm.comment"
              rows="5"
              maxlength="3000"
              placeholder="Collez ici le commentaire, en français ou en fongbe"
              :class="[inputClass, 'py-2']"
            />
            <p class="text-xs text-muted-foreground">
              Évitez de coller le numéro de téléphone ou le nom complet de la personne.
            </p>
          </div>
          <div class="space-y-2">
            <label class="text-sm font-medium">Publication concernée (facultatif)</label>
            <input
              v-model="replyForm.postContext"
              type="text"
              maxlength="1000"
              placeholder="Ex. : annonce du paiement Mobile Money"
              :class="[inputClass, 'h-10']"
            />
          </div>
          <div
            v-if="replyError"
            class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
          >
            {{ replyError }}
          </div>
          <button
            class="w-full rounded-xl bg-primary px-4 py-2.5 text-sm font-medium text-white transition hover:bg-primaryemphasis disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="isReplying || !options?.aiConfigured"
            @click="suggestReply"
          >
            <span v-if="isReplying">Analyse en cours…</span>
            <span v-else>Proposer une réponse</span>
          </button>
        </div>

        <div>
          <p v-if="!replyResult" class="text-sm text-muted-foreground">La réponse proposée apparaîtra ici.</p>
          <Card v-else class="border border-border/60">
            <div class="space-y-3 p-4">
              <div
                v-if="replyResult.needsSupport"
                class="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700"
              >
                <p class="font-medium">À transmettre au support</p>
                <p v-if="replyResult.supportReason" class="mt-1 text-xs">{{ replyResult.supportReason }}</p>
                <p class="mt-1 text-xs">
                  Répondez publiquement avec le texte ci-dessous, puis traitez la demande en privé.
                </p>
              </div>
              <div class="flex flex-wrap gap-2 text-xs">
                <span class="rounded-full border border-border px-2.5 py-1 font-medium">
                  {{ CATEGORY_LABELS[replyResult.category || 'autre'] || replyResult.category }}
                </span>
                <span class="rounded-full border border-border px-2.5 py-1 font-medium">Ton : {{ replyResult.sentiment }}</span>
                <span class="rounded-full border border-border px-2.5 py-1 font-medium">{{ replyResult.languageLabel }}</span>
              </div>
              <template v-if="editingId === replyResult.id">
                <textarea v-model="editForm.content" rows="5" :class="[inputClass, 'py-2']" />
              </template>
              <p v-else class="whitespace-pre-line text-sm">{{ replyResult.content }}</p>
              <div class="flex flex-wrap gap-2">
                <template v-if="editingId === replyResult.id">
                  <button class="rounded-xl bg-primary px-3 py-1.5 text-xs font-medium text-white" @click="saveEdit(replyResult)">Enregistrer</button>
                  <button class="rounded-xl border border-border px-3 py-1.5 text-xs font-medium" @click="editingId = null">Annuler</button>
                </template>
                <template v-else>
                  <button class="rounded-xl border border-border px-3 py-1.5 text-xs font-medium hover:bg-muted" @click="copyPost(replyResult)">Copier</button>
                  <button v-if="['draft', 'approved'].includes(replyResult.status)" class="rounded-xl border border-border px-3 py-1.5 text-xs font-medium hover:bg-muted" @click="startEdit(replyResult)">Modifier</button>
                  <button v-if="replyResult.status === 'draft'" class="rounded-xl bg-sky-600 px-3 py-1.5 text-xs font-medium text-white" @click="setStatus(replyResult, 'approved')">Valider</button>
                  <button v-if="replyResult.status === 'approved'" class="rounded-xl bg-emerald-600 px-3 py-1.5 text-xs font-medium text-white" @click="setStatus(replyResult, 'published')">Marquer publié</button>
                </template>
              </div>
            </div>
          </Card>
        </div>
      </div>

      <!-- Brouillons -->
      <div v-if="activeTab === 'drafts'" class="mt-6 space-y-4">
        <div class="flex flex-wrap items-center gap-3">
          <select v-model="filters.status" :class="[inputClass, 'h-10 w-auto']">
            <option value="">Tous (hors archivés)</option>
            <option v-for="(label, key) in STATUS_LABELS" :key="key" :value="key">{{ label }}</option>
          </select>
          <select v-model="filters.kind" :class="[inputClass, 'h-10 w-auto']">
            <option value="">Publications et réponses</option>
            <option value="post">Publications</option>
            <option value="reply">Réponses</option>
          </select>
          <select v-model="filters.network" :class="[inputClass, 'h-10 w-auto']">
            <option value="">Tous les réseaux</option>
            <option v-for="network in options?.networks || []" :key="network.key" :value="network.key">
              {{ network.label }}
            </option>
          </select>
          <label class="flex items-center gap-2 text-sm">
            <input v-model="filters.needsSupport" type="checkbox" />
            À transmettre au support
          </label>
          <button
            class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
            :disabled="isLoadingDrafts"
            @click="loadDrafts"
          >
            Rafraichir
          </button>
        </div>

        <div
          v-if="draftsError"
          class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
        >
          {{ draftsError }}
        </div>
        <p v-if="isLoadingDrafts" class="text-sm text-muted-foreground">Chargement…</p>
        <p v-else-if="!drafts.length" class="text-sm text-muted-foreground">Aucun brouillon.</p>

        <div class="grid gap-4 lg:grid-cols-2">
          <Card v-for="post in drafts" :key="post.id" class="border border-border/60">
            <div class="space-y-3 p-4">
              <div class="flex flex-wrap items-center gap-2">
                <span class="rounded-full border border-border px-2.5 py-1 text-xs font-medium">
                  {{ post.kind === 'reply' ? 'Réponse' : 'Publication' }} · {{ post.networkLabel }} · {{ post.languageLabel }}
                </span>
                <span :class="STATUS_CLASSES[post.status]" class="rounded-full px-2.5 py-1 text-xs font-medium">
                  {{ STATUS_LABELS[post.status] }}
                </span>
                <span v-if="post.needsSupport" class="rounded-full bg-rose-100 px-2.5 py-1 text-xs font-medium text-rose-700">
                  Support
                </span>
                <span class="ml-auto text-xs text-muted-foreground">{{ post.reference }}</span>
              </div>
              <p v-if="post.sourceText" class="rounded-xl border border-border/60 bg-muted/20 p-3 text-xs italic">« {{ post.sourceText }} »</p>
              <p v-if="post.title" class="text-sm font-semibold">{{ post.title }}</p>

              <template v-if="editingId === post.id">
                <textarea v-model="editForm.content" rows="7" :class="[inputClass, 'py-2']" />
                <input v-if="post.kind === 'post'" v-model="editForm.hashtags" type="text" :class="[inputClass, 'h-10']" />
              </template>
              <template v-else>
                <p class="whitespace-pre-line text-sm">{{ post.content }}</p>
                <p v-if="post.hashtags.length" class="text-sm text-primary">{{ post.hashtags.join(" ") }}</p>
              </template>

              <p class="text-xs text-muted-foreground">
                Créé le {{ formatDate(post.createdAt) }}
                <template v-if="post.approvedBy"> · validé par {{ post.approvedBy }}</template>
                <template v-if="post.publishedAt"> · publié le {{ formatDate(post.publishedAt) }}</template>
              </p>

              <div class="flex flex-wrap gap-2">
                <template v-if="editingId === post.id">
                  <button class="rounded-xl bg-primary px-3 py-1.5 text-xs font-medium text-white" :disabled="busyId === post.id" @click="saveEdit(post)">Enregistrer</button>
                  <button class="rounded-xl border border-border px-3 py-1.5 text-xs font-medium" @click="editingId = null">Annuler</button>
                </template>
                <template v-else>
                  <button class="rounded-xl border border-border px-3 py-1.5 text-xs font-medium hover:bg-muted" @click="copyPost(post)">Copier</button>
                  <button v-if="['draft', 'approved'].includes(post.status)" class="rounded-xl border border-border px-3 py-1.5 text-xs font-medium hover:bg-muted" @click="startEdit(post)">Modifier</button>
                  <button v-if="post.status === 'draft'" class="rounded-xl bg-sky-600 px-3 py-1.5 text-xs font-medium text-white" :disabled="busyId === post.id" @click="setStatus(post, 'approved')">Valider</button>
                  <button v-if="post.status === 'approved'" class="rounded-xl bg-emerald-600 px-3 py-1.5 text-xs font-medium text-white" :disabled="busyId === post.id" @click="setStatus(post, 'published')">Marquer publié</button>
                  <button v-if="post.status === 'archived'" class="rounded-xl border border-border px-3 py-1.5 text-xs font-medium hover:bg-muted" :disabled="busyId === post.id" @click="setStatus(post, 'draft')">Restaurer</button>
                  <button v-else class="rounded-xl border border-border px-3 py-1.5 text-xs font-medium text-muted-foreground hover:bg-muted" :disabled="busyId === post.id" @click="setStatus(post, 'archived')">Archiver</button>
                </template>
              </div>
            </div>
          </Card>
        </div>

        <div v-if="pagination.pages > 1" class="flex items-center justify-center gap-3 text-sm">
          <button class="rounded-xl border border-border px-3 py-1.5" :disabled="pagination.page <= 1" @click="goToPage(pagination.page - 1)">Précédent</button>
          <span>Page {{ pagination.page }} / {{ pagination.pages }} ({{ pagination.total }})</span>
          <button class="rounded-xl border border-border px-3 py-1.5" :disabled="pagination.page >= pagination.pages" @click="goToPage(pagination.page + 1)">Suivant</button>
        </div>
      </div>

      <!-- Fiche de marque -->
      <div v-if="activeTab === 'brand'" class="mt-6 max-w-3xl space-y-4">
        <p class="text-sm text-muted-foreground">
          C'est la référence de l'assistant : il n'affirme que les faits listés ici et respecte les
          interdits. Mettez-la à jour à chaque nouveauté (nouvelle fonctionnalité, numéro du support…).
        </p>
        <div
          v-if="brand.isDefault"
          class="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800"
        >
          Fiche par défaut : relisez-la, complétez le contact du support, puis enregistrez.
        </div>
        <div
          v-if="brandError"
          class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
        >
          {{ brandError }}
        </div>

        <div class="space-y-2">
          <label class="text-sm font-medium">Nom de la marque</label>
          <input v-model="brand.brandName" type="text" maxlength="80" :class="[inputClass, 'h-10']" />
        </div>
        <div class="space-y-2">
          <label class="text-sm font-medium">Description</label>
          <textarea v-model="brand.description" rows="4" maxlength="1500" :class="[inputClass, 'py-2']" />
        </div>
        <div class="space-y-2">
          <label class="text-sm font-medium">Public visé</label>
          <textarea v-model="brand.audience" rows="2" maxlength="800" :class="[inputClass, 'py-2']" />
        </div>
        <div class="space-y-2">
          <label class="text-sm font-medium">Ton</label>
          <textarea v-model="brand.tone" rows="2" maxlength="800" :class="[inputClass, 'py-2']" />
        </div>
        <div class="space-y-2">
          <label class="text-sm font-medium">Faits vérifiés (un par ligne)</label>
          <textarea v-model="brand.keyFacts" rows="5" :class="[inputClass, 'py-2']" />
        </div>
        <div class="space-y-2">
          <label class="text-sm font-medium">Interdits (un par ligne)</label>
          <textarea v-model="brand.forbiddenClaims" rows="5" :class="[inputClass, 'py-2']" />
        </div>
        <div class="space-y-2">
          <label class="text-sm font-medium">Contact du support</label>
          <input v-model="brand.supportContact" type="text" maxlength="300" :class="[inputClass, 'h-10']" />
        </div>
        <div class="space-y-2">
          <label class="text-sm font-medium">Hashtags de marque</label>
          <input v-model="brand.defaultHashtags" type="text" placeholder="#VizioBox #Tontine" :class="[inputClass, 'h-10']" />
        </div>
        <button
          class="rounded-xl bg-primary px-4 py-2 text-sm font-medium text-white transition hover:bg-primaryemphasis disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="isSavingBrand"
          @click="saveBrand"
        >
          <span v-if="isSavingBrand">Enregistrement…</span>
          <span v-else>Enregistrer la fiche</span>
        </button>
      </div>
    </div>
  </Card>
</template>
