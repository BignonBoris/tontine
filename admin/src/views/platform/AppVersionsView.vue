<script setup lang="ts">
import { computed, onMounted, reactive, ref } from "vue";
import { toast } from "vue-sonner";
import Card from "@/components/ui/card/Card.vue";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  appVersionService,
  type AppKey,
  type AppVersionInfo,
} from "@/services/app-versions/appVersionService";
import { getErrorMessage } from "@/services/http/errors";

const APPS: { key: AppKey; label: string; description: string; buildCommand: string }[] = [
  {
    key: "client",
    label: "App Client",
    description: "Application VizioBox des clients (dossier mobile/)",
    buildCommand: "flutter build apk --release --no-tree-shake-icons",
  },
  {
    key: "agent",
    label: "App Agent",
    description: "Application VizioBox Agent des collecteurs (dossier agent/)",
    buildCommand: "flutter build apk --release",
  },
];

const VERSION_PATTERN = /^\d+\.\d+\.\d+$/;
const MAX_RELEASE_NOTES = 1000;

const versions = ref<Partial<Record<AppKey, AppVersionInfo>>>({});
const isLoading = ref(false);
const errorMessage = ref("");

const dialogOpen = ref(false);
const editingApp = ref<AppKey>("client");
const isSaving = ref(false);
const formError = ref("");
const form = reactive({
  version: "",
  build: 1,
  min_build: 0,
  mandatory: false,
  download_url: "",
  release_notes: "",
  released_at: "",
});

const editingLabel = computed(
  () => APPS.find((app) => app.key === editingApp.value)?.label || ""
);
const currentEditing = computed(() => versions.value[editingApp.value]);
const pubspecPreview = computed(() => `version: ${form.version || "X.Y.Z"}+${form.build || "N"}`);

function today() {
  return new Date().toISOString().slice(0, 10);
}

function isPublished(info?: AppVersionInfo) {
  return Boolean(info && info.build > 0 && info.download_url);
}

async function fetchVersions() {
  errorMessage.value = "";
  isLoading.value = true;
  try {
    versions.value = await appVersionService.list();
  } catch (error) {
    errorMessage.value = getErrorMessage(error, "Chargement des versions impossible.");
  } finally {
    isLoading.value = false;
  }
}

function openEditDialog(app: AppKey) {
  const current = versions.value[app];
  editingApp.value = app;
  formError.value = "";
  // On prépare la version suivante : build + 1, mêmes réglages qu'avant.
  form.version = current?.version || "1.0.0";
  form.build = (current?.build || 0) + 1;
  form.min_build = current?.min_build || 0;
  form.mandatory = false;
  form.download_url = current?.download_url || "";
  form.release_notes = "";
  form.released_at = today();
  dialogOpen.value = true;
}

function validateForm(): string {
  const currentBuild = currentEditing.value?.build || 0;
  if (!VERSION_PATTERN.test(form.version.trim())) {
    return "La version doit avoir le format X.Y.Z (ex. 1.0.1).";
  }
  if (!Number.isInteger(Number(form.build)) || Number(form.build) < 1) {
    return "Le build doit être un entier positif.";
  }
  if (Number(form.build) < currentBuild) {
    return `Le build ne peut pas redescendre (actuel : ${currentBuild}).`;
  }
  const minBuild = Number(form.min_build);
  if (!Number.isInteger(minBuild) || minBuild < 0 || minBuild > Number(form.build)) {
    return "Le build minimum doit être compris entre 0 et le build publié.";
  }
  try {
    const url = new URL(form.download_url.trim());
    if (url.protocol !== "https:") throw new Error();
  } catch {
    return "Le lien de téléchargement doit être une adresse https:// valide.";
  }
  if (form.release_notes.trim().length > MAX_RELEASE_NOTES) {
    return `Les nouveautés ne doivent pas dépasser ${MAX_RELEASE_NOTES} caractères.`;
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(form.released_at)) {
    return "La date de publication est invalide.";
  }
  return "";
}

async function submitForm() {
  formError.value = validateForm();
  if (formError.value) return;

  const willBlock = form.mandatory || Number(form.min_build) > (currentEditing.value?.min_build || 0);
  if (
    willBlock &&
    !window.confirm(
      "Cette publication va bloquer certains utilisateurs tant qu'ils n'auront pas installé la nouvelle version. Continuer ?"
    )
  ) {
    return;
  }

  isSaving.value = true;
  try {
    const saved = await appVersionService.update(editingApp.value, {
      version: form.version.trim(),
      build: Number(form.build),
      min_build: Number(form.min_build),
      mandatory: form.mandatory,
      download_url: form.download_url.trim(),
      release_notes: form.release_notes.trim(),
      released_at: form.released_at,
    });
    versions.value = { ...versions.value, [editingApp.value]: saved };
    toast.success(`${editingLabel.value} : version ${saved.version} (build ${saved.build}) publiée.`);
    dialogOpen.value = false;
  } catch (error) {
    formError.value = getErrorMessage(error, "Publication de la version impossible.");
  } finally {
    isSaving.value = false;
  }
}

onMounted(fetchVersions);
</script>

<template>
  <Card class="border border-border/60">
    <div class="p-6">
      <div>
        <h1 class="text-xl font-semibold">Versions des apps</h1>
        <p class="mt-1 text-sm text-muted-foreground">
          Version publiée de chaque application. Les utilisateurs dont l'app est plus ancienne
          voient une fenêtre de mise à jour au démarrage (APK hors Play Store).
        </p>
      </div>

      <div class="mt-6 flex flex-wrap items-center gap-3">
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          :disabled="isLoading"
          @click="fetchVersions"
        >
          Rafraichir
        </button>
      </div>

      <div
        v-if="errorMessage"
        class="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
      >
        {{ errorMessage }}
      </div>

      <div v-if="isLoading && !Object.keys(versions).length" class="mt-6 text-sm text-muted-foreground">
        Chargement des versions...
      </div>

      <div v-else class="mt-6 grid gap-4 lg:grid-cols-2">
        <Card v-for="app in APPS" :key="app.key" class="border border-border/60">
          <div class="space-y-4 p-5">
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="text-base font-semibold">{{ app.label }}</p>
                <p class="text-xs text-muted-foreground">{{ app.description }}</p>
              </div>
              <span
                :class="
                  isPublished(versions[app.key])
                    ? 'bg-emerald-100 text-emerald-700'
                    : 'bg-amber-100 text-amber-700'
                "
                class="shrink-0 rounded-full px-2.5 py-1 text-xs font-medium"
              >
                {{ isPublished(versions[app.key]) ? "Mise à jour active" : "Aucune version publiée" }}
              </span>
            </div>

            <div class="grid grid-cols-2 gap-3 text-sm">
              <div class="rounded-2xl border border-border/60 bg-muted/20 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Version</p>
                <p class="mt-1 text-xl font-semibold">{{ versions[app.key]?.version || "—" }}</p>
              </div>
              <div class="rounded-2xl border border-border/60 bg-muted/20 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Build</p>
                <p class="mt-1 text-xl font-semibold">{{ versions[app.key]?.build ?? "—" }}</p>
              </div>
              <div class="rounded-2xl border border-border/60 bg-muted/20 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Build minimum</p>
                <p class="mt-1 text-xl font-semibold">{{ versions[app.key]?.min_build ?? "—" }}</p>
              </div>
              <div class="rounded-2xl border border-border/60 bg-muted/20 p-3">
                <p class="text-xs uppercase tracking-[0.2em] text-muted-foreground">Publiée le</p>
                <p class="mt-1 text-xl font-semibold">{{ versions[app.key]?.released_at || "—" }}</p>
              </div>
            </div>

            <div v-if="isPublished(versions[app.key])" class="flex flex-wrap gap-2">
              <span
                :class="
                  versions[app.key]?.mandatory
                    ? 'bg-rose-100 text-rose-700'
                    : 'bg-sky-100 text-sky-700'
                "
                class="rounded-full px-2.5 py-1 text-xs font-medium"
              >
                {{ versions[app.key]?.mandatory ? "Mise à jour obligatoire" : "Mise à jour facultative" }}
              </span>
            </div>

            <div class="space-y-1 text-sm">
              <p class="font-medium">Lien de l'APK</p>
              <a
                v-if="versions[app.key]?.download_url"
                :href="versions[app.key]?.download_url"
                target="_blank"
                rel="noopener"
                class="block break-all text-primary underline"
              >
                {{ versions[app.key]?.download_url }}
              </a>
              <p v-else class="text-muted-foreground">Aucun lien renseigné.</p>
            </div>

            <div class="space-y-1 text-sm">
              <p class="font-medium">Nouveautés</p>
              <p class="whitespace-pre-line text-muted-foreground">
                {{ versions[app.key]?.release_notes || "—" }}
              </p>
            </div>

            <button
              class="w-full rounded-xl bg-primary px-4 py-2 text-sm font-medium text-white transition hover:bg-primaryemphasis"
              @click="openEditDialog(app.key)"
            >
              Publier une nouvelle version
            </button>
          </div>
        </Card>
      </div>
    </div>
  </Card>

  <Dialog :open="dialogOpen" @update:open="dialogOpen = $event">
    <DialogContent class="max-h-[90vh] overflow-y-auto sm:max-w-[560px]">
      <DialogHeader>
        <DialogTitle>Publier une version — {{ editingLabel }}</DialogTitle>
        <DialogDescription>
          Version actuelle : {{ currentEditing?.version || "—" }} (build {{ currentEditing?.build ?? 0 }}).
          Mettez d'abord l'APK en ligne, puis renseignez ce formulaire.
        </DialogDescription>
      </DialogHeader>

      <div class="space-y-4">
        <div
          v-if="formError"
          class="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700"
        >
          {{ formError }}
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div class="space-y-2">
            <label class="text-sm font-medium">Version</label>
            <input
              v-model="form.version"
              type="text"
              placeholder="1.0.1"
              class="h-10 w-full rounded-xl border border-border bg-background px-3 text-sm"
            />
          </div>
          <div class="space-y-2">
            <label class="text-sm font-medium">Build</label>
            <input
              v-model.number="form.build"
              type="number"
              min="1"
              step="1"
              class="h-10 w-full rounded-xl border border-border bg-background px-3 text-sm"
            />
          </div>
        </div>
        <p class="-mt-2 text-xs text-muted-foreground">
          Doit correspondre à <code class="rounded bg-slate-100 px-1 text-slate-800">pubspec.yaml</code> :
          <code class="rounded bg-slate-100 px-1 text-slate-800">{{ pubspecPreview }}</code>
        </p>

        <div class="space-y-2">
          <label class="text-sm font-medium">Lien de téléchargement de l'APK</label>
          <input
            v-model="form.download_url"
            type="url"
            placeholder="https://github.com/.../releases/download/v1.0.1/viziobox-client-1.0.1.apk"
            class="h-10 w-full rounded-xl border border-border bg-background px-3 text-sm"
          />
          <p class="text-xs text-muted-foreground">
            Lien direct : il doit télécharger le fichier .apk, pas ouvrir une page.
          </p>
        </div>

        <div class="space-y-2">
          <label class="text-sm font-medium">Nouveautés</label>
          <textarea
            v-model="form.release_notes"
            rows="4"
            :maxlength="MAX_RELEASE_NOTES"
            placeholder="- Paiement Mobile Money plus rapide&#10;- Correction de l'affichage du solde"
            class="w-full rounded-xl border border-border bg-background px-3 py-2 text-sm"
          />
          <p class="text-right text-xs text-muted-foreground">
            {{ form.release_notes.length }} / {{ MAX_RELEASE_NOTES }}
          </p>
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div class="space-y-2">
            <label class="text-sm font-medium">Date de publication</label>
            <input
              v-model="form.released_at"
              type="date"
              class="h-10 w-full rounded-xl border border-border bg-background px-3 text-sm"
            />
          </div>
          <div class="space-y-2">
            <label class="text-sm font-medium">Build minimum accepté</label>
            <input
              v-model.number="form.min_build"
              type="number"
              min="0"
              step="1"
              class="h-10 w-full rounded-xl border border-border bg-background px-3 text-sm"
            />
          </div>
        </div>
        <p class="-mt-2 text-xs text-muted-foreground">
          Les apps avec un build inférieur au build minimum sont obligées de se mettre à jour.
          Laissez la valeur actuelle si vous ne voulez bloquer personne.
        </p>

        <label class="flex items-start gap-3 rounded-2xl border border-border/60 p-3 text-sm">
          <input v-model="form.mandatory" type="checkbox" class="mt-1" />
          <span>
            <span class="font-medium">Mise à jour obligatoire</span>
            <span class="block text-xs text-muted-foreground">
              Tous les utilisateurs devront installer cette version avant de continuer.
              À réserver aux corrections critiques (sécurité, paiements).
            </span>
          </span>
        </label>
      </div>

      <DialogFooter class="gap-2">
        <button
          class="rounded-xl border border-border px-4 py-2 text-sm font-medium transition hover:bg-muted"
          :disabled="isSaving"
          @click="dialogOpen = false"
        >
          Annuler
        </button>
        <button
          class="rounded-xl bg-primary px-4 py-2 text-sm font-medium text-white transition hover:bg-primaryemphasis disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="isSaving"
          @click="submitForm"
        >
          <span v-if="isSaving">Publication...</span>
          <span v-else>Publier la version</span>
        </button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
