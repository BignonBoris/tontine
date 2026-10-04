# Guide de Déploiement Render : WhatsApp OTP & Puppeteer

Ce document résume la configuration nécessaire pour faire fonctionner le service **WhatsApp OTP** basé sur `whatsapp-web.js` / Puppeteer sur **Render.com**.

---

## 1. Contexte du problème initial

Sur Render, lors du déploiement en environnement Node.js natif :
- Puppeteer téléchargeait Chromium dans `~/.cache/puppeteer` (`/opt/render/.cache/puppeteer`).
- Lors de l'étape de mise en ligne (passage Build -> Runtime), **seul le dossier du projet** (`/opt/render/project/src/api`) est préservé.
- Le dossier hors-projet `/opt/render/.cache/` n'était pas transféré, provoquant l'erreur au démarrage :
  ```text
  Error: Could not find Chrome (ver. 146.0.7680.31). This can occur if either
  1. you did not perform an installation before running the script (e.g. `npx puppeteer browsers install chrome`) or
  2. your cache path is incorrectly configured (which is: /opt/render/.cache/puppeteer).
  ```

---

## 2. Architecture de la solution

### A. Fichier `.puppeteerrc.cjs` (à la racine de `api/`)
Ce fichier configure Puppeteer pour enregistrer et chercher Chromium **au sein même du projet** :
```javascript
const { join } = require('path');

module.exports = {
  // Définition du cache à l'intérieur du dossier api/
  cacheDirectory: join(__dirname, '.cache', 'puppeteer'),
};
```
*Note : ce fichier DOIT impérativement être commité et pushé sur Git.*

### B. Scripts `api/package.json`
Le hook `postinstall` garantit que Chrome est systématiquement téléchargé dès que Render exécute `npm install` (y compris avec la commande de build Render par défaut) :
```json
"scripts": {
  "postinstall": "npx puppeteer browsers install chrome",
  "render-build": "npm install && npx puppeteer browsers install chrome",
  "build": "npx puppeteer browsers install chrome",
  "start": "node app.js"
}
```

### C. Auto-récupération à chaud (`whatsapp-otp.service.js`)
Si le serveur redémarre sans le cache de build, la méthode `_resolveOrInstallChrome()` vérifie la présence effective du binaire Chromium avant le lancement de Puppeteer. S'il est manquant, elle exécute dynamiquement `npx puppeteer browsers install chrome` pour auto-guérir le service sans interruption.

### D. Fichier `api/.gitignore`
Le dossier `.cache/` (contenant le binaire Chromium d'environ 300 Mo téléchargé lors du build) ainsi que les sessions WhatsApp sont ignorés :
```gitignore
.cache/
.wwebjs_auth/
.wwebjs_cache/
```

### E. Alternative Docker (`api/Dockerfile`)
Un Dockerfile avec `node:20-slim` et Chromium système (`apt-get install chromium`) est également disponible à la racine de `api/` pour un déploiement 100% conteneurisé.

---

## 3. Configuration requise sur Render Dashboard

1. **Root Directory** : `api` (ou vide si le repo ne contient que l'API)
2. **Build Command** : `npm run render-build` ou simplement `npm install` (le hook `postinstall` s'exécute automatiquement dans les deux cas)
3. **Start Command** : `npm start` (ou `node app.js`)
4. **Variables d'environnement utiles** :
   - `ENABLE_WHATSAPP_OTP` : `true` (défaut) pour activer l'envoi réel et le QR code, `false` pour le mode fallback console (dev/test sans lancer Puppeteer, économie de RAM).
   - `PUPPETEER_CACHE_DIR` : (optionnel) `/opt/render/project/src/api/.cache/puppeteer`.

---

## 4. Première connexion WhatsApp

1. Une fois le déploiement terminé, le serveur initialise WhatsApp Web.
2. Le QR Code est imprimé dans les **logs de Render** et accessible sur le dashboard Admin (`/platform/whatsapp`).
3. Scannez le QR Code avec un téléphone ayant WhatsApp pour lier la session d'expédition des OTP.

