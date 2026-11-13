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

`6_abonnements.csv`, `3_options.csv` et `5_reductions.csv` : une ligne par offre, option ou réduction, prix = frais récurrent le plus récent (en cours, sinon le dernier commencé), frais de mise en service en colonnes (décision Lagoon du 13/11/2026). Sortie dans `data/catalogue/` (non versionné) : `1_comptes.csv`, `2_taxes.csv`, `1b_familles.csv`, `3_options.csv`, `4_articles.csv` (invoice items : articles ponctuels), `5_reductions.csv`, `6_abonnements.csv` (offres d'abonnement : plans par service), `6a_abo_internet.csv` et `6b_abo_voip.csv` (propriétés des abonnements Internet et VOIP, taux de remplissage uniquement). Articles, options et réductions portent l'id de leur famille. Chiffres après les exclusions de familles et de taxes. Une ligne par article (ou option) × frais Smile ; le frais « en cours » donne le prix actuel, les autres sont l'historique des prix.

| Mesure | Valeur |
|---|---|
| Familles (services) | 26 |
| Articles ponctuels (invoice items de type 6, actifs) | 144 : hardware 71, service 35, Mobilis 10, autres 28 |
| Offres d'abonnement (plans) | 95 : 65 utilisés, 91 sans date de fin, 61 les deux |
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
| N7 | Invoice items : aucune famille dans Smile ; 8 sans compte de vente (codes compte `invoice`, `arrCMF`) ; 3 en Tax Free (`bon_FB`, `PN_depla`, `Intmorat`) ; 2 à prix négatif (parrainages `AvoirEasyStart`, `%gamechanger`) ; `BoxTV4K` (invoice item) et `BoxTV4k` (plan) ne diffèrent que par la casse | Famille par compte de reporting ? Correction dans Smile des comptes et taxes ; parrainages en avoirs ? Collision de code à résoudre |
| N8 | Propriétés d'abonnement (6a, 6b) : identifiant de service (`username`) renseigné à 100 % (login Internet, numéro VoIP à 8 chiffres). Internet : Fibre 99 %, profil fibre 92 %, lieu de vente 65 %, contrôle parental 36 %. VOIP : comptes SIP Monde 86 %, France 11 %. Mot de passe, ligne OPT, n° de série et MAC absents ou vides | Liste des propriétés à créer dans So'Bloo, à valider |
