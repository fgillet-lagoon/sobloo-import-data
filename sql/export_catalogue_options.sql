-- Inclus deux fois par export_catalogue.sql : :nature = '3-option' ou '5-réduction'.
-- Options des plans du périmètre, utilisées ou encore valides sur un plan en vente. Une ligne par option × frais.
-- « réduction » = au moins un frais à prix négatif. Le calcul des doublons de codes (O4) porte sur options et réductions ensemble.
with recursive arbre as (
    select salesreportitem, parentitem, itemdescription, name::text as chemin
    from reports.salesreportitem where salesreport = 247 and parentitem is null
    union all
    select c.salesreportitem, c.parentitem, c.itemdescription, a.chemin || ' > ' || c.name
    from reports.salesreportitem c join arbre a on c.parentitem = a.salesreportitem
),
categorie as (
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
usage_options as (
    select o.planoption, count(*) as nb from lar join public.planscheduleoption o on o.psi = lar.psi group by 1
),
perimetre as (
    select * from (
        select p.plan, p.company, sp.service, coalesce(u.nb, 0) as nb_abonnements,
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
options as (
    select po.*, pe.service, pe.en_vente as plan_en_vente, coalesce(uo.nb, 0) as nb_souscriptions,
           (po.validfrom is null or po.validfrom <= current_date) and (po.validto is null or po.validto >= current_date) as valide
    from public.planoption po
    join perimetre pe on pe.plan = po.plan
    left join usage_options uo on uo.planoption = po.planoption
    where (po.option || ' ' || coalesce(po.name, '')) !~* :'exclusion_texte'
),
-- Lagoon 13/11/2026 : option ou réduction dont la date de fin de validité est dépassée exclue, même si encore souscrite
options_perimetre as (
    select * from options
    where (validto is null or validto >= current_date) and (nb_souscriptions > 0 or (valide and plan_en_vente))
),
-- Lagoon 13/11/2026 : une ligne par option, prix = frais récurrent le plus récent (en cours, sinon le dernier commencé)
frais as (
    select distinct on (pa.planoption) pa.planoption, pa.itemcode, fr.name as frequence, pa.frequencyunits, m.name as mode,
           (pa.validfrom is null or pa.validfrom <= current_date) and (pa.validto is null or pa.validto >= current_date) as en_cours
    from public.planautocharge pa
    left join smile03.recurring_charge_frequency_type fr on fr.recurring_charge_frequency_type = pa.frequencytype
    left join smile03.recurring_charge_mode m on m.recurring_charge_mode = pa.chargingmode
    where pa.planoption is not null
    order by pa.planoption, 6 desc, pa.validfrom desc nulls last, pa.planautocharge desc
),
reductions as (  -- réduction = prix le plus récent négatif
    select f.planoption
    from frais f join public.itemdescription i on i.itemcode = f.itemcode and i.company = 1
    where i.rate < 0
),
taux as (
    select distinct on (tax_treatment) tax_treatment, percentage_rate
    from smile03.tax_schedule_item where tax_schedule = 1 and start_date <= current_date
    order by tax_treatment, start_date desc
),
codes as (
    select lower(plan) as c from perimetre
    union all
    select lower(option) from options_perimetre
),
doublons as (select c from codes group by c having count(*) > 1)
select o.plan as "plan (article parent)", o.service as "id famille", sv.name as "famille (service)", o.option as "code Smile",
       case when d.c is null then o.option else o.plan || '-' || o.option end as "code proposé (variant.code)",
       (d.c is not null) as "code en doublon",
       o.name as "désignation", coalesce(g.name, '') as "groupe d'options", dt.name as "type d'affichage", o.required as "obligatoire",
       o.minquantity as "qté min", o.maxquantity as "qté max",
       o.nb_souscriptions as "souscriptions à reprendre", o.valide as "option valide", o.validfrom as "valide du", o.validto as "valide au",
       o.plan_en_vente as "plan en vente",
       f.en_cours as "frais en cours", f.itemcode as "code frais Smile", i.name as "libellé frais",
       coalesce(i.rate, 0) as "prix HT", i.currency as "devise",
       f.frequence as "fréquence", f.frequencyunits as "multiple", f.mode as "mode de facturation",
       t.glcode as "compte de vente", t.name as "libellé compte", tt.name as "taxe", tx.percentage_rate as "taux taxe %",
       cat.chemin as "catégorie rapport des ventes",
       nullif(o.setupchargecode, '') as "code frais mise en service", ims.rate as "prix HT mise en service"
from options_perimetre o
join smile03.service sv on sv.service = o.service
left join public.planoptiongroup g on g.planoptiongroup = o.planoptiongroup
left join smile03.plan_option_display_type dt on dt.plan_option_display_type = o.displaytype
left join reductions r on r.planoption = o.planoption
left join doublons d on d.c = lower(o.option)
left join frais f on f.planoption = o.planoption
left join public.itemdescription i on i.itemcode = f.itemcode and i.company = o.company
left join public.txdescription t on t.txcode = i.txcode and t.company = i.company
left join smile03.tax_treatment tt on tt.tax_treatment = i.taxtreatment
left join taux tx on tx.tax_treatment = i.taxtreatment
left join categorie cat on cat.itemdescription = i.itemdescription
left join public.itemdescription ims on ims.itemcode = o.setupchargecode and ims.company = o.company
where case when r.planoption is null then '3-option' else '5-réduction' end = :'nature'
order by 1, 4;
