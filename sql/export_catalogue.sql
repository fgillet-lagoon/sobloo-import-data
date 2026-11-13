-- Export brut du catalogue Smile (lots 1, 1b, 3, 4, 5, et offres d'abonnement 6, 6a, 6b), selon les décisions Lagoon du 13/11/2026 (docs/arbitrages-catalogue.md).
-- Pas de donnée client : codes, libellés, prix et comptages. Sortie dans data/catalogue/ (ignoré par git).
-- Usage : psql -X -f sql/export_catalogue.sql   (depuis la racine, PGOPTIONS en lecture seule + statement_timeout)
--
-- Règles :
--   C1  périmètre = plans/options utilisés par un abonnement à reprendre OU encore en vente ; obsolètes non utilisés exclus.
--       « Utilisé » = règle du 27/10 (sql/perimetre.sql) : abonnement Active/Suspended, hors Self Care, plan en cours ≠ closed/inactive.
--   C3  1 service = 1 famille, 1 plan = 1 article. Plans de cycle de vie (active, locked, closed, inactive, freesusp) exclus.
--   C6  prix HT tels que Smile (itemdescription.rate = smile03.item_specification.default_rate).
--   O1  options de frais de mise en service et choix par défaut gardés comme options (prix 0 si aucun frais).
--   O4  code = code Smile ; préfixé « plan-code » s'il est en doublon sans casse avec un autre code du catalogue.
--   B1  une option dont un frais est négatif est une réduction : fichier 5, absente du fichier 3 (requête commune : export_catalogue_options.sql).
-- Les CTE sont répétées : la réplique est en lecture seule (pas de vue temporaire).

\pset format csv
\pset footer off

-- Familles (services Smile) exclues par Lagoon le 13/11/2026 : ni famille, ni article, ni option, ni réduction
\set familles_exclues '10, 233, 35, 501, 25, 49, 17, 40, 29'
-- Tout élément mentionnant VoD, Go TV ou Analogique (code, libellé, famille) exclu par Lagoon le 13/11/2026
\set exclusion_texte 'vod|go ?tv|analogique'

-- 1. Comptes de reporting (onglet 1 : code = glcode, compte général Sage)
\o data/catalogue/1_comptes.csv
select t.glcode as "code compte", t.name as "libellé", t.txcode as "code Smile", t.validfrom as "valide du", t.validto as "valide au",
       count(i.itemcode) as "articles Smile rattachés"
from public.txdescription t
left join public.itemdescription i on i.txcode = t.txcode and i.company = t.company
where (coalesce(t.glcode, '') || ' ' || coalesce(t.name, '') || ' ' || t.txcode) !~* :'exclusion_texte'
  and (t.validto is null or t.validto >= current_date)  -- comptes actifs seulement (Lagoon, 13/11/2026)
  and lower(t.txcode) not in ('imp41', 'transfer')  -- report à nouveau et virements, exclus par Lagoon le 13/11/2026
group by t.txdescription, t.glcode, t.name, t.txcode, t.validfrom, t.validto
order by 1, 3;

-- 2. Taxes (onglet 1b n° 8) : taux en vigueur, barème 1
\o data/catalogue/2_taxes.csv
select distinct on (tt.tax_treatment) tt.tax_treatment as "id Smile", tt.name as "taxe",
       s.percentage_rate as "taux %", s.start_date as "depuis"
from smile03.tax_treatment tt
left join smile03.tax_schedule_item s on s.tax_treatment = tt.tax_treatment and s.tax_schedule = 1 and s.start_date <= current_date
where tt.tax_treatment not in (1, 2)  -- Tax Free et Taxable (ancien régime) exclus par Lagoon le 13/11/2026
order by tt.tax_treatment, s.start_date desc;

-- 3. Familles (onglet 1b) : un service Smile ayant au moins un plan dans le périmètre
\o data/catalogue/1b_familles.csv
with pec as (
    select distinct on (i.uid) i.uid as subscription, i.psi, i.plan
    from public.planscheduleitem i
    join public.planschedule p on p.planschedule = i.planschedule and p.active and p.planscheduletype = 1
    where i.startdate is not null and i.startdate <= current_date
    order by i.uid, i.startdate desc, i.starttime desc nulls last, i.psi desc
),
lar as (
    select pec.* from pec
    join smile03.subscription s on s.subscription = pec.subscription
    join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
    left join smile03.service sv on sv.service = s.service
    where st.name in ('Active', 'Suspended') and coalesce(sv.name, '') <> 'Self Care (CAT)'
      and pec.plan not in ('closed', 'inactive')
),
usage as (select plan, count(*) as nb from lar group by 1),
plans as (
    select p.plan, sp.service, coalesce(u.nb, 0) as nb_abonnements,
           (p.validfrom is null or p.validfrom <= current_date) and (p.validto is null or p.validto >= current_date) as en_vente
    from public.plan p
    join smile03.plan sp on sp.plan = p.plan
    left join usage u on u.plan = p.plan
    where p.plan not in ('active', 'locked', 'closed', 'inactive', 'freesusp') and p.plan not like '0%'  -- plans génériques Smile, exclus par Lagoon le 13/11/2026
      and sp.service not in (:familles_exclues)
      and (p.plan || ' ' || coalesce(p.name, '')) !~* :'exclusion_texte'
      and sp.service not in (select service from smile03.service where name ~* :'exclusion_texte')
),
perimetre as (select * from plans where nb_abonnements > 0 or en_vente),
-- Compte et taxe dominants des frais de base des plans de la famille (A2, A4 : portés par la famille, surcharge sur l'article)
frais_base as (
    select pe.service, t.glcode, tt.name as taxe
    from perimetre pe
    join public.planautocharge pa on pa.plan = pe.plan and pa.planoption is null
    join public.itemdescription i on i.itemcode = pa.itemcode and i.company = pa.company
    left join public.txdescription t on t.txcode = i.txcode and t.company = i.company
    left join smile03.tax_treatment tt on tt.tax_treatment = i.taxtreatment
),
compte_dominant as (
    select distinct on (service) service, glcode, count(*) over (partition by service, glcode) as nb
    from frais_base order by service, count(*) over (partition by service, glcode) desc, glcode
),
taxe_dominante as (
    select distinct on (service) service, taxe
    from frais_base order by service, count(*) over (partition by service, taxe) desc, taxe
)
select sv.service as "id service Smile", sv.name as "libellé famille", sv.description as "description",
       count(pe.plan) as "plans dans le périmètre", count(pe.plan) filter (where pe.nb_abonnements > 0) as "plans utilisés",
       count(pe.plan) filter (where pe.en_vente) as "plans en vente", coalesce(sum(pe.nb_abonnements), 0) as "abonnements à reprendre",
       cd.glcode as "compte de vente dominant", td.taxe as "taxe dominante"
from perimetre pe
join smile03.service sv on sv.service = pe.service
left join compte_dominant cd on cd.service = sv.service
left join taxe_dominante td on td.service = sv.service
group by sv.service, sv.name, sv.description, cd.glcode, td.taxe
order by 2;

-- 4. Articles (onglet 4) : invoice items Smile = articles ponctuels (itemdescription de type 6), actifs.
--    Pas de famille dans Smile pour ces articles. Les plans sont exportés à part (fichier 6).
\set reduction_one_shot false
\o data/catalogue/4_articles.csv
\ir export_catalogue_articles.sql

-- 5b. Réductions ponctuelles : invoice items à prix négatif (parrainages). Les réductions récurrentes sont dans 5_reductions.
\set reduction_one_shot true
\o data/catalogue/5b_reductions_one_shot.csv
\ir export_catalogue_articles.sql

-- 6. Abonnements (onglet 6) : une ligne par plan (offre d'abonnement) du périmètre, rattaché à son service (famille).
--    Prix = frais récurrent le plus récent (Lagoon 13/11/2026 : pas de ligne par prix).
--    Smile crée un nouveau frais à chaque changement de tarif : on garde celui en cours, sinon le dernier commencé.
\o data/catalogue/6_abonnements.csv
with recursive arbre as (
    select salesreportitem, parentitem, itemdescription, name::text as chemin
    from reports.salesreportitem where salesreport = 247 and parentitem is null
    union all
    select c.salesreportitem, c.parentitem, c.itemdescription, a.chemin || ' > ' || c.name
    from reports.salesreportitem c join arbre a on c.parentitem = a.salesreportitem
),
categorie as (  -- catégorie du « Rapport des ventes » : chemin du parent du nœud article
    select distinct on (n.itemdescription) n.itemdescription, a.chemin
    from arbre n join arbre a on a.salesreportitem = n.parentitem
    where n.itemdescription is not null order by n.itemdescription, a.chemin
),
pec as (
    select distinct on (i.uid) i.uid as subscription, i.psi, i.plan
    from public.planscheduleitem i
    join public.planschedule p on p.planschedule = i.planschedule and p.active and p.planscheduletype = 1
    where i.startdate is not null and i.startdate <= current_date
    order by i.uid, i.startdate desc, i.starttime desc nulls last, i.psi desc
),
lar as (
    select pec.* from pec
    join smile03.subscription s on s.subscription = pec.subscription
    join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
    left join smile03.service sv on sv.service = s.service
    where st.name in ('Active', 'Suspended') and coalesce(sv.name, '') <> 'Self Care (CAT)'
      and pec.plan not in ('closed', 'inactive')
),
usage as (select plan, count(*) as nb from lar group by 1),
perimetre as (
    select * from (
        select p.plan, p.name, p.userdescription, p.admindescription, p.validfrom, p.validto, p.setupchargecode, p.company,
               sp.service, sp.is_suspension_plan, coalesce(u.nb, 0) as nb_abonnements,
               (p.validfrom is null or p.validfrom <= current_date) and (p.validto is null or p.validto >= current_date) as en_vente
        from public.plan p
        join smile03.plan sp on sp.plan = p.plan
        left join usage u on u.plan = p.plan
        where p.plan not in ('active', 'locked', 'closed', 'inactive', 'freesusp') and p.plan not like '0%'  -- plans génériques Smile, exclus par Lagoon le 13/11/2026
          and sp.service not in (:familles_exclues)
          and (p.plan || ' ' || coalesce(p.name, '')) !~* :'exclusion_texte'
          and sp.service not in (select service from smile03.service where name ~* :'exclusion_texte')
    ) x where nb_abonnements > 0 or en_vente
),
frais as (
    select distinct on (pa.plan) pa.plan, pa.itemcode, fr.name as frequence, pa.frequencyunits, m.name as mode,
           (pa.validfrom is null or pa.validfrom <= current_date) and (pa.validto is null or pa.validto >= current_date) as en_cours
    from public.planautocharge pa
    left join smile03.recurring_charge_frequency_type fr on fr.recurring_charge_frequency_type = pa.frequencytype
    left join smile03.recurring_charge_mode m on m.recurring_charge_mode = pa.chargingmode
    where pa.planoption is null
    order by pa.plan, 6 desc, pa.validfrom desc nulls last, pa.planautocharge desc
),
taux as (
    select distinct on (tax_treatment) tax_treatment, percentage_rate
    from smile03.tax_schedule_item where tax_schedule = 1 and start_date <= current_date
    order by tax_treatment, start_date desc
)
select pe.plan as "code Smile", pe.name as "désignation", sv.service as "id famille", sv.name as "famille (service)", pe.userdescription as "description client", pe.admindescription as "description interne",
       pe.nb_abonnements as "abonnements à reprendre", pe.validfrom as "en vente du", pe.validto as "en vente au",
       f.itemcode as "code frais Smile", i.name as "libellé frais",
       i.rate as "prix HT", i.currency as "devise", f.frequence as "fréquence", f.frequencyunits as "multiple", f.mode as "mode de facturation",
       t.glcode as "compte de vente", t.name as "libellé compte", tt.name as "taxe", tx.percentage_rate as "taux taxe %",
       cat.chemin as "catégorie rapport des ventes",
       nullif(pe.setupchargecode, '') as "code frais mise en service", ims.rate as "prix HT mise en service"
from perimetre pe
join smile03.service sv on sv.service = pe.service
left join frais f on f.plan = pe.plan
left join public.itemdescription i on i.itemcode = f.itemcode and i.company = pe.company
left join public.txdescription t on t.txcode = i.txcode and t.company = i.company
left join smile03.tax_treatment tt on tt.tax_treatment = i.taxtreatment
left join taux tx on tx.tax_treatment = i.taxtreatment
left join categorie cat on cat.itemdescription = i.itemdescription
left join public.itemdescription ims on ims.itemcode = pe.setupchargecode and ims.company = pe.company
order by sv.name, pe.plan;

-- 5. Options (onglet 3) et réductions (onglet 5) : même requête, filtrée par :nature
\set nature '3-option'
\o data/catalogue/3_options.csv
\ir export_catalogue_options.sql
\set nature '5-réduction'
\o data/catalogue/5_reductions.csv
\ir export_catalogue_options.sql

-- 6a / 6b. Propriétés des abonnements Internet et VOIP (onglets 6a, 6b) : taux de remplissage uniquement, aucune valeur
\set famille 47
\o data/catalogue/6a_abo_internet.csv
\ir export_catalogue_proprietes.sql
\set famille 50
\o data/catalogue/6b_abo_voip.csv
\ir export_catalogue_proprietes.sql

\o
