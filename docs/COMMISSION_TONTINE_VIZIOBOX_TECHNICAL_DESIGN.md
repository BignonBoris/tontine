# Conception Technique - Moteur de Commission Tontine VizioBox

## Objet

Ce document traduit les regles metier validees dans `COMMISSION_TONTINE_VIZIOBOX.md` en conception technique exploitable pour l'API, la base de donnees, le mobile client, le mobile agent et le back-office admin.

Ce document ne contient pas encore d'implementation.

## Objectifs techniques

- calculer fidèlement les commissions
- separer strictement caisse, commissions agent, revenu plateforme et flottant
- permettre la traçabilité complete de chaque commission
- permettre la contrepassation en cas de correction
- figer les regles de commission au demarrage d'un cycle
- supporter plusieurs cycles par client avec mises differentes
- supporter les reserves de commission retrait par cycle avec consommation FIFO

## Architecture fonctionnelle cible

Le moteur de commission repose sur 5 briques :

1. `CommissionRule`
- regle configurable par l'admin
- active pour les nouveaux cycles

2. `CycleCommissionSnapshot`
- copie figée de la regle au demarrage du cycle
- reference unique du cycle pour tous les calculs futurs

3. `CommissionLedgerEntry`
- ecriture comptable unitaire de commission
- source de vérité pour les credits, debits, contrepassations et statistiques

4. `ClientWithdrawalCommissionReserve`
- reserve de commission retrait d'un client
- segmentee par cycle
- consommee en FIFO au fil des retraits

5. `CommissionWallets`
- soldes agreges lisibles pour les acteurs
- derives du ledger, pas verite primaire

## Entites recommandees

### 1. `commission_rules`

Role :
- stocker les regles configurables applicables aux futurs cycles

Champs minimums :
- `id`
- `code`
- `name`
- `status` : `active`, `inactive`
- `calculationMode` : `fixed`, `percentage`
- `fixedCycleCommissionAmount`
- `depositPlatformRate`
- `depositAgentRate`
- `withdrawalPlatformRate`
- `withdrawalAgentRate`
- `platformBaseRate`
- `bonusMode`
- `bonusFixedAmount`
- `floatingEnabled`
- `effectiveFrom`
- `effectiveTo`
- `createdByAdminId`
- `updatedByAdminId`
- `createdAt`
- `updatedAt`

Notes :
- garder la regle simple au MVP
- les pourcentages peuvent etre stockes en decimal SQL
- ajouter plus tard des tranches si necessaire

### 2. `tontine_cycle_commission_snapshots`

Role :
- figer la regle au demarrage d'un cycle

Champs minimums :
- `id`
- `tontineCycleId`
- `commissionRuleId`
- `stakeAmount`
- `cycleCommissionAmount`
- `depositPlatformRate`
- `depositAgentRate`
- `withdrawalPlatformRate`
- `withdrawalAgentRate`
- `platformBaseRate`
- `bonusFixedAmount`
- `snapshotPayload`
- `createdAt`

Notes :
- `snapshotPayload` garde le JSON complet utile pour audit et debug
- aucun recalcul ne doit dependre d'une regle active mutable

### 3. `commission_wallets`

Role :
- fournir les soldes visibles et rapides a lire

Type de proprietaire :
- `agent`
- `platform`
- `client`

Champs minimums :
- `id`
- `ownerType`
- `ownerId`
- `walletType`
- `balance`
- `payableBalance`
- `blockedBalance`
- `currency`
- `createdAt`
- `updatedAt`

Wallet types recommandes :
- `agent_commission`
- `platform_commission`
- `platform_floating`
- `client_bonus`

Notes :
- `balance` peut contenir 2 decimales
- `payableBalance` permet plus tard les retraits ou transferts reels
- `blockedBalance` utile pour bonus ou commissions non encore liberables

### 4. `commission_ledger_entries`

Role :
- ledger principal de toute commission

Champs minimums :
- `id`
- `reference`
- `entryType`
- `status`
- `sourceType`
- `sourceId`
- `cycleId`
- `clientId`
- `agentId`
- `platformAccountType`
- `walletId`
- `direction` : `credit`, `debit`
- `amount`
- `payableAmount`
- `blockedAmount`
- `currency`
- `commissionBucket`
- `snapshotId`
- `triggerEvent`
- `initiatorType`
- `initiatedByUserId`
- `reversalOfEntryId`
- `metadata`
- `createdAt`

Valeurs suggerees :

`entryType`
- `deposit_agent_commission_credit`
- `deposit_platform_commission_credit`
- `withdrawal_agent_commission_credit`
- `withdrawal_platform_commission_credit`
- `cycle_bonus_blocked`
- `cycle_bonus_client_credit`
- `cycle_bonus_platform_credit`
- `floating_credit`
- `floating_platform_transfer`
- `commission_reversal`
- `commission_wallet_payout`
- `commission_to_cash_transfer`

`commissionBucket`
- `deposit_agent`
- `deposit_platform`
- `withdrawal_agent`
- `withdrawal_platform`
- `bonus`
- `floating`

`status`
- `posted`
- `reversed`
- `blocked`
- `settled`

Notes :
- le ledger est la verite primaire
- les wallets sont des vues agregées maintenues transactionnellement

### 5. `client_withdrawal_commission_reserves`

Role :
- reserver par client et par cycle la part de commission retrait future

Champs minimums :
- `id`
- `clientId`
- `cycleId`
- `snapshotId`
- `stakeAmount`
- `initialReservedAmount`
- `availableAmount`
- `consumedAmount`
- `status`
- `sequence`
- `createdAt`
- `updatedAt`

Statuts :
- `open`
- `consumed`
- `closed`

Notes :
- `sequence` sert a la consommation FIFO
- la reserve est creee a la cloture du cycle
- la consommation partielle doit rester possible

### 6. `client_withdrawal_commission_consumptions`

Role :
- tracer la consommation exacte de reserve par retrait

Champs minimums :
- `id`
- `withdrawalId`
- `clientId`
- `reserveId`
- `cycleId`
- `agentId`
- `consumedAmount`
- `agentCommissionAmount`
- `platformCommissionAmount`
- `reference`
- `createdAt`

Notes :
- permet de reconstituer exactement quel retrait a consomme quelle reserve
- facilite la contrepassation si necessaire

### 7. `agent_commission_payouts`

Role :
- preparer le retrait futur des commissions agent

Champs minimums :
- `id`
- `agentId`
- `reference`
- `requestedAmount`
- `approvedAmount`
- `status`
- `destinationType`
- `initiatorType`
- `initiatedByUserId`
- `approvedByAdminId`
- `paidAt`
- `createdAt`

Statuts :
- `requested`
- `approved`
- `rejected`
- `paid`
- `cancelled`

### 8. `agent_commission_cash_transfers`

Role :
- futur transfert des commissions vers la caisse operationnelle

Champs minimums :
- `id`
- `agentId`
- `reference`
- `amount`
- `status`
- `initiatorType`
- `initiatedByUserId`
- `approvedByAdminId`
- `createdAt`
- `completedAt`

## Wallets et soldes cibles

### Agent

Deux soldes separes au minimum :

- `agentCashBalance`
- `agentCommissionBalance`

Plus tard :
- `agentCommissionPayableBalance`

### Plateforme

Deux soldes separes au minimum :

- `platformCommissionRevenue`
- `platformFloatingBalance`

### Client

Les bonus n'ont pas besoin d'un wallet client permanent au MVP si le bonus est verse automatiquement au `solde disponible`.

Mais le systeme doit garder :
- les reserves de commission retrait client par cycle

## Evenements metier et mouvements attendus

### 1. Demarrage d'un cycle

Actions :
- selection de la regle active
- creation du `CycleCommissionSnapshot`

Aucun mouvement financier :
- pas de prelevement commission
- pas de reserve retrait

### 2. Depot client valide par agent

Actions :
- calcul commission depot agent sur operation
- calcul commission plateforme sur operation
- creation des `CommissionLedgerEntry`
- mise a jour des wallets agent et plateforme

Contraintes :
- operation source valide uniquement
- si annulation ulterieure : contrepassation

### 3. Cloture ou arret du cycle

Actions :
- prelevement client de `1 part`
- calcul du net client
- creation reserve retrait client pour ce cycle
- determination bonus
- si cycle respecte :
  - bonus verse automatiquement au `solde disponible`
- sinon :
  - bonus bloque puis prepare pour reversement plateforme
- calcul du flottant residuel
- credit du `platformFloatingBalance`

Resultats attendus :
- commission cycle integralement repartie
- reserve retrait creee
- aucune zone grise

### 4. Retrait client paye par agent

Actions :
- consommation FIFO des reserves client
- calcul part agent retrait
- calcul part plateforme retrait
- creation `client_withdrawal_commission_consumptions`
- credits commission agent et plateforme

Contraintes :
- uniquement sur retrait `paid`
- pas sur retrait `requested`
- pas sur retrait `cancelled`

### 5. Correction d'un depot

Actions :
- contrepassation des ecritures commission agent et plateforme liees
- mise a jour des wallets

### 6. Correction d'un retrait

Actions :
- contrepassation des ecritures commission retrait liees
- contrepassation de la consommation de reserve si necessaire
- mise a jour des wallets

### 7. Transfert flottant vers plateforme

Actions :
- debit `platformFloatingBalance`
- credit `platformCommissionRevenue` ou autre compte final
- creation ledger dedie

### 8. Paiement commission agent

Actions :
- debit `agentCommissionBalance`
- credit `agentCommissionPayableBalance` ou sortie
- creation payout trace

### 9. Transfert commission agent vers caisse

Actions :
- debit `agentCommissionBalance`
- credit `agentCashBalance`
- audit obligatoire

## Regles de calcul

### Calcul decimal

Regle retenue :
- troncature a 2 decimales
- jamais d'arrondi mathematique

Fonction logique :
- `truncateTo2(amount)`

### Prorata depot

Base :
- montant de depot reel valide sur le cycle

Formule logique :
- `commissionAgentDepotOperation = truncateTo2((depositAmount / cycleStakeAmount) * unitDepositCommission)`

La formule exacte pourra etre ajustee selon le snapshot retenu, mais le principe reste :
- calcul unitaire
- prorata
- troncature

### Prorata retrait

Base :
- montant de retrait reel paye

Formule logique :
- `commissionAgentWithdrawalOperation = truncateTo2((withdrawalAmount / reserveStakeAmount) * unitWithdrawalCommission)`

Le moteur doit savoir de quelle reserve provient la consommation pour connaitre la base applicable.

## Strategie FIFO reserve retrait

Algorithme cible :

1. charger les reserves `open` du client triees par `sequence asc`
2. prendre la premiere reserve avec `availableAmount > 0`
3. consommer tout ou partie selon le montant de retrait restant
4. creer une ligne de consommation
5. passer a la reserve suivante si necessaire
6. marquer `consumed` quand `availableAmount = 0`

Avantages :
- simple
- reproductible
- auditable

## Regles de disponibilite

### Agent commission

- la commission agent est visible immediatement
- elle peut contenir des decimales
- seul le montant payable entier sera retirable

### Bonus client

- pas de compte bonus separé au MVP
- versement automatique au `solde disponible`

### Flottant

- visible en back-office
- non visible cote client
- distinct du revenu plateforme normal

## API a prevoir plus tard

### Admin

- `GET /admin/commission-rules`
- `POST /admin/commission-rules`
- `PATCH /admin/commission-rules/:id`
- `POST /admin/commission-rules/:id/activate`
- `GET /admin/commission-ledger`
- `GET /admin/platform-floating`
- `POST /admin/platform-floating/transfer`
- `GET /admin/clients/:id/withdrawal-reserves`
- `GET /admin/agents/:id/commission-wallet`
- `GET /admin/agents/:id/commission-ledger`
- `POST /admin/agents/:id/commission-payouts`
- `POST /admin/agents/:id/commission-to-cash`

### Agent

- `GET /agent/commissions`
- `GET /agent/commissions/history`
- `POST /agent/commission-transfer-requests`

### Client

- aucun detail complexe de repartition au MVP
- garder seulement :
  - frais de cloture
  - bonus verse si applicable

## Impacts mobile client

- afficher les frais de cloture simplement
- afficher le montant net recupere
- afficher le bonus si cycle respecte
- ne jamais exposer la repartition interne des commissions

## Impacts mobile agent

- afficher `commission disponible`
- afficher historique commission depot / retrait
- distinguer clairement :
  - caisse operationnelle
  - commissions

## Impacts admin

- gestion des regles
- supervision du ledger commission
- supervision du flottant
- supervision des reserves retrait client
- supervision des wallets commission agent

## Audit et securite

Chaque ecriture commission doit conserver :

- reference unique
- utilisateur ou systeme initiateur
- operation source
- cycle source si applicable
- reserve source si applicable
- contrepassation source si applicable

Toutes les operations sensibles doivent etre auditees :

- creation regle
- activation regle
- transfert flottant
- paiement commission agent
- transfert commission vers caisse
- contrepassation

## Choix de mise en oeuvre recommandes

### Base de donnees

- `DECIMAL(18,2)` pour les montants de commission
- references uniques indexees
- index sur `clientId`, `agentId`, `cycleId`, `status`, `sequence`

### API

- toute la logique critique de calcul reste cote backend
- jamais de calcul source de verite cote mobile

### Transactions

- toute operation qui cree une ecriture de commission doit etre transactionnelle
- wallet + ledger + audit + reserve doivent etre coherents dans la meme transaction quand necessaire

## Points a arbitrer plus tard

- mode exact de calcul par type de regle `fixed` vs `percentage`
- granularite du `platformBaseRate`
- frequence de transfert flottant vers revenu plateforme
- regles precises de `payableBalance` agent
- ecran agent de retrait des commissions

## Plan de livraison technique recommande

### Phase 1

- `commission_rules`
- `cycle_commission_snapshots`
- `commission_ledger_entries`
- `commission_wallets`
- commission depot immediate
- commission plateforme immediate

### Phase 2

- reserves retrait client
- consommation FIFO
- commission retrait immediate
- bonus et flottant a la cloture

### Phase 3

- payouts commission agent
- transfert commission vers caisse
- supervision admin avancee
- statistiques flottant / bonus / rendement plateforme

