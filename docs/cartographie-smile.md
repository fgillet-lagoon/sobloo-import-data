# Cartographie Smile (lagoon.nc)

Base : `lagoon.nc` sur SMILE01 - PROD (`smile.lagoon.local:5432`), PostgreSQL. Éditeur : Inomial Smile.
Source : `sql/cartographie.sql`, exports du 27/10/2026 dans `data/cartographie/` (structure seule, non versionnée).

## Ce qu'il faut savoir

- 1 473 tables et vues, dont plusieurs tables de plusieurs centaines de Go (`billingitem` 469 Go, `eventbinding` 342 Go, `email` 131 Go). Ne jamais les lire sans filtre sur la PROD.
- `public` contient le modèle interne. `public.basic` porte **à la fois les comptes et les abonnements** (`uid`, `parent`, `billto`, `usn`).
- Les schémas `smile01`, `smile02`, `smile03` sont des **versions successives des vues de reporting** Inomial, pas des bases distinctes. **`smile03` est la plus complète : c'est la surface d'extraction retenue.** Le schéma `api` propose une version réduite.
- `usn` (texte, obligatoire) est l'identifiant Smile des comptes et des abonnements : `smile03.account.usn` = accountUsn = `customer.ref`.
- Le schéma `offratel` contient des tables propres à Lagoon (Conso+, migrations VOIP).

## Vues `smile03` candidates par lot

| Lot | Onglet cadrage | Vues `smile03` |
|---|---|---|
| 1 | 1-Comptes comptables | `reporting_account` (`gl_export_code`, `reporting_account_code`) — piste pour les catégories de rapport de vente (cas 21) |
| 1 | 1b-Familles | `service` → famille d'articles, `plan` → article (proposition Lagoon : 1 service = 1 famille, 1 plan = 1 article, à valider avec Sobloo) ; `tax_schedule`, `tax_schedule_item`, `tax_treatment` |
| 2 | 2-Clients | `account`, `account_contact`, `account_address`, `account_custom`, `account_type`, `account_status`, `account_terms`, `account_payment_configuration`, `account_payment_option`, `account_cost_centre`, `account_purchase_order` |
| 3-4 | 3-Options, 4-Articles | `plan`, `plan_option`, `plan_option_group`, `recurring_charge`, `tariff`, `contract` |
| 5 | 5-Réductions | `discount` (rattachée au compte et à l'abonnement via `account.discount`, `subscription.discount`) |
| 6 | 6-Abonnements | `subscription`, `subscription_status`, `subscription_plan_schedule`, `subscription_plan_schedule_item`, `subscription_plan_schedule_item_option`, `subscription_contract`, `subscription_custom`, `subscription_address`, `subscription_contact`, `rating_cycle` |
| 6 | Centre de coût (n° 33) | `account_cost_centre` |

## Inventaire du 27/10/2026 (`sql/inventaire.sql`)

| Lot | Mesure | Valeur |
|---|---|---|
| 1 | Comptes de reporting GL (actifs / total) | 110 / 157 |
| 1 | Traitements de taxe | 6 (Taxable, Tax Free, TGC 445711 à 445714) |
| 1 | Services Smile (familles candidates) | 48 |
| 2 | Comptes | 57 599 : Particulier 50 548, Entreprise 5 251, Contentieux 1 122, Administration 321, Association 134, Grand compte 123, Compte Smile 78, Revendeur L@goon 18 |
| 2 | Statuts de compte | 57 595 Active, 3 Suspended, 1 Deactivated |
| 2 | usn de compte manquants / en double | 0 / 0 |
| 2 | Paiement | Prélèvement BNC 44 988 (dont 43 558 en auto), Prélèvement BCI 315, Espèce 2 400, autres < 100 |
| 2 | Dispositions | À jour 54 661, Relance 1 1 962, Contentieux 838, En retard - Contentieux 116, Relance 2 21, Coupure 1 |
| 2 | Centres de coût | 950 |
| 3-4 | Plans (articles) | 252, dont 202 encore disponibles |
| 3-4 | Groupes d'options / options | 140 / 736 |
| 5 | Réductions définies / valides / utilisées | 4 / 2 / 0 (aucun compte ni abonnement) |
| 5 | Frais récurrents hors plan en cours | 61 |
| 6 | Abonnements | 186 400 : Active 76 199, Closed 107 649, Incomplete 1 421, Ordered 917, Suspended 188, Error 26 |
| 6 | Actifs par service (principaux) | Internet 27 936, Self Care (CAT) 25 943, VOIP 8 417, Location modem/box 6 571, Mise à dispo Labox 5 268, Nom de domaine 606, Numéro en 09 379 |
| 6 | usn d'abonnement manquants / en double ; communs avec un compte | 0 / 0 ; 0 |
| 6 | Contrats d'abonnement (`subscription_contract`) en cours | 0 |
| 6 | Champs personnalisés définis | 265 |

Lectures :
- **« Contentieux » existe à trois endroits** : type de compte (1 122), disposition (838 + 116) et conditions de paiement (838). **Décision Lagoon du 27/10/2026 : c'est un statut de recouvrement, la disposition fait foi** → `customer_states.litigation_date` (cas 22). Le type de compte n'est pas utilisé. Les comptes en contentieux avec un abonnement actif sont repris, mais à vérifier, car c'est une anomalie probable. Au 27/10 (`sql/contentieux.sql`) : 949 comptes en contentieux (838 « Contentieux », 111 « En retard - Contentieux »), dont **92 avec des abonnements à reprendre** (89 « En retard - Contentieux », 3 « Contentieux »), pour **435 abonnements**. 126 de ces abonnements sont suspendus, soit l'essentiel des 175 abonnements Suspended repris. La date à reprendre reste à trancher.
- **Clés de rapprochement (décision Lagoon du 27/10/2026)** : `usn` du compte pour les clients, `usn` de l'abonnement pour les abonnements. Les contrats d'abonnement Smile ne sont pas utilisés, il n'y a donc pas d'ID de contrat.
- **Réductions = « charging options »** (précision Lagoon) : la table `discount` n'est pas utilisée. Une réduction est une **option de plan** (groupe « charge »), par exemple `alce` « -5% Réduction AMCOM », `Alto3m` « -50% Réduction Alto pendant 3 mois », `emplo` « -100% Employés Lagoon », `resseler` « -100% Revendeur Lagoon ». Son frais (`planautocharge.planoption`) a un **tarif négatif** (ex. article 003141, −212 XPF). Elle est souscrite via `planscheduleoption`. Le tarif est surchargeable par abonnement (`psiplanautocharge`), et des frais négatifs peuvent aussi être ajoutés directement (`userautocharge`). Beaucoup d'options sont expirées. Le tarif catalogue est dans `smile03.item_specification` (`default_rate`, compte de reporting). Mesure : `sql/charging_options.sql` (cas 13, 14).
- **Le RIB est stocké en champs personnalisés** (`bankdirectdebitnumber`, `bankbankname`…), et non dans des colonnes dédiées.
- Champs personnalisés utiles au cadrage : `ridet`, `limited_access` (accès limité), `mobile`, `phoneNumberMobile`, `dateOfBirth`, `lieu_naissance`, `Login_Radius`, `login_adsl`, `modemmacaddress`, `serial_number`, `voip_local_number`, `sip*`, `ConsoPlusID`.
- **Plans de facturation d'un abonnement** (`public.planschedule`) : il en existe deux par abonnement.
  - Type 1, « Accounting plan schedule », facture. Ses lignes (`planscheduleitem`) se succèdent : la fin d'une ligne est le début de la suivante. C'est la source du plan en cours d'un abonnement.
  - Type 2, « Refund plan schedule », gère les remboursements. Il contient 3 millions de lignes, essentiellement le plan `inactive`, et 657 000 lignes sans date. Il n'est pas repris.
- **Plans de cycle de vie** : `active` (Active Service), `locked` (Service locked), `closed` (Service closed), `inactive`, `freesusp` (Suspension ADSL gratuite) apparaissent dans le type 1, entre les plans commerciaux (`altop` ADSL Alto+, `monde` VoIP Monde…). **Confirmé par Lagoon (27/10/2026) : ce sont des états techniques**, pas des articles. Ils ne sont pas repris aux lots 3 et 4, et servent à déduire l'état Validé / Suspendu au lot 6 (cas 16).
- **Self Care (CAT)** (25 943 actifs) : accès au portail client, pas des abonnements facturables (décision Lagoon du 27/10/2026). Non repris au lot 6 ; leurs champs (indicateur revendeur, identifiant portail…) relèvent de l'onglet clients.
- **Lignes de plan « en cours »** (plan de facturation de type 1, abonnements Active ou Suspended, hors Self Care) : 50 439 abonnements, 50 516 lignes. Seuls 73 abonnements ont plusieurs plans en cours, sans doute à cause d'un changement de plan daté dans le futur. Le calcul est donc fiable.
  - 73 plans distincts sont utilisés, dont 5 de cycle de vie, soit environ **68 articles commerciaux** à reprendre. **144 options** sont utilisées.
  - 707 abonnements sont sur un plan de cycle de vie : `freesusp` 292, `locked` 182, `active` 150, `inactive` 69, `closed` 14. `closed` et `inactive` sur un abonnement actif sont des anomalies à corriger dans Smile. `active` correspond à un service sans plan commercial.

## Périmètre de reprise (`sql/perimetre.sql`, 27/10/2026)

Règles :
- **Abonnement à reprendre** : statut Active ou Suspended, hors Self Care, et plan en cours autre que `closed` ou `inactive`.
- **Client à reprendre** : au moins un abonnement à reprendre.

| | À reprendre | Exclus |
|---|---|---|
| **Abonnements** (186 402) | **50 371** : 50 196 Active, 175 Suspended | Closed 107 649 ; Self Care 25 950 ; Incomplete 1 421 ; Ordered 917 ; plan `inactive` 68 ; Error 26 |
| **Clients** (57 600) | **26 264** | Abonnements tous clôturés ou exclus 28 670 ; aucun abonnement 2 465 ; Self Care seul 201 |

- **Abonnements à reprendre par service** : Internet 27 957, VOIP 8 417, Location modem/box 6 619, Mise à dispo Labox 5 274, Nom de domaine 608, Numéro en 09 382, Prestations Entreprises 226, Déclaration DNS 189, Smile Access 166, Office 365 142, autres moins de 110 chacun. 470 d'entre eux sont sur un plan de suspension (`freesusp` 289, `locked` 181), 3 n'ont aucun plan en cours.
- **Clients à reprendre par type** : Particulier 23 364 ; pros 2 832 (Entreprise 2 507, Administration 158, Association 84, Grand compte 73, Revendeur L@goon 10) ; Compte Smile 65 ; Contentieux 3.
- **Clients à reprendre par nombre d'abonnements** : 1 abonnement 12 207 ; 2 abonnements 7 226 ; 3 abonnements 5 891 ; 4 abonnements 581 ; 5 et plus 359.
- **À trancher** :
  - Les clients en contentieux sont presque tous sans abonnement actif (3 sur 1 122 comptes de type Contentieux) : faut-il les reprendre pour le recouvrement (cas 23) ?
  - Les commandes en cours (Ordered 917, Incomplete 1 421) sont exclues à ce stade (cas 15).

## Options utilisées (27/10/2026)

Sur les abonnements à reprendre, **144 options de plan** (`planoption`) sont souscrites :
- **20 réductions** (groupes charge et sans groupe), traitées au lot 5 ;
- **124 autres**, de trois natures différentes, à trier par Lagoon :
  - **vraies options commerciales**, par exemple `optmhd` MultiEcran HD (2 812 souscriptions), `optprio` Prioritaire (2 065), `nvxar` Offre Easy Start (946), `optgame` Gaming (311), `std` Static IP Standard (1 267), options de nom de domaine ;
  - **choix de frais de mise en service** (groupe charge), par exemple `alnos` / `prnos` / `spnos` « Normal sans FMES » (15 233 + 809 + 670), `noset` « Sans frais de mise en service » (7 214), `alstd` « Normal avec FMES » (3 617), `withset` (1 191). Ils relèvent plutôt des frais fixes de l'onglet 4 ;
  - **choix par défaut, sans valeur commerciale**, par exemple `nostat` « No Static IP » / « IP Dynamique » (25 006 + 1 366), `nooption` « Aucun Service L@goon » (142). Ils ne sont probablement pas à reprendre.

Répartition par groupe : charge 64 options (31 260 souscriptions), staticip 31 (27 878), sans groupe 26 (6 376), Service Pack, bp et amperage 1 chacun.

## Réductions : charging options (`sql/charging_options.sql`, 27/10/2026)

- **Catalogue** : 565 options de plan avec frais (charge 231, sans groupe 173, staticip 137…). **122 options de réduction** (frais à tarif négatif), dont **93 expirées** et 29 valides.
- **Abonnements à reprendre** : **7 217 abonnements** ont au moins une réduction, pour 7 333 souscriptions. **5 653 portent sur une option ou un frais expiré**, 1 680 sur une option valide. Aucun tarif n'est surchargé par abonnement, et aucun frais négatif n'a été ajouté directement.
- **20 options souscrites** : `alce` -5% AMCOM 3 784 (expirée) ; `discgam` Game Changer 1 380 ; `ExNitro` 1 167 (expirée, −0,95 XPF : ajustement d'arrondi plutôt que réduction ?) ; `spce` 274 et `prce` 244 (-5% AMCOM, expirées) ; `reducopt` Alto+ toutes options 256 ; `al25` -25% 69 ; `%canon` 41 ; réductions employés (`emplo`, `employés`) 69 ; `resseler` revendeur 12 ; autres moins de 25 chacune.
- **Attention aux montants** : le tarif affiché est le `default_rate` de l'article (ex. `alce` −286 XPF), alors que Smile montre −212 XPF sur le plan `altop`. **Le montant réel dépend du plan** (tarif de plan, `plan_tariff_uuid`) : à extraire au niveau du plan pour le lot 5.
- **À trancher** :
  - Les réductions expirées mais toujours souscrites (5 653) sont-elles encore facturées ? À vérifier sur la dernière facturation (cas 14).
  - Les réductions de durée limitée (`Alto3m` « pendant 3 mois ») : où Smile garde-t-il la période restante ?

## Questions ouvertes

- Bases DB1 et DB2 du groupe pgAdmin « SMILE » (cas limite 1) : DB1 (`192.168.51.30`) ne répond ni au ping ni sur le port 5432, n'a plus de nom DNS, et pgAdmin ne la joint plus. Hypothèse : anciens serveurs arrêtés lors de la migration vers SMILE01, toutes les données étant dans `lagoon.nc`. À confirmer par l'admin.
- RIB, RUM et mandats SEPA : **hors périmètre**, déjà gérés dans So'Bloo (décision Lagoon du 27/10/2026). La vue `smile03.account_payment_configuration` masque le numéro (`****************`).
