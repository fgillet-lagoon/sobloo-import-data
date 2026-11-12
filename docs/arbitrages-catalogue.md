# Arbitrages à effectuer : catalogue (lots 1 à 5)

Mise à jour du 13/11/2026. Les données clients et abonnements (lots 2 et 6) sont mises de côté : on se concentre sur les comptes, familles, options, articles et réductions.

Sources : onglets 1, 1b, 3, 4, 5 et cas limites 8 à 14 et 21 du fichier de cadrage ; mesures Smile du 27/10 (`docs/cartographie-smile.md`, `sql/inventaire.sql`, `sql/charging_options.sql`). Aucun retour Lagoon ou Sobloo postérieur au 27/10 n'est intégré.

## Déjà tranché

| Sujet | Décision | Source |
|---|---|---|
| Organisation | Lagoon seule : renseigne onglet 1 n° 8 et onglet 5 n° 17 | Lagoon, 27/10 |
| Plans `active`, `locked`, `closed`, `inactive`, `freesusp` | États techniques, non repris comme articles | Lagoon, 27/10 |
| Réductions | Ce sont les « charging options » (options de plan à tarif négatif) ; la table `discount` est vide | Lagoon, 27/10 |
| Comptabilité clients | Tous en compte client débit | Cas 20 |

## Décisions Lagoon du 13/11/2026

| N° | Décision | Conséquence sur l'export |
|---|---|---|
| C1 | Plans et options utilisés **+** encore en vente | Export = utilisés par les abonnements en cours ∪ disponibles à la vente ; obsolètes non utilisés exclus |
| C3 | 1 service = 1 famille, 1 plan = 1 article | Familles depuis `service`, articles depuis `plan` ; un plan à plusieurs frais est signalé pour éclatement |
| C5 | 1 article par plan (donc par segment), pas de variante | Tranche aussi C4 |
| C6 | Prix **HT tel que Smile** | Montants HT à décimales repris à l'identique. Risque : écarts d'arrondi au TTC en XPF, à contrôler en recette |
| A2 | Compte sur la famille, surcharge sur l'article si Smile diffère | Export du compte par frais, comparaison au compte dominant de la famille |
| A4 | Taxe sur la famille, exception sur l'article | Même logique que A2 |
| O1 | Choix de frais de mise en service repris **comme options telles quelles** | Options `alnos`, `noset`, `alstd`… exportées comme les autres |
| O1 | Choix par défaut (`nostat`, `nooption`) repris **à prix 0** | Exportés comme options |
| O4 | Code Smile, préfixé par le plan si doublon sans casse | Doublons listés dans l'export |
| O5 | Matériel loué : type Abonnement, sans suivi de stock | |
| B1 | Réductions reprises comme **réductions So'Bloo** (`discount`) | Le montant dépendant du plan, une réduction Smile peut donner une réduction So'Bloo par plan. Points à valider par Sobloo : aucun import de réductions n'existe ; non-cumul (prix le plus bas) ; pas de remise automatique sur un article de type Service ; clé de rapprochement hors `discount.code` |
| Périmètre | Familles (services Smile) exclues : 10, 233, 35, 501, 25, 49, 17, 40 | Ni famille, ni article, ni option, ni réduction rattachés (variable `familles_exclues` de `sql/export_catalogue.sql`) |
| Périmètre | Plans dont le code commence par 0 exclus (plans génériques Smile) | 66 articles et 12 options retirés. 5 familles n'ont plus d'article et sortent de l'export : 311 Bande Passante, 1136 GED, 502 Hébergement OPTIONS, 375 Prestation de services Entreprises, 145 WiMax. **3 plans retirés ont des abonnés** (268 abonnements) : `00365` Prestation de services Entreprises 223, `00313` Abonnements OPT 29, `01135` Bande Passante Internet Dédié 16. Au lot 6, ces abonnements n'auront pas d'article |
| Périmètre | Tout élément mentionnant VoD, Go TV ou Analogique (code, libellé, famille) exclu : variable `exclusion_texte` | 11 comptes, 3 familles (48 Analogique, 1124 Go TV, 146 TV - Vidéo à la demande), 8 articles, 28 options et 3 réductions retirés. Le compte 7083-1.4 « Location décodeur TV » (code Smile `locGoTV`) est exclu mais reste le compte de l'article `BoxTV4k` (Location Box TV 4K, 1 abonné), qui ne mentionne aucun des termes |
| Taxes | Tax Free (1) et Taxable (2, ancien régime) exclues | Seules les TGC 445711 à 445714 sont exportées |
| B2 | Options et réductions dont la date de fin de validité est dépassée : **exclues**, même encore souscrites (remplace la décision « exportées, marquées expirées ») | 5 réductions retirées, 1 259 souscriptions : `ExNitro` 1 163, `al25` 68, `spcenos` 24, `alyo` 3, `pryo` 1. Aucune option hors réductions concernée. Au lot 6, ces souscriptions n'auront pas de réduction cible : à abandonner explicitement, sinon les lignes seront rejetées (pas de création partielle) |

## Export du 13/11/2026 (`sql/export_catalogue.sql`)

`4_articles.csv`, `3_options.csv` et `5_reductions.csv` : une ligne par article, option ou réduction, prix = frais récurrent le plus récent (en cours, sinon le dernier commencé), frais de mise en service en colonnes (décision Lagoon du 13/11/2026). Sortie dans `data/catalogue/` (non versionné) : `1_comptes.csv`, `2_taxes.csv`, `1b_familles.csv`, `4_articles.csv`, `3_options.csv`, `5_reductions.csv`. Articles, options et réductions portent l'id de leur famille. Chiffres après les exclusions de familles et de taxes. Une ligne par article (ou option) × frais Smile ; le frais « en cours » donne le prix actuel, les autres sont l'historique des prix.

| Mesure | Valeur |
|---|---|
| Familles (services) | 26 |
| Articles (plans) | 95 : 65 utilisés, 91 sans date de fin, 61 les deux |
| Options hors réductions | 366, dont 122 utilisées ; 59 sans frais (prix 0) |
| Réductions | 15, toutes utilisées (6 088 souscriptions) |
| Comptes de reporting | 146 |
| Taxes en vigueur | TGC 445711 = 3 %, 445712 = 6 %, 445713 = 11 %, 445714 = 22 % |
| Codes préfixés (O4) | 167 options ; plus aucun doublon sans casse après préfixe |
| Fréquences | Toutes à 1 « période de facturation » ou « période de rating », à terme échu pour l'essentiel |

Constats qui appellent une décision :

| N° | Constat | Question |
|---|---|---|
| N1 | « En vente » = plan sans date de fin : 91 plans sur 95, dont 30 sans aucun abonné. Smile ne ferme pas les plans abandonnés | Lagoon liste les plans réellement commercialisés ; les autres sont exclus (C1) |
| N2 | 24 plans utilisés n'ont aucun frais récurrent en cours (14 678 abonnements) : VoIP Monde 8 366 (son dernier frais, 990,57 HT, est clos), modems Labox, noms de domaine, DNS, Office 365, hébergement | Prix à 0 dans So'Bloo ? Facturation à l'usage (VoIP) ou frais annuels portés ailleurs (domaines) : à identifier avant le lot 4 |
| N3 | Catégories du « Rapport des ventes » (dernière génération 2018) : 426 frais sur 594 n'en ont pas | Les catégories Smile ne suffisent pas pour A1 : à redéfinir à partir des comptes |
| N4 | 4 plans partagent leur code avec une option (`forfdns`, `standard`, `std`, `SoSevo1`) | Aucune : l'article garde son code, l'option est préfixée |
| N5 | Réductions : le 27/10 comptait comme expirée toute réduction ayant un ancien tarif expiré (Smile crée un nouveau frais à chaque changement de prix). Recalculé sur le frais en cours : **environ 1 280 souscriptions** sur une réduction sans frais en cours ou à option expirée, dont `ExNitro` 1 164 et `al25` 68, et non 5 653 | Le chiffre de 5 653 du point d'avancement du 27/10 est à corriger auprès de Sobloo. B2 et B4 portent en pratique sur `ExNitro` |
| N6 | Le montant d'une réduction ne dépend pas d'un tarif de plan : c'est le prix du frais en cours (ex. `alce` −212,26 HT ; −286 était un ancien tarif) | Corrige la remarque du 27/10 |

## Arbitrages Lagoon

Un arbitrage bloque l'écriture de la transformation du lot indiqué.

### Transverse catalogue

| N° | Question | Constat Smile | Proposition | Lot |
|---|---|---|---|---|
| C1 | Périmètre du catalogue : seuls les plans et options utilisés, ou aussi ceux encore en vente sans souscripteur ? | 252 plans, dont 202 disponibles ; environ 68 utilisés par les abonnements en cours. 736 options, 144 utilisées | Utilisés **+** disponibles à la vente : So'Bloo doit pouvoir vendre au lendemain de la bascule. Les obsolètes non utilisés restent dans Smile | 3, 4 |
| C2 | Le périmètre « utilisé » dépend des abonnements à reprendre (lot 6, mis de côté) : on garde la règle du 27/10 ? | Active ou Suspended, hors Self Care, hors plan `closed`/`inactive` | Oui, sans la rediscuter tant que le lot 6 est en pause | 3, 4 |
| C3 | Modèle : 1 service Smile = 1 famille, 1 plan Smile = 1 article ? (aussi à valider par Sobloo) | 48 services ; un plan peut porter plusieurs frais (récurrent, mise en service) | Oui pour le principe. À vérifier : nombre de frais par plan avant de figer « 1 plan = 1 article » | 1b, 4 |
| C4 | Variantes d'articles (cas 9) | Pas de notion de variante dans Smile | Pas de variante : 1 article = 1 déclinaison | 3, 4 |
| C5 | Prix différents selon le type de client ou la zone (cas 12) | Les plans semblent dupliqués par segment (`al*`, `pr*`, `sp*`) | Un article par plan Smile, donc par segment ; pas de prix par site | 4 |
| C6 | Prix saisis HT ou TTC ? | Smile stocke du HT à décimales issu de TTC ronds (ex. −471,70 XPF HT = −500 TTC à 6 %) | Import en **TTC** (`is_input_with_tax_included`) pour retomber sur des montants XPF ronds. À confirmer avec la compta | 3, 4 |

### Lot 1 : comptes et familles

| N° | Question | Constat Smile | Proposition |
|---|---|---|---|
| A1 | Catégories de rapport de vente et lien aux comptes 7XXX (cas 21, onglet 1 n° 10) | `reporting_account` : 110 comptes actifs sur 157, avec `gl_export_code` | Lister les 110 comptes et décider si la catégorie Smile devient un champ So'Bloo (à créer) ou est portée par la famille |
| A2 | Compte de vente au niveau famille ou article (cas 10, onglet 4 n° 18) | Compte porté par chaque frais (`item_specification`) | Compte sur la famille, surcharge sur l'article seulement là où Smile diffère. Un compte par forfait a été demandé par Lagoon : à confirmer, car il multiplie les surcharges |
| A3 | Un article ventilé sur plusieurs comptes (cas 10) | Possible si un plan porte plusieurs frais à comptes différents | So'Bloo n'a qu'un compte par article : éclater en plusieurs articles (abonnement + frais) |
| A4 | Taxes : sur la famille ou sur l'article ? | 6 traitements : Taxable, Tax Free, TGC 445711 à 445714 | Sur la famille ; taxe propre à l'article seulement en exception (elle remplace celle de la famille) |
| A5 | Comptes vente exonéré, remise, remise exonéré par famille (onglet 1b n° 10 à 12) | `Tax Free` existe | Exonéré : oui si des clients exonérés existent. Remise : dépend de B1 |
| A6 | Hiérarchie de familles (onglet 1b n° 6) | Pas de hiérarchie de services | Familles à plat. Attention : le compte n'est pas hérité du parent |

### Lots 3 et 4 : options et articles

| N° | Question | Constat Smile | Proposition |
|---|---|---|---|
| O1 | Tri des 124 options utilisées hors réductions | Vraies options (`optmhd`, `optprio`, `std`…), choix de frais de mise en service (`alnos`, `noset`, `alstd`…), choix par défaut (`nostat`, `nooption`) | Vraies options : lot 3. Choix de FMES : voir O3. Choix par défaut : non repris (un groupe non obligatoire suffit) |
| O2 | Option partagée par plusieurs articles (cas 8) | Les options sont définies par plan : la même réduction existe en `alce`, `spce`, `prce` avec des montants différents | Une option So'Bloo par option métier, rattachée à plusieurs articles avec un prix par groupe (`option.transaction_price_id`). À valider : prix par groupe accepté à l'import ? |
| O3 | Frais de mise en service (onglet 4 n° 38) | Modélisés comme un choix d'option « avec / sans FMES » | Article de type Frais, proposé dans un groupe Unique (avec / sans) ; vérifier si les « Packages associés » So'Bloo couvrent le besoin |
| O4 | Code article (`variant.code`) : unicité sans casse | Des codes d'options semblent réutilisés entre plans (`nostat` sur 2 options) | Code = code Smile s'il est unique, sinon code préfixé par le plan. Contrôle à lancer sur Smile avant de trancher |
| O5 | Matériel loué (Location modem/box, Mise à dispo Labox) | 6 619 et 5 274 abonnements | Type Abonnement sans suivi de stock (le parc est géré ailleurs ?), dépôt de garantie si Smile en a un |
| O6 | Articles obsolètes encore souscrits (cas 11) | Inclus via C1/C2 | Importés avec `is_deleted` = Oui |
| O7 | Fréquence de facturation | À extraire du plan | Obligatoire pour tout prix Abonnement ; contrôle bloquant pré-import |
| O8 | Champs « À créer » de l'onglet 4 (n° 39 à 42) : engagement, reconduction, mention inclus / offert, contrat requis | Engagement : à chercher dans `contract` (contrats non utilisés sur les abonnements) | Lagoon décrit le besoin ; Sobloo décide s'il les développe avant le lot 4 |
| O9 | Dépendances entre options (onglet 3 n° 21) | 140 groupes d'options | Couvert par les groupes So'Bloo (Unique, obligatoire) ; lister les seules dépendances entre groupes |

### Lot 5 : réductions

| N° | Question | Constat Smile | Proposition |
|---|---|---|---|
| B1 | Modèle So'Bloo d'une réduction Smile | Option à tarif négatif dont le montant **dépend du plan** ; 122 au catalogue, 20 utilisées. So'Bloo : réductions non cumulables (prix le plus bas), **pas de remise automatique sur un article de type Service**, `discount.code` les transforme en code promo, aucun import existant | **Option à prix négatif** rattachée aux articles (fidèle à Smile, rejouable par `variant.code`, montant par plan). La réduction So'Bloo ne convient pas : non-cumul, exclusion des Services, pas d'import. À valider par Sobloo : prix négatif accepté ? |
| B2 | Réductions expirées encore souscrites (cas 14) | 5 653 souscriptions sur 93 options expirées | Vérifier sur la dernière facturation si elles sont facturées ; si oui, importer l'option avec `is_deleted` = Oui |
| B3 | Réductions à durée limitée (`Alto3m` « pendant 3 mois ») | Durée non localisée dans Smile | Côté catalogue, rien à porter ; la période restante relève du lot 6 |
| B4 | `ExNitro` (−0,95 XPF HT, 1 167 souscriptions) | Ajustement d'arrondi de −1 F TTC | Confirmer que c'est un arrondi ; si oui, le reprendre tel quel ou l'intégrer au prix, à décider avec la compta |
| B5 | Portée : article seul ou article + options ; réduction sur package (onglet 5 n° 18, 19) | `reducopt` « Alto+ toutes options », `emplo` −100 % | Sans objet si B1 retient l'option à prix négatif : le montant couvre ce que Smile couvre |

## Attendus de Sobloo pour le catalogue

| Sujet | Bloque |
|---|---|
| Format CSV ou XLSX avec validations | Tous les dépôts |
| Import des comptes comptables (n'existe pas) | Lot 1 |
| Compte général parent (onglet 1 n° 11, développement prévu) | Lot 1 |
| Validation du modèle C3 (1 service = 1 famille, 1 plan = 1 article) | Lots 1b, 4 |
| Rejeu de l'import articles (création seule aujourd'hui) | Lots 3, 4 |
| Forme du lien article ↔ groupe d'options dans le modèle d'import, prix par groupe (O2) | Lot 4 |
| Prix négatif sur un article option (B1) | Lot 5 |
| Champs « À créer » de l'onglet 4 : développés ou non avant le lot 4 (O8) | Lot 4 |

## Ordre de traitement proposé

1. C1 à C6 et B1 : ils conditionnent la structure de tout le catalogue.
2. A1 à A6 : débloquent le lot 1, premier à déposer.
3. O1 à O9 : lots 3 et 4.
4. B2 à B5 : lot 5.

Côté données, deux requêtes Smile lèvent des incertitudes avant d'arbitrer : nombre de frais et de comptes par plan (C3, A3) ; doublons de codes d'options sans casse (O4).
