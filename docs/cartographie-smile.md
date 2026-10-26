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
| 1 | 1b-Familles | `service`, `plan` (à confirmer : la famille So'Bloo peut correspondre au service Smile) ; `tax_schedule`, `tax_schedule_item`, `tax_treatment` |
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
- **« Contentieux » existe à trois endroits** : type de compte (1 122), disposition (838 + 116) et conditions de paiement (838). À traduire en `customer_states.litigation_date` (cas 22), règle à fixer.
- **Les contrats d'abonnement Smile ne sont pas utilisés** : la clé du lot 6 ne peut pas être un ID de contrat. Candidat : `usn` de l'abonnement (unique, jamais vide).
- **Les réductions Smile ne sont pas utilisées** : les remises éventuelles passent par des plans ou les 61 frais récurrents hors plan (cas 13, 14).
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

## Questions ouvertes

- Bases DB1 et DB2 du groupe pgAdmin « SMILE » (cas limite 1) : DB1 (`192.168.51.30`) ne répond ni au ping ni sur le port 5432, n'a plus de nom DNS, et pgAdmin ne la joint plus. Hypothèse : anciens serveurs arrêtés lors de la migration vers SMILE01, toutes les données étant dans `lagoon.nc`. À confirmer par l'admin.
- RIB, RUM et mandats SEPA : **hors périmètre**, déjà gérés dans So'Bloo (décision Lagoon du 27/10/2026). La vue `smile03.account_payment_configuration` masque le numéro (`****************`).
