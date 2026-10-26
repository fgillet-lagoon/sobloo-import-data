# Correspondance cadrage onglet 2-Clients ↔ Smile

Brouillon du 27/10/2026, construit à partir de la structure de `lagoon.nc` (vues `smile03`, champs personnalisés), de l'inventaire, des taux de remplissage (`sql/remplissage_clients.sql`) et du profil des formats (`sql/profil_clients.sql`). À valider par Lagoon, puis à reporter dans les colonnes jaunes du fichier de cadrage.

Population : `smile03.account`, soit 57 600 comptes (statut `D` exclu par la vue). Pros (Entreprise, Administration, Association, Grand compte, Revendeur) : 5 847. Les 78 comptes « Compte Smile » sont probablement internes : à exclure ? (cas 5).
**Hors périmètre : RIB et mandats SEPA (n° 57 à 65, 78, 84, 85)**. Ils sont déjà gérés dans So'Bloo depuis l'import SEPA (décision Lagoon du 27/10/2026). Dans Smile, la vue masque d'ailleurs le numéro de RIB (`card_number` = `****************`).
Abonnements Self Care (CAT) : non repris comme abonnements (accès au portail, décision du 27/10/2026). Leurs champs utiles sont rattachés au client.
« Rempli » = valeur non vide. Pour un champ personnalisé booléen, une valeur « false » compte comme remplie : la répartition des valeurs reste à vérifier.

## Identité

| N° | Champ So'Bloo | Source Smile | Rempli | Règle proposée | Statut |
|---|---|---|---|---|---|
| 1 | `customer.ref` | `account.usn` | 100 % | Tel quel. 0 manquant, 0 doublon | Proposé |
| 2 | `customer.person_type` | `account.account_type` | 100 % | Particulier → Particulier ; Entreprise, Administration, Association, Grand compte, Revendeur L@goon → Société ; Contentieux → Société si raison sociale renseignée, sinon Particulier | À valider (cas 4) |
| 3 | `customer.title` | `account_contact.contact_title` ; `gender` | 9 ; 1 509 | Trop peu rempli : non repris, ou civilité déduite du genre (2,6 %) | À valider |
| 4 | `customer.last_name` | `account_contact.family_name` | 52 236 (89 %) | Obligatoire si particulier : les particuliers sans nom seront rejetés | Proposé |
| 5 | `customer.first_name` | `account_contact.given_name` | 50 984 (87 %) | Obligatoire si particulier | Proposé |
| 6 | `customer.label` | `account_contact.company_name` | 7 120 | Obligatoire si société. 7 120 raisons sociales pour 5 847 pros : des particuliers en ont aussi | À vérifier |
| 7 | `customer.acronym` | `account_contact.trading_name` | 96 | Nom commercial | Proposé |
| 8 | `customer.legal_status_id` | — | — | Aucun champ | Non repris |
| 9 | `customer.ridet` | `account_contact.abn` (= champ perso `australianBusinessNumber`) | 4 565 | Le champ « ABN » sert de RIDET (le champ perso `ridet` n'est rempli que 11 fois). **Formats hétérogènes** (96 masques) : `9999999.999` 1 196, `999999.999` 1 069, `999999` 549, avec espaces 862, avec tiret 289… Règle proposée : normaliser en 7 chiffres (zéro ajouté devant) + `.` + 3 chiffres d'établissement ; sans établissement, à trancher (`.000` ?). 115 RIDET partagés par plusieurs comptes : acceptable (pas d'unicité en base) | À valider |
| 10-15 | SIRET, APE, RCS, capital, site | — | — | Aucun champ (le champ perso `kbis`, 1 164, est sans doute un document) | Non repris |
| 19 | `customer.birth_date` | `account_contact.date_of_birth` | 9 827 (17 %) | Tel quel | Proposé |
| 20 | `customer.place_of_birth` | champ perso `lieu_naissance` | 8 179 | Tel quel | Proposé |
| 21 | `customer.loyalty_card` | champ perso `ConsoPlusID` (N° Conso+) | 11 534 | **Unique en base : 122 doublons** ⇒ lignes bloquées. À corriger dans Smile avant l'import | Proposé |
| 22 | `customer.is_prospect` | — | — | Non pour tous | Proposé |
| 26 | `customer_to_group` | `account.account_type` ; champ perso `nomduce` (nom du CE) | 100 % ; 6 233 | Administration, Association, Grand compte, Revendeur → groupe du même nom ; `nomduce` → groupe CE (un groupe par CE ?) | À valider |
| 27 | `customer.parent_id` | `account.delegate_account_uuid` | 100 % | Renseigné sur tous les comptes, donc probablement le compte lui-même : pas de hiérarchie parent / enfant exploitable. Non repris, sauf besoin exprimé par Lagoon | À valider |
| 71 | `customer.occupation` | champ perso `profession` | 4 465 | Tel quel (`account_contact.position` : 23, non repris) | Proposé |
| 73-74 | Hors territoire, pays | `account_address.country` | 258 | Hors territoire si pays ≠ Nouvelle-Calédonie | À valider |
| 66-67 | Notes client | champ perso `comments` | 19 134 | Une note par client | À valider |
| — | Ancien numéro de compte | `account.alternate_account_number` | 19 742 (34 %) | À reprendre en propriété dynamique (recherche par ancien numéro) ? | À valider |
| — | Commercial | champ perso `Commercial` | 4 070 | Propriété dynamique ? | À valider |
| 35, 43 | Contact avec procuration | champ perso `Procuration_` (nom de la personne) | 30 576 | **À migrer** (décision Lagoon du 27/10/2026) : un contact par client avec `contact.is_proxy` = Oui, nom = valeur Smile. **Conflit** : So'Bloo exige la date et le lieu de naissance du mandataire (n° 45-46), absents de Smile. À trancher avec Sobloo. Vérifier aussi que les 30 576 valeurs ne sont pas un texte par défaut (« aucune »…) | Ouvert |

## Coordonnées

| N° | Champ So'Bloo | Source Smile | Rempli | Règle proposée | Statut |
|---|---|---|---|---|---|
| 16 | `customer.email` | `account_contact.email_address` | 54 549 (95 %) | **69 formats invalides** à corriger dans Smile. 3 615 adresses partagées entre comptes (familles, sociétés) : acceptable, pas d'unicité à l'import | Proposé |
| 17 | `customer.phone_number` | `account_contact.phone_home`, sinon `phone_work` | 37 576 ; 19 148 | Normalisation 6 → +687, 8 → +689, 10 → +33. `phone_home` : 6 chiffres à 99,4 % ; 150 valeurs à 12 chiffres (sans doute deux numéros dans le même champ) et 71 autres longueurs : anomalies à corriger dans Smile | Proposé |
| 18 | `customer.mobile_phone_number` | `account_contact.phone_mobile` | 51 538 (89 %) | Normalisé. 6 chiffres à 98,6 % ; **693 valeurs à 12 chiffres** (deux mobiles dans le même champ ?) : soit correction dans Smile, soit second numéro reporté dans les mobiles supplémentaires (n° 86) | À valider |
| 86 | Mobiles supplémentaires (à créer) | — | — | Aucune donnée : les champs perso `mobile` et `phoneNumberMobile` sont vides. Besoin à reconfirmer | Ouvert |
| 72 | `customer.fax` | `account_contact.fax` | 3 251 | Tel quel | Proposé |
| 28 | `customer_address.address_line_1` | `account_address.address_detail` | 94 % | L'adresse est en **texte libre** : les champs structurés (n°, rue, bâtiment, BP…) sont vides à plus de 99 % | Proposé |
| 31 | `customer_address.address_label` | `account_address.address_name` | 89 % | Tel quel, sinon libellé du client | Proposé |
| 32 | `customer_address.city_label` | `account_address.suburb` | 93 % | Tel quel | Proposé |
| 33 | `customer_address.zip_code_label` | `account_address.postcode` | 88 % | Tel quel | Proposé |
| 34 | `customer_address.country_label` | `account_address.country` | < 1 % | Nouvelle-Calédonie par défaut | À valider |
| 28-34 | Types d'adresse 0 et 1 | 58 714 de chaque | — | **Identiques pour 55 927 comptes, différentes pour 2 787.** Règle proposée : une adresse si identiques, deux sinon. Lagoon doit dire lequel des types est l'adresse de facturation | À valider (cas 6) |
| 35-46 | Contacts | `account_contact` : un seul contact (type 0) par compte | — | Le contact alimente la fiche client ; aucun contact secondaire | Proposé |

## États et recouvrement (cas 22)

| N° | Champ So'Bloo | Source Smile | Rempli | Règle proposée | Statut |
|---|---|---|---|---|---|
| 23 | `customer_states.blocking_date` | disposition « En retard - Coupure » | 1 | Date à définir (date de bascule ou dernier changement, `account_audit_log`) | Ouvert |
| 24 | `customer_states.suspension_date` | statut de compte Suspended | 3 | Idem | Ouvert |
| 25 | `customer_states.litigation_date` | disposition « Contentieux » / « En retard - Contentieux » ; type Contentieux ; conditions « Contentieux (no email) » | 954 ; 1 122 ; 838 | Une seule règle : quelle source fait foi ? | Ouvert |
| 87 | Accès limité (à créer) | champ perso `limited_access` de l'abonnement **Self Care** | 54 « true », 2 « false » | Oui pour les 54 clients concernés, Non sinon | Proposé |
| — | Revendeur | champ perso `retailerAccount` de l'abonnement **Self Care** | 20 « true », 1 995 « false » | Groupe Revendeur pour les 20 « true ». Cohérent avec les 18 comptes de type Revendeur L@goon : les 2 écarts sont à vérifier | Proposé |
| 88 | Client Chorus (à créer) | — | — | Aucun champ | Ouvert |

Les relances (Relance 1 : 1 962 ; Relance 2 : 21) n'ont pas d'équivalent : il n'y a pas de workflow de recouvrement dans So'Bloo.

## Paiement et comptabilité

| N° | Champ So'Bloo | Source Smile | Rempli | Règle proposée | Statut |
|---|---|---|---|---|---|
| 47 | `payment_profile.type` | — | — | Débit pour tous (décision du 8/10) | Validé |
| 48-49 | Exonération, mention | `account.taxable`, `account.tax_schedule` | 100 % | 34 comptes non taxables ⇒ exonérés, mention à fournir par Lagoon (liste blanche). Barème de taxe : 1 (57 594 comptes) ou 258 (6 comptes) | À valider |
| 50 | Compte général | — | — | Compte client par défaut (411…) | Proposé |
| 51 | Compte tiers | — | — | `OptiGold_num_ro_comptable` n'est rempli qu'une fois : pas de compte tiers à reprendre | Non repris |
| 55 | `settlement_period` (mois) | `account.account_terms` | 100 % | « Paiement normal à 20 jours » ⇒ 1 mois ; « 30 jours fin de mois » ⇒ 1 mois | À valider |
| 56 | Type de paiement privilégié | `account_payment_configuration.payment_type` | 47 855 comptes | Prélèvement BNC/BCI → Prélèvement ; Espèce, Chèque, Virement, Carte bancaire → idem ; Paybox, EPayNC, AMEX → Carte bancaire ? 9 745 comptes n'ont aucune configuration de paiement | À valider |
| 57-65, 78 | RIB, mandat SEPA, prélèvement automatique | — | — | **Hors périmètre** : déjà dans So'Bloo (import SEPA). Ne pas écraser à l'import clients | Validé |
| — | Adresse de la banque | champs perso `bank*` (agence, ville, BP, code postal…) | 4 000 à 25 000 | Pas de champ So'Bloo : non repris | Non repris |
| 82 | Devise | `account.currency` | 100 % | XPF | Proposé |
| 77 | Organisation du profil | — | — | Lagoon / Lagoon Business : à trancher | Ouvert |

## Non repris

- Mots de passe du portail et des services (`selfcare_password`, `password`, `emailpassword*`) : jamais transférés en clair (revue sécurité du plan).
- Champs techniques Smile (`billingAddress`, `streetAddress`, `contact`, `objectName`, `creatingOperator`, `creationDate`) et anciennes données OptiGold (`Optigold_ancien_email`).

## Champs d'abonnement repérés pour le lot 6 (pour mémoire)

Internet : `FIBRE` 27 806, `Fibre_Profil` 25 695, `LieudelaVente` 18 060, `parentalControl` 9 906, `exisitingphoneline` 4 900 (ligne OPT existante), `FIBRE_DATE` 3 610. Labox : `login_adsl` 5 204, `voip_local_number` 5 144, `office_location` 1 495. Location modem/box : `login_adsl` 6 153, `serial_number` 4 183, `voip_local_number` 889. VOIP : `sipfrance` 7 212, `siplocal` 883, `sipdeco` 154. Numéro en 09 : `sip09france` 381.
