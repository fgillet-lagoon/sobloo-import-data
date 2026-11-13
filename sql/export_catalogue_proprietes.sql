-- Inclus par export_catalogue.sql avec :famille (47 Internet, 50 VOIP).
-- Propriétés des abonnements à reprendre de la famille : identifiant de service (username) et champs personnalisés (custom).
-- AGRÉGATS UNIQUEMENT : nombre d'abonnements renseignés par propriété, aucune valeur client.
with pec as (
    select distinct on (i.uid) i.uid as subscription, i.plan
    from public.planscheduleitem i
    join public.planschedule p on p.planschedule = i.planschedule and p.active and p.planscheduletype = 1
    where i.startdate is not null and i.startdate <= current_date
    order by i.uid, i.startdate desc, i.starttime desc nulls last, i.psi desc
),
ab as (
    select sc.username, coalesce(sc.custom, '{}'::jsonb) as custom
    from smile03.subscription_custom sc
    join pec on pec.subscription = sc.subscription
    join smile03.subscription_status st on st.subscription_status::text = sc.subscription_status::text
    where st.name in ('Active', 'Suspended') and pec.plan not in ('closed', 'inactive') and sc.service = :famille
),
total as (select count(*) as n from ab),
proprietes as (
    select 'username' as code, 'Identifiant de service (champ standard)' as libelle, 'string' as type,
           count(*) filter (where nullif(trim(username), '') is not null) as renseignes
    from ab
    union all
    select k.key, coalesce(cf.name, ''), string_agg(distinct jsonb_typeof(k.value), ', '),
           count(*) filter (where nullif(trim(k.value #>> '{}'), '') is not null and k.value not in ('[]'::jsonb, '{}'::jsonb))
    from ab cross join lateral jsonb_each(ab.custom) k
    left join smile03.custom_fields cf on cf.code = k.key
    group by k.key, cf.name
)
select :famille as "id famille", p.code as "propriété (code Smile)", p.libelle as "libellé Smile", p.type as "type",
       p.renseignes as "abonnements renseignés", t.n as "abonnements à reprendre",
       round(100.0 * p.renseignes / nullif(t.n, 0), 1) as "taux %",
       p.code in ('contact', 'billingAddress', 'streetAddress', 'creationDate', 'creatingOperator', 'objectName') as "métadonnée Smile"
from proprietes p cross join total t
where p.renseignes > 0
order by 8, 5 desc, 2;
