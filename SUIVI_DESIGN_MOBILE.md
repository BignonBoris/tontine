# 📱 Fichier de Suivi - Modernisation Mobile VizioBox

Ce document trace l'avancement écran par écran du chantier de modernisation UI/UX, d'ergonomie et de conformité FinTech de l'application mobile **VizioBox**.

---

## 📊 Tableau de Bord d'Avancement global

| N° | Écran / Composant | Fichier source | Statut | Validation |
| :--- | :--- | :--- | :---: | :---: |
| 1️⃣ | **Splash Screen** | `splash_screen.dart` | ✅ Terminé | 100% Validé |
| 2️⃣ | **Onboarding / Slider** | `onboarding_screen.dart` | ✅ Terminé | 100% Validé |
| 3️⃣ | **Choix d'Authentification** | `auth_choice_screen.dart` | ✅ Terminé | 100% Validé |
| 4️⃣ | **Ouverture de compte (Inscription / Connexion)** | `auth_identification_screen.dart` | ✅ Terminé | 100% Validé & Conforme |
| 🎧 | **Module d'Assistance Client** | `auth_help_bottom_sheet.dart` | ✅ Terminé | 100% Validé |
| 5️⃣ | **Validation OTP (WhatsApp)** | `auth_otp_screen.dart` | ✅ Terminé | 100% Validé & Conforme Prod (WhatsApp 100%) |
| 6️⃣ | **Configuration Code PIN** | `auth_pin_setup_screen.dart` | ✅ Terminé | 100% Validé & Conforme |
| 7️⃣ | **Sélection Boxs d'Épargne (Onboarding)** | `onboarding_goals_selection_screen.dart` | ✅ Terminé | 100% Validé & Connecté API |
| 8️⃣ | **Vérification KYC & Identité** | `kyc_submission_screen.dart` | ✅ Terminé | 100% Validé & Conforme (BCEAO / APDP) |
| 9️⃣ | **Gestion de Tontine (UX/UI)** | `tontine_detail_screen.dart` | ✅ Terminé | 100% Validé & Conforme |

---

## 🛠️ Détail des Réalisations Écran par Écran

### 1️⃣ Splash Screen (`splash_screen.dart`)
- **Apports UI/UX** :
  - Mise en place du fond bleu nuit institutionnel VizioBox (`AppTheme.primaryColor`).
  - Animation fluide d'ouverture de l'application.

---

### 2️⃣ Écran d'Onboarding (`onboarding_screen.dart`)
- **Apports UI/UX** :
  - **Titre Slider 3** : Harmonisé sur une seule ligne *"Des coffres jusqu'au marketplace"*.
  - **Identité de Marque** : Suppression de toute mention parasite ("Web Up Technology").
  - **Bouton CTA** : Modernisation du bouton "Commencer" (taille ajustée, dégradé doré VizioBox `AppTheme.accentGradient` et icône flèche).
  - **Nettoyage du Fond** : Élimination du bloc blanc massif résiduel sous les 3 tags (*Tontine*, *Coffres*, *Marketplace*).

---

### 3️⃣ Écran de Choix d'Authentification (`auth_choice_screen.dart`)
- **Apports UI/UX** :
  - **Pills de Marque** : Remplacement du grand cadre blanc opaque par des badges translucides modernes avec icônes dédiées.
  - **Accents & Textes** : Titre corrigé en *"Prêt à concrétiser vos projets ?"*.
  - **Boutons d'Action** :
    - Bouton *"Ouvrir un compte"* en dégradé doré lumineux avec icône `Icons.person_add_rounded`.
    - Bouton *"Se connecter"* en bouton translucide épuré avec icône `Icons.login_rounded`.

---

### 4️⃣ Écran d'Ouverture de Compte / Connexion (`auth_identification_screen.dart`)
- **Apports UI/UX, Conformité & Sécurité** :
  - **Validation Télécom Réelle (API Backend)** : Intégration de `libphonenumber-js` pour valider le plan de numérotation international (Bénin 🇧🇯, Togo 🇹🇬, UEMOA). Rejet automatique des numéros factices (`0000000000`) et des formats incorrects avant génération d'OTP.
  - **Securisation du PIN (Connexion)** : Code PIN à 4 chiffres **obligatoire** lors de la connexion.
  - **Protection Anti Brute-Force** : Suspension du compte pendant 15 minutes après 3 tentatives de PIN infructueuses (compte à rebours dynamique et audit log `auth.pin_failed`).
  - **Protection Anti-Vol de SIM (Option A MVP)** : Retrait du contournement par SMS direct lors de l'oubli du PIN ; le lien *"Code PIN oublié ?"* redirige de manière sécurisée vers le support client et l'agent tontinier.
  - **Juridique & Conformité APDP Bénin** : Liens interactifs et cliquables vers les **CGU** et la **Politique de Confidentialité** ouvrant une modale complète ([`legal_terms_bottom_sheet.dart`](file:///c:/Users/HP/projects/finance/mobile/lib/features/auth/widgets/legal_terms_bottom_sheet.dart)).
  - **Contrôles de Saisie Avancés** : Capitalisation automatique, validation des prénoms/noms composés, autofill OS, et coche verte dynamique (`✓`).

---

### 🎧 Module d'Assistance Client (`auth_help_bottom_sheet.dart`)
- **Apports UI/UX** :
  - **Accessibilité** : Bouton *"Besoin d'aide ?"* fonctionnel sur tous les écrans d'authentification.
  - **Canaux de Support** :
    - 💬 WhatsApp direct avec message pré-rempli (vers le `+229 01 96 44 73 54`).
    - 📞 Appel téléphonique vers le service client VizioBox (`+229 01 96 44 73 54`).
    - ✉️ Email officiel (`managerwebspace@gmail.com`) avec action de copie automatique.
    - 🛡️ Note de confiance : "Vos informations restent sécurisées et 100% confidentielles."

---

### 5️⃣ Écran de Validation du Code OTP WhatsApp (`auth_otp_screen.dart`)
- **Conformité BCEAO, APDP & Sécurité FinTech** :
  - **Terminologie Normalisée** : Intitulé *« Vérification du numéro »* avec label *« Code envoyé au +229... »*.
  - **Délais de Production Calibrés & Harmonisés** :
    - **Cooldown de renvoi (Front & Back) :** `30 secondes`.
    - **Validité du code secret (TTL) :** `5 minutes` (aligné en API et dans le message WhatsApp).
    - **Blocage anti-brute force :** `15 minutes` après `3 tentatives infructueuses`.
  - **Avertissement Anti-Fraude Obligatoire** : Mention de sécurité explicite (*« Ne partagez jamais ce code, même avec un agent VizioBox »*) et mention de conformité réglementaire BCEAO.
  - **Assistance Client Immédiate** : Bouton d'aide *« Besoin d'aide ? »* unifié en bas de formulaire ouvrant [`auth_help_bottom_sheet.dart`](file:///c:/Users/HP/projects/finance/mobile/lib/features/auth/widgets/auth_help_bottom_sheet.dart) (WhatsApp, Téléphone, Email).
- **Mise en Valeur du Canal WhatsApp & Ergonomie** :
  - **Auto-Fill OS (`AutofillGroup` & `oneTimeCode`)** : Détection automatique et proposition de remplissage en 1-clic.
  - **Coller Rapide (Paste 1-Clic)** : Ventilation automatique d'un code complet à 4 chiffres (ex: `4829`) dans les 4 cases lors d'un "Coller".
  - **Soumission Automatique (Auto-Submit)** : Déclenchement immédiat de la vérification dès que la 4ème case est remplie, sans clic supplémentaire requis.
  - **Smart Backspace & Auto-Clear** : Recul automatique sur case vide et vidage + focus en cas de code erroné.
  - **Bouton CTA Modernisé** : Dégradé doré VizioBox `AppTheme.accentGradient`, coins arrondis 16px et flèche directionnelle.
  - **Sécurité OWASP Mobile** : Désactivation des fuites du clavier virtuel (`enableSuggestions: false`, `autocorrect: false`).
- **Envoi Réel d'OTP par WhatsApp (0 FCFA)** :
  - **Service Open-Source Backend** : Intégration de `whatsapp-otp.service.js` basé sur `whatsapp-web.js` et `qrcode-terminal`.
  - **Résolution d'Identifiant Officiel (`getNumberId`)** : Interrogation des serveurs WhatsApp pour obtenir l'identifiant JID/LID exact de chaque membre.
  - **Gestion de la Réforme 10 chiffres (Bénin)** : Fallback automatique entre le format à 10 chiffres (+229 01...) et l'ancien format à 8 chiffres (+229...) pour garantir 100% de délivrabilité.
  - **Stabilisation du QR Code** : Nettoyage des processus Puppeteer et suppression du `webVersionCache` obsolète pour un affichage stable du QR code.
  - **Résilience Déploiement Cloud (Render)** :
    - Hook `postinstall` dans `package.json` (`npx puppeteer browsers install chrome`) pour forcer le téléchargement du binaire Chromium à chaque `npm install` en phase de build.
    - Module d'auto-récupération à chaud (`_resolveOrInstallChrome()`) dans `whatsapp-otp.service.js` : détection d'absence du binaire au runtime et téléchargement dynamique avant initialisation de Puppeteer, évitant tout plantage en cas de rebuild sans cache.
    - Pilotage flexible via variable d'environnement : `ENABLE_WHATSAPP_OTP=true` pour le service complet avec QR code, ou `false` pour le mode fallback console économique.

---

### 6️⃣ Configuration du Code PIN (`auth_pin_setup_screen.dart`)
- **Apports UI/UX & Sécurité** :
  - **Saisie & Confirmation** : Double champ sécurisé avec masquage, feedback haptique et validation de concordance.
  - **Chiffrement & Local Storage** : Enregistrement local sécurisé et synchronisation distante des préférences.
  - **Transition Onboarding** : Redirection fluide vers l'écran de sélection des boxs d'épargne.

---

### 7️⃣ Sélection des Boxs d'Épargne / Coffres par Défaut (`onboarding_goals_selection_screen.dart`)
- **Apports UI/UX, Gamification & FinTech** :
  - **Résolution de l'état vide (Zero Empty State)** : Sélection de 1 à 3 projets suggérés par l'administration (ex: Scolarité, Commerce, Cérémonies, Urgences, Immobilier).
  - **Design Signature VizioBox** : En-tête bleu nuit institutionnel, cartes animées avec contour doré, badges de cibles financières suggérées (FCFA) et coche de sélection circulaire dorée.
  - **Contrôle & Ergonomie** : Limitation stricte à 3 sélections avec alerte haptique, pré-sélection intelligente du premier projet, compteur dynamique (`X / 3 boxs`).
  - **Bouton Passer & Liberté** : Bouton *"Passer"* pour ne pas bloquer l'onboarding, et mention de réassurance *"Sans engagement financier immédiat"*.
  - **Connexion API Réelle** : Consommation de `GET /v1/goal-templates` et `POST /v1/goal-templates/apply` pour alimenter directement le tableau de bord avec les boxs créées à 0 FCFA.

---

### 9️⃣ Gestion de Tontine (`tontine_detail_screen.dart` & `tontine_history_list.dart`)
- **Améliorations UX/UI & Vulnérabilités Résolues** :
  - **Arrêt Anticipé Sécurisé** : L'icône de pause confuse a été remplacée par une icône d'interruption explicite (`Icons.stop_circle_outlined`). Une modale avec une case à cocher explicite d'acceptation de la retenue de mise a été ajoutée pour éviter les erreurs de manipulation.
  - **Reçu de Cotisation Officiel** : Intégration de la librairie `pdf` et `share_plus` pour générer un véritable reçu en PDF (téléchargeable et partageable via WhatsApp, Drive, etc.) contenant le QR Code de traçabilité certifié VizioBox.
  - **Clarté du Solde** : Ajout de la mention explicite *"Épargne bloquée jusqu'à terme"* sous le total cotisé pour éviter toute confusion avec un solde retirable immédiatement.
  - **Compatibilité Base de Données & Synchronisation (`sync_id`)** :
    - Résolution de l'erreur de champ manquant `Unknown column 'sync_id' in 'field list'` survenue en production lors des requêtes `GET /api/v1/tontine`.
    - Mise à niveau du bootstrap automatique de démarrage (`tontine-history.bootstrap.js`) pour ajouter dynamiquement la colonne `sync_id` (UUID unique) ainsi que `initiated_by_user_id` et `initiator_type` sur `tontine_histories`.
    - Création du bootstrap `provisioning.bootstrap.js` (enregistré dans `run-bootstrap.js`) pour garantir également la présence de `sync_id` sur la table `provisionings`.
    - Création de la migration Sequelize `20260903170000-add-sync-id-to-tontine-histories-and-provisionings.js`.

---

### 8️⃣ Vérification KYC & Identité (`kyc_submission_screen.dart`)
- **Apports UI/UX, Conformité & Sécurité** :
  - **Capture Multi-Face** : Prise en charge distincte du Recto et du Verso selon le type de document (CNI, CIP, Passeport).
  - **Selfie de Vérification** : Module de capture via la caméra frontale pour le contrôle de la vivacité (liveness).
  - **Suivi des Statuts** : Intégration complète avec les statuts du backend (`pending_review`, `verified`, `rejected`) affichés via une carte de statut (couleurs sémantiques).
  - **Réassurance (APDP)** : Mention explicite du chiffrement des données et de la conformité à la réglementation BCEAO et APDP.

---

### 🔟 Enrôlement KYC par l'Agent (`agent_client_enrollment_screen.dart`)
- **Conformité LCB/FT (BCEAO)** :
  - **Désactivation de la Galerie Publique** : L'agent est désormais dans l'obligation stricte d'utiliser l'appareil photo en direct pour capturer les pièces d'identité et les selfies. L'importation d'images préexistantes depuis la galerie est techniquement bloquée pour éviter le vol de données ou le stockage d'images sensibles sur l'appareil personnel de l'agent.

---

### 1️⃣1️⃣ Module Agent : Retraits & Clôtures de Tontine (`agent_withdrawal_payment_sheet.dart` & `agent_close_tontine_sheet.dart`)
- **Apports UI/UX & Sécurité (Maker-Checker)** :
  - **Retrait Direct en 2 étapes** : 
    - Séparation de la saisie (recherche client + montant) et de la validation. 
    - Le backend (`previewDirectWithdrawal`) vérifie le solde avant même d'initier la création.
    - Création de la transaction (envoi OTP SMS au client) *avant* l'affichage du pavé numérique.
  - **Clôture Anticipée par l'Agent** : 
    - Nouveau flux pour les clients "offline" sans application : un bouton "Clôturer la tontine" est disponible sur la fiche client.
    - Validation irréfutable : L'agent initie, mais **le client doit taper son code PIN secret sur l'appareil de l'agent** via le `ClientPinPad` pour valider la clôture.
    - Intégration backend avec `closeClientTontine` qui vérifie le `bcrypt` du PIN avant d'exécuter la liquidation.
