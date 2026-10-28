---
target: landing page VizioBox
total_score: 22
max_score: 36
na_heuristics: 7
p0_count: 1
p1_count: 2
target_identity: "file:C:\\Users\\HP\\projects\\finance\\api\\src\\landing\\home.view.js"
target_fingerprint: "sha256:5448f8c81fb0740615fe6d72859c4be55103c4033c8e9b1e04c975bc24c2da58"
target_path: "C:\\Users\\HP\\projects\\finance\\api\\src\\landing\\home.view.js"
timestamp: 2026-10-28T09-54-14Z
slug: api-src-landing-home-view-js
---
Method: dual-agent (A: revue de design · B: détecteur + navigateur)

## Design Health Score — 22/36 (61 %, Acceptable) — heuristique 7 n/a (page Persuade à objectif unique)

| # | Heuristique | Score | Problème clé |
|---|---|---|---|
| 1 | Visibilité de l'état du système | 2 | « Votre téléchargement a commencé » affiché avant l'avertissement Chrome sur les APK ; ni taille ni version du fichier |
| 2 | Correspondance avec le monde réel | 3 | Vocabulaire local juste (mise, coffre, agent de quartier) ; la règle des frais oblige à calculer |
| 3 | Contrôle et liberté | 3 | Fenêtre fermable (Échap, fond, bouton) ; « Télécharger quand même » pousse un APK inutile sur ordinateur/iPhone |
| 4 | Cohérence et standards | 2 | Moyens de paiement répétés 3 fois ; pastilles de paiement qui ressemblent à des boutons ; maquette dont les montants ne s'additionnent pas (184 500 vs 48 500 + 21 000) |
| 5 | Prévention des erreurs | 2 | Aucun avertissement Play Protect / « fichier dangereux » ; rien pour iPhone ; sans lien, tous les boutons mènent à « bientôt disponible » |
| 6 | Reconnaissance plutôt que rappel | 3 | Le guide cite les vrais libellés Android ; frais et bonus éparpillés entre FAQ et bénéfices |
| 7 | Flexibilité et efficacité | n/a | Page à objectif unique |
| 8 | Esthétique et minimalisme | 2 | ~10 760 px sur mobile (13 écrans) ; téléphone de 650 px ; promesses de sécurité dites deux fois |
| 9 | Récupération après erreur | 2 | « Réessayer » présent, mais aucune aide humaine (WhatsApp) dans la fenêtre d'installation |
| 10 | Aide et documentation | 3 | FAQ + guide en 3 étapes ; manquent « qui est VizioBox », « taille de l'app », « iPhone ? » |

## Verdict de spécificité
Contenu très ancré (Awa, F CFA, machine à coudre, MTN/Moov/Celtiis, agent de quartier, QR de retrait, 31 barres = 31 mises), palette tenue. Mais structure de gabarit SaaS standard (héros sombre + téléphone, bandeau, 3 étapes, bento, 4 cartes sécurité, FAQ, CTA). La page ne répond pas à la première question d'un épargnant prudent : qui garde mon argent ?
Détecteur : 0 constat sur le gabarit JS (limite d'analyse, pas un résultat propre) ; 16 constats sur la page rendue : icon-tile-stack ×5, cramped-padding ×4, low-contrast ×3, overused-font ×2, cream-palette ×1, dark-glow ×1. Faux positifs probables : dark-glow (ombre d'élévation de la fenêtre), cramped-padding (bandes pleine largeur avec conteneur interne), icon-tile-stack sur la fenêtre cachée. Overlay navigateur impossible : CSP helmet (script-src 'self').

## Priorités
1. [P0] Aucune information sur qui opère VizioBox ni sur la protection des fonds → bloc « Qui sommes-nous / Où va votre argent », entité légale, RCCM/IFU, cadre ou partenaire, adresse, téléphone/WhatsApp toujours visible ; mention de FedaPay pour le Mobile Money. /impeccable clarify
2. [P1] Chiffres incohérents ou optimistes : « 31 000 F épargnés » alors que 30 000 F sont reçus ; total de la maquette faux ; bonus sans montant ni règle → corriger. /impeccable clarify
3. [P1] Parcours d'installation APK insuffisant : avertissement Chrome et Play Protect non annoncés, taille/version absentes, iPhone non géré, lien Drive peu rassurant, pas d'aide WhatsApp. /impeccable harden
4. [P2] Page mobile trop longue et répétitive pour une connexion lente : téléphone 650 px, paiements ×3, sécurité ×2, pas de bouton de téléchargement collant. /impeccable distill
5. [P2] Accessibilité : aria-labelledby faux sur la variante QR, cibles FAQ 24 px et pied de page 19 px (< 44 px), pas de focus visible sur les boutons, pastilles statiques qui ressemblent à des boutons, numéros d'étapes à 1,4:1, copyright à 4,4:1. /impeccable audit

## Personas
- Jordan (première fois) : coffre, mise, cycle, plafonds, marketplace, bonus non définis ; frais à calculer ; « Tontine entre proches » (tours) introduit un autre modèle de tontine sans explication.
- Riley (testeur) : totaux faux ; 31 000 vs 30 000 ; boutons en boucle sans lien ; APK téléchargeable sur iPhone ; nom accessible faux de la fenêtre QR ; commentaire « sans JavaScript » obsolète.
- Casey (mobile, connexion lente) : 650 px de visuel avant toute preuve ; pas de taille de fichier ; CTA seulement en haut et en bas ; FAQ à ~8 700 px ; fenêtre de 779 px sur un écran de 812 px ; 2 familles Google Fonts / 9 graisses bloquent le premier affichage.

## Observations mineures
Bandeau de confiance redondant avec la section Sécurité ; « investir dans son activité » (3e personne + proche du vocabulaire interdit) ; bouton de navigation en contour moins fort que le bouton or ; QR final inutile sur téléphone ; style différent des pages légales.

## Questions
1. Une seule preuve de confiance : la promesse logicielle ou un agent nommé et un numéro qui répond ?
2. Et si le héros montrait la scène réelle : un agent qui collecte 500 F au marché et le reçu qui s'affiche sur le téléphone ?
3. « Télécharger pour Android » est-il le bon bouton principal pour des gens qui n'ont jamais installé d'APK, ou « Être rappelé par un agent / WhatsApp » ?
