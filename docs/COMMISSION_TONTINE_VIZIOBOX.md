# Moteur de Commission Tontine VizioBox

## Objet

Ce document formalise les regles metier validees pour le calcul, la ventilation, la reservation, le versement et la tracabilite des commissions liees aux cycles de tontine VizioBox.

Ce document sert de base fonctionnelle avant implementation technique.

## Principes directeurs

- La commission totale d'un cycle de tontine est egale a `1 part de tontine`.
- Cette commission totale est toujours integralement repartie a la fin.
- La caisse agent est strictement separee des commissions agent.
- Les commissions agent sont strictement separees du revenu plateforme.
- Le flottant est separe du revenu plateforme principal pour des raisons de statistique.
- Le bonus client est une composante theorique fixe de la part de commission.
- Toutes les commissions et contrepassations doivent etre tracees par ecritures, jamais par simple mise a jour opaque de solde.
- Toute regle de commission est figee au demarrage du cycle.

## Regles de configuration

Les regles de commission doivent etre parametriques :

- activation / desactivation
- montant fixe
- pourcentage
- autres variantes futures si necessaire

Les sous-parts d'une commission de cycle doivent etre configurables au minimum pour :

- plateforme
- agent depot
- agent retrait
- bonus client

Une nouvelle regle ne s'applique qu'aux nouveaux cycles crees apres son activation.

## Regle de gel des commissions

Au lancement d'un cycle de tontine :

- un snapshot complet de la regle active est rattache au cycle
- ce snapshot reste la reference jusqu'a la cloture ou l'arret du cycle
- une modification admin ulterieure ne change pas les cycles deja demarres

## Commission totale du cycle

Pour un cycle donne :

- `commissionCycleTotal = 1 part de tontine`

Cette commission totale est la base de reference de toute la ventilation du cycle.

## Sous-composants de la commission

Chaque cycle doit permettre de distinguer au minimum :

- `platformCommission`
- `depositAgentCommission`
- `withdrawalAgentCommission`
- `bonusCommission`
- `floatingCommission`

La somme finale de ces composantes doit toujours etre egale a `commissionCycleTotal`.

## Regle client

- Le client ne paie pas la commission au premier depot.
- Le client cotise normalement pendant la vie du cycle.
- Le prelevement reel de la commission client se fait a la cloture ou a l'arret du cycle.
- Cote mobile client, l'affichage reste simple :
  - une ligne de `frais de cloture`
  - pas de detail interne de repartition plateforme / agents / bonus

## Commission depot

### Principe

- La part `agent depot` est calculee au prorata des depots reels effectues par les agents sur le cycle.
- La part `plateforme` liee aux operations de depot est calculee au fil des operations concernees.

### Acquisition

- La commission depot agent est creditee immediatement dans le `compte commission agent`.
- La part plateforme associee est creditee immediatement dans le revenu plateforme.

### Regle de repartition

- La commission depot n'appartient pas au premier agent ayant demarre le cycle.
- Elle est repartie entre les agents au prorata des depots reels effectues sur le cycle.
- Seuls les depots valides comptent dans le calcul.

### Correction

Si un depot est annule, rejete ou contrepasse :

- la commission agent associee doit etre contrepassee
- la part plateforme associee doit etre contrepassee

## Commission retrait

### Principe

- La commission retrait n'est attribuable qu'au moment d'un retrait reellement paye.
- Elle est repartie entre les agents au prorata des retraits reels payes.
- Seuls les retraits `paid` sont eligibles.

### Acquisition

- La commission retrait agent est creditee immediatement dans le `compte commission agent` au moment du retrait paye.
- La part plateforme associee est creditee immediatement dans le revenu plateforme.

### Correction

Si un retrait paye devait etre corrige par une operation exceptionnelle :

- la commission agent associee doit etre contrepassee
- la part plateforme associee doit etre contrepassee

## Reserve commission retrait client

### Principe

Un client peut cloturer plusieurs cycles avant d'effectuer des retraits.

La part de commission retrait ne doit donc pas etre geree comme un simple pot global ambigu.

### Modele retenu

- la reserve retrait est propre a chaque client
- elle est segmentee par cycle cloture
- chaque poche conserve son identite de cycle d'origine
- chaque poche conserve sa base de calcul

### Consommation

- la consommation de la reserve retrait suit une logique `FIFO`
- les poches les plus anciennes sont consommees en premier
- un retrait peut consommer plusieurs poches de cycles differents

## Bonus client

### Principe

- Le bonus existe toujours comme composante theorique de la part de commission.
- Le bonus ne devient jamais du flottant.

### Si le cycle est respecte

- le bonus est verse automatiquement au client
- destination : `solde disponible`

### Si le cycle n'est pas respecte

- le bonus n'est pas reverse au client
- il est bloque
- puis reverse a la plateforme

## Flottant

### Principe

Le flottant represente la part residuelle de commission qui ne va ni aux agents ni au bonus client reverse.

### Regles retenues

- le flottant est separe du revenu plateforme principal
- il est conserve pour des besoins de statistique et pilotage
- il n'est pas permanent
- il peut etre reverse plus tard a la plateforme via une vraie operation dediee

### Contraintes

- le flottant doit avoir son propre compte / ledger
- il ne doit pas etre fusionne automatiquement avec le revenu plateforme normal

## Decimal et paiement reel

### Calcul

- Les calculs de commission peuvent produire des decimales.
- La regle retenue est la troncature a 2 decimales.
- Exemples :
  - `50,45` devient `50,45`
  - `50,95` devient `50,95`
  - `50,105` devient `50,10`

### Paiement reel

- Les decimales ne sont pas payees directement en cash.
- Le `compte commission agent` peut porter des decimales internes.
- Seul le montant effectivement payable et retirable est sorti.
- Le reliquat decimal reste dans le compte commission jusqu'a atteindre un montant retirable.

## Lien entre commission et caisse agent

### Regle actuelle

- `compte commission agent` et `caisse operationnelle agent` sont separes

### Evolution prevue

- un flux metier futur pourra permettre de transferer des fonds du compte commission vers la caisse operationnelle
- ce transfert devra etre une vraie operation financiere tracee

## Arret anticipe et cycle incomplet

- Une tontine demarree ne peut plus etre annulee ni modifiee.
- Elle peut etre arretee.
- Un cycle incomplet garde la meme commission totale de reference : `1 part`.
- L'arret avant terme ne change pas la base de calcul de la commission totale.
- Les sous-parts sont determinees selon les regles validees du cycle.

## Exemple simplifie

### Cas

- mise : `1000`
- cycle cloture avec `31 parts`
- commission totale de cycle : `1000`

### Exemple de ventilation cible

- plateforme : `300`
- agent depot : `300`
- agent retrait : `300`
- bonus client : `100`
- flottant : `0`

### Cas non respecte

Si le cycle n'est pas respecte :

- le bonus n'est pas reverse au client
- le bonus est bloque puis reverse a la plateforme
- le flottant garde sa logique separee selon les reliquats definis par la plateforme

## Ecritures et audit attendus

Chaque mouvement doit etre historise avec :

- reference unique
- operation source
- type de commission
- beneficiaire
- montant
- statut
- initiateur
- dates
- cycle rattache si applicable

Les corrections doivent se faire uniquement par :

- annulation
- contrepassation
- ecriture de compensation

Jamais par suppression physique.

## Recommandations techniques pour la suite

Le moteur technique devra probablement introduire des notions proches de :

- `CommissionRule`
- `CycleCommissionSnapshot`
- `CommissionLedgerEntry`
- `ClientWithdrawalCommissionReserve`
- `AgentCommissionWallet`
- `PlatformCommissionLedger`
- `PlatformFloatingLedger`

Les noms exacts sont techniques et restent a arbitrer pendant la conception.

## Resume decisionnel

- commission cycle = `1 part`
- regle figee au demarrage du cycle
- client preleve a la cloture, pas au premier depot
- part agent depot = immediate, au prorata des depots reels
- part agent retrait = immediate, au prorata des retraits reels payes
- part plateforme = immediate au fil des operations concernees
- reserve retrait = par client, segmentee par cycle, consommation FIFO
- bonus client = automatique vers solde disponible si cycle respecte
- bonus non verse = bloque puis reverse a la plateforme
- flottant = separe du revenu plateforme, puis reversable plus tard
- calcul decimal = troncature a 2 decimales
- paiement reel agent = seulement sur montant retirable

