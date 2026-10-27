# CLAUDE.md — sobloo-import-data

## Objectif du projet

Reprise des données de **Lagoon** (opérateur télécom / FAI, Nouvelle-Calédonie) depuis **Smile** (ancien SI, source de vérité) vers **So'Bloo** (nouveau SI de facturation / abonnements, éditeur Sobloo).

Ce dépôt sert le **côté Lagoon** de la reprise : cadrer les champs Smile à reprendre, produire les extracts au format des modèles d'import So'Bloo, contrôler leur qualité avant dépôt, et suivre les points ouverts. Seule Lagoon a accès à Smile.

Objectifs fixés (CR du 8/10/2026) :
- importer sans ressaisie manuelle les référentiels : comptabilité, clients, catalogue ;
- reprendre les abonnements **en cours** dans leur état actuel ;
- pouvoir tester, corriger à la source dans Smile, et **rejouer** les imports ;
- identifier en amont un maximum de cas limites.

Acteurs : Lagoon — François Gillet · Sobloo — Tom Chitty, Charlotte Hoorelbeke.

## Documents de référence (`docs/`)

| Fichier | Contenu |
|---|---|
| `docs/Imports Lagoon — Compte rendu et plan d_action.docx` | Décisions actées, démarche en 6 étapes, gestion des erreurs, recette, RACI, points ouverts |
| `docs/Imports_Lagoon_Fichier_de_cadrage.xlsx` | **Référence commune** : un onglet par import, champ par champ (So'Bloo pré-rempli en bleu, Lagoon à compléter en jaune, lignes vertes = champs Smile à créer dans So'Bloo) |

Le fichier de cadrage fait foi pour les champs, formats, obligations et règles. Il est issu du code So'Bloo, branche `develop` du 06/10/2026. Toujours le relire avant d'écrire ou modifier une transformation.

Pour lire les fichiers Office sans dépendance : `textutil -convert txt -stdout <docx>` (macOS) ; pour le xlsx, dézipper et parser `xl/sharedStrings.xml` + `xl/worksheets/*.xml` (openpyxl n'est pas installé).

## Ordre des imports (chaque lot dépend des précédents)

Un lot ne démarre que lorsque le précédent est validé par Lagoon **et** Sobloo.

| Lot | Onglet(s) cadrage | Clé de rapprochement | Remarques |
|---|---|---|---|
| 1 | `1-Comptes comptables`, `1b-Familles articles` | code du compte ; code famille | Import comptes à développer côté Sobloo. Les familles portent taxes et comptes de vente par défaut |
| 2 | `2-Clients` | `customer.ref` = **`usn` du compte Smile** (accountUsn) | Particuliers et professionnels |
| 3 | `3-Options articles` | `variant.code` | Une option = un article rattaché via un groupe d'options |
| 4 | `4-Articles` | `variant.code` | Frais fixes inclus ; liens vers options |
| 5 | `5-Réductions` | à définir (`discount.code` le transforme en code promo) | Absentes des données actuelles : fichier à fournir par Lagoon |
| 6 | `6-Abonnements`, `6a-Abo Internet`, `6b-Abo VOIP` | **`usn` de l'abonnement Smile** (décision Lagoon du 27/10/2026 ; les contrats d'abonnement ne sont pas utilisés dans Smile) | En cours uniquement, sans historique de factures |

Onglet `Cas limites` : 27 questions à trancher (sources, doublons, suspendus, bascule…). Une réponse Lagoon doit y aboutir à une « Règle d'import retenue ».

## Règles transverses (non négociables)

- **Référence Smile = clé primaire** : unique et obligatoire sur chaque ligne. Rejouer un fichier **met à jour** au lieu de dupliquer. Absente ou en double ⇒ ligne bloquée (déjà vécu sur l'import SEPA). `customer.ref` n'a **aucune contrainte d'unicité en base** : dédoublonner avant dépôt.
- **Pas de création partielle** : une ligne qui référence un élément absent (client rejeté, option non importée…) est rejetée avec un motif explicite.
- **Erreur de données ⇒ corrigée dans Smile par Lagoon**, puis rejeu. Ne jamais « réparer » une donnée métier dans le fichier d'extract sans que la source soit corrigée. Erreur de règle / correspondance / outil ⇒ Sobloo.
- **Extracts complets** : un fichier par import, toutes bases confondues (des clients pros étaient répartis sur deux bases lors du SEPA).
- **Transmission** : dépôt direct dans So'Bloo via le modèle d'import générique. Pas de Drive partagé. Ne jamais pousser de données clients vers un service externe.
- **Format** : CSV ou XLSX avec validations, **non tranché** (porteur Sobloo). Ne pas figer le format dans le code sans confirmation.
- Comptabilité : tous les types de clients sont en **compte client débit** (profil de paiement « Débit »).
- Organisation So'Bloo : **Lagoon seule** (décision Lagoon du 27/10/2026, pas de Lagoon Business pour la reprise).

## Pièges techniques relevés dans le cadrage

Clients
- Téléphones normalisés à l'import : 6 chiffres → +687, 8 → +689, 10 → +33.
- Aucun contrôle serveur du format e-mail : à vérifier en pré-import.
- `settlement_period` est en **mois** (défaut 1), pas en jours : convertir les délais Smile.
- RIB : code banque 5 chiffres, guichet 5, compte 11, clé 2 (modulo 97). RIB ≠ 23 caractères = rejet SEPA. IBAN calculé avec pays FR (à vérifier pour la NC).
- RUM : reprendre celle de Smile si elle existe (continuité des prélèvements). Date de signature obligatoire pour un mandat Validé.
- `siret` et `loyalty_card` sont **uniques** en base.
- Forme juridique, mention de taxe, compte tiers : l'import actuel **crée** la valeur si inconnue ⇒ attention aux fautes de frappe.
- États client (bloqué / suspendu / contentieux) = des **dates** par organisation, pas une liste de statuts.
- Propriétés dynamiques client : ni import ni contrôle serveur aujourd'hui.

Catalogue
- Codes articles uniques **sans casse** parmi les déclinaisons actives ; codes familles convertis en minuscules.
- Un article/option obsolète encore utilisé par un abonnement en cours **doit** être importé.
- `is_option_only` et `is_option` : colonnes NOT NULL sans défaut ⇒ toujours envoyer une valeur.
- Prix Abonnement ⇒ fréquence de facturation obligatoire (non contrôlée côté serveur). L'import actuel met 0 si prix vide.
- Taxes propres à l'article **remplacent** celles de la famille. Compte de l'article > compte de la famille directe (pas de remontée vers la famille parente) > compte par défaut.
- L'import articles actuel ne fait que créer, pas de mise à jour : le rejeu est à faire évoluer côté Sobloo.

Réductions
- Ne se cumulent pas : So'Bloo retient le prix le plus bas. Importer à l'état **Validée** (défaut Brouillon). Pas de compte sur la réduction.

Abonnements
- Un abonnement = un devis de type Abonnement (`estimate`) + lignes (`estimate_line`) ; options = lignes enfants.
- `estimate_line.start_date` **indispensable** : sans elle la ligne n'est jamais facturée.
- Pas de champ « prochaine échéance » : la traduire en dates de début / de facturation pour éviter double facturation ou trou à la bascule.
- « Résilié » n'est pas un état : se déduit d'une date de fin passée. États importables : Validé / Suspendu / Partiellement suspendu.
- Ne pas stocker l'ID Smile dans `estimate.contract_number` (visible et modifiable).
- Propriétés dynamiques définies globalement, pas par type d'abonnement : les onglets 6a/6b se traduisent en propriétés de ligne.

## Contrôles attendus (pré-import et recette)

Pré-import, par fichier : colonnes manquantes, obligatoires vides, formats invalides (IBAN, e-mail, téléphone, date), références inconnues, doublons de référence Smile.

Rapport d'erreurs : numéro de ligne, référence Smile, champ, motif.

Critères de sortie d'un lot :
- lignes lues = créées + mises à jour + en erreur ;
- comptages par type (clients part./pro, articles, options, réductions, abonnements) égaux à Smile ;
- panel de clients représentatifs (dont pros et SEPA) contrôlé ;
- liens articles ↔ options, ventilation comptable, abonnements (client, articles, réductions, échéance, montant, propriétés) corrects ;
- **rejeu d'un import déjà passé sans doublon**.

## Points ouverts (au 12/10/2026)

| Point | Porteur |
|---|---|
| Format CSV ou XLSX avec validations | Sobloo |
| Conservation des fichiers importés (rattachés au journal d'import) | Sobloo |
| Utilisation des variantes d'articles | Lagoon |
| Types d'abonnement à propriétés dynamiques (Internet, VOIP…) | Lagoon |
| Catégories de rapports de vente et lien aux comptes 7XXX | Lagoon |
| Pas de workflow de recouvrement ; statuts clients à reprendre | Lagoon |
| Abonnements en cours seulement, sans historique de factures | Lagoon |
| Fichier des réductions | Lagoon |

## Conventions de travail

- Langue : français pour la documentation, les messages et les noms métier ; garder les noms techniques So'Bloo (`customer.ref`, `estimate_line.start_date`…) tels quels.
- Les extracts Smile contiennent des données personnelles et bancaires : ne jamais les committer (prévoir un `.gitignore` pour les répertoires de données), ne jamais les envoyer à un service tiers.
- Toute règle de transformation ajoutée doit pouvoir être reliée à une ligne du fichier de cadrage (onglet + N°) ou à un cas limite.
