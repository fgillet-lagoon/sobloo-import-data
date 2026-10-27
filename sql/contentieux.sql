-- 09_contentieux : comptes en contentieux ayant encore des abonnements à reprendre (cadrage onglet 2 n° 25, cas 22).
-- Un compte en contentieux ne devrait pas avoir d'abonnement actif : ces cas sont repris, mais signalés à Lagoon pour vérification.
-- Contentieux = disposition « Contentieux » ou « En retard - Contentieux » (décision Lagoon du 27/10/2026).
-- Abonnement à reprendre : mêmes règles que sql/perimetre.sql. Agrégats uniquement.
-- Dans pgAdmin : 1) exécuter SEULES les deux lignes set ; 2) vérifier le coût avec « explain » devant « with » ;
-- 3) exécuter la requête (de « with » à la fin) ; exporter vers data/cartographie/09_contentieux.csv.

set default_transaction_read_only = on;
set statement_timeout = '5min';

with plan_en_cours as (
    select distinct on (i.uid) i.uid as subscription, i.plan
    from public.planscheduleitem i
    join public.planschedule p on p.planschedule = i.planschedule and p.active and p.planscheduletype = 1
    where i.startdate is not null and i.startdate <= current_date
    order by i.uid, i.startdate desc, i.starttime desc nulls last, i.psi desc
),
abonnements_a_reprendre as (
    select s.subscription, s.account, coalesce(sv.name, '?') as service, st.name as statut
    from smile03.subscription s
    join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
    left join smile03.service sv on sv.service = s.service
    left join plan_en_cours pc on pc.subscription = s.subscription
    where st.name in ('Active', 'Suspended')
      and coalesce(sv.name, '') <> 'Self Care (CAT)'
      and coalesce(pc.plan, '') not in ('closed', 'inactive')
),
contentieux as (
    select a.account, d.name as disposition
    from smile03.account a
    join smile03.account_disposition d on d.account_disposition = a.account_disposition
    where d.name in ('Contentieux', 'En retard - Contentieux')
)

select 'comptes en contentieux' as mesure, c.disposition as detail, count(*) as nombre
from contentieux c
group by 2
union all
select 'dont avec au moins un abonnement à reprendre', c.disposition, count(*)
from contentieux c
where exists (select 1 from abonnements_a_reprendre x where x.account = c.account)
group by 2
union all
select 'abonnements à reprendre sur ces comptes, par statut', x.statut, count(*)
from contentieux c
join abonnements_a_reprendre x on x.account = c.account
group by 2
union all
select 'abonnements à reprendre sur ces comptes, par service', x.service, count(*)
from contentieux c
join abonnements_a_reprendre x on x.account = c.account
group by 2
order by 1, 3 desc;
