# Prompt — Vidéo de lancement VizioBox (Remotion), version clients

> À remettre tel quel à l'agent Claude chargé de produire la vidéo.

---

## 1. Ta mission

Tu es motion designer et développeur Remotion. Produis la **vidéo de lancement de VizioBox destinée au grand public (les futurs clients)** avec Remotion (v4, TypeScript, React).

La vidéo raconte une histoire portée par **des personnages animés** (illustration vectorielle « flat » animée en code), entrecoupée de **maquettes animées de l'application mobile Client** VizioBox. Elle doit donner envie de télécharger l'app, inspirer confiance et être comprise par un public non technique au Bénin (zone UEMOA).

**Public cible :** commerçant(e)s, artisans, jeunes actifs, parents. Ce sont des gens qui épargnent déjà « à la maison » ou en tontine informelle et qui veulent réaliser un projet concret.

**Hors cible :** cette vidéo ne s'adresse **pas** aux agents collecteurs. Ne montre pas l'application Agent, ne fais aucun appel à « devenir agent » et ne parle ni de commissions ni de caisse agent. L'agent n'apparaît que comme un **service de proximité** pour le client (dépôt en espèces, retrait).

Livrables :
1. Un projet Remotion autonome dans `launch-video/` (ce dossier).
2. Deux compositions :
   - `LaunchVideo16x9` : 1920×1080, 30 fps, ~85 s (YouTube, site web, Facebook).
   - `LaunchVideo9x16` : 1080×1920, 30 fps, même histoire avec une mise en page pensée pour le vertical (WhatsApp Status, TikTok, Reels), pas un simple recadrage.
3. Les rendus MP4 (H.264) dans `launch-video/out/`.
4. Un `README.md` court : installation, preview (`npx remotion studio`), rendu, où changer les textes et la voix.

---

## 2. Ce qu'est VizioBox pour le client (à respecter fidèlement)

**Promesse :** *« La tontine pour réaliser vos projets. »*

VizioBox est une application mobile qui transforme une épargne régulière en **projets concrets** : la tontine donne la discipline, les **coffres** donnent un but, le **marketplace** permet de concrétiser.

### Fonctionnalités à montrer (uniquement celles vues par le client)

- **Inscription simple** : numéro de téléphone, puis **code OTP**, puis **code PIN** (et empreinte digitale en option) pour déverrouiller l'app.
- **Tableau de bord** : solde total, **solde disponible**, montant en **tontine**, coffres actifs, aperçu du marketplace, notifications.
- **Tontine individuelle** : le client choisit sa **mise** (multiple de 500 FCFA). Un cycle compte **31 mises** : à la fin, **30 mises** reviennent dans son disponible et **1 mise** correspond aux **frais de clôture**. Barre de progression, historique, archives. Un client régulier reçoit un **bonus** versé sur son disponible.
- **Cotiser par Mobile Money** : depuis l'app, le client paie sa cotisation avec **MTN Mobile Money, Moov Money ou Celtiis Cash**, ou par carte **Visa/Mastercard**. Le paiement est sécurisé par **FedaPay**.
- **Ou cotiser en espèces** auprès d'un **agent VizioBox** qui passe près de chez lui. Le dépôt apparaît immédiatement dans l'app avec une référence unique.
- **Coffres projets** : le client crée un coffre (« Machine à coudre », « Loyer », « Rentrée scolaire »…), fixe un objectif et l'alimente depuis son disponible. Des **modèles d'objectifs** prêts à l'emploi existent.
- **Marketplace** : catalogue d'articles. Le client peut **acheter tout de suite** avec son disponible, ou **créer un coffre lié à l'article** (objectif = prix × quantité). Favoris, suivi des commandes.
- **Tontine de groupe** : le client **rejoint le groupe de ses proches via un lien ou un QR code d'invitation**. L'**ordre des tours** est clair ; à chaque tour, un membre reçoit la cagnotte. Tout est visible dans l'app.
- **Retrait sécurisé** : le client génère dans l'app un **QR code de retrait à usage unique** et le présente à un agent VizioBox, qui le scanne et lui remet son argent. Reçu dans l'app.
- **Vérification d'identité (KYC)** : pièce et photo, depuis l'app, ce qui augmente les plafonds.
- **Notifications** : dépôt reçu, fin de cycle, objectif atteint, commande, tour de groupe.
- **Confiance** : chaque opération a une **référence unique** et un historique complet. **Aucune opération n'est jamais effacée.** L'argent est protégé par le PIN et l'empreinte.

### Règles de ton et de conformité (obligatoire)
- **Ne présente JAMAIS VizioBox comme une banque, un placement ou un investissement.** Pas de « rendement », d'« intérêts » ni de « faites fructifier ».
- Formulations autorisées : « application de tontine et d'épargne projet », « épargne disciplinée », « réaliser vos projets ».
- Pas de promesse absolue (« 100 % sans risque », « garanti »). Préfère « tracé », « transparent », « sécurisé par PIN, empreinte et vérification d'identité ».
- **Mobile Money :** écris les noms exactement ainsi : **MTN Mobile Money**, **Moov Money**, **Celtiis Cash**. **N'utilise pas les logos officiels des opérateurs ni de FedaPay** (marques déposées) : affiche des **badges texte** sobres (pastille arrondie avec le nom), dans la charte VizioBox. Ne dis pas que le *retrait* se fait par Mobile Money : seule la **cotisation** passe par Mobile Money, le retrait se fait auprès d'un agent avec le QR code.
- Monnaie : **FCFA**. Les montants s'écrivent avec une espace comme séparateur de milliers : `1 000 FCFA`, `31 000 FCFA`.
- Langue : **français**, phrases courtes, chaleureuses et concrètes. Le tutoiement est interdit : utilise « vous ».

---

## 3. Identité visuelle

Copie ces fichiers dans `launch-video/public/` et utilise-les :
- `../mobile/assets/branding/logo.png` (logo)
- `../mobile/assets/branding/logo_text.png` (logo avec texte)
- `../mobile/assets/branding/viziobox-icon.png` (icône de l'app)
- `../mobile/assets/onboarding/onboarding_1.png`, `onboarding_2.png`, `onboarding_3.png` (illustrations existantes de l'app, utiles pour rester cohérent)

Ouvre-les pour en vérifier le style avant de dessiner les personnages.

**Palette (tokens à définir dans `src/theme.ts`) :**

| Rôle | Hex |
|---|---|
| Primaire (bleu nuit) | `#082040` |
| Primaire variante | `#183860` |
| Secondaire (vert) | `#78B860` |
| Secondaire foncé | `#409848` |
| Accent (or) | `#C89818` |
| Accent foncé | `#805808` |
| Fond clair | `#F4F7FA` |
| Texte principal | `#111827` |
| Texte secondaire | `#667085` |
| Bordure | `#D0D5DD` |
| Succès (confirmation d'opération uniquement) | `#2E7D32` |

- Dégradé « héros » : `#082040` vers `#183860` (diagonale). Dégradé « accent » : `#C89818` vers `#B08010`.
- Polices : **Poppins** (titres, 700) et **Inter** (texte), via `@remotion/google-fonts`.
- Style : moderne, lumineux, arrondi (rayons de 16 à 24 px), ombres douces. L'or sert aux moments de réussite.

---

## 4. Les personnages animés

Crée les personnages **en SVG et en React** (pas d'images générées), animés avec `spring()` et `interpolate()`. Chaque personnage est un composant découpé en parties animables : tête, yeux, sourcils, **bouche avec 4 à 5 formes de visème**, bras (bras avant et bras arrière séparés), torse, jambes.

Comportements (composant `<Character pose="..." talking emotion="..." />`) :
- respiration discrète en boucle ;
- clignement des yeux déterministe (avec `random(seed)` de Remotion, jamais `Math.random()`) ;
- **bouche synchronisée à la voix** : `@remotion/media-utils` (`useAudioData` + `visualizeAudio`) ouvre la bouche selon l'amplitude de la piste de voix. En l'absence d'audio, la bouche s'anime selon les timings des sous-titres ;
- poses : `idle`, `wave`, `point` (montre l'écran du téléphone), `holdPhone`, `tapPhone`, `celebrate` (bras levés), `worried`, `thumbsUp` ;
- émotions : `neutral`, `happy`, `worried`, `proud`.

**Distribution :**
- **Awa** (héroïne et narratrice), environ 30 ans, commerçante de pagnes au marché de Dantokpa (Cotonou). Peau foncée, foulard (`gele`) aux couleurs de la marque (or et vert), tenue en wax stylisé, smartphone en main. Énergique et attachante. Son rêve : **acheter une machine à coudre** pour confectionner elle-même ses vêtements.
- **Koffi**, environ 35 ans, **agent VizioBox de son quartier** : polo bleu nuit `#082040` avec le logo VizioBox, sacoche en bandoulière. **Rôle secondaire**, il incarne le service de proximité (dépôt en espèces, retrait).
- **Les amies du groupe** (2 ou 3 silhouettes simplifiées, couleurs variées), pour la tontine de groupe.

Des personnages dignes et modernes, sans caricature. Décors en aplats : étal de marché avec rouleaux de pagnes, rue animée, intérieur d'atelier. Léger parallaxe sur 2 ou 3 plans.

---

## 5. Script et storyboard (environ 85 s en 16:9)

Narration à la première personne par **Awa**, plus une voix off finale. Les textes à l'écran reprennent les mots-clés. On ne voit **que l'application Client**.

| # | Durée | Scène | Visuel | Voix (V.O.) / dialogue |
|---|---|---|---|---|
| 1 | 0–8 s | **Le problème** | Awa à son étal glisse des billets dans une vieille boîte en fer. Les billets s'envolent un à un (dépenses imprévues). Awa est inquiète. Au loin, une silhouette de machine à coudre en pointillés. | **Awa :** « Chaque jour, je mets un peu de côté… et chaque mois, tout disparaît. Ma machine à coudre, je la vois toujours de loin. » |
| 2 | 8–17 s | **La découverte** | Une amie lui montre son téléphone avec l'icône VizioBox. Awa télécharge l'app (icône qui rebondit), saisit son numéro, reçoit le code OTP, crée son PIN (points qui se remplissent) et pose l'empreinte. Arrivée sur le **tableau de bord** « Bonjour Awa 👋 ». | **Awa :** « Mon amie m'a parlé de VizioBox. Mon numéro, un code reçu par SMS, mon code secret… et c'est prêt. Mon argent est à moi seule. » |
| 3 | 17–30 s | **Cotiser comme je veux** | **Écran Tontine** : Awa choisit sa mise, 1 000 FCFA par jour. Écran partagé en deux : **à gauche**, elle paie depuis son téléphone et les trois badges **MTN Mobile Money · Moov Money · Celtiis Cash** (plus « Carte bancaire ») apparaissent, puis la confirmation. **À droite**, un autre jour au marché, Koffi passe et elle lui remet 1 000 FCFA en espèces. Dans les deux cas, la notification « Dépôt reçu : 1 000 FCFA, réf. VZB-… » s'affiche. | **Awa :** « Je cotise comme je veux : par Mobile Money avec MTN, Moov ou Celtiis… ou en espèces avec Koffi, l'agent du quartier. Tout s'affiche aussitôt dans mon téléphone. » |
| 4 | 30–40 s | **La tontine qui avance** | Montage rythmé (soleil qui se lève et se couche) : **anneau de progression de 1/31 à 31/31**, compteur jusqu'à **31 000 FCFA**. À la fin : explosion dorée et carte « Cycle terminé : 30 000 FCFA dans votre disponible + bonus de régularité ». | **Awa :** « 31 mises, et 30 me reviennent. Et comme j'ai été régulière… j'ai même un bonus ! » |
| 5 | 40–52 s | **Un coffre pour mon projet** | **Marketplace** : la carte « Machine à coudre, 120 000 FCFA » s'ouvre en bottom sheet ; Awa touche « Créer un coffre ». **Écran Coffre** : jauge qui se remplit depuis le disponible, la machine en pointillés de la scène 1 se « dessine » progressivement. Autres coffres en vignettes : « Loyer », « Rentrée scolaire ». | **Awa :** « Mon argent a enfin un but. J'ai créé un coffre pour ma machine à coudre et je le remplis à mon rythme. » |
| 6 | 52–62 s | **La tontine entre amies** | Awa reçoit un **QR code d'invitation** et le scanne : elle rejoint le cercle de ses amies dans l'app. **Écran Groupe (vue client)** : avatars numérotés 1, 2, 3, 4 et flèche qui tourne. C'est le tour d'Awa : la cagnotte vole vers elle et la notification « C'est votre tour ! » s'affiche. | **Awa :** « Avec mes amies aussi, on fait notre tontine sur VizioBox. On rejoint le groupe par QR code, l'ordre des tours est clair… plus de disputes ! » |
| 7 | 62–70 s | **Le retrait** | **App Client** : « QR code de retrait, 120 000 FCFA, usage unique ». Koffi le scanne (on voit seulement son téléphone de dos avec un cadre de scan lumineux, pas d'écran de l'app Agent). Coche verte et reçu dans l'app d'Awa ; Koffi lui remet l'argent. | **Awa :** « Le grand jour ! Je présente mon QR code de retrait, et je reçois mon argent en toute sécurité. » |
| 8 | 70–77 s | **La confiance** | Fond bleu nuit, icônes animées en séquence : 🔒 PIN et empreinte · 🪪 identité vérifiée · 🧾 une référence pour chaque opération · 📜 historique complet, rien n'est jamais effacé · 📲 paiements Mobile Money sécurisés. | **V.O. :** « Chaque opération a sa référence. Chaque franc est tracé. Rien n'est jamais effacé. » |
| 9 | 77–85 s | **Le rêve réalisé + appel à l'action** | Awa dans son atelier devant SA machine à coudre (`proud`, puis `celebrate`). Transition vers le logo VizioBox sur le dégradé héros, promesse en Poppins, puis appel « Téléchargez VizioBox » avec des badges génériques « Android » / « iOS » (sans logo officiel des stores). | **Awa :** « Mon projet est devenu réalité. Et le vôtre ? » **V.O. :** « VizioBox. La tontine pour réaliser vos projets. Téléchargez l'application dès aujourd'hui. » |

Pour la version 9:16 : personnages en bas, téléphone en grand au centre, textes en haut ; la scène 3 passe d'un écran partagé gauche/droite à un partage **haut/bas**.

---

## 6. Maquettes d'écrans de l'app Client (à recréer en React, pas de captures)

Composant `<PhoneFrame>` (smartphone générique arrondi, sans marque d'appareil) et écrans simplifiés **fidèles à la charte** :
- **Inscription** : champ numéro (+229), 6 cases OTP, pavé PIN, icône d'empreinte.
- **Tableau de bord** : en-tête dégradé bleu nuit, « Bonjour Awa 👋 », carte solde (Disponible / En tontine), rangée d'actions rapides, vignettes de coffres, aperçu marketplace.
- **Tontine** : anneau de progression (couleur accent), « Mise : 1 000 FCFA », « Objectif du cycle : 31 000 FCFA », bouton « Cotiser », historique.
- **Choix du moyen de paiement** : liste de tuiles avec badge texte : « Mobile Money · MTN, Moov, Celtiis », « Carte Visa / Mastercard ». La sélection se fait avec une coche, puis un écran de confirmation.
- **Marketplace** : grille d'articles, puis bottom sheet avec les boutons « Acheter maintenant » et « Créer un coffre », sélecteur de quantité.
- **Coffre** : titre, objectif, jauge, bouton « Alimenter ».
- **Groupe** : liste des membres avec l'ordre des tours et le tour en cours mis en évidence.
- **QR de retrait** : QR code (lib `qrcode`, contenu fictif), montant, mention « Usage unique, à présenter à votre agent ».
- **Notification** : bannière qui glisse du haut de l'écran.

Données **fictives** mais réalistes (prénoms béninois, montants en FCFA, références du type `VZB-2026-000123`, numéro masqué `+229 01 •• •• 47`).

---

## 7. Audio

- **Voix** : produis `src/content/voiceover.json` (id de réplique, personnage, texte, début et fin en secondes). Si `ELEVENLABS_API_KEY` est présente dans l'environnement, génère les voix (voix féminine chaleureuse pour Awa, voix off posée pour la fin, accent d'Afrique de l'Ouest si possible) dans `public/audio/`. **Sinon**, ne bloque pas : rends la vidéo avec les **sous-titres animés** et la bouche animée par les timings, et documente comment ajouter les voix plus tard.
- **Sous-titres** toujours présents et incrustés (la plupart des gens regardent sans le son sur mobile), avec mise en évidence du mot courant.
- **Musique** : afrobeat ou highlife léger et optimiste, libre de droits. Si tu n'en as pas, laisse un emplacement `public/audio/music.mp3`, avec un volume qui baisse automatiquement (ducking) sous la voix.
- **Bruitages** légers : ding de notification, pièces, swoosh, validation.

---

## 8. Exigences techniques

- Remotion v4, TypeScript strict. Une scène = un composant dans `src/scenes/`, enchaînées avec `<Series>` ou `@remotion/transitions`.
- Tous les textes de la vidéo dans `src/content/fr.ts`, sans texte en dur dans les composants (pour une future version en fon ou en anglais).
- Toute animation dépend de `useCurrentFrame()` ; aucune dépendance au temps réel ni à `Math.random()`.
- Durées de scène centralisées dans `src/timeline.ts`.
- Vérifie chaque scène dans le Studio, puis lance les deux rendus. Corrige tout texte coupé, chevauchement ou débordement, en particulier en 9:16.
- Lisibilité : sous-titres d'au moins 42 px en 1080p, contraste suffisant (blanc sur bleu nuit, texte foncé sur fond clair).

---

## 9. Critères d'acceptation

- [ ] Les 9 scènes sont présentes, dans l'ordre, pour environ 85 s.
- [ ] Awa (et Koffi en second rôle) sont des personnages animés : respiration, clignement, bouche qui parle, poses et émotions.
- [ ] On ne voit **que l'app Client** : aucun écran de l'app Agent, aucun appel à « devenir agent ».
- [ ] Les fonctionnalités clés apparaissent : inscription OTP et PIN, cotisation par **MTN Mobile Money, Moov Money ou Celtiis Cash** (ou espèces via un agent), tontine 31 mises et bonus, coffres, marketplace, tontine de groupe par QR, retrait par QR, traçabilité.
- [ ] Ni logo d'opérateur, ni logo de FedaPay, ni logo des stores : uniquement des badges texte.
- [ ] Charte respectée et vocabulaire conforme (jamais « banque », « placement » ou « investissement »).
- [ ] Compositions 16:9 et 9:16 rendues en MP4 dans `out/`, avec sous-titres lisibles sans le son.
- [ ] README d'utilisation présent.
