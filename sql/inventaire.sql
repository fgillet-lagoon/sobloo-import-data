-- 04_inventaire : comptages de référence par lot, depuis les vues de reporting smile03.
-- Agrégats uniquement, aucune ligne client. Sert de base aux contrôles de recette (lus = créés + mis à jour + en erreur).
-- Cadrage : cas limites 1, 24 (sources), 25 (volumétrie) ; R3 du plan (référence Smile unique et obligatoire).
-- Dans pgAdmin : voir les garde-fous ci-dessous, puis exécuter la requête (de « with » à la fin), exporter en CSV vers data/cartographie/04_inventaire.csv.
-- « En cours » = sans date de fin ou date de fin future (now()) ; les statuts sont détaillés pour arbitrage (cas 15, 16).

-- Garde-fous PROD : sélectionner et exécuter SEULES ces deux lignes d'abord (F5), puis la requête.
-- Exécutées dans le même lot que la requête, elles ne s'appliquent pas.
set default_transaction_read_only = on;
set statement_timeout = '5min';

-- Lignes de plan en cours : calculées sur public.planscheduleitem (fin = début de la ligne suivante du même plan),
-- car le filtre sur smile03.subscription_plan_schedule_item.end_time coûte ~18 M par appel (calcul ligne à ligne).
-- shortcut: approximation de end_time de la vue smile03 (sans fuseau horaire), à recouper sur un échantillon avant la recette.
-- planscheduletype 1 = « Accounting plan schedule » (facturation, lignes successives) ; 2 = « Refund plan schedule »
-- (remboursements, surtout le plan « inactive », souvent sans date) : seul le type 1 compte (diagnostic du 27/10/2026).
-- Les lignes sans date de début sont ignorées.
with lignes_plan as (
    select i.psi, i.uid as subscription, i.plan, s.planscheduletype as type_plan,
           lead(i.startdate) over (partition by i.planschedule order by i.startdate, i.starttime nulls first, i.psi) as fin
    from public.planscheduleitem i
    join public.planschedule s on s.planschedule = i.planschedule and s.active
    where i.startdate is not null
      and s.planscheduletype = 1
),
-- En cours = ligne non terminée ET abonnement Active ou Suspended, hors Self Care (CAT) :
-- accès au portail client, pas un abonnement facturable (décision Lagoon du 27/10/2026).
lignes_en_cours as (
    select l.*
    from lignes_plan l
    join smile03.subscription s on s.subscription = l.subscription
    join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
    left join smile03.service sv on sv.service = s.service
    where (l.fin is null or l.fin > current_date)
      and st.name in ('Active', 'Suspended')
      and coalesce(sv.name, '') <> 'Self Care (CAT)'
)

-- Lot 1 : comptes comptables et familles
select 'L1' as lot, 'comptes de reporting (GL)' as indicateur, '' as detail, count(*) as nombre
from smile03.reporting_account
union all
select 'L1', 'comptes de reporting (GL) actifs', '', count(*)
from smile03.reporting_account
where not_after is null or not_after > now()
union all
select 'L1', 'services (familles candidates)', '', count(*)
from smile03.service
union all
select 'L1', 'traitements de taxe', name, 1
from smile03.tax_treatment

-- Lot 2 : clients
union all
select 'L2', 'comptes par type / statut', coalesce(t.name, '?') || ' / ' || coalesce(s.name, a.account_status::text, '?'), count(*)
from smile03.account a
left join smile03.account_type t on t.account_type = a.account_type
left join smile03.account_status s on s.account_status::text = a.account_status::text
group by 3
union all
select 'L2', 'comptes sans usn', '', count(*)
from smile03.account
where usn is null or trim(usn) = ''
union all
select 'L2', 'usn de compte en double (lignes en trop)', '', count(*) - count(distinct usn)
from smile03.account
union all
select 'L2', 'comptes désactivés', '', count(*)
from smile03.account
where deactivated_time is not null
union all
select 'L2', 'comptes par mode de paiement', coalesce(pt.name, '?') || case when c.auto_payment_enabled then ' / prélèvement auto' else '' end, count(*)
from smile03.account_payment_configuration c
left join smile03.payment_type pt on pt.payment_type = c.payment_type
group by 3
union all
select 'L2', 'comptes par conditions de paiement', coalesce(at.name, '?'), count(*)
from smile03.account a
left join smile03.account_terms at on at.account_terms = a.account_terms
group by 3
union all
select 'L2', 'comptes par disposition (contentieux…)', coalesce(d.name, '(aucune)'), count(*)
from smile03.account a
left join smile03.account_disposition d on d.account_disposition = a.account_disposition
group by 3
union all
select 'L2', 'contacts de compte par type', contact_type::text, count(*)
from smile03.account_contact
group by 3
union all
select 'L2', 'adresses de compte par type', address_type::text, count(*)
from smile03.account_address
group by 3
union all
select 'L2', 'comptes avec réduction', '', count(*)
from smile03.account
where discount is not null
union all
select 'L2', 'centres de coût', '', count(*)
from smile03.account_cost_centre

-- Lots 3 et 4 : catalogue
union all
select 'L3-4', 'plans (articles) par service', coalesce(sv.name, '?'), count(*)
from smile03.plan p
left join smile03.service sv on sv.service = p.service
group by 3
union all
select 'L3-4', 'plans encore disponibles', '', count(*)
from smile03.plan
where last_available_date is null or last_available_date > now()
union all
select 'L3-4', 'plans utilisés par un abonnement en cours', '', count(distinct plan)
from lignes_en_cours
union all
-- Plans de cycle de vie (active, locked, closed, inactive, freesusp) : états du service, pas des articles commerciaux (à confirmer)
select 'L6', 'abonnements en cours par plan de cycle de vie', plan, count(distinct subscription)
from lignes_en_cours
where plan in ('active', 'locked', 'closed', 'inactive', 'freesusp')
group by 3
union all
select 'L3-4', 'groupes d''options', '', count(*)
from smile03.plan_option_group
union all
select 'L3-4', 'options', '', count(*)
from smile03.plan_option
union all
select 'L3-4', 'options utilisées par un abonnement en cours', '', count(distinct o.planoption)
from public.planscheduleoption o
join lignes_en_cours l on l.psi = o.psi
group by 3
union all
select 'L3-4', 'contrats (modèles)', '', count(*)
from smile03.contract

-- Lot 5 : réductions
union all
select 'L5', 'réductions par mode / comportement', coalesce(mode, '?') || ' / ' || coalesce(discount_behaviour, '?'), count(*)
from smile03.discount
group by 3
union all
select 'L5', 'réductions valides aujourd''hui', '', count(*)
from smile03.discount
where (valid_from is null or valid_from <= current_date) and (valid_to is null or valid_to >= current_date)
union all
select 'L5', 'abonnements avec réduction', '', count(*)
from smile03.subscription
where discount is not null
union all
select 'L5', 'frais récurrents en cours (hors plan)', '', count(*)
from smile03.recurring_charge
where cancellation_time is null and (end_date is null or end_date > now())

-- Lot 6 : abonnements
union all
select 'L6', 'abonnements par service / statut', coalesce(sv.name, '?') || ' / ' || coalesce(st.name, s.subscription_status::text, '?'), count(*)
from smile03.subscription s
left join smile03.service sv on sv.service = s.service
left join smile03.subscription_status st on st.subscription_status::text = s.subscription_status::text
group by 3
union all
select 'L6', 'abonnements sans usn', '', count(*)
from smile03.subscription
where usn is null or trim(usn) = ''
union all
select 'L6', 'usn d''abonnement en double (lignes en trop)', '', count(*) - count(distinct usn)
from smile03.subscription
union all
select 'L6', 'usn communs compte / abonnement', '', count(*)
from smile03.subscription s
join smile03.account a on a.usn = s.usn
union all
select 'L6', 'abonnements avec plan en cours', '', count(distinct subscription)
from lignes_en_cours
group by 3
union all
select 'L6', 'lignes de plan en cours', '', count(*)
from lignes_en_cours
group by 3
union all
select 'L6', 'abonnements avec plusieurs plans en cours', '', count(*)
from (select subscription, type_plan
      from lignes_en_cours
      group by subscription, type_plan
      having count(*) > 1) x
group by 3
union all
select 'L6', 'contrats d''abonnement en cours', '', count(*)
from smile03.subscription_contract
where termination_date is null and (end_date is null or end_date > now())
union all
select 'L6', 'abonnements avec centre de coût', '', count(*)
from smile03.subscription
where account_cost_centre is not null
union all
select 'L6', 'champs personnalisés définis', code || ' — ' || coalesce(name, ''), 1
from smile03.custom_fields
order by 1, 2, 3;
