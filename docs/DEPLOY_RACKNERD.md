# Déployer l'API VizioBox sur un VPS RackNerd

Architecture cible :

```
Apps mobiles / admin ──HTTPS──▶ api.<ton-domaine> (Nginx + Let's Encrypt)
                                   │
                                   ▼
                          Node 22 + PM2 (API Express, cron de réconciliation)
                                   │  SSL
                                   ▼
                          MySQL managé sur Aiven (inchangé)
```

Ce qui change par rapport à Vercel : le serveur tourne en permanence. Il n'y a donc plus de démarrage à froid ni de quota CPU, et le cron de réconciliation, le SSE, le rate limiting et les uploads locaux fonctionnent.

Durée estimée : 1 h à 1 h 30 la première fois.

---

## 0. Avant d'acheter

1. **Région de la base Aiven.** Dans la console Aiven, ouvre le service MySQL et note le *Cloud / Region* (par exemple `do-ams` ou `google-europe-west1`).
   - Choisis un datacenter RackNerd **le plus proche possible de cette région**. Chaque requête de l'API fait plusieurs allers-retours vers la base, donc cette distance compte plus que celle avec les utilisateurs.
   - Si RackNerd n'a pas de datacenter proche, il faudra envisager de déplacer la base plus tard.
2. **Offre conseillée** : au moins **1 vCPU, 1 Go de RAM et 20 Go de SSD**, en paiement annuel. Les offres Black Friday ou « New Year » sont souvent autour de 10–12 $ par an. Prends **2 Go** si l'écart de prix est faible.
3. **Système** : Ubuntu **24.04** (sinon 22.04).
4. **Domaine** : il faut un sous-domaine, par exemple `api.<ton-domaine>`, que tu pourras faire pointer vers le VPS.

Après l'achat, RackNerd envoie par email **l'IP du VPS et le mot de passe root**. Ne les partage pas.

---

## 1. Première connexion et sécurisation

Depuis ton PC (PowerShell ou Git Bash) :

```bash
ssh root@IP_DU_VPS
```

Sur le VPS :

```bash
# Mises à jour
apt update && apt upgrade -y

# Utilisateur dédié (ne pas faire tourner l'API en root)
adduser viziobox
usermod -aG sudo viziobox

# Mises à jour de sécurité automatiques + anti-bruteforce SSH
apt install -y unattended-upgrades fail2ban
dpkg-reconfigure -plow unattended-upgrades

# Pare-feu : SSH + HTTP + HTTPS uniquement
ufw allow OpenSSH
ufw allow 'Nginx Full' 2>/dev/null || { ufw allow 80; ufw allow 443; }
ufw enable

# Swap de 2 Go (indispensable avec 1 Go de RAM)
fallocate -l 2G /swapfile && chmod 600 /swapfile
mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

### Connexion par clé SSH (recommandé)

Sur **ton PC** :

```bash
ssh-keygen -t ed25519 -C "viziobox-vps"
ssh-copy-id viziobox@IP_DU_VPS
```

`ssh-copy-id` n'existe pas dans PowerShell : utilise Git Bash, ou copie le contenu de `~/.ssh/id_ed25519.pub` dans `/home/viziobox/.ssh/authorized_keys` sur le VPS.

Vérifie que `ssh viziobox@IP_DU_VPS` fonctionne **sans mot de passe**. Désactive ensuite la connexion par mot de passe et la connexion en root :

```bash
sudo sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/; s/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

> ⚠️ Garde ta session SSH actuelle ouverte pendant que tu testes une nouvelle connexion dans un autre terminal. Sinon tu risques de te bloquer l'accès au serveur.

À partir d'ici, tout se fait connecté en `viziobox`.

---

## 2. Installer Node 22, PM2, Nginx et Git

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs nginx git
sudo npm install -g pm2
node -v   # doit afficher v22.x
```

---

## 3. Récupérer le code (repo privé)

Le dépôt reste **privé**. On donne au VPS une **clé de déploiement en lecture seule**, valable uniquement pour ce dépôt.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/github_deploy -N "" -C "vps-deploy"
cat ~/.ssh/github_deploy.pub
```

Sur GitHub : **repo du code → Settings → Deploy keys → Add deploy key**.
- Colle la clé.
- Laisse **« Allow write access » décoché**.

```bash
cat >> ~/.ssh/config <<'EOF'
Host github.com
  IdentityFile ~/.ssh/github_deploy
  IdentitiesOnly yes
EOF

git clone git@github.com:<UTILISATEUR>/<REPO_DU_CODE>.git ~/viziobox
cd ~/viziobox/api
git checkout main
```

---

## 4. Variables d'environnement

Le plus simple est de **reprendre les variables de Render**. Sur Render, va dans **Environment**, puis utilise **« Export »** si disponible, sinon copie les variables une par une.

```bash
nano ~/viziobox/api/.env
chmod 600 ~/viziobox/api/.env
```

Valeurs spécifiques au VPS (les autres reprennent celles de Render) :

```dotenv
NODE_ENV=production
PORT=3000
APP_BASE_URL=https://api.<ton-domaine>
CLIENT_APP_BASE_URL=https://api.<ton-domaine>
MTN_MOMO_CALLBACK_BASE_URL=https://api.<ton-domaine>

# Base Aiven (valeurs dans la console Aiven → Overview → Connection information)
DB_HOST=...
DB_PORT=...
DB_NAME=...
DB_USER=...
DB_PASSWORD=...
DB_SSL=true
DB_SSL_REJECT_UNAUTHORIZED=false   # mêmes valeurs que sur Render

# Économie de ressources sur un petit VPS
SWAGGER_ENABLED=false
SEQUELIZE_SYNC=false
ENABLE_WHATSAPP_OTP=false
```

Règles :
- `JWT_SECRET` et `ADMIN_PASSWORD` doivent être **forts**. L'API refuse de démarrer en production avec les valeurs par défaut.
- **Ne commite jamais ce fichier.** `*.env` est déjà dans `api/.gitignore`.
- **Firebase** : mets le JSON du compte de service dans `FIREBASE_SERVICE_ACCOUNT`, sur une seule ligne, ou bien `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL` et `FIREBASE_PRIVATE_KEY`.
- **Aiven** : si tu as activé une **liste d'IP autorisées** (*Allowed IP addresses*), ajoutes-y l'IP du VPS.

---

## 5. Installer, migrer, démarrer

```bash
cd ~/viziobox/api

# --ignore-scripts : évite le postinstall qui télécharge Chrome (~170 Mo),
# inutile tant que WhatsApp Web est désactivé.
npm ci --omit=dev --ignore-scripts

# Migrations sur la base Aiven
npx --yes sequelize-cli db:migrate

# Démarrage avec PM2 (redémarrage auto si crash ou si la mémoire dépasse 450 Mo)
pm2 start app.js --name viziobox-api \
  --node-args="--max-old-space-size=384" \
  --max-memory-restart 450M \
  --time
pm2 save
pm2 startup systemd -u viziobox --hp /home/viziobox   # puis exécute la commande sudo qu'il affiche
pm2 install pm2-logrotate

# Vérification locale
curl -s http://127.0.0.1:3000/health
pm2 logs viziobox-api --lines 50
```

---

## 6. Nom de domaine

Chez ton registrar, ajoute :

| Type | Nom | Valeur | TTL |
|---|---|---|---|
| A | `api` | IP du VPS | 300 |

Vérifie avec `nslookup api.<ton-domaine>`. Cela peut prendre de 5 minutes à quelques heures.

---

## 7. Nginx et HTTPS

```bash
sudo nano /etc/nginx/sites-available/viziobox-api
```

```nginx
server {
    listen 80;
    server_name api.<ton-domaine>;

    # Uploads KYC / justificatifs (l'API accepte jusqu'à 10 Mo)
    client_max_body_size 12m;

    # Flux temps réel (SSE) : pas de mise en tampon
    location /api/v1/notifications/stream {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Connection '';
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 1h;
    }

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/viziobox-api /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# Certificat HTTPS gratuit, renouvelé automatiquement
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.<ton-domaine> --redirect -m <ton-email> --agree-tos
```

Test depuis ton PC : `https://api.<ton-domaine>/health` doit répondre `{"success":true,...}`.

> L'API utilise `app.set('trust proxy', 1)`. Avec Nginx en frontal, c'est correct : le rate limiting voit la vraie IP du client.

---

## 8. Mises à jour (déploiement)

Crée le script une fois :

```bash
cat > ~/deploy.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd ~/viziobox/api
git fetch origin main
git reset --hard origin/main
npm ci --omit=dev --ignore-scripts
npx --yes sequelize-cli db:migrate
pm2 reload viziobox-api --update-env
sleep 3
curl -fsS http://127.0.0.1:3000/health && echo " ✅ déployé"
EOF
chmod +x ~/deploy.sh
```

Ensuite, à chaque mise à jour :

```bash
ssh viziobox@IP_DU_VPS '~/deploy.sh'
```

Le `git reset --hard` écrase toute modification faite à la main sur le VPS. Le `.env` et `src/public/uploads/` ne sont pas versionnés, ils sont donc conservés.

---

## 9. Basculer les services externes vers la nouvelle URL

| Où | Quoi changer |
|---|---|
| **FedaPay** (tableau de bord → Webhooks) | `https://api.<ton-domaine>/api/v1/tontine/fedapay/webhook` |
| **MTN MoMo** | URL de callback (via `MTN_MOMO_CALLBACK_BASE_URL`, déjà dans le `.env`) |
| **AfrikMoney** | `https://api.<ton-domaine>/api/v1/tontine/afrikmoney/webhook` |
| **Admin** (`VITE_API_BASE_URL` dans `admin/.env`, puis rebuild et redéploiement sur Vercel) | `https://api.<ton-domaine>/api/v1` |
| **Apps mobile et agent** (`API_BASE_URL` dans `.env`, puis nouvel APK) | `https://api.<ton-domaine>/api/v1` |

> Les APK déjà installés pointent vers `finance-tontine-api.vercel.app`. Ils ne fonctionneront qu'une fois la nouvelle version installée.
>
> Une fois les apps sur `api.<ton-domaine>`, un futur changement d'hébergeur ne demandera **qu'une modification DNS**, sans nouvel APK.

---

## 10. Sauvegardes et surveillance

- **Base** : Aiven fait ses propres sauvegardes. Vérifie leur fréquence et leur durée de conservation selon ton plan (*Backups* dans la console). Les plans gratuits ont des garanties limitées.
- **Fichiers uploadés** (`~/viziobox/api/src/public/uploads/`) : ils ne sont **que sur le VPS**. Sauvegarde-les régulièrement, par exemple vers ton PC :
  ```bash
  scp -r viziobox@IP_DU_VPS:~/viziobox/api/src/public/uploads ./backup-uploads-$(date +%F)
  ```
- **Disponibilité** : crée une sonde gratuite (UptimeRobot, Better Stack…) sur `https://api.<ton-domaine>/health` avec une alerte par email.
- **Logs** : `pm2 logs viziobox-api`. Pour la mémoire et le CPU : `pm2 monit` ou `htop`.

---

## 11. Dépannage rapide

| Symptôme | Piste |
|---|---|
| `pm2 logs` affiche `[SECURITY] JWT_SECRET...` | Secret absent ou trop faible dans `.env` |
| `ETIMEDOUT` / `ECONNREFUSED` vers la base | IP du VPS absente de la liste autorisée Aiven, mauvais port, ou service Aiven éteint |
| `self signed certificate` | Reprendre les valeurs `DB_SSL*` utilisées sur Render |
| 502 Bad Gateway | L'API ne tourne pas : `pm2 status`, `pm2 logs` |
| Le processus redémarre en boucle | Manque de mémoire : vérifier le swap (`free -h`), ou passer à 2 Go de RAM |
| Certbot échoue | Le DNS ne pointe pas encore vers le VPS, ou les ports 80/443 sont fermés (`sudo ufw status`) |
