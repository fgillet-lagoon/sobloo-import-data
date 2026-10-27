-- 08_charging_options : réductions Smile (onglet 5-Réductions, cas 13 et 14).
-- Dans Smile, une réduction est une « charging option » : une option de plan (planoption, groupe « charge » en général)
-- qui porte un frais (planautocharge) dont l'article a un tarif négatif (ex. alce « -5% Réduction AMCOM » → 003141, -212 XPF).
-- Un abonnement la souscrit comme une option (planscheduleoption) ; le tarif peut être surchargé par abonnement (psiplanautocharge).
-- La table discount n'est pas utilisée. Tarif catalogue : smile03.item_specification.default_rate.
-- Validité vérifiée sur l'option (validfrom / validto) et sur le frais (validfrom / validto) : beaucoup sont expirées.
-- Agrégats uniquement : codes et libellés du catalogue, comptages ; aucune donnée client.
-- Dans pgAdmin : 1) exécuter SEULES les deux lignes set ; 2) vérifier le coût avec « explain » devant « with » ;
-- 3) exécuter la requête (de « with » à la fin) ; exporter vers data/cartographie/08_charging_options.csv.

set default_transaction_read_only = on;
set statement_timeout = '5min';

-- Frais portés par les options de plan, avec tarif catalogue et validité
with frais_options as (
    select po.planoption, po.plan, po.option as code_option, po.name as option, coalesce(g.name, '?') as groupe,
           pa.planautocharge, pa.itemcode, it.name as article, it.default_rate as tarif,
           (po.validto is not null and po.validto < current_date)
             or (pa.validto is not null and pa.validto < current_date) as expiree
    from public.planoption po
    left join public.planoptiongroup g on g.planoptiongroup = po.planoptiongroup
    join public.planautocharge pa on pa.planoption = po.planoption
    left join smile03.item_specification it on it.item_code = pa.itemcode
),
options_reduction as (
    select planoption, plan, code_option, option, groupe, bool_or(expiree) as expiree, min(tarif) as tarif
    from frais_options
    where tarif < 0
    group by 1, 2, 3, 4, 5
),
-- Ligne de plan en cours des abonnements à reprendre (mêmes règles que sql/perimetre.sql)
plan_en_cours as (
    select distinct on (i.uid) i.uid as subscription, i.psi, i.plan
    from public.planscheduleitem i
    join public.planschedule p on p.planschedule = i.planschedule and p.active and p.planscheduletype = 1
    where i.startdate is not null and i.startdate <= current_date
    order by i.uid, i.startdate desc, i.starttime desc nulls last, i.psi desc
),
lignes_a_reprendre as (
    select pc.*
    from plan_en_cours pc
    join smile03.subscription s on s.subscription = pc.subscription
    join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
    left join smile03.service sv on sv.service = s.service
    where st.name in ('Active', 'Suspended')
      and coalesce(sv.name, '') <> 'Self Care (CAT)'
      and pc.plan not in ('closed', 'inactive')
),
-- Réductions souscrites par les abonnements à reprendre
reductions_souscrites as (
    select l.subscription, l.psi, r.*
    from lignes_a_reprendre l
    join public.planscheduleoption o on o.psi = l.psi
    join options_reduction r on r.planoption = o.planoption
)

-- Catalogue
select 'catalogue' as niveau, 'options de plan par groupe' as mesure, groupe as detail, count(distinct planoption) as nombre
from frais_options
group by 3
union all
select 'catalogue', 'options de réduction (frais à tarif négatif)', case when expiree then 'expirées' else 'valides' end, count(*)
from options_reduction
group by 3
union all
select 'catalogue', 'frais d''option sans tarif catalogue (à vérifier)', '', count(*)
from frais_options
where tarif is null

-- Réductions souscrites par les abonnements à reprendre
union all
select 'souscrites', 'abonnements avec au moins une réduction', '', count(distinct subscription)
from reductions_souscrites
union all
select 'souscrites', 'réductions souscrites', case when expiree then 'option ou frais expiré' else 'valide' end, count(*)
from reductions_souscrites
group by 3
union all
select 'souscrites', 'par option', code_option || ' — ' || option || ' (' || tarif || ' XPF' || case when expiree then ', expirée' else '' end || ')', count(*)
from reductions_souscrites
group by 3
union all
select 'souscrites', 'tarif surchargé sur l''abonnement', case
         when ppa.rate is null then 'tarif catalogue'
         when ppa.rate < 0 then 'autre tarif négatif'
         when ppa.rate = 0 then 'neutralisé (0)'
         else 'positif'
       end, count(*)
from reductions_souscrites r
join public.planautocharge pa on pa.planoption = r.planoption
left join public.psiplanautocharge ppa on ppa.psi = r.psi and ppa.planautocharge = pa.planautocharge
group by 3

-- Frais négatifs ajoutés directement à un abonnement à reprendre (hors options)
union all
select 'frais ajoutés', 'négatifs en cours', coalesce(u.itemcode, '?') || ' — ' || coalesce(it.name, '?'), count(*)
from public.userautocharge u
join lignes_a_reprendre l on l.subscription = u.uid
left join smile03.item_specification it on it.item_code = u.itemcode
where u.cancelled is null and (u.enddate is null or u.enddate > current_date)
  and coalesce(u.rate, it.default_rate) < 0
group by 3
order by 1, 2, 4 desc;
