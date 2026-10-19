# Publier une nouvelle version APK (hors Play Store)

Les apps **Client** (`mobile/`) et **Agent** (`agent/`) vérifient au démarrage
`GET /api/v1/app-version/client` ou `/app-version/agent`. Si le `build` annoncé par
l'API est supérieur au build installé **et** qu'un `download_url` est renseigné,
une fenêtre propose (ou impose) la mise à jour.

> Règle d'or : le `build` de l'API = le nombre après `+` dans `pubspec.yaml`.

## Étapes (exemple : passer l'app Client en 1.0.1)

1. **Augmenter la version** dans `mobile/pubspec.yaml` (ou `agent/pubspec.yaml`) :
   ```yaml
   version: 1.0.1+2   # 1.0.1 = version affichée, 2 = build (toujours +1)
   ```
2. **Construire l'APK** :
   ```bash
   cd mobile && flutter build apk --release --no-tree-shake-icons
   cd agent  && flutter build apk --release
   ```
   Fichier produit : `build/app/outputs/flutter-apk/app-release.apk`.
3. **Mettre l'APK en ligne** (GitHub Releases, Firebase Storage…) et copier
   le **lien de téléchargement direct** (il doit télécharger le fichier, pas ouvrir une page).
4. **Annoncer la version** dans la console admin, menu **« Versions des apps »** →
   carte de l'app → **« Publier une nouvelle version »** (sans redéploiement).
   Les champs sont contrôlés (format X.Y.Z, build qui ne redescend jamais, lien https…)
   et l'opération est tracée dans l'audit log (`app_version.updated`).

   Équivalent en ligne de commande, avec un token admin :
   ```bash
   curl -X PUT "$API/api/v1/admin/app-versions/client" \
     -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
     -d '{"version": "1.0.1", "build": 2, "min_build": 1, "mandatory": false,
          "download_url": "https://…/viziobox-1.0.1.apk",
          "release_notes": "Corrections et améliorations.", "released_at": "2026-10-20"}'
   ```
   (`/admin/app-versions/agent` pour l'app Agent.)
5. **Vérifier** : `GET $API/api/v1/app-version/client` doit renvoyer le nouveau `build`.

## Rendre une mise à jour obligatoire

- `mandatory: true` → tous les utilisateurs doivent passer au nouveau `build`.
- ou `min_build: N` → seuls les builds installés **inférieurs à N** sont bloqués
  (utile pour couper une version boguée sans forcer tout le monde).

## Valeurs par défaut / secours

- Les lignes `APP_VERSION_AGENT` / `APP_VERSION_CLIENT` sont créées par la migration
  `20261019120000-seed-app-version-settings.js` (build 1, lien vide = rien proposé).
- Si la base est indisponible, l'API lit les variables d'environnement
  `CLIENT_APP_VERSION`, `CLIENT_APP_BUILD`, `CLIENT_APP_MIN_BUILD`, `CLIENT_APP_MANDATORY`,
  `CLIENT_APP_DOWNLOAD_URL`, `CLIENT_APP_RELEASE_NOTES`, `CLIENT_APP_RELEASED_AT`
  (préfixe `AGENT_APP_` pour l'agent).

## ⚠️ Signature

Android n'installe une mise à jour que si elle est signée avec **la même clé** que
l'app déjà installée. Toujours construire avec le même keystore de release.
