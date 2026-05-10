# PRD MVP - VizioBox

## 1. Resume
VizioBox est une plateforme de tontine orientee realisation de projets. Le produit combine :
- une application mobile client
- une application mobile agent terrain
- une API backend REST
- une base de donnees relationnelle

Le principe central est :
- le client epargne avec discipline
- la tontine alimente sa progression
- le solde disponible sert de source interne de financement
- les coffres permettent de realiser des projets concrets
- les agents terrain assurent l'inscription client et le provisioning reel

Ce document est destine a servir de base de travail pour :
- DAT
- SFD
- architecture fonctionnelle
- decomposition en modules
- generation de diagrammes par une autre IA

---

## 2. Vision produit
VizioBox aide un utilisateur a :
- participer a une tontine
- suivre sa progression
- convertir sa capacite d'epargne en projets
- financer ses coffres projets
- utiliser un marketplace relie a ses objectifs

Le produit n'est pas une simple app de tontine.
Le produit est une plateforme de :
- discipline d'epargne
- realisation de projets
- collecte terrain tracee
- supervision de flux financiers

---

## 3. Objectifs du MVP
Objectifs principaux :
- digitaliser la tontine client
- introduire une logique claire de solde disponible
- permettre la creation et l'alimentation de coffres projets
- introduire un marketplace lie a l'epargne projet
- permettre aux agents de terrain de creer des clients et d'enregistrer des depots reels
- tracer toutes les operations critiques

Objectifs techniques :
- API REST versionnee
- securisation JWT
- audit minimal
- base relationnelle avec statuts
- applications mobiles distinctes client et agent

---

## 4. Acteurs

### 4.1 Client
Le client final peut :
- s'inscrire et se connecter
- consulter son dashboard
- consulter sa tontine
- consulter son solde disponible
- consulter ses coffres
- alimenter un coffre depuis son solde disponible
- transferer du disponible vers la tontine
- consulter le marketplace
- acheter ou creer un coffre depuis un article
- consulter ses notifications
- gerer son profil et sa securite locale

### 4.2 Agent
L'agent terrain peut :
- se connecter avec numero + PIN
- consulter son tableau de bord
- consulter ses clients inscrits
- creer un nouveau client
- renseigner une adresse client
- initialiser une tontine pour un nouveau client
- initialiser une tontine pour un client existant sans tontine active
- enregistrer un depot pour un client
- consulter son historique de provisionings

### 4.3 Admin / Supervision
Pas encore finalise en interface web, mais deja prevu conceptuellement :
- supervision des utilisateurs
- supervision des agents
- audit
- validation avancee
- futur provisioning admin
- futur reporting

---

## 5. Canaux
- Mobile client : Flutter
- Mobile agent : Flutter
- API : Express.js + Sequelize
- Base de donnees : MySQL
- Landing page : servie temporairement depuis l'API Express

---

## 6. Modules fonctionnels du MVP

### 6.1 Authentification client
Fonctionnalites :
- identification par numero de telephone
- OTP pour inscription / connexion
- session persistante
- deconnexion
- gestion de session expiree

Regles :
- un numero existant ne peut pas repasser par l'inscription
- un numero absent ne peut pas se connecter
- OTP avec expiration
- OTP avec limitation essais et renvois

### 6.2 Securite locale client
Fonctionnalites :
- PIN local
- biometrie optionnelle
- deverrouillage de l'app au retour d'arriere-plan
- confirmation locale sur actions sensibles

Actions sensibles deja ciblees :
- achat marketplace
- creation de coffre depuis article
- arret tontine
- confirmation de reversement

### 6.3 Dashboard client
Le dashboard client sert a :
- visualiser le solde total estime
- voir le disponible
- voir le montant en tontine
- acceder rapidement a la tontine
- consulter les coffres actifs
- consulter un apercu marketplace
- acceder aux notifications

### 6.4 Tontine client
Fonctionnalites :
- configurer une mise
- demarrer un cycle
- voir le cumul
- voir l'objectif cycle
- voir la progression
- transferer du disponible vers la tontine
- confirmer la fin de cycle
- arreter de facon anticipee
- consulter l'historique
- consulter les archives

Regles metier :
- la mise est un multiple de 500
- un cycle vise 31 mises
- 30 mises = montant net de fin de cycle
- 1 mise = commission
- un client mobile ne peut plus faire de depot externe direct dans la tontine
- la tontine client est alimentee uniquement depuis le solde disponible
- les agents peuvent eux creer un provisioning externe legitime

Statuts de cycle :
- nonConfiguree
- active
- enAttenteValidationFin
- terminee
- arretee

### 6.5 Solde disponible
Fonctionnalites :
- consulter le solde disponible
- consulter l'historique du disponible
- alimenter un coffre
- transferer vers la tontine
- servir de source pour achat marketplace

Regle metier :
- le solde disponible est la source interne legitime de financement cote client

### 6.6 Coffres projets
Fonctionnalites :
- creer un coffre libre
- creer un coffre depuis un article marketplace
- alimenter un coffre depuis le solde disponible
- consulter le detail d'un coffre
- cloturer un coffre
- reverser le montant cloture dans le disponible

Regles metier :
- pas de suppression physique
- cloture = archive logique + retour du montant au disponible
- un article marketplace ne peut avoir qu'un seul coffre actif par utilisateur
- un coffre peut stocker :
  - linkedOfferId
  - quantity
  - unitPrice

### 6.7 Marketplace client
Fonctionnalites :
- consulter les articles
- filtrer par categorie
- rechercher un article
- ouvrir le detail article en bottom sheet
- ajouter / retirer des favoris
- voir ses favoris
- acheter maintenant
- creer un coffre depuis un article
- choisir la quantite
- consulter ses commandes

Regles metier :
- achat immediat = debiter le disponible
- creation coffre article = objectif = prix unitaire x quantite
- quantite entiere positive uniquement
- un meme article ne peut pas avoir plusieurs coffres actifs simultanes

### 6.8 Profil client
Fonctionnalites :
- consulter ses informations
- modifier nom et numero
- consulter son resume
- regler ses notifications
- regler sa securite locale
- consulter FAQ et support
- se deconnecter

### 6.9 Notifications client
Fonctionnalites :
- centre de notifications
- marquage lu / non lu
- tout marquer comme lu
- preferences de notification

Evenements notifiables :
- depot / mouvement important
- fin de cycle
- objectif atteint
- commandes marketplace

### 6.10 Application agent
Fonctionnalites principales :
- connexion agent
- dashboard agent
- menu Clients
- menu Depot
- menu Historique

#### Module Clients agent
Permet de :
- lister uniquement les clients inscrits par l'agent connecte
- rechercher
- filtrer
- consulter la fiche client
- creer un nouveau client
- initialiser une tontine lors de la creation
- renseigner un premier depot facultatif

Donnees minimales client cree par agent :
- nom / displayName
- telephone
- adresse
- mise initiale
- premier depot facultatif

#### Module Depot agent
Permet de :
- rechercher tous les clients eligibles du systeme
- faire un depot pour un client, meme s'il n'a pas ete inscrit par cet agent
- demarrer une tontine pour un client existant qui n'en a pas

Regle importante :
- Clients = portefeuille propre de l'agent
- Depot = action transverse possible sur tous les clients eligibles

#### Historique agent
Permet de :
- consulter les operations de provisioning
- voir reference, client, montant, statut, date

---

## 7. Flux metier majeurs

### 7.1 Inscription / connexion client
1. client saisit son numero
2. systeme determine login ou register
3. OTP envoye
4. OTP verifie
5. session ouverte
6. wallet et preferences assures cote backend

### 7.2 Configuration et demarrage d'une tontine client
1. client configure une mise
2. cycle cree
3. targetAmount = 31 x mise
4. expectedEndAt = startedAt + 30 jours
5. cycle passe actif

### 7.3 Alimentation de la tontine par le client
1. client ouvre sa tontine
2. saisit un montant
3. le montant est preleve du disponible
4. le cumul de tontine augmente
5. si objectif atteint :
   - statut = enAttenteValidationFin

### 7.4 Fin de cycle tontine
1. cycle atteint l'objectif
2. client confirme le reversement
3. disponible augmente du net
4. archive creee
5. cycle passe termine

### 7.5 Arret anticipe tontine
1. client demande l'arret
2. penalite = 1 mise
3. net reverse dans disponible
4. archive creee
5. cycle passe arretee

### 7.6 Coffre libre
1. client cree un coffre
2. define titre et objectif
3. alimente le coffre depuis disponible
4. cloture le coffre si besoin
5. montant retourne dans disponible

### 7.7 Coffre depuis marketplace
1. client ouvre un article
2. choisit quantite
3. choisit "Creer un coffre"
4. systeme verifie qu'aucun coffre actif n'existe deja pour cet article
5. coffre cree avec linkedOfferId, quantity, unitPrice, targetAmount

### 7.8 Achat marketplace
1. client choisit article + quantite
2. systeme verifie le disponible
3. commande creee
4. disponible diminue
5. historique et notification mis a jour

### 7.9 Creation client par agent
1. agent ouvre Clients
2. clique Ajouter
3. saisit client + adresse + mise initiale
4. optionnellement saisit un premier depot
5. backend cree le client
6. backend lie createdByAgentProfileId
7. backend cree la tontine si mise fournie
8. backend enregistre le premier depot si fourni

### 7.10 Depot agent
1. agent ouvre Depot
2. recherche un client
3. si client sans tontine active :
   - proposition de demarrage de tontine
4. si client avec tontine active :
   - saisie montant + commentaire
5. provisioning cree
6. operation tracee avec initiatorType = agent
7. tontine du client creditee

---

## 8. Regles metier critiques

### 8.1 Regles de montant
- multiples de 500 sur la tontine
- quantite article > 0 et entiere
- un depot ne peut pas depasser le reste a verser d'un cycle
- un depot coffre ne peut pas depasser l'objectif restant du coffre
- un achat marketplace ne peut pas depasser le disponible

### 8.2 Separation des sources de fonds
- provisioning externe reel : agent / admin / futur mobile money
- disponible : source interne pour actions client
- client mobile : plus de depot externe direct dans la tontine

### 8.3 Traçabilite
Chaque operation sensible doit conserver :
- acteur initiateur
- type d'initiateur
- cible de l'operation
- montant
- reference si pertinente
- date

Exemples :
- initiatorType = client
- initiatorType = agent
- initiatorType = admin

### 8.4 Aucune suppression physique
- pas de suppression definitive des operations financieres
- toute correction = annulation / contrepassation / statut

---

## 9. Donnees metier majeures

### 9.1 Entites deja visibles ou necessaires
- User
- UserPreference
- Wallet
- TontineCycle
- TontineHistory
- TontineArchive
- Goal
- GoalTransaction
- MarketOffer
- MarketOrder
- MarketFavorite
- Notification
- AuthOtp
- AuditLog
- AgentProfile
- Provisioning

### 9.2 Champs metier notables

#### User
- id
- phoneNumber
- displayName
- accountType
- isActive
- address
- createdByAgentProfileId

#### Wallet
- userId
- availableBalance
- tontineBalance

#### TontineCycle
- userId
- stakeAmount
- cumulativeAmount
- status
- startedAt
- expectedEndAt
- endedAt

#### Goal
- userId
- title
- targetAmount
- currentAmount
- status
- linkedOfferId
- quantity
- unitPrice

#### Provisioning
- reference
- agentProfileId
- clientUserId
- amount
- source
- status
- notes
- validatedAt
- validatedByUserId
- initiatedByUserId
- initiatorType

#### TontineHistory
- userId
- cycleId
- type
- amount
- label
- note
- initiatedByUserId
- initiatorType

---

## 10. API - modules logiques
API versionnee sous :
- `/api/v1`

Modules deja presents ou vises :
- `/auth`
- `/profile`
- `/notifications`
- `/wallet`
- `/tontine`
- `/goals`
- `/marketplace`
- `/dashboard`
- `/agent/auth`
- `/agent/dashboard`
- `/agent/clients`
- `/agent/provisionings`

---

## 11. Securite et controle

### 11.1 Client
- JWT
- OTP
- verrou local PIN / biometrie
- verification de session au demarrage
- gestion de session expiree

### 11.2 Agent
- numero + PIN
- profil agent actif obligatoire
- operations tracees

### 11.3 Audit
Audit minimal attendu sur :
- auth
- configuration tontine
- depots tontine
- reversement
- arret anticipe
- creation / alimentation / cloture coffre
- commandes marketplace
- creation client agent
- provisioning agent

---

## 12. Etat du perimetre

### 12.1 Deja dans le MVP
- client mobile tres avance
- agent mobile deja pose
- backend REST present
- landing simple cote API
- marketplace, coffres, tontine, profil, notifications
- provisioning agent de base

### 12.2 Partiellement couverts
- role admin
- supervision avancee
- reporting avance
- web admin

### 12.3 Hors MVP immediate
- mobile money reel
- caisse agent complete
- retraits / workflow de decaissement avance
- reclamations
- scoring
- offline-first complet et sync agent

---

## 13. Points ouverts pour DAT / SFD
Les sujets suivants devront etre clarifies ou modelises plus finement :
- modele exact de provisioning reel
- difference entre portefeuille agent et droit de depot transverse
- modele de tontine produit vs cycle simple actuel
- modele futur de cash session agent
- modele de reporting et supervision
- gestion future des transferts client vers client
- strategie offline agent
- modele de permissions admin / superviseur / agent
- strategie d'integration mobile money

---

## 14. Positionnement de marque
Nom retenu :
- **VizioBox**

Promesse :
- la tontine pour realiser des projets

Angle produit :
- vision
- coffre
- progression
- discipline financiere

---

## 15. Resume executif pour autre IA
Si une autre IA doit produire un DAT ou un SFD a partir de ce document, elle doit partir de ces hypotheses :
- VizioBox est une plateforme fintech / tontine / epargne projet
- il existe deux applications mobiles distinctes : client et agent
- les flux d'entree d'argent reels passent desormais par agent ou futur canal externe autorise
- le client n'injecte plus d'argent externe directement dans sa tontine
- le disponible est la source interne de financement cote client
- les coffres servent a la realisation de projets
- le marketplace est connecte a cette logique de projet
- toutes les operations critiques doivent etre tracees
- aucune suppression physique des transactions financieres n'est autorisee

---

## 16. Livrables attendus en suite
Ce PRD peut servir de base a :
- DAT global
- SFD backend
- SFD mobile client
- SFD mobile agent
- modele de donnees conceptuel et logique
- BPMN / diagrammes de sequence
- backlog de finalisation MVP
