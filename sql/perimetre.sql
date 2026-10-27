-- 07_perimetre : clients et abonnements réellement à reprendre (cas limites 5, 15, 16).
-- Agrégats uniquement, aucune ligne client.
-- Abonnement à reprendre = statut Active ou Suspended, hors Self Care (CAT) (accès portail, décision Lagoon du 27/10/2026),
-- et plan en cours qui n'est pas un état technique de fin (closed, inactive).
-- Client à reprendre = au moins un abonnement à reprendre.
-- Dans pgAdmin : 1) exécuter SEULES les deux lignes set ; 2) vérifier le coût avec « explain » devant « with » ;
-- 3) exécuter la requête (de « with » à la fin) ; exporter vers data/cartographie/07_perimetre.csv.

set default_transaction_read_only = on;
set statement_timeout = '5min';

with abonnements as (
    select s.subscription, s.account, coalesce(sv.name, '?') as service, coalesce(st.name, '?') as statut
    from smile03.subscription s
    left join smile03.service sv on sv.service = s.service
    left join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
),
-- Plan en cours : dernière ligne commencée du plan de facturation (type 1), même logique que sql/inventaire.sql
plan_en_cours as (
    select distinct on (i.uid) i.uid as subscription, i.plan
    from public.planscheduleitem i
    join public.planschedule p on p.planschedule = i.planschedule and p.active and p.planscheduletype = 1
    where i.startdate is not null and i.startdate <= current_date
    order by i.uid, i.startdate desc, i.starttime desc nulls last, i.psi desc
),
classes as (
    select a.*, pc.plan,
           case
             when a.statut not in ('Active', 'Suspended') then 'exclu : statut ' || a.statut
             when a.service = 'Self Care (CAT)' then 'exclu : Self Care'
             when pc.plan in ('closed', 'inactive') then 'exclu : plan technique ' || pc.plan
             else 'à reprendre'
           end as classe
    from abonnements a
    left join plan_en_cours pc on pc.subscription = a.subscription
),
clients as (
    select c.account,
           coalesce(t.name, '?') as type_compte,
           count(*) filter (where k.classe = 'à reprendre') as nb_a_reprendre,
           count(*) filter (where k.classe = 'exclu : Self Care') as nb_selfcare,
           count(k.subscription) as nb_abonnements
    from smile03.account c
    left join smile03.account_type t on t.account_type = c.account_type
    left join classes k on k.account = c.account
    group by c.account, t.name
)

-- Abonnements
select 'abonnements' as niveau, 'par classe' as mesure, classe as detail, count(*) as nombre
from classes
group by 3
union all
select 'abonnements', 'à reprendre par service', service, count(*)
from classes
where classe = 'à reprendre'
group by 3
union all
select 'abonnements', 'à reprendre par statut', statut, count(*)
from classes
where classe = 'à reprendre'
group by 3
union all
select 'abonnements', 'à reprendre sans plan en cours', '', count(*)
from classes
where classe = 'à reprendre' and plan is null
union all
select 'abonnements', 'à reprendre sur un plan de suspension', plan, count(*)
from classes
where classe = 'à reprendre' and plan in ('locked', 'freesusp')
group by 3

-- Clients
union all
select 'clients', 'par situation', case
         when nb_a_reprendre > 0 then 'à reprendre : au moins un abonnement à reprendre'
         when nb_selfcare > 0 then 'exclu : Self Care seul'
         when nb_abonnements > 0 then 'exclu : abonnements tous clôturés ou exclus'
         else 'exclu : aucun abonnement'
       end, count(*)
from clients
group by 3
union all
select 'clients', 'à reprendre par type de compte', type_compte, count(*)
from clients
where nb_a_reprendre > 0
group by 3
union all
select 'clients', 'à reprendre par nombre d''abonnements', case when nb_a_reprendre >= 5 then '5 et plus' else nb_a_reprendre::text end, count(*)
from clients
where nb_a_reprendre > 0
group by 3
order by 1, 2, 4 desc;
