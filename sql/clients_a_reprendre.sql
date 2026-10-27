-- 10_clients_a_reprendre : chiffres de l'onglet 2-Clients recalculés sur les seuls clients à reprendre
-- (au moins un abonnement à reprendre, mêmes règles que sql/perimetre.sql), et non plus sur les 57 600 comptes Smile.
-- Agrégats uniquement : comptages, aucune valeur.
-- Dans pgAdmin : 1) exécuter SEULES les deux lignes set ; 2) vérifier le coût avec « explain » devant « with » ;
-- 3) exécuter la requête (de « with » à la fin) ; exporter vers data/cartographie/10_clients_a_reprendre.csv.

set default_transaction_read_only = on;
set statement_timeout = '5min';

with plan_en_cours as (
    select distinct on (i.uid) i.uid as subscription, i.plan
    from public.planscheduleitem i
    join public.planschedule p on p.planschedule = i.planschedule and p.active and p.planscheduletype = 1
    where i.startdate is not null and i.startdate <= current_date
    order by i.uid, i.startdate desc, i.starttime desc nulls last, i.psi desc
),
abonnements as (
    select s.subscription, s.account, coalesce(sv.name, '') as service, st.name as statut, pc.plan
    from smile03.subscription s
    join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
    left join smile03.service sv on sv.service = s.service
    left join plan_en_cours pc on pc.subscription = s.subscription
),
clients as (
    select distinct account
    from abonnements
    where statut in ('Active', 'Suspended') and service <> 'Self Care (CAT)' and coalesce(plan, '') not in ('closed', 'inactive')
),
-- Indicateurs portés par l'abonnement Self Care actif du client
selfcare as (
    select s.account,
           bool_or(lower(trim(s.custom ->> 'limited_access')) = 'true') as acces_limite,
           bool_or(lower(trim(s.custom ->> 'retailerAccount')) = 'true') as revendeur
    from smile03.subscription_custom s
    join abonnements a on a.subscription = s.subscription
    where a.service = 'Self Care (CAT)' and a.statut in ('Active', 'Suspended')
    group by s.account
),
fiche as (
    select c.account,
           nullif(trim(ac.custom ->> 'Procuration_'), '') is not null as procuration,
           nullif(trim(ac.custom ->> 'ConsoPlusID'), '') as conso_plus,
           nullif(trim(ac.custom ->> 'lieu_naissance'), '') is not null as lieu_naissance,
           nullif(trim(ct.abn), '') as ridet,
           nullif(trim(ct.email_address), '') as email,
           length(regexp_replace(coalesce(ct.phone_mobile, ''), '\D', '', 'g')) as chiffres_mobile,
           length(regexp_replace(coalesce(ct.phone_home, ''), '\D', '', 'g')) as chiffres_fixe,
           ct.date_of_birth is not null as date_naissance,
           coalesce(sc.acces_limite, false) as acces_limite,
           coalesce(sc.revendeur, false) as revendeur
    from clients c
    join smile03.account_custom ac on ac.account = c.account
    left join smile03.account_contact ct on ct.account = c.account
    left join selfcare sc on sc.account = c.account
)

select 'clients à reprendre' as mesure, '' as detail, count(*) as nombre from fiche
union all
select 'procuration renseignée', '', count(*) from fiche where procuration
union all
select 'accès limité', '', count(*) from fiche where acces_limite
union all
select 'revendeur', '', count(*) from fiche where revendeur
union all
select 'N° Conso+ renseigné', '', count(*) from fiche where conso_plus is not null
union all
select 'N° Conso+ en double (lignes en trop)', '', count(conso_plus) - count(distinct conso_plus) from fiche
union all
select 'RIDET renseigné', '', count(ridet) from fiche
union all
select 'e-mail renseigné', '', count(email) from fiche
union all
select 'e-mail au format invalide', '', count(*) from fiche where email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
union all
select 'date de naissance renseignée', '', count(*) from fiche where date_naissance
union all
select 'lieu de naissance renseigné', '', count(*) from fiche where lieu_naissance
union all
select 'téléphones à 12 chiffres', 'mobile', count(*) from fiche where chiffres_mobile = 12
union all
select 'téléphones à 12 chiffres', 'fixe', count(*) from fiche where chiffres_fixe = 12
union all
select 'téléphones de longueur anormale (hors 0, 6, 8, 10, 12)', '', count(*) from fiche
where chiffres_mobile not in (0, 6, 8, 10, 12) or chiffres_fixe not in (0, 6, 8, 10, 12)
union all
select 'adresses 0 et 1 différentes', '', count(*)
from clients c
join smile03.account_address a0 on a0.account = c.account and a0.address_type = 0
join smile03.account_address a1 on a1.account = c.account and a1.address_type = 1
where a0.address_detail is distinct from a1.address_detail
   or a0.suburb is distinct from a1.suburb
   or a0.postcode is distinct from a1.postcode
order by 1, 2;
