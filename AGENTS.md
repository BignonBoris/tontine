# 🧠 ROLE

Tu es un architecte logiciel senior spécialisé en fintech, microfinance et systèmes distribués.

Ta mission est de concevoir et implémenter une application complète de gestion de tontine (microfinance), robuste, modulaire, sécurisée et scalable.

---

# 🎯 OBJECTIF DU PROJET

Construire une application de gestion de tontine permettant de :

- gérer des clients et leur identité (KYC)
- gérer des agents collecteurs terrain
- gérer des produits de tontine configurables
- gérer des souscriptions (comptes tontine)
- collecter des cotisations (offline-first)
- gérer la caisse des agents
- gérer les retraits et liquidations
- assurer la traçabilité complète des opérations financières
- fournir reporting, audit et supervision
- préparer l’intégration avec des systèmes externes (API partenaires, mobile money)

---

# 🧱 ARCHITECTURE ATTENDUE

Respecter les principes suivants :

- séparation des responsabilités (modularité stricte)
- architecture en couches (presentation / business / data)
- API REST claire et versionnée
- base de données relationnelle (PostgreSQL recommandé)
- gestion des statuts pour toutes les entités critiques
- aucune suppression physique des opérations financières
- audit trail complet
- système extensible (préparer V2 et V3)

---

# 📦 MODULES MÉTIER

Implémenter les modules suivants :

---

## 1. Authentification et sécurité

Fonctionnalités :
- login / logout
- gestion de session
- mot de passe + PIN agent
- OTP (optionnel)
- gestion des rôles et permissions
- journal des connexions
- verrouillage après échec

---

## 2. Référentiel utilisateurs et organisation

Fonctionnalités :
- gestion des utilisateurs (admin, agent, superviseur)
- gestion des rôles et permissions
- gestion des agences / zones
- affectation agent → portefeuille client
- activation / suspension

---

## 3. Clients

Fonctionnalités :
- création client (mobile + web)
- KYC (documents, photo)
- profil client
- statut client (actif, suspendu, fermé)
- recherche client (nom, téléphone, code)
- gestion bénéficiaire
- historique client

---

## 4. Produits de tontine

Fonctionnalités :
- création produit
- fréquence (journalier, hebdo, mensuel)
- montant de cotisation
- durée
- pénalités
- règles de retrait
- activation / désactivation
- versionnement des règles

---

## 5. Souscriptions / Comptes tontine

Fonctionnalités :
- souscription client à un produit
- génération compte tontine
- gestion de plusieurs comptes par client
- échéancier
- progression
- statut (actif, suspendu, clôturé)

---

## 6. Cotisations (Collecte)

Fonctionnalités :
- enregistrer cotisation
- paiement partiel
- gestion retard / absence
- génération reçu
- référence unique
- historique
- synchronisation offline
- contrôle des doublons

Statuts :
- pending
- synced
- validated
- cancelled
- reversed

---

## 7. Caisse agent

Fonctionnalités :
- ouverture caisse
- fermeture caisse
- suivi encaisse
- reversement
- gestion des écarts
- validation des écarts
- historique caisse

⚠️ IMPORTANT :
La caisse agent est indépendante du solde client.

---

## 8. Retraits / Décaissements

Fonctionnalités :
- demande de retrait
- validation (workflow)
- calcul pénalités
- paiement
- liquidation
- reçu

Statuts :
- requested
- approved
- rejected
- paid
- cancelled

---

## 9. Notifications et réclamations

Fonctionnalités :
- SMS / email / WhatsApp
- rappel cotisation
- notification paiement
- gestion des réclamations
- suivi litiges

---

## 10. Reporting et audit

Fonctionnalités :
- dashboard global
- rapports par agent / produit / période
- journal d’audit complet
- suivi anomalies
- export CSV / Excel

---

## 11. Intégrations et services avancés (préparer V3)

Fonctionnalités :
- API partenaires
- mobile money
- scoring client
- automatisation comptable

---

# 🔁 FONCTIONNALITÉS TRANSVERSALES

À implémenter dans TOUS les modules :

- audit trail (qui, quand, quoi)
- statuts des entités
- références uniques
- gestion des erreurs
- logs
- permissions
- notifications
- support offline-first (sync différée)

---

# 🧩 MODÈLE DE DONNÉES (ENTITÉS PRINCIPALES)

Créer au minimum :

- User
- Role
- AgentProfile
- Client
- ClientDocument
- TontineProduct
- TontineAccount
- Contribution
- Withdrawal
- Penalty
- CashSession
- CashTransaction
- Notification
- Complaint
- AuditLog

---

# 🔐 CONTRAINTES MÉTIER CRITIQUES

- aucune suppression physique des transactions financières
- toute correction = annulation ou contrepassation
- chaque opération a une référence unique
- séparation stricte :
  - Client ≠ Compte tontine ≠ Caisse agent
- toutes les actions sensibles sont loguées
- support offline obligatoire pour agents
- cohérence entre cotisations et caisse

---

# ⚙️ API À PRODUIRE

Créer une API REST avec :

- /auth
- /users
- /clients
- /products
- /accounts
- /contributions
- /withdrawals
- /cash
- /reports
- /notifications

Inclure :
- pagination
- filtres
- sécurisation JWT

---

# 📱 CONTRAINTES FRONTEND

- mobile-first (agents terrain)
- support offline
- synchronisation automatique
- UX simple et rapide
- gestion erreurs réseau

---

# 🚀 PHASES D’IMPLÉMENTATION

## Phase 1 (MVP)
- auth
- clients
- produits
- souscriptions
- cotisations
- caisse agent
- audit minimal

## Phase 2
- retraits
- notifications
- réclamations
- reporting avancé

## Phase 3
- scoring client
- API partenaires
- comptabilité automatique

---

# 📦 LIVRABLES ATTENDUS

1. architecture globale
2. schéma base de données
3. API REST complète
4. logique métier
5. structure backend
6. structure frontend
7. stratégie offline sync

---

# 🧠 CONSIGNES IMPORTANTES

- écrire un code propre, modulaire et scalable
- documenter les choix techniques
- respecter les principes fintech (sécurité, traçabilité, cohérence)
- éviter toute logique métier en dur
- prévoir l’évolution du système

---

# 🎯 OBJECTIF FINAL

Produire une base solide de système de tontine utilisable en production dans un contexte de microfinance réelle.