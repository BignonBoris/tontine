# Image Node.js officielle optimisée
FROM node:22-slim

# Installation de Chromium et des bibliothèques système requises par Puppeteer / WhatsApp Web
RUN apt-get update && apt-get install -y \
    chromium \
    fonts-liberation \
    libnss3 \
    libatk-bridge2.0-0 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpangocairo-1.0-0 \
    libatk1.0-0 \
    libcups2 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Indiquer à Puppeteer d'utiliser le binaire Chromium natif du conteneur
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    PORT=3000

# Vercel le definissait automatiquement ; sans lui l'API passe en mode
# developpement (code OTP renvoye dans la reponse, logs de debogage).
ENV NODE_ENV=production

WORKDIR /app

# Dépendances Node
COPY package*.json ./
# --ignore-scripts : le postinstall (scripts/install-chrome.js) télécharge Chrome
# via puppeteer. Inutile ici (Chromium est installé par apt ci-dessus) et le
# dossier scripts/ n'est pas encore copié à cette étape.
RUN npm ci --omit=dev --ignore-scripts

# Code source de l'API
COPY . .

EXPOSE 3000

CMD ["node", "app.js"]
