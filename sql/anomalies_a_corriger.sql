-- Listes nominatives des points à corriger dans Smile (slide 5 du point d'avancement du 27/10/2026).
-- CONTIENT DES DONNÉES PERSONNELLES : à exécuter avec psql, sortie écrite dans data/anomalies/ (ignoré par git).
-- Usage : psql -X -f sql/anomalies_a_corriger.sql   (depuis la racine du dépôt, session en lecture seule)
-- Périmètre : clients et abonnements à reprendre, mêmes règles que sql/perimetre.sql.
-- Nom affiché : raison sociale, sinon nom de famille ; prénom à part.

\pset format csv
\pset footer off

-- Les CTE sont répétées dans chaque requête : la réplique est en lecture seule (pas de vue temporaire possible).

-- 1. N° Conso+ en double (cadrage onglet 2 n° 21 : loyalty_card unique dans So'Bloo)
\o data/anomalies/1_conso_plus_doublons.csv
with pec as (
    select distinct on (i.uid) i.uid as subscription, i.plan
    from public.planscheduleitem i
    join public.planschedule p on p.planschedule = i.planschedule and p.active and p.planscheduletype = 1
    where i.startdate is not null and i.startdate <= current_date
    order by i.uid, i.startdate desc, i.starttime desc nulls last, i.psi desc
),
cl as (
    select distinct s.account
    from smile03.subscription s
    join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
    left join smile03.service sv on sv.service = s.service
    left join pec on pec.subscription = s.subscription
    where st.name in ('Active', 'Suspended') and coalesce(sv.name, '') <> 'Self Care (CAT)'
      and coalesce(pec.plan, '') not in ('closed', 'inactive')
),
contact as (select distinct on (account) * from smile03.account_contact order by account, contact_type),
conso as (
    select cl.account, trim(ac.custom ->> 'ConsoPlusID') as conso_plus
    from cl join smile03.account_custom ac on ac.account = cl.account
    where nullif(trim(ac.custom ->> 'ConsoPlusID'), '') is not null
),
doublons as (
    select conso_plus, count(*) as nb from conso group by 1 having count(*) > 1
)
select c.conso_plus as "N° Conso+", d.nb as "Comptes avec ce numéro", a.usn as "usn compte",
       coalesce(nullif(trim(ct.company_name), ''), ct.family_name) as "Nom / raison sociale", ct.given_name as "Prénom"
from conso c
join doublons d on d.conso_plus = c.conso_plus
join smile03.account a on a.account = c.account
left join contact ct on ct.account = c.account
order by 1, 3;

-- 2. Abonnements actifs sur le plan inactive
\o data/anomalies/2_abonnements_plan_inactive.csv
with pec as (
    select distinct on (i.uid) i.uid as subscription, i.plan
    from public.planscheduleitem i
    join public.planschedule p on p.planschedule = i.planschedule and p.active and p.planscheduletype = 1
    where i.startdate is not null and i.startdate <= current_date
    order by i.uid, i.startdate desc, i.starttime desc nulls last, i.psi desc
),
contact as (select distinct on (account) * from smile03.account_contact order by account, contact_type)
select s.usn as "usn abonnement", sv.name as "Service", st.name as "Statut", a.usn as "usn compte",
       coalesce(nullif(trim(ct.company_name), ''), ct.family_name) as "Nom / raison sociale", ct.given_name as "Prénom"
from smile03.subscription s
join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
left join smile03.service sv on sv.service = s.service
join pec on pec.subscription = s.subscription
join smile03.account a on a.account = s.account
left join contact ct on ct.account = s.account
where st.name in ('Active', 'Suspended') and coalesce(sv.name, '') <> 'Self Care (CAT)' and pec.plan = 'inactive'
order by 4, 1;

-- 3. Comptes en contentieux avec abonnement actif (décision du 27/10 : la disposition fait foi)
\o data/anomalies/3_contentieux_abonnement_actif.csv
with pec as (
    select distinct on (i.uid) i.uid as subscription, i.plan
    from public.planscheduleitem i
    join public.planschedule p on p.planschedule = i.planschedule and p.active and p.planscheduletype = 1
    where i.startdate is not null and i.startdate <= current_date
    order by i.uid, i.startdate desc, i.starttime desc nulls last, i.psi desc
),
arep as (
    select s.account, s.usn, st.name as statut
    from smile03.subscription s
    join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
    left join smile03.service sv on sv.service = s.service
    left join pec on pec.subscription = s.subscription
    where st.name in ('Active', 'Suspended') and coalesce(sv.name, '') <> 'Self Care (CAT)'
      and coalesce(pec.plan, '') not in ('closed', 'inactive')
),
contact as (select distinct on (account) * from smile03.account_contact order by account, contact_type)
select a.usn as "usn compte", coalesce(nullif(trim(ct.company_name), ''), ct.family_name) as "Nom / raison sociale",
       ct.given_name as "Prénom", d.name as "Disposition",
       count(*) as "Abonnements actifs", count(*) filter (where x.statut = 'Suspended') as "dont suspendus",
       string_agg(x.usn, ', ' order by x.usn) as "usn des abonnements"
from smile03.account a
join smile03.account_disposition d on d.account_disposition = a.account_disposition
join arep x on x.account = a.account
left join contact ct on ct.account = a.account
where d.name in ('Contentieux', 'En retard - Contentieux')
group by a.usn, 2, 3, 4
order by 4, 1;

-- 4. Téléphones à 12 chiffres ou de longueur anormale (normalisation 6 → +687, 8 → +689, 10 → +33)
\o data/anomalies/4_telephones.csv
with pec as (
    select distinct on (i.uid) i.uid as subscription, i.plan
    from public.planscheduleitem i
    join public.planschedule p on p.planschedule = i.planschedule and p.active and p.planscheduletype = 1
    where i.startdate is not null and i.startdate <= current_date
    order by i.uid, i.startdate desc, i.starttime desc nulls last, i.psi desc
),
cl as (
    select distinct s.account
    from smile03.subscription s
    join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
    left join smile03.service sv on sv.service = s.service
    left join pec on pec.subscription = s.subscription
    where st.name in ('Active', 'Suspended') and coalesce(sv.name, '') <> 'Self Care (CAT)'
      and coalesce(pec.plan, '') not in ('closed', 'inactive')
),
contact as (select distinct on (account) * from smile03.account_contact order by account, contact_type),
tel as (
    select cl.account, 'Mobile' as champ, ct.phone_mobile as telephone from cl join contact ct on ct.account = cl.account
    union all
    select cl.account, 'Fixe', ct.phone_home from cl join contact ct on ct.account = cl.account
)
select a.usn as "usn compte", coalesce(nullif(trim(ct.company_name), ''), ct.family_name) as "Nom / raison sociale",
       ct.given_name as "Prénom", t.champ as "Champ", t.telephone as "Téléphone actuel",
       length(regexp_replace(t.telephone, '\D', '', 'g')) as "Nombre de chiffres",
       case when length(regexp_replace(t.telephone, '\D', '', 'g')) = 12 then 'Deux numéros dans le champ ?' else 'Longueur anormale' end as "Anomalie"
from tel t
join smile03.account a on a.account = t.account
left join contact ct on ct.account = t.account
where nullif(trim(t.telephone), '') is not null
  and length(regexp_replace(t.telephone, '\D', '', 'g')) not in (6, 8, 10)
order by 7, 1;

-- 5. RIDET au mauvais format (attendu 1234567.001 ; champ « ABN » du contact)
\o data/anomalies/5_ridet_format.csv
with pec as (
    select distinct on (i.uid) i.uid as subscription, i.plan
    from public.planscheduleitem i
    join public.planschedule p on p.planschedule = i.planschedule and p.active and p.planscheduletype = 1
    where i.startdate is not null and i.startdate <= current_date
    order by i.uid, i.startdate desc, i.starttime desc nulls last, i.psi desc
),
cl as (
    select distinct s.account
    from smile03.subscription s
    join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
    left join smile03.service sv on sv.service = s.service
    left join pec on pec.subscription = s.subscription
    where st.name in ('Active', 'Suspended') and coalesce(sv.name, '') <> 'Self Care (CAT)'
      and coalesce(pec.plan, '') not in ('closed', 'inactive')
),
contact as (select distinct on (account) * from smile03.account_contact order by account, contact_type),
r as (
    select cl.account, trim(ct.abn) as ridet, regexp_replace(ct.abn, '\D', '', 'g') as chiffres
    from cl join contact ct on ct.account = cl.account
    where nullif(trim(ct.abn), '') is not null and trim(ct.abn) !~ '^[0-9]{7}\.[0-9]{3}$'
)
select a.usn as "usn compte", coalesce(nullif(trim(ct.company_name), ''), ct.family_name) as "Nom / raison sociale",
       r.ridet as "RIDET actuel",
       case length(r.chiffres)
         when 10 then substr(r.chiffres, 1, 7) || '.' || substr(r.chiffres, 8, 3)
         when 9 then '0' || substr(r.chiffres, 1, 6) || '.' || substr(r.chiffres, 7, 3)
       end as "Proposition (à vérifier)",
       case when length(r.chiffres) in (6, 7) then 'Numéro d''établissement manquant' when length(r.chiffres) in (9, 10) then 'Séparateurs à corriger' else 'Format à vérifier' end as "Anomalie"
from r
join smile03.account a on a.account = r.account
left join contact ct on ct.account = r.account
order by 5, 1;

-- 6. E-mails au format invalide
\o data/anomalies/6_emails_invalides.csv
with pec as (
    select distinct on (i.uid) i.uid as subscription, i.plan
    from public.planscheduleitem i
    join public.planschedule p on p.planschedule = i.planschedule and p.active and p.planscheduletype = 1
    where i.startdate is not null and i.startdate <= current_date
    order by i.uid, i.startdate desc, i.starttime desc nulls last, i.psi desc
),
cl as (
    select distinct s.account
    from smile03.subscription s
    join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
    left join smile03.service sv on sv.service = s.service
    left join pec on pec.subscription = s.subscription
    where st.name in ('Active', 'Suspended') and coalesce(sv.name, '') <> 'Self Care (CAT)'
      and coalesce(pec.plan, '') not in ('closed', 'inactive')
),
contact as (select distinct on (account) * from smile03.account_contact order by account, contact_type)
select a.usn as "usn compte", coalesce(nullif(trim(ct.company_name), ''), ct.family_name) as "Nom / raison sociale",
       ct.given_name as "Prénom", ct.email_address as "E-mail actuel"
from cl
join smile03.account a on a.account = cl.account
join contact ct on ct.account = cl.account
where nullif(trim(ct.email_address), '') is not null
  and trim(ct.email_address) !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'  -- espaces autour : nettoyés à l'import, pas une erreur
order by 1;

\o
